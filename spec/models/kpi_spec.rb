require 'rails_helper'

RSpec.describe Kpi, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:target_value) }
    it { should validate_numericality_of(:target_value).is_greater_than(0) }
    it { should validate_numericality_of(:actual_value).is_greater_than_or_equal_to(0) }
  end

  describe 'associations' do
    it { should belong_to(:employee) }
    it { should belong_to(:position).optional }
  end

  describe 'instance methods' do
    let(:kpi) { create(:kpi, target_value: 100, actual_value: 75) }

    describe '#achievement_percentage' do
      it 'calculates achievement as percentage of target' do
        expect(kpi.achievement_percentage).to eq(75.0)
      end

      it 'handles zero target value' do
        kpi.target_value = 0
        expect(kpi.achievement_percentage).to eq(0)
      end
    end

    describe '#achievement_status' do
      it 'returns correct status for different achievement levels' do
        kpi.update(actual_value: 95)
        expect(kpi.achievement_status).to eq('approaching_target')
      end
    end
  end
end 