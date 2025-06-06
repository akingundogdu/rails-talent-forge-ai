# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BulkEmployeeService, type: :service do
  let(:department) { create(:department) }
  let(:position) { create(:position, department: department, level: 1) }
  let(:manager_position) { create(:position, department: department, level: 2) }
  
  let(:user) { create(:user) }
  let(:manager_user) { create(:user) }

  describe '.bulk_create' do
    let(:valid_employees) do
      [
        {
          'first_name' => 'John',
          'last_name' => 'Doe',
          'email' => 'john.doe@example.com',
          'position_id' => position.id,
          'user_id' => user.id
        },
        {
          'first_name' => 'Jane',
          'last_name' => 'Smith', 
          'email' => 'jane.smith@example.com',
          'position_id' => position.id,
          'user_id' => manager_user.id
        }
      ]
    end

    context 'with valid data' do
      it 'creates employees successfully' do
        result = described_class.bulk_create(valid_employees)
        expect(result).to be_a(Hash)
        expect(result[:success]).to be_an(Array)
        expect(result[:success].size).to eq(2)
      end

      it 'creates employees with correct attributes' do
        result = described_class.bulk_create(valid_employees)
        john = result[:success].find { |e| e.first_name == 'John' }
        jane = result[:success].find { |e| e.first_name == 'Jane' }

        expect(john.last_name).to eq('Doe')
        expect(john.email).to eq('john.doe@example.com')
        expect(john.position_id).to eq(position.id)
        
        expect(jane.last_name).to eq('Smith')
        expect(jane.email).to eq('jane.smith@example.com')
        expect(jane.position_id).to eq(position.id)
      end
    end

    context 'when exceeding batch limit' do
      let(:too_many_employees) do
        (1..51).map do |i|
          {
            'first_name' => "Employee#{i}",
            'last_name' => 'Test',
            'email' => "employee#{i}@example.com",
            'position_id' => position.id
          }
        end
      end

      it 'raises BulkOperationError' do
        expect {
          described_class.bulk_create(too_many_employees)
        }.to raise_error(BulkOperationService::BulkOperationError, /Batch size exceeds limit/)
      end
    end

    context 'with missing required fields' do
      let(:invalid_employees) do
        [
          {
            'first_name' => 'John',
            'last_name' => 'Doe',
            'position_id' => position.id
            # missing email
          }
        ]
      end

      it 'raises BulkOperationError for missing fields' do
        expect {
          described_class.bulk_create(invalid_employees)
        }.to raise_error(BulkOperationService::BulkOperationError, /Missing required fields/)
      end
    end

    context 'with duplicate emails' do
      let(:duplicate_employees) do
        [
          {
            'first_name' => 'John',
            'last_name' => 'Doe',
            'email' => 'same@example.com',
            'position_id' => position.id
          },
          {
            'first_name' => 'Jane',
            'last_name' => 'Smith',
            'email' => 'same@example.com',
            'position_id' => position.id
          }
        ]
      end

      it 'raises BulkOperationError for duplicate emails' do
        expect {
          described_class.bulk_create(duplicate_employees)
        }.to raise_error(BulkOperationService::BulkOperationError, /Duplicate values found/)
      end
    end

    context 'with existing email in database' do
      let!(:existing_employee) { create(:employee, email: 'existing@example.com') }
      
      let(:conflicting_employees) do
        [
          {
            'first_name' => 'John',
            'last_name' => 'Doe', 
            'email' => 'existing@example.com',
            'position_id' => position.id
          }
        ]
      end

      it 'raises BulkOperationError for existing emails' do
        expect {
          described_class.bulk_create(conflicting_employees)
        }.to raise_error(BulkOperationService::BulkOperationError, /Email already exists/)
      end
    end
  end

  describe '.bulk_update' do
    let!(:employee1) { create(:employee, position: position, first_name: 'Original1') }
    let!(:employee2) { create(:employee, position: position, first_name: 'Original2') }
    
    let(:valid_updates) do
      [
        {
          id: employee1.id,
          first_name: 'Updated1',
          last_name: 'NewLastName1'
        },
        {
          id: employee2.id,
          first_name: 'Updated2',
          position_id: manager_position.id
        }
      ]
    end

    context 'with valid data' do
      it 'updates employees successfully' do
        result = described_class.bulk_update(valid_updates)
        expect(result).to be_a(Hash)
        expect(result[:success]).to be_an(Array)
        expect(result[:success].size).to eq(2)
      end

      it 'updates employee attributes correctly' do
        described_class.bulk_update(valid_updates)
        employee1.reload
        employee2.reload

        expect(employee1.first_name).to eq('Updated1')
        expect(employee1.last_name).to eq('NewLastName1')
        expect(employee2.first_name).to eq('Updated2')
        expect(employee2.position_id).to eq(manager_position.id)
      end
    end

    context 'with non-existent employee IDs' do
      let(:invalid_updates) do
        [
          {
            id: 999999,
            first_name: 'Updated'
          }
        ]
      end

      it 'raises BulkOperationError for missing employees' do
        expect {
          described_class.bulk_update(invalid_updates)
        }.to raise_error(BulkOperationService::BulkOperationError, /Employee not found/)
      end
    end
  end

  describe '.bulk_delete' do
    let!(:employee1) { create(:employee, position: position) }
    let!(:employee2) { create(:employee, position: position) }
    let(:employee_ids) { [employee1.id, employee2.id] }

    context 'with valid employee IDs' do
      it 'deletes employees successfully' do
        result = described_class.bulk_delete(employee_ids)
        expect(result).to be_a(Hash)
        expect(result[:success]).to be_an(Array)
        expect(result[:success].size).to eq(2)
      end
    end

    context 'with non-existent employee IDs' do
      let(:invalid_ids) { [999999, 999998] }

      it 'raises BulkOperationError for missing employees' do
        expect {
          described_class.bulk_delete(invalid_ids)
        }.to raise_error(BulkOperationService::BulkOperationError, /Employee not found/)
      end
    end

    context 'when employees have subordinates' do
      let!(:manager_employee) { create(:employee, position: manager_position) }
      let!(:subordinate) { create(:employee, position: position, manager: manager_employee) }

      it 'raises BulkOperationError for employees with subordinates' do
        expect {
          described_class.bulk_delete([manager_employee.id])
        }.to raise_error(BulkOperationService::BulkOperationError, /Cannot delete employees with subordinates/)
      end
    end
  end

  describe '.bulk_transfer' do
    let!(:employee1) { create(:employee, position: position) }
    let!(:employee2) { create(:employee, position: position) }
    let(:employee_ids) { [employee1.id, employee2.id] }

    context 'with valid data' do
      it 'transfers employees to new position' do
        result = described_class.bulk_transfer(employee_ids, manager_position.id)
        expect(result).to be_a(Hash)
        expect(result[:success]).to be_an(Array)
        expect(result[:success].size).to eq(2)
      end

      it 'updates employee positions correctly' do
        described_class.bulk_transfer(employee_ids, manager_position.id)
        employee1.reload
        employee2.reload

        expect(employee1.position_id).to eq(manager_position.id)
        expect(employee2.position_id).to eq(manager_position.id)
      end
    end

    context 'with non-existent employee IDs' do
      let(:invalid_ids) { [999999, 999998] }

      it 'raises BulkOperationError for missing employees' do
        expect {
          described_class.bulk_transfer(invalid_ids, manager_position.id)
        }.to raise_error(BulkOperationService::BulkOperationError, /Employee not found/)
      end
    end

    context 'with non-existent position ID' do
      it 'raises BulkOperationError for missing position' do
        expect {
          described_class.bulk_transfer(employee_ids, 999999)
        }.to raise_error(BulkOperationService::BulkOperationError, /Position not found/)
      end
    end
  end

  describe '.bulk_assign_manager' do
    let!(:employee1) { create(:employee, position: position) }
    let!(:employee2) { create(:employee, position: position) }
    let!(:manager_employee) { create(:employee, position: manager_position) }
    let(:employee_ids) { [employee1.id, employee2.id] }

    context 'with valid data' do
      it 'assigns manager to employees successfully' do
        result = described_class.bulk_assign_manager(employee_ids, manager_employee.id)
        expect(result).to be_a(Hash)
        expect(result[:success]).to be_an(Array)
        expect(result[:success].size).to eq(2)
      end

      it 'updates employee managers correctly' do
        described_class.bulk_assign_manager(employee_ids, manager_employee.id)
        employee1.reload
        employee2.reload

        expect(employee1.manager_id).to eq(manager_employee.id)
        expect(employee2.manager_id).to eq(manager_employee.id)
      end
    end

    context 'with non-existent employee IDs' do
      let(:invalid_ids) { [999999, 999998] }

      it 'raises BulkOperationError for missing employees' do
        expect {
          described_class.bulk_assign_manager(invalid_ids, manager_employee.id)
        }.to raise_error(BulkOperationService::BulkOperationError, /Employee not found/)
      end
    end

    context 'with non-existent manager ID' do
      it 'raises BulkOperationError for missing manager' do
        expect {
          described_class.bulk_assign_manager(employee_ids, 999999)
        }.to raise_error(BulkOperationService::BulkOperationError, /Employee not found/)
      end
    end

    context 'when employee tries to be their own manager' do
      it 'raises BulkOperationError for self-management' do
        expect {
          described_class.bulk_assign_manager([employee1.id], employee1.id)
        }.to raise_error(BulkOperationService::BulkOperationError, /Employee cannot be their own manager/)
      end
    end
  end

  describe 'class constants and inheritance' do
    it 'has correct batch limit' do
      expect(described_class::BATCH_LIMIT).to eq(50)
    end

    it 'has correct required fields' do
      expect(described_class::REQUIRED_FIELDS).to eq(%w[first_name last_name email position_id])
    end
  end

  describe 'private validation methods' do
    describe '.validate_limit!' do
      it 'raises error when exceeding limit' do
        large_params = Array.new(51) { {} }
        expect {
          described_class.send(:validate_limit!, large_params)
        }.to raise_error(BulkOperationService::BulkOperationError, /Batch size exceeds limit/)
      end

      it 'does not raise error within limit' do
        small_params = Array.new(10) { {} }
        expect {
          described_class.send(:validate_limit!, small_params)
        }.not_to raise_error
      end
    end

    describe '.validate_presence!' do
      it 'raises error for missing required fields' do
        params = [{ first_name: 'John' }] # missing other required fields
        expect {
          described_class.send(:validate_presence!, params, %w[first_name last_name email])
        }.to raise_error(BulkOperationService::BulkOperationError, /Missing required fields/)
      end

      it 'does not raise error when all fields present' do
        params = [{ first_name: 'John', last_name: 'Doe', email: 'john@example.com' }]
        expect {
          described_class.send(:validate_presence!, params, %w[first_name last_name email])
        }.not_to raise_error
      end
    end

    describe '.validate_uniqueness!' do
      it 'raises error for duplicate values within params' do
        params = [
          { email: 'same@example.com' },
          { email: 'same@example.com' }
        ]
        expect {
          described_class.send(:validate_uniqueness!, params, :email)
        }.to raise_error(BulkOperationService::BulkOperationError, /Duplicate values found/)
      end

      it 'raises error for existing values in database' do
        create(:employee, email: 'existing@example.com')
        params = [{ email: 'existing@example.com' }]
        expect {
          described_class.send(:validate_uniqueness!, params, :email)
        }.to raise_error(BulkOperationService::BulkOperationError, /Email already exists/)
      end
    end

    describe '.validate_existence!' do
      it 'raises error for non-existent records' do
        expect {
          described_class.send(:validate_existence!, [999999], Employee)
        }.to raise_error(BulkOperationService::BulkOperationError, /Employee not found/)
      end

      it 'does not raise error for existing records' do
        employee = create(:employee)
        expect {
          described_class.send(:validate_existence!, [employee.id], Employee)
        }.not_to raise_error
      end
    end

    describe '.validate_no_subordinates!' do
      it 'raises error for employees with subordinates' do
        manager = create(:employee, position: manager_position)
        create(:employee, position: position, manager: manager)
        
        expect {
          described_class.send(:validate_no_subordinates!, [manager.id])
        }.to raise_error(BulkOperationService::BulkOperationError, /Cannot delete employees with subordinates/)
      end

      it 'does not raise error for employees without subordinates' do
        employee = create(:employee)
        expect {
          described_class.send(:validate_no_subordinates!, [employee.id])
        }.not_to raise_error
      end
    end

    describe '.validate_no_self_management!' do
      it 'raises error when employee tries to be their own manager' do
        expect {
          described_class.send(:validate_no_self_management!, [1], 1)
        }.to raise_error(BulkOperationService::BulkOperationError, /Employee cannot be their own manager/)
      end

      it 'does not raise error for valid manager assignment' do
        expect {
          described_class.send(:validate_no_self_management!, [1], 2)
        }.not_to raise_error
      end
    end
  end
end 