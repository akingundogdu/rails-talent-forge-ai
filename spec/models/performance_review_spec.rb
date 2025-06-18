require 'rails_helper'

RSpec.describe PerformanceReview, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
  end

  describe 'associations' do
    it { should belong_to(:employee) }
    it { should belong_to(:reviewer).class_name('Employee') }
    it { should have_many(:goals).dependent(:destroy) }
    it { should have_many(:feedbacks).dependent(:destroy) }
    it { should have_many(:ratings).dependent(:destroy) }
  end
end 