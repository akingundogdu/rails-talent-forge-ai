class PermissionPolicy < ApplicationPolicy
  def bulk_create?
    user.admin? || user.super_admin?
  end
  # ... existing code ...
end 