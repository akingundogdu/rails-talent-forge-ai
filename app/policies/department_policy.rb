class DepartmentPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin? || user.admin?
        scope.all
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
    admin?
  end

  def destroy?
    admin?
  end

  def tree?
    true
  end

  def org_chart?
    show?
  end

  def bulk_create?
    user.admin? || user.super_admin?
  end

  def bulk_update?
    user.admin? || user.super_admin?
  end

  def bulk_delete?
    user.admin? || user.super_admin?
  end

  def employees?
    show?
  end

  def positions?
    show?
  end
end 