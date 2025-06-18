class UserPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end

  def show?
    user.super_admin? || user.admin? || record == user
  end

  def update?
    user.super_admin? || record == user
  end

  def sign_out?
    true
  end

  def profile?
    true
  end

  def update_profile?
    true
  end

  def change_password?
    true
  end

  def manage_permissions?
    super_admin? || (admin? && !record.admin?)
  end
end 