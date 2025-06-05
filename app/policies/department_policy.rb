class DepartmentPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.admin?
        scope.where(id: user.managed_departments.pluck(:id))
      else
        scope.where(id: user.employee&.department_id)
      end
    end
  end

  def index?
    true
  end

  def show?
    admin? || manages_department? || record.employees.exists?(id: user.employee&.id)
  end

  def create?
    admin?
  end

  def update?
    admin? && manages_department?
  end

  def destroy?
    super_admin?
  end

  def tree?
    true
  end

  def org_chart?
    show?
  end
end 