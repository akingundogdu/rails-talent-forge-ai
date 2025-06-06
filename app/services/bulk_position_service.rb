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

      super(Position, positions)
    end

    def bulk_update(positions)
      validate_limit!(positions, BATCH_LIMIT)
      validate_existence!(positions, 'id', Position)
      validate_existence!(positions, 'department_id', Department) if positions.any? { |p| p['department_id'].present? }
      validate_existence!(positions, 'parent_position_id', Position) if positions.any? { |p| p['parent_position_id'].present? }

      super(Position, positions)
    end

    def bulk_delete(position_ids)
      validate_limit!(position_ids, BATCH_LIMIT)
      positions = Position.where(id: position_ids)
      
      missing_ids = position_ids - positions.pluck(:id)
      unless missing_ids.empty?
        raise BulkOperationError.new("Some positions not found", { missing_ids: missing_ids })
      end

      process_in_transaction(positions) do
        positions.each do |position|
          if position.employees.exists?
            raise BulkOperationError.new(
              "Cannot delete position with employees",
              { position_id: position.id }
            )
          end
          position.destroy!
        end
      end
    end

    def bulk_transfer(position_ids, new_department_id)
      validate_limit!(position_ids, BATCH_LIMIT)
      positions = Position.where(id: position_ids)
      
      missing_ids = position_ids - positions.pluck(:id)
      unless missing_ids.empty?
        raise BulkOperationError.new("Some positions not found", { missing_ids: missing_ids })
      end

      department = Department.find_by(id: new_department_id)
      unless department
        raise BulkOperationError.new("Department not found", { department_id: new_department_id })
      end

      process_in_transaction(positions) do
        positions.each do |position|
          position.update!(department: department)
        end
      end
    end

    private

    def process_in_transaction(records)
      ActiveRecord::Base.transaction do
        yield records
      end
    rescue ActiveRecord::RecordInvalid => e
      raise BulkOperationError.new("Validation failed", e.record.errors.full_messages)
    end
  end
end 