# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BulkPositionService, type: :service do
  let(:department) { create(:department) }
  let(:parent_position) { create(:position, department: department, level: 2) }
  let(:position) { create(:position, department: department, level: 1, parent_position: parent_position) }

  describe '.bulk_create' do
    let(:valid_positions) do
      [
                 {
           'title' => 'Manager',
           'level' => 2,
           'department_id' => department.id,
           'description' => 'Department Manager'
         },
         {
           'title' => 'Senior Developer',
           'level' => 1,
           'department_id' => department.id,
           'parent_position_id' => parent_position.id
         }
      ]
    end

    context 'with valid data' do
      it 'creates positions successfully' do
        expect {
          described_class.bulk_create(valid_positions)
        }.to change(Position, :count).by(3)
      end

      it 'returns created positions' do
        result = described_class.bulk_create(valid_positions)
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
        expect(result.all? { |p| p.is_a?(Position) }).to be true
      end

      it 'creates positions with correct attributes' do
        result = described_class.bulk_create(valid_positions)
        manager = result.find { |p| p.title == 'Manager' }
        developer = result.find { |p| p.title == 'Senior Developer' }

        expect(manager.level).to eq(2)
        expect(manager.department_id).to eq(department.id)
        expect(developer.parent_position_id).to eq(parent_position.id)
      end
    end

    context 'when exceeding batch limit' do
      let(:too_many_positions) do
        (1..51).map do |i|
                     {
             'title' => "Position #{i}",
             'level' => 2,
             'department_id' => department.id
           }
        end
      end

      it 'raises BulkOperationError' do
        expect {
          described_class.bulk_create(too_many_positions)
        }.to raise_error(BulkOperationService::BulkOperationError, /Batch size exceeds limit/)
      end
    end

    context 'with missing required fields' do
      let(:invalid_positions) do
        [
          {
            'title' => 'Manager',
            'department_id' => department.id
            # missing level
          }
        ]
      end

      it 'raises BulkOperationError for missing fields' do
        expect {
          described_class.bulk_create(invalid_positions)
        }.to raise_error(BulkOperationService::BulkOperationError, /Missing required fields/)
      end
    end

    context 'with duplicate titles' do
      let(:duplicate_positions) do
        [
                     {
             'title' => 'Manager',
             'level' => 2,
             'department_id' => department.id
           },
           {
             'title' => 'Manager',
             'level' => 2,
             'department_id' => department.id
           }
        ]
      end

      it 'raises BulkOperationError for duplicate titles' do
        expect {
          described_class.bulk_create(duplicate_positions)
        }.to raise_error(BulkOperationService::BulkOperationError, /Duplicate values found/)
      end
    end

    context 'with non-existent department' do
      let(:invalid_department_positions) do
        [
                     {
             'title' => 'Manager',
             'level' => 2,
             'department_id' => 999999
           }
        ]
      end

      it 'raises BulkOperationError for missing department' do
        expect {
          described_class.bulk_create(invalid_department_positions)
        }.to raise_error(BulkOperationService::BulkOperationError, /Department not found/)
      end
    end

    context 'with non-existent parent position' do
      let(:invalid_parent_positions) do
        [
                     {
             'title' => 'Manager',
             'level' => 1,
             'department_id' => department.id,
             'parent_position_id' => 999999
           }
        ]
      end

      it 'raises BulkOperationError for missing parent position' do
        expect {
          described_class.bulk_create(invalid_parent_positions)
        }.to raise_error(BulkOperationService::BulkOperationError, /Position not found/)
      end
    end
  end

  describe '.bulk_update' do
    let!(:position1) { create(:position, department: department, title: 'Original Title 1') }
    let!(:position2) { create(:position, department: department, title: 'Original Title 2') }
    
    let(:valid_updates) do
      [
        {
          'id' => position1.id,
          'title' => 'Updated Title 1',
          'level' => 3
        },
        {
          'id' => position2.id,
          'title' => 'Updated Title 2',
          'department_id' => department.id
        }
      ]
    end

    context 'with valid data' do
      it 'updates positions successfully' do
        result = described_class.bulk_update(valid_updates)
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
      end

      it 'updates position attributes correctly' do
        described_class.bulk_update(valid_updates)
        position1.reload
        position2.reload

        expect(position1.title).to eq('Updated Title 1')
        expect(position1.level).to eq(3)
        expect(position2.title).to eq('Updated Title 2')
      end
    end

    context 'when exceeding batch limit' do
      let(:too_many_updates) do
                 (1..51).map do |i|
           {
             'id' => create(:position).id,
             'title' => "Updated #{i}"
           }
         end
      end

      it 'raises BulkOperationError' do
        expect {
          described_class.bulk_update(too_many_updates)
        }.to raise_error(BulkOperationService::BulkOperationError, /Batch size exceeds limit/)
      end
    end

    context 'with non-existent position IDs' do
      let(:invalid_updates) do
        [
          {
            'id' => 999999,
            'title' => 'Updated Title'
          }
        ]
      end

      it 'raises BulkOperationError for missing positions' do
        expect {
          described_class.bulk_update(invalid_updates)
        }.to raise_error(BulkOperationService::BulkOperationError, /Position not found/)
      end
    end

    context 'with non-existent department in updates' do
      let(:invalid_department_updates) do
        [
          {
            'id' => position1.id,
            'department_id' => 999999
          }
        ]
      end

      it 'raises BulkOperationError for missing department' do
        expect {
          described_class.bulk_update(invalid_department_updates)
        }.to raise_error(BulkOperationService::BulkOperationError, /Department not found/)
      end
    end
  end

  describe '.bulk_delete' do
    let!(:position1) { create(:position, department: department) }
    let!(:position2) { create(:position, department: department) }
    let(:position_ids) { [position1.id, position2.id] }

    context 'with valid position IDs' do
      it 'deletes positions successfully' do
        expect {
          described_class.bulk_delete(position_ids)
        }.to change(Position, :count).by(-2)
      end

      it 'deletes the correct positions' do
        described_class.bulk_delete(position_ids)
        expect(Position.exists?(position1.id)).to be false
        expect(Position.exists?(position2.id)).to be false
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

    context 'with non-existent position IDs' do
      let(:invalid_ids) { [999999, 999998] }

      it 'raises BulkOperationError for missing positions' do
        expect {
          described_class.bulk_delete(invalid_ids)
        }.to raise_error(BulkOperationService::BulkOperationError) do |error|
          expect(error.message).to include('Some positions not found')
          expect(error.errors[:missing_ids]).to match_array(invalid_ids)
        end
      end
    end

    context 'when positions have employees' do
      let!(:employee) { create(:employee, position: position1) }

      it 'raises BulkOperationError for positions with employees' do
        expect {
          described_class.bulk_delete([position1.id])
        }.to raise_error(BulkOperationService::BulkOperationError) do |error|
          expect(error.message).to include('Cannot delete position with employees')
          expect(error.errors[:position_id]).to eq(position1.id)
        end
      end

      it 'does not delete any positions when one has employees' do
        expect {
          described_class.bulk_delete([position1.id, position2.id])
        }.to raise_error(BulkOperationService::BulkOperationError)
        
        expect(Position.exists?(position1.id)).to be true
        expect(Position.exists?(position2.id)).to be true
      end
    end
  end

  describe '.bulk_transfer' do
    let!(:position1) { create(:position, department: department) }
    let!(:position2) { create(:position, department: department) }
    let(:new_department) { create(:department) }
    let(:position_ids) { [position1.id, position2.id] }

    context 'with valid data' do
      it 'transfers positions to new department' do
        described_class.bulk_transfer(position_ids, new_department.id)
        
        position1.reload
        position2.reload
        
        expect(position1.department_id).to eq(new_department.id)
        expect(position2.department_id).to eq(new_department.id)
      end

      it 'returns updated positions' do
        result = described_class.bulk_transfer(position_ids, new_department.id)
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
      end
    end

    context 'when exceeding batch limit' do
      let(:too_many_ids) { (1..51).to_a }

      it 'raises BulkOperationError' do
        expect {
          described_class.bulk_transfer(too_many_ids, new_department.id)
        }.to raise_error(BulkOperationService::BulkOperationError, /Batch size exceeds limit/)
      end
    end

    context 'with non-existent position IDs' do
      let(:invalid_ids) { [999999, 999998] }

      it 'raises BulkOperationError for missing positions' do
        expect {
          described_class.bulk_transfer(invalid_ids, new_department.id)
        }.to raise_error(BulkOperationService::BulkOperationError) do |error|
          expect(error.message).to include('Some positions not found')
          expect(error.errors[:missing_ids]).to match_array(invalid_ids)
        end
      end
    end

    context 'with non-existent department' do
      it 'raises BulkOperationError for missing department' do
        expect {
          described_class.bulk_transfer(position_ids, 999999)
        }.to raise_error(BulkOperationService::BulkOperationError) do |error|
          expect(error.message).to include('Department not found')
          expect(error.errors[:department_id]).to eq(999999)
        end
      end
    end

    context 'when validation fails during transfer' do
      before do
        allow_any_instance_of(Position).to receive(:update!).and_raise(
          ActiveRecord::RecordInvalid.new(position1)
        )
        allow(position1).to receive_message_chain(:errors, :full_messages).and_return(['Invalid position'])
      end

      it 'raises BulkOperationError with validation errors' do
        expect {
          described_class.bulk_transfer(position_ids, new_department.id)
        }.to raise_error(BulkOperationService::BulkOperationError, /Validation failed/)
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
      expect(described_class::REQUIRED_FIELDS).to eq(%w[title level department_id])
    end
  end

  describe 'error handling' do
    context 'when ActiveRecord errors occur' do
      before do
        allow(Position).to receive(:where).and_raise(ActiveRecord::StatementInvalid, 'Database error')
      end

      it 'allows database errors to bubble up' do
        expect {
          described_class.bulk_delete([position.id])
        }.to raise_error(ActiveRecord::StatementInvalid, 'Database error')
      end
    end
  end
end 