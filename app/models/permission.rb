class Permission < ApplicationRecord
  belongs_to :user
  
  # Define available resources
  RESOURCES = %w[
    department
    position
    employee
    user
  ].freeze

  # Define available actions
  ACTIONS = %w[
    read
    create
    update
    delete
    manage
  ].freeze

  validates :resource, presence: true, inclusion: { in: RESOURCES }
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :resource_id, presence: true, unless: :global_permission?
  
  scope :for_resource, ->(resource) { where(resource: resource) }
  scope :global, -> { where(resource_id: nil) }
  scope :specific, -> { where.not(resource_id: nil) }
  
  private
  
  def global_permission?
    action == 'manage'
  end
end 