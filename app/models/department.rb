class Department < ApplicationRecord
  include Cacheable
  acts_as_paranoid

  # Associations
  belongs_to :parent_department, class_name: 'Department', optional: true
  belongs_to :manager, class_name: 'Employee', optional: true
  has_many :sub_departments, class_name: 'Department', foreign_key: 'parent_department_id'
  has_many :positions
  has_many :employees, through: :positions

  # Validations
  validates :name, presence: true, uniqueness: { scope: :deleted_at }
  validate :no_circular_hierarchy
  validate :manager_must_belong_to_department

  # Callbacks
  after_commit :touch_cache
  after_commit :invalidate_tree_cache
  after_commit :invalidate_org_chart_cache

  # Scopes
  scope :root_departments, -> { where(parent_department_id: nil) }

  # Callbacks for cache invalidation
  after_commit :invalidate_caches
  after_touch :invalidate_caches

  # Custom methods
  def ancestors
    return [] unless parent_department
    [parent_department] + parent_department.ancestors
  end

  def descendants
    sub_departments.flat_map { |child| [child] + child.descendants }
  end

  def subtree
    Department.where(id: [id] + descendants.map(&:id))
             .includes(:manager, :parent_department)
  end

  def org_chart
    {
      department: self,
      positions: positions.includes(:parent_position, :employees),
      employees: employees.includes(:position, :manager)
    }
  end

  def self.cached_tree
    CacheService.fetch('departments:tree', expires_in: 1.day) do
      includes(:sub_departments, :manager)
        .where(parent_department_id: nil)
        .map { |dept| dept.as_tree }
    end
  end

  def self.cached_org_chart(department_id)
    CacheService.fetch(["departments:org_chart", department_id], expires_in: 1.day) do
      department = find(department_id)
      department.as_org_chart
    end
  end

  def as_tree
    {
      id: id,
      name: name,
      description: description,
      manager: manager&.as_json(only: [:id, :first_name, :last_name]),
      sub_departments: sub_departments.map(&:as_tree)
    }
  end

  def as_org_chart
    {
      id: id,
      name: name,
      description: description,
      manager: manager&.as_json(only: [:id, :first_name, :last_name]),
      employees: employees.map { |emp| emp.as_json(only: [:id, :first_name, :last_name, :position_id]) },
      sub_departments: sub_departments.map(&:as_org_chart)
    }
  end

  private

  def no_circular_hierarchy
    return unless parent_department_id_changed? && parent_department_id.present?
    
    visited = Set.new
    current = parent_department_id

    while current.present?
      if current == id || visited.include?(current)
        errors.add(:parent_department_id, 'circular hierarchy is not allowed')
        break
      end

      visited.add(current)
      current = Department.find_by(id: current)&.parent_department_id
    end
  end

  def manager_must_belong_to_department
    if manager && !employees.include?(manager)
      errors.add(:manager, 'must be an employee of the department')
    end
  end

  def invalidate_tree_cache
    CacheService.delete('departments:tree')
  end

  def invalidate_org_chart_cache
    CacheService.delete_matched('departments:org_chart:*')
    ancestors.each { |dept| CacheService.delete(["departments:org_chart", dept.id]) }
  end

  def invalidate_caches
    CacheService.invalidate_department_caches(self)
  end
end 