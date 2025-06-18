require 'rails_helper'

RSpec.describe Feedback, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:message) }
    it { should validate_presence_of(:feedback_type) }
  end

  describe 'associations' do
    it { should belong_to(:performance_review).optional }
    it { should belong_to(:giver).class_name('Employee') }
    it { should belong_to(:receiver).class_name('Employee') }
  end

  describe 'instance methods' do
    let(:feedback) { create(:feedback, rating: 4) }

    describe '#sentiment_score' do
      it 'returns very_positive for rating 5' do
        feedback.update(rating: 5)
        expect(feedback.sentiment_score).to eq('very_positive')
      end

      it 'returns positive for rating 4' do
        expect(feedback.sentiment_score).to eq('positive')
      end

      it 'returns neutral for rating 3' do
        feedback.update(rating: 3)
        expect(feedback.sentiment_score).to eq('neutral')
      end
    end

    describe '#is_positive?' do
      it 'returns true for ratings 4 and above' do
        expect(feedback.is_positive?).to be true
      end

      it 'returns false for ratings below 4' do
        feedback.update(rating: 3)
        expect(feedback.is_positive?).to be false
      end
    end

    describe '#anonymous?' do
      it 'returns true when feedback is anonymous' do
        feedback.update(anonymous: true)
        expect(feedback.anonymous?).to be true
      end

      it 'returns false when feedback is not anonymous' do
        feedback.update(anonymous: false)
        expect(feedback.anonymous?).to be false
      end
    end
  end
end 