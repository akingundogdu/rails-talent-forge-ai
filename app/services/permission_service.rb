class PermissionService
  def self.assign_default_permissions(user)
    return if user.admin? || user.super_admin?

    # Assign read permission to user's own department
    if user.employee&.position&.department
      user.grant_permission('read', 'department', user.employee.position.department_id)
    end

    # Assign read permission to user's own position
    if user.employee&.position
      user.grant_permission('read', 'position', user.employee.position_id)
    end

    # Assign read permission to user's own employee record
    if user.employee
      user.grant_permission('read', 'employee', user.employee.id)
    end

    # For managers, grant additional permissions
    if user.employee&.managed_departments.present?
      user.employee.managed_departments.each do |dept|
        user.grant_permission('manage', 'department', dept.id)
        
        # Grant read access to all positions in managed departments
        Position.where(department_id: dept.id).find_each do |position|
          user.grant_permission('read', 'position', position.id)
        end

        # Grant read access to all employees in managed departments
        Employee.joins(:position)
               .where(positions: { department_id: dept.id })
               .find_each do |employee|
          user.grant_permission('read', 'employee', employee.id)
        end
      end
    end
  end

  def self.update_manager_permissions(employee)
    return unless employee.manager_id_changed?

    if employee.manager_id_was.present?
      old_manager = User.joins(:employee).find_by(employees: { id: employee.manager_id_was })
      old_manager&.revoke_permission('manage', 'employee', employee.id)
    end

    if employee.manager_id.present?
      new_manager = User.joins(:employee).find_by(employees: { id: employee.manager_id })
      new_manager&.grant_permission('manage', 'employee', employee.id)
    end
  end

  def self.update_department_permissions(employee)
    return unless employee.position_id_changed?

    old_department_id = Position.find_by(id: employee.position_id_was)&.department_id
    new_department_id = Position.find_by(id: employee.position_id)&.department_id

    return if old_department_id == new_department_id

    user = employee.user
    
    # Remove old department permissions
    if old_department_id.present?
      user.revoke_permission('read', 'department', old_department_id)
    end

    # Add new department permissions
    if new_department_id.present?
      user.grant_permission('read', 'department', new_department_id)
    end
  end
end 