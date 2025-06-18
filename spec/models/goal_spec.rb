require 'rails_helper'

RSpec.describe Goal, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:due_date) }
    it { should validate_presence_of(:target_value) }
    it { should validate_numericality_of(:target_value).is_greater_than(0) }
    it { should validate_numericality_of(:actual_value).is_greater_than_or_equal_to(0) }
  end

  describe 'associations' do
    it { should belong_to(:employee) }
    it { should belong_to(:performance_review).optional }
  end

  describe 'instance methods' do
    let(:goal) { create(:goal, target_value: 100, actual_value: 75) }

    describe '#completion_percentage' do
      it 'calculates completion as percentage of target' do
        expect(goal.completion_percentage).to eq(75.0)
      end

      it 'caps completion at 100%' do
        goal.update(actual_value: 120)
        expect(goal.completion_percentage).to eq(100.0)
      end
    end

    describe '#is_overdue?' do
      it 'returns true for overdue goals' do
        overdue_goal = build(:goal, due_date: 1.day.from_now)
        overdue_goal.save(validate: false)
        overdue_goal.update_column(:due_date, 1.day.ago)
        expect(overdue_goal.is_overdue?).to be true
      end

      it 'returns false for future goals' do
        future_goal = create(:goal, due_date: 1.day.from_now)
        expect(future_goal.is_overdue?).to be false
      end
    end
  end
end 