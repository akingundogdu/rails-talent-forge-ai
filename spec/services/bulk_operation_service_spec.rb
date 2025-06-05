require 'rails_helper'

RSpec.describe BulkOperationService, type: :service do
  let(:service) { described_class.new(Department) }
  let(:valid_department_params) do
    [
      { name: 'Department 1', description: 'Description 1' },
      { name: 'Department 2', description: 'Description 2' }
    ]
  end

  describe '.bulk_create' do
    context 'with valid params' do
      it 'creates all records successfully' do
        result = described_class.bulk_create(Department, valid_department_params)
        
        expect(result[:success].length).to eq(2)
        expect(result[:errors]).to be_empty
        expect(Department.count).to eq(2)
      end

      it 'handles empty params array' do
        result = described_class.bulk_create(Department, [])
        
        expect(result[:success]).to be_empty
        expect(result[:errors]).to be_empty
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        [
          { name: 'Valid Department' },
          { name: '' }  # Invalid due to presence validation
        ]
      end

      it 'rolls back all changes when validate_all is true' do
        result = described_class.bulk_create(Department, invalid_params)
        
        expect(result[:success]).to be_empty
        expect(result[:errors]).not_to be_empty
        expect(Department.count).to eq(0)
      end

      it 'creates valid records when validate_all is false' do
        service = described_class.new(Department, validate_all: false)
        result = service.bulk_create(invalid_params)
        
        expect(result[:success].length).to eq(1)
        expect(result[:errors].length).to eq(1)
        expect(Department.count).to eq(1)
      end
    end
  end

  describe '.bulk_update' do
    let!(:departments) { create_list(:department, 2) }
    let(:update_params) do
      [
        { id: departments[0].id, name: 'Updated Department 1' },
        { id: departments[1].id, name: 'Updated Department 2' }
      ]
    end

    context 'with valid params' do
      it 'updates all records successfully' do
        result = described_class.bulk_update(Department, update_params)
        
        expect(result[:success].length).to eq(2)
        expect(result[:errors]).to be_empty
        expect(departments[0].reload.name).to eq('Updated Department 1')
        expect(departments[1].reload.name).to eq('Updated Department 2')
      end

      it 'handles empty params array' do
        result = described_class.bulk_update(Department, [])
        
        expect(result[:success]).to be_empty
        expect(result[:errors]).to be_empty
      end
    end

    context 'with invalid params' do
      let(:invalid_update_params) do
        [
          { id: departments[0].id, name: 'Valid Name' },
          { id: departments[1].id, name: '' }  # Invalid due to presence validation
        ]
      end

      it 'rolls back all changes when validate_all is true' do
        result = described_class.bulk_update(Department, invalid_update_params)
        
        expect(result[:success]).to be_empty
        expect(result[:errors]).not_to be_empty
        expect(departments[0].reload.name).not_to eq('Valid Name')
      end

      it 'updates valid records when validate_all is false' do
        service = described_class.new(Department, validate_all: false)
        result = service.bulk_update(invalid_update_params)
        
        expect(result[:success].length).to eq(1)
        expect(result[:errors].length).to eq(1)
        expect(departments[0].reload.name).to eq('Valid Name')
      end
    end

    context 'with non-existent records' do
      let(:invalid_id_params) do
        [{ id: 999999, name: 'Non-existent Department' }]
      end

      it 'returns appropriate error' do
        result = described_class.bulk_update(Department, invalid_id_params)
        
        expect(result[:success]).to be_empty
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first[:errors]).to include(
          "Couldn't find Department with 'id'=999999"
        )
      end
    end
  end

  describe '.bulk_delete' do
    let!(:departments) { create_list(:department, 3) }
    let(:department_ids) { departments.map(&:id) }

    context 'with valid ids' do
      it 'deletes all records successfully' do
        result = described_class.bulk_delete(Department, department_ids)
        
        expect(result[:success].length).to eq(3)
        expect(result[:errors]).to be_empty
        expect(Department.count).to eq(0)
      end

      it 'handles empty ids array' do
        result = described_class.bulk_delete(Department, [])
        
        expect(result[:success]).to be_empty
        expect(result[:errors]).to be_empty
      end
    end

    context 'with non-existent records' do
      let(:invalid_ids) { [999999, 999998] }

      it 'returns appropriate error' do
        result = described_class.bulk_delete(Department, invalid_ids)
        
        expect(result[:success]).to be_empty
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first[:message]).to include(
          "Records not found with ids: #{invalid_ids.join(', ')}"
        )
      end

      it 'deletes existing records when validate_all is false' do
        mixed_ids = department_ids + invalid_ids
        service = described_class.new(Department, validate_all: false)
        result = service.bulk_delete(mixed_ids)
        
        expect(result[:success].length).to eq(3)
        expect(result[:errors].length).to eq(1)
        expect(Department.count).to eq(0)
      end
    end
  end

  describe 'batch processing' do
    let(:large_params) { 150.times.map { |i| { name: "Department #{i}" } } }

    it 'processes records in batches' do
      service = described_class.new(Department, batch_size: 50)
      expect(Department).to receive(:new).exactly(150).times.and_call_original
      
      result = service.bulk_create(large_params)
      expect(result[:success].length).to eq(150)
    end
  end
end 