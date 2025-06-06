class Employee < ApplicationRecord
  include Cacheable
  # Associations
  belongs_to :position
  belongs_to :user
  has_one :managed_department, class_name: 'Department', foreign_key: 'manager_id'
  has_many :managed_departments, class_name: 'Department', foreign_key: 'manager_id'
  has_one :department, through: :position
  belongs_to :manager, class_name: 'Employee', optional: true
  has_many :subordinates, class_name: 'Employee', foreign_key: 'manager_id'

  # Validations
  validates :first_name, :last_name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }, 
                   format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :manager_position_level_check
  validate :no_circular_management

  # Soft delete
  acts_as_paranoid

  # Callbacks
  before_save :update_manager_based_on_position
  after_create :assign_default_permissions
  after_save :update_permissions

  # Callbacks for cache invalidation
  after_commit :invalidate_caches
  after_touch :invalidate_caches

  # Custom methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def ancestors
    return [] unless manager
    manager.ancestors + [manager]
  end

  def all_subordinates
    subordinates.flat_map { |sub| [sub] + sub.all_subordinates }
  end

  def subordinates_tree
    Employee.where(id: all_subordinates.map(&:id))
           .includes(:position, :department)
  end

  private

  def manager_position_level_check
    return unless manager && position && manager.position
    unless position.level < manager.position.level
      errors.add(:manager, "must have a higher position level")
    end
  end

  def no_circular_management
    return unless manager_id_changed? && manager_id.present?

    visited = Set.new
    current = manager_id

    while current.present?
      if visited.include?(current)
        errors.add(:manager_id, 'circular management is not allowed')
        break
      end

      visited.add(current)
      current = Employee.find_by(id: current)&.manager_id
    end
  end

  def update_manager_based_on_position
    return unless position_changed?
    self.manager = position.parent_position&.employees&.first if position.parent_position
  end

  def assign_default_permissions
    PermissionService.assign_default_permissions(user)
  end

  def update_permissions
    PermissionService.update_manager_permissions(self)
    PermissionService.update_department_permissions(self)
  end

  def invalidate_caches
    CacheService.invalidate_employee_caches(self)
  end
end 