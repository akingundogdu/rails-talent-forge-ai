class UserPolicy < ApplicationPolicy
  def show?
    user == record || admin?
  end

  def update?
    user == record || super_admin?
  end

  def manage_permissions?
    super_admin? || (admin? && !record.admin?)
  end
end 