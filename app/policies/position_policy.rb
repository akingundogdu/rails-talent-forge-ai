class PositionPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin? || user.admin?
        scope.all
      else
        scope.where(department_id: user.employee&.department_id)
      end
    end
  end

  def index?
    true
  end

  def show?
    admin? || record.department_id == user.employee&.department_id
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

  def hierarchy?
    show?
  end

  def bulk_create?
    user.admin? || user.super_admin?
  end

  def tree?
    true
  end

  def employees?
    show?
  end

  private

  def manages_department?
    user.managed_departments.exists?(id: record.department_id)
  end
end 