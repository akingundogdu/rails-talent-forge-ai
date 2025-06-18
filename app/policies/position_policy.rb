class PositionPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.admin?
        # Admin users can only see positions from departments they manage
        managed_dept_ids = user.employee&.managed_departments&.pluck(:id) || []
        scope.where(department_id: managed_dept_ids)
      else
        scope.where(department_id: user.employee&.department&.id)
      end
    end
  end

  def index?
    true
  end

  def show?
    super_admin? || 
    (admin? && manages_department?) ||
    record.department_id == user.employee&.department&.id
  end

  def create?
    admin? || super_admin?
  end

  def update?
    super_admin? || 
    (admin? && manages_department?)
  end

  def destroy?
    super_admin?
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
    user.employee&.managed_departments&.exists?(id: record.department_id)
  end
end 