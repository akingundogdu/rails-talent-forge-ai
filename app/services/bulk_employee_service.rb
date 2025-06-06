class BulkEmployeeService
  BATCH_LIMIT = 50
  REQUIRED_FIELDS = %w[first_name last_name email position_id].freeze

  class << self
    def bulk_create(params)
      validate_limit!(params)
      validate_presence!(params, REQUIRED_FIELDS)
      validate_uniqueness!(params, :email)

      BulkOperationService.bulk_create(Employee, params)
    end

    def bulk_update(params)
      validate_existence!(params.map { |p| p[:id] }, Employee)

      BulkOperationService.bulk_update(Employee, params)
    end

    def bulk_delete(ids)
      validate_existence!(ids, Employee)
      validate_no_subordinates!(ids)

      BulkOperationService.bulk_delete(Employee, ids)
    end

    def bulk_transfer(employee_ids, new_position_id)
      validate_existence!(employee_ids, Employee)
      validate_existence!([new_position_id], Position)

      params = employee_ids.map { |id| { id: id, position_id: new_position_id } }
      BulkOperationService.bulk_update(Employee, params)
    end

    def bulk_assign_manager(employee_ids, new_manager_id)
      validate_existence!(employee_ids, Employee)
      validate_existence!([new_manager_id], Employee)
      validate_no_self_management!(employee_ids, new_manager_id)

      params = employee_ids.map { |id| { id: id, manager_id: new_manager_id } }
      BulkOperationService.bulk_update(Employee, params)
    end

    private

    def validate_limit!(params)
      raise BulkOperationService::BulkOperationError.new("Batch size exceeds limit of #{BATCH_LIMIT}") if params.size > BATCH_LIMIT
    end

    def validate_presence!(params, fields)
      missing_fields = params.each_with_object([]) do |param, acc|
        missing = fields.select { |field| param[field.to_sym].blank? }
        acc.concat(missing) if missing.any?
      end

      raise BulkOperationService::BulkOperationError.new("Missing required fields: #{missing_fields.uniq.join(', ')}") if missing_fields.any?
    end

    def validate_uniqueness!(params, field)
      values = params.map { |p| p[field.to_sym] }
      duplicates = values.select { |v| values.count(v) > 1 }.uniq
      raise BulkOperationService::BulkOperationError.new("Duplicate values found for #{field}: #{duplicates.join(', ')}") if duplicates.any?

      existing = Employee.where(field => values).pluck(field)
      raise BulkOperationService::BulkOperationError.new("#{field.to_s.titleize} already exists: #{existing.join(', ')}") if existing.any?
    end

    def validate_existence!(ids, model_class)
      existing_ids = model_class.where(id: ids).pluck(:id)
      missing_ids = ids - existing_ids
      raise BulkOperationService::BulkOperationError.new("#{model_class.name} not found with ids: #{missing_ids.join(', ')}") if missing_ids.any?
    end

    def validate_no_subordinates!(ids)
      managers = Employee.where(id: ids).joins(:subordinates).distinct
      raise BulkOperationService::BulkOperationError.new("Cannot delete employees with subordinates: #{managers.pluck(:id).join(', ')}") if managers.exists?
    end

    def validate_no_self_management!(employee_ids, manager_id)
      raise BulkOperationService::BulkOperationError.new("Employee cannot be their own manager") if employee_ids.include?(manager_id)
    end
  end
end 