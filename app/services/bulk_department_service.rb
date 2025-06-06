class BulkDepartmentService < BulkOperationService
  BATCH_LIMIT = 50
  REQUIRED_FIELDS = %w[name].freeze

  class << self
    def bulk_create(departments)
      validate_limit!(departments, BATCH_LIMIT)
      validate_presence!(departments, REQUIRED_FIELDS)
      validate_uniqueness!(departments, 'name')
      validate_existence!(departments, 'parent_department_id', Department) if departments.any? { |d| d['parent_department_id'].present? }
      validate_existence!(departments, 'manager_id', Employee) if departments.any? { |d| d['manager_id'].present? }

      # Manual creation with our validation
      created_departments = []
      ActiveRecord::Base.transaction do
        departments.each do |department_params|
          department = Department.create!(department_params)
          created_departments << department
        end
      end
      created_departments
    end

    def bulk_update(departments)
      validate_limit!(departments, BATCH_LIMIT)
      validate_existence!(departments, 'id', Department)
      validate_existence!(departments, 'parent_department_id', Department) if departments.any? { |d| d['parent_department_id'].present? }
      validate_existence!(departments, 'manager_id', Employee) if departments.any? { |d| d['manager_id'].present? }

      # Manual update with our validation
      updated_departments = []
      ActiveRecord::Base.transaction do
        departments.each do |department_params|
          id = department_params['id'] || department_params[:id]
          department = Department.find(id)
          update_params = department_params.except('id', :id)
          department.update!(update_params)
          updated_departments << department
        end
      end
      updated_departments
    end

    def bulk_delete(department_ids)
      validate_limit!(department_ids, BATCH_LIMIT)
      departments = Department.where(id: department_ids)
      
      missing_ids = department_ids - departments.pluck(:id)
      unless missing_ids.empty?
        raise BulkOperationService::BulkOperationError.new("Some departments not found", { missing_ids: missing_ids })
      end

      process_in_transaction(departments) do
        departments.each do |department|
          if department.employees.exists?
            raise BulkOperationService::BulkOperationError.new(
              "Cannot delete department with employees",
              { department_id: department.id }
            )
          end
          department.destroy!
        end
        departments.to_a
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