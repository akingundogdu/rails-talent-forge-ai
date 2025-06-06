require 'rails_helper'

RSpec.describe PositionPolicy do
  let(:department) { create(:department) }
  let(:position) { create(:position, department: department) }
  
  let(:regular_user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:super_admin_user) { create(:user, :super_admin) }
  
  let(:employee) { create(:employee, department: department) }
  let(:user_with_employee) { create(:user) }

  before do
    user_with_employee.update!(employee: employee)
  end

  describe 'Scope' do
    let!(:department1) { create(:department) }
    let!(:department2) { create(:department) }
    let!(:position1) { create(:position, department: department1) }
    let!(:position2) { create(:position, department: department2) }

    subject { described_class::Scope.new(user, Position).resolve }

    context 'when user is super_admin' do
      let(:user) { super_admin_user }

      it 'returns all positions' do
        expect(subject).to include(position1, position2)
      end
    end

    context 'when user is admin' do
      let(:user) { admin_user }
      
      before do
        admin_user.managed_departments << department1
      end

      it 'returns positions from managed departments' do
        expect(subject).to include(position1)
        expect(subject).not_to include(position2)
      end
    end

    context 'when user is regular employee' do
      let(:user) { user_with_employee }

      it 'returns positions from user department' do
        position_in_dept = create(:position, department: employee.department)
        expect(subject).to include(position_in_dept)
        expect(subject).not_to include(position1, position2)
      end
    end
  end

  describe '#index?' do
    it 'allows access to everyone' do
      [regular_user, admin_user, super_admin_user].each do |user|
        policy = described_class.new(user, Position)
        expect(policy.index?).to be true
      end
    end
  end

  describe '#show?' do
    it 'allows admin to view any position' do
      policy = described_class.new(admin_user, position)
      expect(policy.show?).to be true
    end

    it 'allows users to view positions in their department' do
      position_in_dept = create(:position, department: employee.department)
      policy = described_class.new(user_with_employee, position_in_dept)
      expect(policy.show?).to be true
    end

    it 'denies users from viewing positions in other departments' do
      policy = described_class.new(user_with_employee, position)
      expect(policy.show?).to be false
    end
  end

  describe '#create?' do
    it 'allows admin to create positions' do
      policy = described_class.new(admin_user, Position)
      expect(policy.create?).to be true
    end

    it 'denies regular users from creating positions' do
      policy = described_class.new(regular_user, Position)
      expect(policy.create?).to be false
    end
  end

  describe '#update?' do
    context 'when user is admin' do
      before do
        admin_user.managed_departments << department
      end

      it 'allows admin to update positions in managed departments' do
        policy = described_class.new(admin_user, position)
        expect(policy.update?).to be true
      end

      it 'denies admin from updating positions in unmanaged departments' do
        other_dept_position = create(:position, department: create(:department))
        policy = described_class.new(admin_user, other_dept_position)
        expect(policy.update?).to be false
      end
    end

    it 'denies regular users from updating positions' do
      policy = described_class.new(regular_user, position)
      expect(policy.update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows super admin to delete positions' do
      policy = described_class.new(super_admin_user, position)
      expect(policy.destroy?).to be true
    end

    it 'denies admin from deleting positions' do
      policy = described_class.new(admin_user, position)
      expect(policy.destroy?).to be false
    end

    it 'denies regular users from deleting positions' do
      policy = described_class.new(regular_user, position)
      expect(policy.destroy?).to be false
    end
  end

  describe '#hierarchy?' do
    it 'follows the same rules as show?' do
      policy = described_class.new(admin_user, position)
      expect(policy.hierarchy?).to be true
      
      position_in_dept = create(:position, department: employee.department)
      policy = described_class.new(user_with_employee, position_in_dept)
      expect(policy.hierarchy?).to be true
      
      policy = described_class.new(user_with_employee, position)
      expect(policy.hierarchy?).to be false
    end
  end

  describe '#bulk_create?' do
    it 'allows admin to bulk create positions' do
      policy = described_class.new(admin_user, Position)
      expect(policy.bulk_create?).to be true
    end

    it 'allows super admin to bulk create positions' do
      policy = described_class.new(super_admin_user, Position)
      expect(policy.bulk_create?).to be true
    end

    it 'denies regular users from bulk creating positions' do
      policy = described_class.new(regular_user, Position)
      expect(policy.bulk_create?).to be false
    end
  end

  describe '#manages_department?' do
    let(:policy) { described_class.new(admin_user, position) }

    before do
      admin_user.managed_departments << department
    end

    it 'returns true when admin manages the department' do
      expect(policy.send(:manages_department?)).to be true
    end

    it 'returns false when admin does not manage the department' do
      other_position = create(:position, department: create(:department))
      policy = described_class.new(admin_user, other_position)
      expect(policy.send(:manages_department?)).to be false
    end
  end
end 