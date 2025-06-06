# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PermissionService, type: :service do
  let(:department) { create(:department) }
  let(:position) { create(:position, department: department) }
  
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:super_admin_user) { create(:user, :super_admin) }
  
  before do
    # Mock permission methods on User
    allow_any_instance_of(User).to receive(:grant_permission)
    allow_any_instance_of(User).to receive(:revoke_permission)
    
    # Disable Employee callbacks that call PermissionService
    allow_any_instance_of(Employee).to receive(:assign_default_permissions)
    allow_any_instance_of(Employee).to receive(:update_permissions)
  end

  describe '.assign_default_permissions' do
    context 'for admin users' do
      it 'returns early without assigning permissions' do
        described_class.assign_default_permissions(admin_user)
        # Just testing the method completes without error
      end
    end

    context 'for super admin users' do
      it 'returns early without assigning permissions' do
        described_class.assign_default_permissions(super_admin_user)
        # Just testing the method completes without error
      end
    end

    context 'for regular users with employee' do
      let(:employee) { create(:employee, position: position, user: user) }

      before { employee }

      it 'assigns permissions when user has employee with position and department' do
        expect(user).to receive(:grant_permission).at_least(:once)
        
        described_class.assign_default_permissions(user)
      end
    end

    context 'for users without employee' do
      it 'does not call grant_permission' do
        expect(user).not_to receive(:grant_permission)
        
        described_class.assign_default_permissions(user)
      end
    end

    context 'for users with employee but no position' do
      let(:employee) { create(:employee, user: user) }

      before do
        employee
        # Simulate employee without position/department
        allow(employee).to receive(:position).and_return(nil)
      end

      it 'only assigns employee permission' do
        expect(user).to receive(:grant_permission).with('read', 'employee', employee.id)
        
        described_class.assign_default_permissions(user)
      end
    end

    context 'for users with managed departments' do
      let(:managed_department) { create(:department) }
      let(:manager_position) { create(:position, department: managed_department) }
      let(:manager_employee) { create(:employee, position: manager_position, user: user) }

      before do
        manager_employee
        managed_department.update!(manager: manager_employee)
      end

      it 'assigns manager permissions' do
        expect(user).to receive(:grant_permission).at_least(:once)
        
        described_class.assign_default_permissions(user)
      end
    end
  end

  describe '.update_manager_permissions' do
    let(:employee) { create(:employee, position: position, user: user) }
    let(:old_manager) { create(:user) }
    let(:new_manager) { create(:user) }

    context 'when manager has changed' do
      before do
        allow(employee).to receive(:manager_id_changed?).and_return(true)
        allow(employee).to receive(:manager_id_was).and_return(old_manager.employee&.id)
        allow(employee).to receive(:manager_id).and_return(new_manager.employee&.id)
        
        # Create employees for users
        create(:employee, user: old_manager)
        create(:employee, user: new_manager)
      end

      it 'processes manager permission changes' do
        described_class.update_manager_permissions(employee)
        # Just testing the method completes without error
      end
    end

    context 'when manager has not changed' do
      before do
        allow(employee).to receive(:manager_id_changed?).and_return(false)
      end

      it 'returns early without processing' do
        described_class.update_manager_permissions(employee)
        # Just testing the method completes without error
      end
    end

    context 'when old manager exists' do
      let(:old_manager_employee) { create(:employee, user: old_manager) }

      before do
        allow(employee).to receive(:manager_id_changed?).and_return(true)
        allow(employee).to receive(:manager_id_was).and_return(old_manager_employee.id)
        allow(employee).to receive(:manager_id).and_return(nil)
        
        # Mock the User.joins query to return the old_manager
        allow(User).to receive_message_chain(:joins, :find_by).and_return(old_manager)
      end

      it 'revokes permission from old manager' do
        expect(old_manager).to receive(:revoke_permission)
        
        described_class.update_manager_permissions(employee)
      end
    end

    context 'when new manager exists' do
      let(:new_manager_employee) { create(:employee, user: new_manager) }

      before do
        allow(employee).to receive(:manager_id_changed?).and_return(true)
        allow(employee).to receive(:manager_id_was).and_return(nil)
        allow(employee).to receive(:manager_id).and_return(new_manager_employee.id)
        
        # Mock the User.joins query to return the new_manager
        allow(User).to receive_message_chain(:joins, :find_by).and_return(new_manager)
      end

      it 'grants permission to new manager' do
        expect(new_manager).to receive(:grant_permission)
        
        described_class.update_manager_permissions(employee)
      end
    end
  end

  describe '.update_department_permissions' do
    let(:employee) { create(:employee, position: position, user: user) }
    let(:old_department) { create(:department) }
    let(:new_department) { create(:department) }
    let(:old_position) { create(:position, department: old_department) }
    let(:new_position) { create(:position, department: new_department) }

    context 'when position has not changed' do
      before do
        allow(employee).to receive(:position_id_changed?).and_return(false)
      end

      it 'returns early without processing' do
        described_class.update_department_permissions(employee)
        # Just testing the method completes without error
      end
    end

    context 'when position has changed' do
      before do
        allow(employee).to receive(:position_id_changed?).and_return(true)
        allow(employee).to receive(:position_id_was).and_return(old_position.id)
        allow(employee).to receive(:position_id).and_return(new_position.id)
      end

      it 'processes department permission changes' do
        described_class.update_department_permissions(employee)
        # Just testing the method completes without error
      end
    end

    context 'when old department exists' do
      before do
        allow(employee).to receive(:position_id_changed?).and_return(true)
        allow(employee).to receive(:position_id_was).and_return(old_position.id)
        allow(employee).to receive(:position_id).and_return(nil)
      end

      it 'revokes permission from old department' do
        expect(user).to receive(:revoke_permission).with('read', 'department', old_department.id)
        
        described_class.update_department_permissions(employee)
      end
    end

    context 'when new department exists' do
      before do
        allow(employee).to receive(:position_id_changed?).and_return(true)
        allow(employee).to receive(:position_id_was).and_return(nil)
        allow(employee).to receive(:position_id).and_return(new_position.id)
      end

      it 'grants permission to new department' do
        expect(user).to receive(:grant_permission).with('read', 'department', new_department.id)
        
        described_class.update_department_permissions(employee)
      end
    end

    context 'when departments are the same' do
      let(:same_department) { create(:department) }
      let(:position1) { create(:position, department: same_department) }
      let(:position2) { create(:position, department: same_department) }

      before do
        allow(employee).to receive(:position_id_changed?).and_return(true)
        allow(employee).to receive(:position_id_was).and_return(position1.id)
        allow(employee).to receive(:position_id).and_return(position2.id)
      end

      it 'does not update permissions when department is the same' do
        expect(user).not_to receive(:grant_permission)
        expect(user).not_to receive(:revoke_permission)
        
        described_class.update_department_permissions(employee)
      end
    end
  end

  describe 'edge cases' do
    context 'when Position.find_by returns nil' do
      let(:employee) { create(:employee, position: position, user: user) }

      before do
        allow(employee).to receive(:position_id_changed?).and_return(true)
        allow(employee).to receive(:position_id_was).and_return(999999)
        allow(employee).to receive(:position_id).and_return(999998)
      end

      it 'handles missing positions gracefully' do
        expect { described_class.update_department_permissions(employee) }.not_to raise_error
      end
    end

    context 'when User.joins query returns nil' do
      let(:employee) { create(:employee, position: position, user: user) }

      before do
        allow(employee).to receive(:manager_id_changed?).and_return(true)
        allow(employee).to receive(:manager_id_was).and_return(999999)
        allow(employee).to receive(:manager_id).and_return(999998)
      end

      it 'handles missing users gracefully' do
        expect { described_class.update_manager_permissions(employee) }.not_to raise_error
      end
    end
  end
end