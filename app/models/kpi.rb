class Kpi < ApplicationRecord
  include Cacheable

  # Associations
  belongs_to :employee
  belongs_to :position, optional: true
  belongs_to :goal, optional: true

  # Enums
  enum status: {
    active: 0,
    completed: 1,
    cancelled: 2,
    archived: 3
  }, _prefix: true

  enum measurement_unit: {
    number: 'number',
    percentage: 'percentage', 
    currency: 'currency',
    hours: 'hours',
    days: 'days',
    total_count: 'total_count',
    ratio: 'ratio'
  }, _prefix: false

  enum measurement_period: {
    daily: 'daily',
    weekly: 'weekly',
    monthly: 'monthly',
    quarterly: 'quarterly',
    annually: 'annually'
  }, _prefix: false

  # Validations
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :description, presence: true, length: { minimum: 10, maximum: 500 }
  validates :target_value, presence: true, numericality: { greater_than: 0 }
  validates :actual_value, numericality: { greater_than_or_equal_to: 0 }
  validates :period_start, :period_end, presence: true
  validates :measurement_unit, presence: true
  validate :period_end_after_start
  validate :target_value_reasonable_for_unit

  # Soft delete
  acts_as_paranoid

  # Scopes
  scope :active_kpis, -> { where(status: :active) }
  scope :completed_kpis, -> { where(status: :completed) }
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :for_position, ->(position_id) { where(position_id: position_id) }
  scope :current_period, -> { where('period_start <= ? AND period_end >= ?', Date.current, Date.current) }
  scope :in_period, ->(start_date, end_date) { where('period_start <= ? AND period_end >= ?', end_date, start_date) }
  scope :by_measurement_unit, ->(unit) { where(measurement_unit: unit) }
  scope :underperforming, -> { where('(actual_value / target_value) < 0.8') }
  scope :overperforming, -> { where('(actual_value / target_value) > 1.2') }

  # Callbacks
  before_save :update_completion_status
  after_commit :invalidate_caches
  after_touch :invalidate_caches

  # Business Methods
  def achievement_percentage
    return 0 if target_value.nil? || target_value.zero?
    ((actual_value || 0).to_f / target_value * 100).round(2)
  end

  def achievement_status
    percentage = achievement_percentage
    
    case percentage
    when 0...50
      'poor'
    when 50...80
      'below_target'
    when 80...100
      'approaching_target'
    when 100...120
      'target_met'
    else
      'exceeds_target'
    end
  end

  def is_overdue?
    period_end < Date.current && !status_completed?
  end

  def days_until_period_end
    (period_end - Date.current).to_i
  end

  def period_duration_days
    (period_end - period_start).to_i
  end

  def elapsed_period_percentage
    return 100 if period_end <= Date.current
    return 0 if period_start > Date.current
    
    total_days = period_duration_days
    elapsed_days = (Date.current - period_start).to_i
    
    (elapsed_days.to_f / total_days * 100).round(2)
  end

  def expected_progress
    return target_value if period_end <= Date.current
    return 0 if period_start > Date.current
    
    (target_value * elapsed_period_percentage / 100).round(2)
  end

  def progress_variance
    (actual_value - expected_progress).round(2)
  end

  def is_on_track?
    progress_variance >= -(target_value * 0.1) # Within 10% of expected
  end

  def formatted_value
    case measurement_unit
    when 'percentage'
      "#{actual_value}%"
    when 'currency'
      "$#{actual_value}"
    when 'hours'
      "#{actual_value}h"
    when 'days'
      "#{actual_value} days"
    else
      actual_value.to_s
    end
  end

  def formatted_target
    case measurement_unit
    when 'percentage'
      "#{target_value}%"
    when 'currency'
      "$#{target_value}"
    when 'hours'
      "#{target_value}h"
    when 'days'
      "#{target_value} days"
    else
      target_value.to_s
    end
  end

  def formatted_actual
    case measurement_unit
    when 'percentage'
      "#{actual_value}%"
    when 'currency'
      "$#{actual_value}"
    when 'hours'
      "#{actual_value}h"
    when 'days'
      "#{actual_value} days"
    else
      actual_value.to_s
    end
  end

  def update_progress!(new_actual_value, notes = nil)
    return false if status_completed? || status_cancelled?
    
    transaction do
      self.actual_value = new_actual_value
      self.description = [description, "Progress Update: #{notes}"].compact.join("\n\n") if notes.present?
      
      # Auto-complete if target reached and period ended
      if actual_value >= target_value && period_end <= Date.current
        self.status = :completed
      end
      
      save!
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def complete!(completion_notes = nil)
    return false unless can_be_completed?
    
    transaction do
      update!(
        status: :completed,
        description: [description, "Completed: #{completion_notes}"].compact.join("\n\n")
      )
    end
    true
  end

  def archive!(reason = nil)
    return false if status_archived?
    
    transaction do
      update!(
        status: :archived,
        description: [description, "Archived: #{reason}"].compact.join("\n\n")
      )
    end
    true
  end

  def can_be_completed?
    status_active? && (achievement_percentage >= 100 || period_end <= Date.current)
  end

  def trend_direction
    # Simple trend based on progress variance
    if progress_variance > (target_value * 0.1)
      :up
    elsif progress_variance < -(target_value * 0.1)
      :down
    else
      :stable
    end
  end

  # Analytics Methods
  def self.department_performance_summary(department_id, period_start, period_end)
    employee_ids = Employee.joins(:position).where(positions: { department_id: department_id }).pluck(:id)
    kpis = in_period(period_start, period_end).where(employee_id: employee_ids)
    
    {
      total_kpis: kpis.count,
      completed_kpis: kpis.completed_kpis.count,
      average_achievement: kpis.average('actual_value / target_value * 100')&.round(2) || 0,
      underperforming_count: kpis.underperforming.count,
      overperforming_count: kpis.overperforming.count
    }
  end

  def self.position_benchmarks(position_id, measurement_unit)
    where(position_id: position_id, measurement_unit: measurement_unit)
      .group(:name)
      .average('actual_value / target_value * 100')
  end

  def self.trending_analysis(employee_id, kpi_name, months = 6)
    start_date = months.months.ago
    
    kpis = where(employee_id: employee_id, name: kpi_name)
           .where('period_start >= ?', start_date)
           .order(:period_start)
    
    kpis.map do |kpi|
      {
        period: "#{kpi.period_start.strftime('%b %Y')}",
        achievement_percentage: kpi.achievement_percentage,
        actual_value: kpi.actual_value,
        target_value: kpi.target_value
      }
    end
  end

  # Search functionality
  def self.search(query)
    return all if query.blank?
    
    joins(:employee)
      .where(
        "kpis.name ILIKE ? OR kpis.description ILIKE ? OR employees.first_name ILIKE ? OR employees.last_name ILIKE ?",
        "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
      )
  end

  # Bulk operations
  def self.bulk_create_for_position(position_id, kpi_templates)
    employee_ids = Employee.where(position_id: position_id).pluck(:id)
    
    transaction do
      employee_ids.each do |employee_id|
        kpi_templates.each do |template|
          create!(
            employee_id: employee_id,
            position_id: position_id,
            name: template[:name],
            description: template[:description],
            target_value: template[:target_value],
            measurement_unit: template[:measurement_unit],
            period_start: template[:period_start],
            period_end: template[:period_end]
          )
        end
      end
    end
  end

  private

  def period_end_after_start
    return unless period_start && period_end
    
    if period_end <= period_start
      errors.add(:period_end, 'must be after period start')
    end
  end

  def target_value_reasonable_for_unit
    return unless target_value && measurement_unit
    
    case measurement_unit
    when 'percentage'
      if target_value > 100
        errors.add(:target_value, 'cannot exceed 100 for percentage')
      end
    when 'ratio'
      if target_value > 10
        errors.add(:target_value, 'ratio should typically be under 10')
      end
    end
  end

  def update_completion_status
    if period_end_changed? && period_end <= Date.current && achievement_percentage >= 100
      self.status = :completed
    end
  end

  def invalidate_caches
    CacheService.invalidate_kpi_caches(employee_id, position_id)
  end
end 