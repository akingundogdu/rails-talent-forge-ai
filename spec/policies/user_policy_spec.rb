require 'rails_helper'

RSpec.describe UserPolicy do
  let(:regular_user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:super_admin_user) { create(:user, :super_admin) }
  let(:target_user) { create(:user) }

  describe '#show?' do
    it "allows users to view their own profile" do
      policy = described_class.new(regular_user, regular_user)
      expect(policy.show?).to be true
    end

    it "allows admins to view any user's profile" do
      policy = described_class.new(admin_user, target_user)
      expect(policy.show?).to be true
    end

    it "denies users from viewing other users' profiles" do
      policy = described_class.new(regular_user, target_user)
      expect(policy.show?).to be false
    end
  end

  describe '#update?' do
    it "allows users to update their own profile" do
      policy = described_class.new(regular_user, regular_user)
      expect(policy.update?).to be true
    end

    it "allows super admins to update any user's profile" do
      policy = described_class.new(super_admin_user, target_user)
      expect(policy.update?).to be true
    end

    it "denies admins from updating other users' profiles" do
      policy = described_class.new(admin_user, target_user)
      expect(policy.update?).to be false
    end

    it "denies regular users from updating other users' profiles" do
      policy = described_class.new(regular_user, target_user)
      expect(policy.update?).to be false
    end
  end

  describe '#manage_permissions?' do
    it "allows super admins to manage any user's permissions" do
      policy = described_class.new(super_admin_user, target_user)
      expect(policy.manage_permissions?).to be true
    end

    it "allows admins to manage regular users' permissions" do
      policy = described_class.new(admin_user, regular_user)
      expect(policy.manage_permissions?).to be true
    end

    it "denies admins from managing other admin's permissions" do
      other_admin = create(:user, :admin)
      policy = described_class.new(admin_user, other_admin)
      expect(policy.manage_permissions?).to be false
    end

    it "denies regular users from managing permissions" do
      policy = described_class.new(regular_user, target_user)
      expect(policy.manage_permissions?).to be false
    end
  end
end 