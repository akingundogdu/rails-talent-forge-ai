class Goal < ApplicationRecord
  include Cacheable

  # Associations
  belongs_to :employee
  belongs_to :performance_review, optional: true

  # Enums
  enum status: {
    active: 0,
    completed: 1,
    cancelled: 2,
    overdue: 3,
    paused: 4
  }, _prefix: true

  enum priority: {
    low: 0,
    medium: 1,
    high: 2,
    critical: 3
  }, _prefix: true

  # Validations
  validates :title, presence: true, length: { minimum: 3, maximum: 150 }
  validates :description, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :target_value, presence: true, numericality: { greater_than: 0 }
  validates :actual_value, numericality: { greater_than_or_equal_to: 0 }
  validates :due_date, presence: true
  validate :due_date_in_future
  validate :target_value_greater_than_actual

  # Soft delete
  acts_as_paranoid

  # Scopes
  scope :active_goals, -> { where(status: :active) }
  scope :completed_goals, -> { where(status: :completed) }
  scope :overdue_goals, -> { where('due_date < ? AND status = ?', Date.current, 0) }
  scope :due_soon, ->(days = 7) { where('due_date <= ? AND status = ?', days.days.from_now, 0) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :for_review, ->(review_id) { where(performance_review_id: review_id) }
  scope :standalone, -> { where(performance_review_id: nil) }

  # Callbacks
  before_save :update_completion_status
  before_save :set_completed_at, if: :will_save_change_to_status?
  after_commit :invalidate_caches
  after_touch :invalidate_caches
  after_update :check_overdue_status

  # Business Methods
  def completion_percentage
    return 0 if target_value.zero?
    percentage = (actual_value / target_value * 100).round(2)
    [percentage, 100].min # Cap at 100%
  end

  alias_method :progress_percentage, :completion_percentage

  def is_overdue?
    due_date < Date.current && status_active?
  end

  def days_until_due
    (due_date - Date.current).to_i
  end

  alias_method :days_remaining, :days_until_due

  def days_overdue
    return 0 unless is_overdue?
    (Date.current - due_date).to_i
  end

  def progress_status
    return 'completed' if status_completed?
    return 'overdue' if is_overdue?
    return 'on_track' if completion_percentage >= expected_progress_percentage
    return 'behind_schedule'
  end

  def expected_progress_percentage
    return 0 if due_date <= created_at.to_date
    
    total_days = (due_date - created_at.to_date).to_i
    elapsed_days = (Date.current - created_at.to_date).to_i
    
    return 100 if elapsed_days >= total_days
    return 0 if elapsed_days <= 0
    
    (elapsed_days.to_f / total_days * 100).round(2)
  end

  def update_progress!(new_actual_value, notes = nil)
    return false if status_completed? || status_cancelled?
    
    transaction do
      self.actual_value = new_actual_value
      self.description = [description, "Progress Update: #{notes}"].compact.join("\n\n") if notes.present?
      
      if actual_value >= target_value
        self.status = :completed
        self.completed_at = Time.current
      end
      
      save!
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def mark_completed!(completion_notes = nil)
    return false unless status_active?
    
    transaction do
      update!(
        status: :completed,
        actual_value: target_value,
        completed_at: Time.current,
        description: [description, "Completed: #{completion_notes}"].compact.join("\n\n")
      )
    end
    true
  end

  def pause!(reason = nil)
    return false unless status_active?
    
    transaction do
      update!(
        status: :paused,
        description: [description, "Paused: #{reason}"].compact.join("\n\n")
      )
    end
    true
  end

  def resume!(notes = nil)
    return false unless status_paused?
    
    transaction do
      update!(
        status: :active,
        description: [description, "Resumed: #{notes}"].compact.join("\n\n")
      )
    end
    true
  end

  def cancel!(reason = nil)
    return false if status_completed?
    
    transaction do
      update!(
        status: :cancelled,
        description: [description, "Cancelled: #{reason}"].compact.join("\n\n")
      )
    end
    true
  end

  # SMART Goal validation
  def is_smart_goal?
    {
      specific: title.present? && description.present?,
      measurable: target_value.present? && target_value > 0,
      achievable: target_value <= (actual_value * 5), # Reasonable multiplier
      relevant: employee.present?,
      time_bound: due_date.present? && due_date > Date.current
    }
  end

  def smart_score
    smart_criteria = is_smart_goal?
    achieved_criteria = smart_criteria.values.count(true)
    (achieved_criteria.to_f / smart_criteria.length * 100).round(2)
  end

  # Search functionality
  def self.search(query)
    return all if query.blank?
    
    joins(:employee)
      .where(
        "goals.title ILIKE ? OR goals.description ILIKE ? OR employees.first_name ILIKE ? OR employees.last_name ILIKE ?",
        "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
      )
  end

  # Bulk operations
  def self.bulk_update_progress(goal_updates)
    transaction do
      goal_updates.each do |goal_id, progress_data|
        goal = find(goal_id)
        goal.update_progress!(progress_data[:actual_value], progress_data[:notes])
      end
    end
  end

  def smart_compliant?
    # SMART criteria: Specific, Measurable, Achievable, Relevant, Time-bound
    specific = title.present? && title.length > 10
    measurable = target_value.present? && target_value > 0
    achievable = target_value.present? && target_value <= 1000000 # Reasonable upper limit
    relevant = employee.present?
    time_bound = due_date.present? && due_date > Date.current
    
    specific && measurable && achievable && relevant && time_bound
  end

  def smart_violations
    violations = []
    
    violations << "Title must be specific (at least 10 characters)" unless title.present? && title.length > 10
    violations << "Target value must be measurable (greater than 0)" unless target_value.present? && target_value > 0
    violations << "Target value must be achievable (reasonable limit)" unless target_value.present? && target_value <= 1000000
    violations << "Goal must be relevant (employee must be assigned)" unless employee.present?
    violations << "Goal must be time-bound (due date in future)" unless due_date.present? && due_date > Date.current
    
    violations
  end

  private

  def due_date_in_future
    return unless due_date
    return if persisted? # Skip validation for existing records
    
    if due_date <= Date.current
      errors.add(:due_date, 'must be in the future')
    end
  end

  def target_value_greater_than_actual
    return unless target_value && actual_value
    
    if actual_value > target_value
      errors.add(:actual_value, 'cannot exceed target value')
    end
  end

  def update_completion_status
    if actual_value_changed? && actual_value >= target_value && status_active?
      self.status = :completed
    end
  end

  def set_completed_at
    if status_completed? && completed_at.blank?
      self.completed_at = Time.current
    elsif !status_completed? && completed_at.present?
      self.completed_at = nil
    end
  end

  def check_overdue_status
    if is_overdue? && status_active?
      update_column(:status, :overdue)
    end
  end

  def invalidate_caches
    CacheService.invalidate_goal_caches(employee_id)
  end
end 