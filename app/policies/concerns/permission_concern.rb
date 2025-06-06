module PermissionConcern
  extend ActiveSupport::Concern

  def has_permission?(action)
    return true if user.super_admin?
    return true if user.admin? && ['read', 'update', 'create', 'delete'].include?(action)

    resource_name = record.class.name.downcase
    user.has_permission?(action, resource_name, record.id)
  end

  def has_create_permission?
    has_permission?('create')
  end

  def has_read_permission?
    has_permission?('read')
  end

  def has_update_permission?
    has_permission?('update')
  end

  def has_delete_permission?
    has_permission?('delete')
  end

  def has_manage_permission?
    has_permission?('manage')
  end
end 