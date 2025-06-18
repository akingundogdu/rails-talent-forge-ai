class FeedbackRequest < ApplicationRecord
  # Associations
  belongs_to :requester, class_name: 'Employee'
  belongs_to :recipient, class_name: 'Employee'
  
  # Enums
  enum status: {
    pending: 'pending',
    accepted: 'accepted',
    declined: 'declined',
    completed: 'completed'
  }, _prefix: true
  
  enum feedback_type: {
    peer: 'peer',
    upward: 'upward',
    downward: 'downward',
    self_review: 'self_review',
    customer: 'customer'
  }, _prefix: true
  
  # Validations
  validates :message, presence: true, length: { minimum: 10, maximum: 500 }
  validates :feedback_type, presence: true
  validates :status, presence: true
  
  # Soft delete
  acts_as_paranoid
  
  # Scopes
  scope :pending_requests, -> { where(status: :pending) }
  scope :completed_requests, -> { where(status: :completed) }
  scope :for_recipient, ->(employee_id) { where(recipient_id: employee_id) }
  scope :from_requester, ->(employee_id) { where(requester_id: employee_id) }
end
