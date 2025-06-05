class PositionPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.admin?
        scope.where(department_id: user.managed_departments.pluck(:id))
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
    admin? && manages_department?
  end

  def destroy?
    super_admin?
  end

  def hierarchy?
    show?
  end

  private

  def manages_department?
    user.managed_departments.exists?(id: record.department_id)
  end
end 