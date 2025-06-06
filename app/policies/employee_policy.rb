class EmployeePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.admin?
        scope.joins(:position).where(positions: { department_id: user.managed_departments.pluck(:id) })
      else
        scope.where(manager_id: user.employee&.id)
      end
    end
  end

  def index?
    true
  end

  def show?
    admin? || record.manager_id == user.employee&.id || record.id == user.employee&.id
  end

  def create?
    admin?
  end

  def update?
    admin? && manages_employee_department?
  end

  def destroy?
    super_admin?
  end

  def subordinates?
    show?
  end

  def bulk_create?
    user.admin? || user.super_admin?
  end

  def manager?
    show?
  end

  def search?
    true
  end

  private

  def manages_employee_department?
    user.managed_departments.exists?(id: record.position.department_id)
  end
end 