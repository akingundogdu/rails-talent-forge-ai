require 'rails_helper'

RSpec.describe BulkEmployeeService do
  let(:department) { create(:department) }
  let(:position) { create(:position, department: department, level: 1) }
  let(:manager_position) { create(:position, department: department, level: 2) }

  describe '.bulk_create' do
    let(:valid_employees) do
      [
        {
          'first_name' => 'John',
          'last_name' => 'Doe',
          'email' => 'john@example.com',
          'position_id' => position.id,
          'user_id' => create(:user).id
        },
        {
          'first_name' => 'Jane',
          'last_name' => 'Smith',
          'email' => 'jane@example.com',
          'position_id' => position.id,
          'user_id' => create(:user).id
        }
      ]
    end

    it 'creates multiple employees' do
      expect {
        described_class.bulk_create(valid_employees)
      }.to change(Employee, :count).by(2)
    end

    it 'validates batch limit' do
      employees = (BulkEmployeeService::BATCH_LIMIT + 1).times.map do |i|
        {
          'first_name' => "Employee #{i}",
          'last_name' => 'Last',
          'email' => "employee#{i}@example.com",
          'position_id' => position.id,
          'user_id' => create(:user).id
        }
      end

      expect {
        described_class.bulk_create(employees)
      }.to raise_error(BulkOperationService::BulkOperationError)
    end

    it 'validates required fields' do
      employees = [{ 'first_name' => 'Missing Required Fields' }]

      expect {
        described_class.bulk_create(employees)
      }.to raise_error(BulkOperationService::BulkOperationError)
    end

    it 'validates email uniqueness' do
      employees = [
        {
          'first_name' => 'John',
          'last_name' => 'Doe',
          'email' => 'same@example.com',
          'position_id' => position.id,
          'user_id' => create(:user).id
        },
        {
          'first_name' => 'Jane',
          'last_name' => 'Smith',
          'email' => 'same@example.com',
          'position_id' => position.id,
          'user_id' => create(:user).id
        }
      ]

      expect {
        described_class.bulk_create(employees)
      }.to raise_error(BulkOperationService::BulkOperationError)
    end
  end

  describe '.bulk_update' do
    let!(:employees) do
      create_list(:employee, 2, position: position).each do |employee|
        create(:user, employee: employee)
      end
    end

    let(:valid_updates) do
      employees.map do |emp|
        {
          'id' => emp.id,
          'first_name' => "Updated #{emp.first_name}"
        }
      end
    end

    it 'updates multiple employees' do
      updated_employees = described_class.bulk_update(valid_updates)
      expect(updated_employees.map(&:first_name)).to all(start_with('Updated'))
    end

    it 'validates existence of employees' do
      updates = [{ 'id' => 999, 'first_name' => 'Non-existent' }]

      expect {
        described_class.bulk_update(updates)
      }.to raise_error(BulkOperationService::BulkOperationError)
    end
  end

  describe '.bulk_delete' do
    let!(:employees) do
      create_list(:employee, 2, position: position).each do |employee|
        create(:user, employee: employee)
      end
    end

    let!(:manager) do
      create(:employee, position: manager_position).tap do |mgr|
        create(:user, employee: mgr)
        create(:employee, position: position, manager: mgr).tap do |sub|
          create(:user, employee: sub)
        end
      end
    end

    it 'deletes multiple employees' do
      expect {
        described_class.bulk_delete(employees.map(&:id))
      }.to change(Employee, :count).by(-2)
    end

    it 'validates existence of employees' do
      expect {
        described_class.bulk_delete([999])
      }.to raise_error(BulkOperationService::BulkOperationError)
    end

    it 'prevents deletion of employees with subordinates' do
      expect {
        described_class.bulk_delete([manager.id])
      }.to raise_error(BulkOperationService::BulkOperationError)
    end
  end

  describe '.bulk_transfer' do
    let!(:employees) do
      create_list(:employee, 2, position: position).each do |employee|
        create(:user, employee: employee)
      end
    end

    let(:new_position) { create(:position, department: department) }

    it 'transfers multiple employees to new position' do
      described_class.bulk_transfer(employees.map(&:id), new_position.id)
      expect(employees.map(&:reload).map(&:position_id)).to all(eq(new_position.id))
    end

    it 'validates existence of employees' do
      expect {
        described_class.bulk_transfer([999], new_position.id)
      }.to raise_error(BulkOperationService::BulkOperationError)
    end

    it 'validates existence of new position' do
      expect {
        described_class.bulk_transfer(employees.map(&:id), 999)
      }.to raise_error(BulkOperationService::BulkOperationError)
    end
  end

  describe '.bulk_assign_manager' do
    let!(:employees) do
      create_list(:employee, 2, position: position).each do |employee|
        create(:user, employee: employee)
      end
    end

    let(:new_manager) do
      create(:employee, position: manager_position).tap do |mgr|
        create(:user, employee: mgr)
      end
    end

    it 'assigns manager to multiple employees' do
      described_class.bulk_assign_manager(employees.map(&:id), new_manager.id)
      expect(employees.map(&:reload).map(&:manager_id)).to all(eq(new_manager.id))
    end

    it 'validates existence of employees' do
      expect {
        described_class.bulk_assign_manager([999], new_manager.id)
      }.to raise_error(BulkOperationService::BulkOperationError)
    end

    it 'validates existence of new manager' do
      expect {
        described_class.bulk_assign_manager(employees.map(&:id), 999)
      }.to raise_error(BulkOperationService::BulkOperationError)
    end

    it 'prevents self-management' do
      expect {
        described_class.bulk_assign_manager([employees.first.id], employees.first.id)
      }.to raise_error(BulkOperationService::BulkOperationError)
    end
  end
end 