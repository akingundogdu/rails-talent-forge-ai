class BulkEmployeeService < BulkOperationService
  BATCH_LIMIT = 50
  REQUIRED_FIELDS = %w[first_name last_name email position_id].freeze

  class << self
    def bulk_create(employees)
      validate_limit!(employees, BATCH_LIMIT)
      validate_presence!(employees, REQUIRED_FIELDS)
      validate_uniqueness!(employees, 'email')
      validate_existence!(employees, 'position_id', Position)
      validate_existence!(employees, 'manager_id', Employee) if employees.any? { |e| e['manager_id'].present? }
      validate_existence!(employees, 'user_id', User) if employees.any? { |e| e['user_id'].present? }

      process_in_transaction(employees) do
        employees.map do |emp_params|
          Employee.create!(emp_params)
        end
      end
    end

    def bulk_update(employees)
      validate_limit!(employees, BATCH_LIMIT)
      validate_existence!(employees, 'id', Employee)
      validate_existence!(employees, 'position_id', Position) if employees.any? { |e| e['position_id'].present? }
      validate_existence!(employees, 'manager_id', Employee) if employees.any? { |e| e['manager_id'].present? }
      validate_existence!(employees, 'user_id', User) if employees.any? { |e| e['user_id'].present? }

      process_in_transaction(employees) do
        employees.map do |emp_params|
          employee = Employee.find(emp_params['id'])
          employee.update!(emp_params.except('id'))
          employee
        end
      end
    end

    def bulk_delete(employee_ids)
      validate_limit!(employee_ids, BATCH_LIMIT)
      employees = Employee.where(id: employee_ids)
      
      missing_ids = employee_ids - employees.pluck(:id)
      unless missing_ids.empty?
        raise BulkOperationError.new("Some employees not found", { missing_ids: missing_ids })
      end

      process_in_transaction(employees) do
        employees.each do |employee|
          if employee.subordinates.exists?
            raise BulkOperationError.new(
              "Cannot delete employee with subordinates",
              { employee_id: employee.id }
            )
          end
          if employee.managed_department.present?
            raise BulkOperationError.new(
              "Cannot delete employee who manages a department",
              { employee_id: employee.id }
            )
          end
          employee.destroy!
        end
      end
    end

    def bulk_transfer(employee_ids, new_position_id)
      validate_limit!(employee_ids, BATCH_LIMIT)
      employees = Employee.where(id: employee_ids)
      
      missing_ids = employee_ids - employees.pluck(:id)
      unless missing_ids.empty?
        raise BulkOperationError.new("Some employees not found", { missing_ids: missing_ids })
      end

      position = Position.find_by(id: new_position_id)
      unless position
        raise BulkOperationError.new("Position not found", { position_id: new_position_id })
      end

      process_in_transaction(employees) do
        employees.each do |employee|
          employee.update!(position: position)
        end
      end
    end

    def bulk_assign_manager(employee_ids, new_manager_id)
      validate_limit!(employee_ids, BATCH_LIMIT)
      employees = Employee.where(id: employee_ids)
      
      missing_ids = employee_ids - employees.pluck(:id)
      unless missing_ids.empty?
        raise BulkOperationError.new("Some employees not found", { missing_ids: missing_ids })
      end

      manager = Employee.find_by(id: new_manager_id)
      unless manager
        raise BulkOperationError.new("Manager not found", { manager_id: new_manager_id })
      end

      process_in_transaction(employees) do
        employees.each do |employee|
          if employee.id == new_manager_id
            raise BulkOperationError.new(
              "Employee cannot be their own manager",
              { employee_id: employee.id }
            )
          end
          employee.update!(manager: manager)
        end
      end
    end
  end
end 