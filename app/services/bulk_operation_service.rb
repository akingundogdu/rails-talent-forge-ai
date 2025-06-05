class BulkOperationService
  class BulkOperationError < StandardError
    attr_reader :errors

    def initialize(message = nil, errors = [])
      super(message)
      @errors = errors
    end
  end

  class << self
    def bulk_create(model_class, records_params, options = {})
      new(model_class, options).bulk_create(records_params)
    end

    def bulk_update(model_class, records_params, options = {})
      new(model_class, options).bulk_update(records_params)
    end

    def bulk_delete(model_class, ids, options = {})
      new(model_class, options).bulk_delete(ids)
    end
  end

  def initialize(model_class, options = {})
    @model_class = model_class
    @options = options
    @batch_size = options.fetch(:batch_size, 100)
    @validate_all = options.fetch(:validate_all, true)
  end

  def bulk_create(records_params)
    return { success: [], errors: [] } if records_params.empty?

    results = { success: [], errors: [] }

    ActiveRecord::Base.transaction do
      records_params.each_slice(@batch_size) do |batch_params|
        batch_results = process_create_batch(batch_params)
        results[:success].concat(batch_results[:success])
        results[:errors].concat(batch_results[:errors])
      end

      raise BulkOperationError.new("Bulk create failed", results[:errors]) if @validate_all && results[:errors].any?
    end

    results
  rescue ActiveRecord::RecordInvalid => e
    { success: [], errors: [{ record: e.record.attributes, errors: e.record.errors.full_messages }] }
  end

  def bulk_update(records_params)
    return { success: [], errors: [] } if records_params.empty?

    results = { success: [], errors: [] }

    ActiveRecord::Base.transaction do
      records_params.each_slice(@batch_size) do |batch_params|
        batch_results = process_update_batch(batch_params)
        results[:success].concat(batch_results[:success])
        results[:errors].concat(batch_results[:errors])
      end

      raise BulkOperationError.new("Bulk update failed", results[:errors]) if @validate_all && results[:errors].any?
    end

    results
  rescue ActiveRecord::RecordInvalid => e
    { success: [], errors: [{ record: e.record.attributes, errors: e.record.errors.full_messages }] }
  end

  def bulk_delete(ids)
    return { success: [], errors: [] } if ids.empty?

    results = { success: [], errors: [] }

    ActiveRecord::Base.transaction do
      ids.each_slice(@batch_size) do |batch_ids|
        batch_results = process_delete_batch(batch_ids)
        results[:success].concat(batch_results[:success])
        results[:errors].concat(batch_results[:errors])
      end

      raise BulkOperationError.new("Bulk delete failed", results[:errors]) if @validate_all && results[:errors].any?
    end

    results
  rescue ActiveRecord::RecordNotFound => e
    { success: [], errors: [{ message: e.message }] }
  end

  private

  def process_create_batch(batch_params)
    results = { success: [], errors: [] }

    batch_params.each do |params|
      record = @model_class.new(params)
      
      if record.save
        results[:success] << record
      else
        results[:errors] << { record: params, errors: record.errors.full_messages }
        raise ActiveRecord::Rollback unless @validate_all
      end
    end

    results
  end

  def process_update_batch(batch_params)
    results = { success: [], errors: [] }

    batch_params.each do |params|
      record = @model_class.find(params[:id])
      
      if record.update(params.except(:id))
        results[:success] << record
      else
        results[:errors] << { record: params, errors: record.errors.full_messages }
        raise ActiveRecord::Rollback unless @validate_all
      end
    end

    results
  rescue ActiveRecord::RecordNotFound => e
    results[:errors] << { record: params, errors: [e.message] }
    raise ActiveRecord::Rollback unless @validate_all
    results
  end

  def process_delete_batch(batch_ids)
    results = { success: [], errors: [] }

    existing_records = @model_class.where(id: batch_ids)
    missing_ids = batch_ids - existing_records.pluck(:id)

    if missing_ids.any?
      results[:errors] << { message: "Records not found with ids: #{missing_ids.join(', ')}" }
      raise ActiveRecord::Rollback unless @validate_all
    end

    existing_records.each do |record|
      if record.destroy
        results[:success] << record.id
      else
        results[:errors] << { record: record.id, errors: record.errors.full_messages }
        raise ActiveRecord::Rollback unless @validate_all
      end
    end

    results
  end
end 
end 