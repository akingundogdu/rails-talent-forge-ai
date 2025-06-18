class BulkOperationService
  class BulkOperationError < StandardError
    attr_reader :errors

    def initialize(message, errors = [])
      super(message)
      @errors = errors
    end
  end

  BATCH_LIMIT = 50

  def initialize(model_class, options = {})
    @model_class = model_class
    @options = options
    @batch_size = options.fetch(:batch_size, 100)
    @validate_all = options.fetch(:validate_all, true)
  end

  class << self
    def bulk_create(model_class, params, options = {})
      new(model_class, options).bulk_create(params)
    end

    def bulk_update(model_class, params, options = {})
      new(model_class, options).bulk_update(params)
    end

    def bulk_delete(model_class, ids, options = {})
      new(model_class, options).bulk_delete(ids)
    end

    # Class methods for child services to use
    def validate_limit!(params, limit = BATCH_LIMIT)
      raise BulkOperationError.new("Batch size exceeds limit of #{limit}") if params.size > limit
    end

    def validate_presence!(params, fields)
      missing_fields = params.each_with_object([]) do |param, acc|
        missing = fields.select do |field|
          value = param[field.to_s] || param[field.to_sym]
          value.blank?
        end
        acc.concat(missing) if missing.any?
      end

      raise BulkOperationError.new("Missing required fields: #{missing_fields.uniq.join(', ')}") if missing_fields.any?
    end

    def validate_uniqueness!(params, field)
      values = params.map { |p| p[field.to_s] || p[field.to_sym] }.compact
      duplicates = values.select { |v| values.count(v) > 1 }.uniq
      raise BulkOperationError.new("Duplicate values found for #{field}: #{duplicates.join(', ')}") if duplicates.any?
    end

    def validate_existence!(params, field, model_class)
      if params.is_a?(Array) && params.first.is_a?(Hash)
        # For bulk operations with hash params
        ids = params.map { |p| p[field.to_s] || p[field.to_sym] }.compact
      else
        # For simple ID arrays
        ids = params
        model_class = field if field.is_a?(Class)
      end

      return if ids.empty?

      # Use unscoped to avoid acts_as_paranoid default scope issues in tests
      # Check if model uses acts_as_paranoid by checking if it responds to deleted_at
      if model_class.column_names.include?('deleted_at')
        existing_ids = model_class.unscoped.where(id: ids, deleted_at: nil).pluck(:id)
      else
        existing_ids = model_class.where(id: ids).pluck(:id)
      end
      
      missing_ids = ids - existing_ids
      raise BulkOperationError.new("#{model_class.name} not found", { missing_ids: missing_ids }) if missing_ids.any?
    end
  end

  def bulk_create(params)
    validate_limit!(params)
    validate_presence!(params, required_fields) if @validate_all
    validate_uniqueness!(params, unique_fields) if @validate_all && unique_fields.any?

    process_in_transaction do
      results = { success: [], errors: [] }

      params.each do |param|
        record = @model_class.new(param)
        if record.save
          results[:success] << record
        else
          results[:errors] << { record: param, errors: record.errors.full_messages }
          raise ActiveRecord::Rollback if @validate_all
        end
      end

      results
    end
  end

  def bulk_update(params)
    validate_limit!(params)
    ids = params.map { |p| p['id'] || p[:id] }.compact
    validate_existence!(ids, @model_class) if @validate_all

    process_in_transaction do
      results = { success: [], errors: [] }

      params.each do |param|
        id = param['id'] || param[:id]
        begin
          record = @model_class.find(id)
          update_params = param.is_a?(Hash) ? param.except('id', :id) : param
          if record.update(update_params)
            results[:success] << record
          else
            results[:errors] << { record: param, errors: record.errors.full_messages }
            raise ActiveRecord::Rollback if @validate_all
          end
        rescue ActiveRecord::RecordNotFound => e
          results[:errors] << { record: param, errors: [e.message] }
          raise ActiveRecord::Rollback if @validate_all
        end
      end

      results
    end
  end

  def bulk_delete(ids)
    validate_limit!(ids) if ids.respond_to?(:size)
    validate_existence!(ids, @model_class) if @validate_all

    process_in_transaction do
      results = { success: [], errors: [] }

      ids.each do |id|
        begin
          record = @model_class.find(id)
          if record.destroy
            results[:success] << record
          else
            results[:errors] << { record: { id: id }, errors: record.errors.full_messages }
            raise ActiveRecord::Rollback if @validate_all
          end
        rescue ActiveRecord::RecordNotFound => e
          results[:errors] << { record: { id: id }, errors: [e.message] }
          raise ActiveRecord::Rollback if @validate_all
        end
      end

      results
    end
  end

  private

  def validate_limit!(params)
    raise BulkOperationError.new("Batch size exceeds limit of #{BATCH_LIMIT}") if params.size > BATCH_LIMIT
  end

  def validate_presence!(params, fields)
    missing_fields = params.each_with_object([]) do |param, acc|
      missing = fields.select { |field| param[field.to_sym].blank? }
      acc.concat(missing) if missing.any?
    end

    raise BulkOperationError.new("Missing required fields: #{missing_fields.uniq.join(', ')}") if missing_fields.any?
  end

  def validate_uniqueness!(params, fields)
    fields.each do |field|
      values = params.map { |p| p[field.to_sym] }
      duplicates = values.select { |v| values.count(v) > 1 }.uniq
      raise BulkOperationError.new("Duplicate values found for #{field}: #{duplicates.join(', ')}") if duplicates.any?

      existing = @model_class.where(field => values).pluck(field)
      raise BulkOperationError.new("#{field.to_s.titleize} already exists: #{existing.join(', ')}") if existing.any?
    end
  end

  def validate_existence!(ids, model_class)
    # Use unscoped to avoid acts_as_paranoid default scope issues in tests
    existing_ids = model_class.unscoped.where(id: ids, deleted_at: nil).pluck(:id)
    missing_ids = ids - existing_ids
    raise BulkOperationError.new("#{model_class.name} not found with ids: #{missing_ids.join(', ')}") if missing_ids.any?
  end

  def process_in_transaction
    results = { success: [], errors: [] }
    ActiveRecord::Base.transaction do
      results = yield
      if @validate_all && results[:errors].any?
        # Keep the errors but clear successes since transaction will rollback
        results[:success] = []
        raise ActiveRecord::Rollback
      end
    end
    results
  end

  def required_fields
    return [] unless @model_class.respond_to?(:validators)
    
    begin
      presence_fields = @model_class.validators.select { |v| v.is_a?(ActiveRecord::Validations::PresenceValidator) }
        .flat_map(&:attributes)
        .map(&:to_s)
      
      # Convert belongs_to association names to foreign key names
      belongs_to_associations = @model_class.reflect_on_all_associations(:belongs_to)
      belongs_to_associations.each do |association|
        if presence_fields.include?(association.name.to_s)
          presence_fields.delete(association.name.to_s)
          presence_fields << association.foreign_key.to_s
        end
      end
      
      presence_fields
    rescue => e
      # If there's any error getting validators, return empty array
      []
    end
  end

  def unique_fields
    return [] unless @model_class.respond_to?(:validators)
    
    begin
      @model_class.validators.select { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
        .flat_map(&:attributes)
        .map(&:to_s)
    rescue => e
      # If there's any error getting validators, return empty array
      []
    end
  end
end 