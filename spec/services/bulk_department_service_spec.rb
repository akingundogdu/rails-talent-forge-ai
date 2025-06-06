# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BulkDepartmentService, type: :service do
  let(:test_department_for_manager) { create(:department) }
  let(:position_for_manager) { create(:position, department: test_department_for_manager) }
  let(:employee) { create(:employee, position: position_for_manager) }
  let(:parent_department) { create(:department) }
  let!(:department1) { create(:department) }

  describe '.bulk_create' do
    let(:valid_departments) do
      [
        {
          'name' => 'Engineering',
          'description' => 'Software Development Department'
          # manager will be added later after department is created
        },
        {
          'name' => 'Marketing',
          'description' => 'Marketing and Sales Department',
          'parent_department_id' => parent_department.id
        }
      ]
    end

    context 'with valid data' do
      it 'creates departments successfully' do
        expect {
          described_class.bulk_create(valid_departments)
        }.to change(Department, :count).by(3) # parent_department + 2 new
      end

      it 'returns created departments' do
        result = described_class.bulk_create(valid_departments)
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
        expect(result.all? { |d| d.is_a?(Department) }).to be true
      end

      it 'creates departments with correct attributes' do
        result = described_class.bulk_create(valid_departments)
        engineering = result.find { |d| d.name == 'Engineering' }
        marketing = result.find { |d| d.name == 'Marketing' }

        expect(engineering.description).to eq('Software Development Department')
        expect(marketing.parent_department_id).to eq(parent_department.id)
      end
    end

    context 'when exceeding batch limit' do
      let(:too_many_departments) do
        (1..51).map do |i|
          {
            'name' => "Department #{i}",
            'description' => 'Test Department'
          }
        end
      end

      it 'raises BulkOperationError' do
        expect {
          described_class.bulk_create(too_many_departments)
        }.to raise_error(BulkOperationService::BulkOperationError, /Batch size exceeds limit/)
      end
    end

    context 'with missing required fields' do
      let(:invalid_departments) do
        [
          {
            'description' => 'Missing name'
            # missing name
          }
        ]
      end

      it 'raises BulkOperationError for missing fields' do
        expect {
          described_class.bulk_create(invalid_departments)
        }.to raise_error(BulkOperationService::BulkOperationError, /Missing required fields/)
      end
    end

    context 'with duplicate names' do
      let(:duplicate_departments) do
        [
          {
            'name' => 'Engineering',
            'description' => 'First Engineering'
          },
          {
            'name' => 'Engineering',
            'description' => 'Second Engineering'
          }
        ]
      end

      it 'raises BulkOperationError for duplicate names' do
        expect {
          described_class.bulk_create(duplicate_departments)
        }.to raise_error(BulkOperationService::BulkOperationError, /Duplicate values found/)
      end
    end

    context 'with non-existent parent department' do
      let(:invalid_parent_departments) do
        [
          {
            'name' => 'Engineering',
            'parent_department_id' => 999999
          }
        ]
      end

      it 'raises BulkOperationError for missing parent department' do
        expect {
          described_class.bulk_create(invalid_parent_departments)
        }.to raise_error(BulkOperationService::BulkOperationError, /Department not found/)
      end
    end

    context 'with non-existent manager' do
      let(:invalid_manager_departments) do
        [
          {
            'name' => 'Engineering',
            'manager_id' => 999999
          }
        ]
      end

      it 'raises BulkOperationError for missing manager' do
        expect {
          described_class.bulk_create(invalid_manager_departments)
        }.to raise_error(BulkOperationService::BulkOperationError, /Employee not found/)
      end
    end
  end

  describe '.bulk_update' do
    let!(:department1) { create(:department, name: 'Original Name 1') }
    let!(:department2) { create(:department, name: 'Original Name 2') }
    
    let(:valid_updates) do
      [
        {
          'id' => department1.id,
          'name' => 'Updated Name 1',
          'description' => 'Updated Description 1'
        },
        {
          'id' => department2.id,
          'name' => 'Updated Name 2'
          # manager assignment removed to avoid circular dependency
        }
      ]
    end

    context 'with valid data' do
      it 'updates departments successfully' do
        result = described_class.bulk_update(valid_updates)
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
      end

      it 'updates department attributes correctly' do
        described_class.bulk_update(valid_updates)
        department1.reload
        department2.reload

        expect(department1.name).to eq('Updated Name 1')
        expect(department1.description).to eq('Updated Description 1')
        expect(department2.name).to eq('Updated Name 2')
      end
    end

    context 'when exceeding batch limit' do
      let(:too_many_updates) do
        (1..51).map do |i|
          {
            'id' => create(:department).id,
            'name' => "Updated #{i}"
          }
        end
      end

      it 'raises BulkOperationError' do
        expect {
          described_class.bulk_update(too_many_updates)
        }.to raise_error(BulkOperationService::BulkOperationError, /Batch size exceeds limit/)
      end
    end

    context 'with non-existent department IDs' do
      let(:invalid_updates) do
        [
          {
            'id' => 999999,
            'name' => 'Updated Name'
          }
        ]
      end

      it 'raises BulkOperationError for missing departments' do
        expect {
          described_class.bulk_update(invalid_updates)
        }.to raise_error(BulkOperationService::BulkOperationError, /Department not found/)
      end
    end

    context 'with non-existent parent department in updates' do
      let(:invalid_parent_updates) do
        [
          {
            'id' => department1.id,
            'parent_department_id' => 999999
          }
        ]
      end

      it 'raises BulkOperationError for missing parent department' do
        expect {
          described_class.bulk_update(invalid_parent_updates)
        }.to raise_error(BulkOperationService::BulkOperationError, /Department not found/)
      end
    end

    context 'with non-existent manager in updates' do
      let(:invalid_manager_updates) do
        [
          {
            'id' => department1.id,
            'manager_id' => 999999
          }
        ]
      end

      it 'raises BulkOperationError for missing manager' do
        expect {
          described_class.bulk_update(invalid_manager_updates)
        }.to raise_error(BulkOperationService::BulkOperationError, /Employee not found/)
      end
    end
  end

  describe '.bulk_delete' do
    let!(:department1) { create(:department) }
    let!(:department2) { create(:department) }
    let(:department_ids) { [department1.id, department2.id] }

    context 'with valid department IDs' do
      it 'deletes departments successfully' do
        expect {
          described_class.bulk_delete(department_ids)
        }.to change(Department, :count).by(-2)
      end

      it 'deletes the correct departments' do
        described_class.bulk_delete(department_ids)
        expect(Department.exists?(department1.id)).to be false
        expect(Department.exists?(department2.id)).to be false
      end
    end

    context 'when exceeding batch limit' do
      let(:too_many_ids) { (1..51).to_a }

      it 'raises BulkOperationError' do
        expect {
          described_class.bulk_delete(too_many_ids)
        }.to raise_error(BulkOperationService::BulkOperationError, /Batch size exceeds limit/)
      end
    end

    context 'with non-existent department IDs' do
      let(:invalid_ids) { [999999, 999998] }

      it 'raises BulkOperationError for missing departments' do
        expect {
          described_class.bulk_delete(invalid_ids)
        }.to raise_error(BulkOperationService::BulkOperationError) do |error|
          expect(error.message).to include('Some departments not found')
          expect(error.errors[:missing_ids]).to match_array(invalid_ids)
        end
      end
    end

    context 'when departments have employees' do
      let!(:position) { create(:position, department: department1) }
      let!(:employee_in_dept) { create(:employee, position: position) }

      it 'raises BulkOperationError for departments with employees' do
        expect {
          described_class.bulk_delete([department1.id])
        }.to raise_error(BulkOperationService::BulkOperationError) do |error|
          expect(error.message).to include('Cannot delete department with employees')
          expect(error.errors[:department_id]).to eq(department1.id)
        end
      end

      it 'does not delete any departments when one has employees' do
        expect {
          described_class.bulk_delete([department1.id, department2.id])
        }.to raise_error(BulkOperationService::BulkOperationError)
        
        expect(Department.exists?(department1.id)).to be true
        expect(Department.exists?(department2.id)).to be true
      end
    end
  end

  describe 'inheritance from BulkOperationService' do
    it 'inherits from BulkOperationService' do
      expect(described_class.superclass).to eq(BulkOperationService)
    end

    it 'has correct batch limit' do
      expect(described_class::BATCH_LIMIT).to eq(50)
    end

    it 'has correct required fields' do
      expect(described_class::REQUIRED_FIELDS).to eq(%w[name])
    end
  end

  describe 'error handling' do
    context 'when ActiveRecord errors occur' do
      before do
        allow(Department).to receive(:where).and_raise(ActiveRecord::StatementInvalid, 'Database error')
      end

      it 'allows database errors to bubble up' do
        expect {
          described_class.bulk_delete([department1.id])
        }.to raise_error(ActiveRecord::StatementInvalid, 'Database error')
      end
    end
  end
end 