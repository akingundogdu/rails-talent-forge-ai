class BulkPositionService < BulkOperationService
  BATCH_LIMIT = 50
  REQUIRED_FIELDS = %w[title level department_id].freeze

  class << self
    def bulk_create(positions)
      validate_limit!(positions, BATCH_LIMIT)
      validate_presence!(positions, REQUIRED_FIELDS)
      validate_uniqueness!(positions, 'title')
      validate_existence!(positions, 'department_id', Department)
      validate_existence!(positions, 'parent_position_id', Position) if positions.any? { |p| p['parent_position_id'].present? }

      # Manual creation with our validation
      created_positions = []
      ActiveRecord::Base.transaction do
        positions.each do |position_params|
          position = Position.create!(position_params)
          created_positions << position
        end
      end
      created_positions
    end

    def bulk_update(positions)
      validate_limit!(positions, BATCH_LIMIT)
      validate_existence!(positions, 'id', Position)
      validate_existence!(positions, 'department_id', Department) if positions.any? { |p| p['department_id'].present? }
      validate_existence!(positions, 'parent_position_id', Position) if positions.any? { |p| p['parent_position_id'].present? }

      # Manual update with our validation
      updated_positions = []
      ActiveRecord::Base.transaction do
        positions.each do |position_params|
          id = position_params['id'] || position_params[:id]
          position = Position.find(id)
          update_params = position_params.except('id', :id)
          position.update!(update_params)
          updated_positions << position
        end
      end
      updated_positions
    end

    def bulk_delete(position_ids)
      validate_limit!(position_ids, BATCH_LIMIT)
      positions = Position.where(id: position_ids)
      
      missing_ids = position_ids - positions.pluck(:id)
      unless missing_ids.empty?
        raise BulkOperationService::BulkOperationError.new("Some positions not found", { missing_ids: missing_ids })
      end

      process_in_transaction(positions) do
        positions.each do |position|
          if position.employees.exists?
            raise BulkOperationService::BulkOperationError.new(
              "Cannot delete position with employees",
              { position_id: position.id }
            )
          end
          position.destroy!
        end
        positions.to_a
      end
    end

    def bulk_transfer(position_ids, new_department_id)
      validate_limit!(position_ids, BATCH_LIMIT)
      positions = Position.where(id: position_ids)
      
      missing_ids = position_ids - positions.pluck(:id)
      unless missing_ids.empty?
        raise BulkOperationService::BulkOperationError.new("Some positions not found", { missing_ids: missing_ids })
      end

      department = Department.find_by(id: new_department_id)
      unless department
        raise BulkOperationService::BulkOperationError.new("Department not found", { department_id: new_department_id })
      end

      process_in_transaction(positions) do
        positions.each do |position|
          position.update!(department: department)
        end
        positions.to_a
      end
    end

    private

    def process_in_transaction(records)
      ActiveRecord::Base.transaction do
        yield records
      end
    rescue ActiveRecord::RecordInvalid => e
      raise BulkOperationService::BulkOperationError.new("Validation failed", e.record.errors.full_messages)
    end
  end
end 