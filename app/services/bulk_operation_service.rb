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
  end

  def bulk_create(params)
    validate_limit!(params)
    validate_presence!(params, required_fields)
    validate_uniqueness!(params, unique_fields) if unique_fields.any?

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
    validate_existence!(params.map { |p| p[:id] }, @model_class)

    process_in_transaction do
      results = { success: [], errors: [] }

      params.each do |param|
        record = @model_class.find(param[:id])
        if record.update(param.except(:id))
          results[:success] << record
        else
          results[:errors] << { record: param, errors: record.errors.full_messages }
          raise ActiveRecord::Rollback if @validate_all
        end
      end

      results
    end
  end

  def bulk_delete(ids)
    validate_existence!(ids, @model_class)

    process_in_transaction do
      results = { success: [], errors: [] }

      ids.each do |id|
        record = @model_class.find(id)
        if record.destroy
          results[:success] << record
        else
          results[:errors] << { record: { id: id }, errors: record.errors.full_messages }
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
    existing_ids = model_class.where(id: ids).pluck(:id)
    missing_ids = ids - existing_ids
    raise BulkOperationError.new("#{model_class.name} not found with ids: #{missing_ids.join(', ')}") if missing_ids.any?
  end

  def process_in_transaction
    results = nil
    ActiveRecord::Base.transaction do
      results = yield
      raise ActiveRecord::Rollback if @validate_all && results[:errors].any?
    end
    results
  end

  def required_fields
    @model_class.validators.select { |v| v.is_a?(ActiveRecord::Validations::PresenceValidator) }
      .flat_map(&:attributes)
      .map(&:to_s)
  end

  def unique_fields
    @model_class.validators.select { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
      .flat_map(&:attributes)
      .map(&:to_s)
  end
end 