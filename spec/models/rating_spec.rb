require 'rails_helper'

RSpec.describe Rating, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:score) }
    it { should validate_presence_of(:competency_name) }
  end

  describe 'associations' do
    it { should belong_to(:performance_review) }
  end
end 