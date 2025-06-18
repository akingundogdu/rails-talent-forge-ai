class Feedback < ApplicationRecord
  include Cacheable

  # Associations
  belongs_to :giver, class_name: 'Employee'
  belongs_to :receiver, class_name: 'Employee'
  belongs_to :performance_review, optional: true

  # Enums
  enum feedback_type: {
    peer: 0,
    subordinate: 1,
    manager: 2,
    self_evaluation: 3,
    upward: 4,
    client: 5
  }, _prefix: true

  # Validations
  validates :message, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :feedback_type, presence: true
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true
  validate :giver_not_same_as_receiver
  validate :feedback_relationship_valid
  validate :self_evaluation_consistency

  # Soft delete
  acts_as_paranoid

  # Scopes
  scope :for_receiver, ->(employee_id) { where(receiver_id: employee_id) }
  scope :by_giver, ->(employee_id) { where(giver_id: employee_id) }
  scope :for_review, ->(review_id) { where(performance_review_id: review_id) }
  scope :by_type, ->(type) { where(feedback_type: type) }
  scope :anonymous_feedback, -> { where(anonymous: true) }
  scope :public_feedback, -> { where(anonymous: false) }
  scope :rated_feedback, -> { where.not(rating: nil) }
  scope :recent, ->(days = 30) { where('created_at >= ?', days.days.ago) }

  # Callbacks
  after_commit :invalidate_caches
  after_touch :invalidate_caches
  after_create :notify_participants

  # Business Methods
  def is_positive?
    return nil unless rating.present?
    rating >= 4
  end

  def is_negative?
    sentiment_score == 'negative' || (rating.present? && rating <= 2)
  end

  def is_constructive?
    # Constructive feedback typically has specific suggestions or actionable advice
    message.downcase.include?('suggest') || 
    message.downcase.include?('recommend') || 
    message.downcase.include?('improve') ||
    message.downcase.include?('consider') ||
    (rating.present? && rating >= 3 && message.length > 50)
  end

  def sentiment_score
    case rating
    when 1
      'very_negative'
    when 2
      'negative'
    when 3
      'neutral'
    when 4
      'positive'
    when 5
      'very_positive'
    else
      'unrated'
    end
  end

  def relationship_type
    return 'self' if giver == receiver
    return 'manager_to_subordinate' if giver == receiver.manager
    return 'subordinate_to_manager' if receiver == giver.manager
    return 'peer' if giver.department == receiver.department
    'cross_department'
  end

  def can_be_edited?
    created_at > 24.hours.ago && !performance_review&.status_completed?
  end

  def formatted_giver_name
    anonymous? ? 'Anonymous' : giver.full_name
  end

  def word_count
    message.split(/\s+/).length
  end

  def update_feedback!(new_message, new_rating = nil)
    return false unless can_be_edited?
    
    transaction do
      update!(
        message: new_message,
        rating: new_rating
      )
    end
    true
  end

  # 360° Feedback Analytics
  def self.feedback_summary_for_employee(employee_id, period_start = nil, period_end = nil)
    scope = for_receiver(employee_id)
    scope = scope.where(created_at: period_start..period_end) if period_start && period_end
    
    {
      total_feedback_count: scope.count,
      by_type: scope.group(:feedback_type).count,
      average_rating: scope.rated_feedback.average(:rating)&.round(2) || 0,
      rating_distribution: scope.rated_feedback.group(:rating).count,
      anonymous_count: scope.anonymous_feedback.count,
      public_count: scope.public_feedback.count,
      sentiment_breakdown: scope.rated_feedback.group_by(&:sentiment_score).transform_values(&:count)
    }
  end

  def self.peer_comparison_analysis(employee_id, department_id = nil)
    employee = Employee.find(employee_id)
    department_id ||= employee.department.id
    
    peer_employees = Employee.joins(:position)
                            .where(positions: { department_id: department_id })
                            .where.not(id: employee_id)
    
    employee_avg = for_receiver(employee_id).rated_feedback.average(:rating) || 0
    peer_averages = peer_employees.map do |peer|
      {
        employee: peer,
        average_rating: for_receiver(peer.id).rated_feedback.average(:rating) || 0
      }
    end
    
    department_avg = peer_averages.sum { |p| p[:average_rating] } / peer_averages.length
    
    {
      employee_average: employee_avg.round(2),
      department_average: department_avg.round(2),
      peer_rankings: peer_averages.sort_by { |p| -p[:average_rating] },
      percentile: calculate_percentile(employee_avg, peer_averages.map { |p| p[:average_rating] })
    }
  end

  def self.feedback_trends(employee_id, months = 12)
    start_date = months.months.ago
    
    monthly_data = for_receiver(employee_id)
                   .where('created_at >= ?', start_date)
                   .group("DATE_TRUNC('month', created_at)")
                   .group(:feedback_type)
                   .average(:rating)
    
    monthly_data.map do |key, avg_rating|
      date, feedback_type = key
      {
        month: date.strftime('%Y-%m'),
        feedback_type: feedback_type,
        average_rating: avg_rating.round(2)
      }
    end
  end

  # Search functionality
  def self.search(query)
    return all if query.blank?
    
    joins(:giver, :receiver)
      .where(
        "feedbacks.message ILIKE ? OR givers_feedbacks.first_name ILIKE ? OR givers_feedbacks.last_name ILIKE ?",
        "%#{query}%", "%#{query}%", "%#{query}%"
      )
  end

  private

  def giver_not_same_as_receiver
    if giver_id == receiver_id && !feedback_type_self_evaluation?
      errors.add(:giver, 'cannot be the same as receiver unless self-evaluation')
    end
  end

  def feedback_relationship_valid
    return unless giver && receiver
    
    case feedback_type
    when 'manager'
      unless giver == receiver.manager || giver.user.admin? || giver.user.super_admin?
        errors.add(:feedback_type, 'manager feedback must come from actual manager or admin')
      end
    when 'subordinate'
      unless receiver == giver.manager
        errors.add(:feedback_type, 'subordinate feedback must go to actual manager')
      end
    when 'peer'
      if giver == receiver.manager || receiver == giver.manager
        errors.add(:feedback_type, 'peer feedback should not be between manager and subordinate')
      end
    end
  end

  def self_evaluation_consistency
    if feedback_type_self_evaluation? && giver_id != receiver_id
      errors.add(:feedback_type, 'self-evaluation must have same giver and receiver')
    end
  end

  def notify_participants
    # TODO: Implement notification system
    # FeedbackMailer.feedback_received(self).deliver_later unless anonymous?
  end

  def invalidate_caches
    CacheService.invalidate_feedback_caches(receiver_id, giver_id)
  end

  def self.calculate_percentile(score, scores_array)
    return 0 if scores_array.empty?
    
    sorted_scores = scores_array.sort
    below_count = sorted_scores.count { |s| s < score }
    
    (below_count.to_f / sorted_scores.length * 100).round(2)
  end
end 