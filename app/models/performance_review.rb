class PerformanceReview < ApplicationRecord
  include Cacheable

  # Associations
  belongs_to :employee
  belongs_to :reviewer, class_name: 'Employee'
  has_many :goals, dependent: :destroy
  has_many :feedbacks, dependent: :destroy
  has_many :ratings, dependent: :destroy

  # Enums
  enum status: {
    draft: 0,
    in_progress: 1,
    completed: 2,
    archived: 3
  }, _prefix: true

  enum review_type: {
    annual: 0,
    mid_year: 1,
    quarterly: 2,
    probation: 3,
    promotion: 4
  }, _prefix: true

  # Validations
  validates :title, presence: true, length: { minimum: 3, maximum: 100 }
  validates :start_date, :end_date, presence: true
  validates :review_type, :status, presence: true
  validate :end_date_after_start_date
  validate :reviewer_not_same_as_employee
  validate :reviewer_authority_check

  # Soft delete
  acts_as_paranoid

  # Scopes
  scope :active, -> { where(status: [:draft, :in_progress]) }
  scope :completed_in_period, ->(start_date, end_date) { 
    where(status: :completed, completed_at: start_date..end_date) 
  }
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :by_reviewer, ->(reviewer_id) { where(reviewer_id: reviewer_id) }
  scope :overdue, -> { where('end_date < ? AND status IN (?)', Date.current, [0, 1]) }

  # Callbacks
  before_save :set_completed_at, if: :will_save_change_to_status?
  after_commit :invalidate_caches
  after_touch :invalidate_caches

  # Business Methods
  def overall_score
    return 0 if ratings.empty?
    
    total_weighted_score = ratings.sum { |rating| rating.score * rating.weight }
    total_weight = ratings.sum(&:weight)
    
    return 0 if total_weight.zero?
    (total_weighted_score / total_weight).round(2)
  end

  def completion_percentage
    return 0 if goals.empty?
    completed_goals = goals.where(status: :completed).count
    (completed_goals.to_f / goals.count * 100).round(2)
  end

  def feedback_summary
    {
      total_count: feedbacks.count,
      by_type: feedbacks.group(:feedback_type).count,
      average_rating: feedbacks.where.not(rating: nil).average(:rating)&.round(2) || 0
    }
  end

  def is_overdue?
    end_date < Date.current && !status_completed?
  end

  def days_until_due
    (end_date - Date.current).to_i
  end

  def can_be_completed?
    status_in_progress? && goals.where(status: :active).empty?
  end

  def submit_for_review!
    return false unless status_draft?
    
    transaction do
      update!(status: :in_progress)
      # Notify reviewer
      # PerformanceReviewMailer.review_submitted(self).deliver_later
    end
    true
  end

  def complete_review!(overall_comments = nil)
    return false unless can_be_completed?
    
    transaction do
      update!(
        status: :completed, 
        completed_at: Time.current,
        description: [description, overall_comments].compact.join("\n\n")
      )
      # Notify employee
      # PerformanceReviewMailer.review_completed(self).deliver_later
    end
    true
  end

  # Search functionality
  def self.search(query)
    return all if query.blank?
    
    joins(:employee)
      .where(
        "performance_reviews.title ILIKE ? OR employees.first_name ILIKE ? OR employees.last_name ILIKE ?",
        "%#{query}%", "%#{query}%", "%#{query}%"
      )
  end

  def feedbacks_count
    feedbacks.count
  end

  def goals_count
    goals.count
  end

  def ratings_count
    ratings.count
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date <= start_date
      errors.add(:end_date, 'must be after start date')
    end
  end

  def reviewer_not_same_as_employee
    if reviewer_id == employee_id
      errors.add(:reviewer, 'cannot be the same as employee')
    end
  end

  def reviewer_authority_check
    return unless reviewer && employee
    
    # Reviewer must be manager or have HR role
    unless reviewer == employee.manager || reviewer.user.admin? || reviewer.user.super_admin?
      errors.add(:reviewer, 'must be employee manager or have admin privileges')
    end
  end

  def set_completed_at
    if status_completed? && completed_at.blank?
      self.completed_at = Time.current
    elsif !status_completed? && completed_at.present?
      self.completed_at = nil
    end
  end

  def invalidate_caches
    CacheService.invalidate_performance_caches(employee_id)
  end
end 