require 'rails_helper'

RSpec.describe Api::V1::GoalsController, type: :controller do
  let(:user) { create(:user) }
  let(:employee) { create(:employee, user: user) }
  let(:goal) { create(:goal, employee: employee) }

  before do
    sign_in(user)
    allow(controller).to receive(:current_employee).and_return(employee)
  end

  describe 'GET #index' do
    let!(:own_goal) { create(:goal, employee: employee) }
    let!(:other_goal) { create(:goal) }

    it 'returns own goals only' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => own_goal.id))
      expect(json_response['data']).not_to include(hash_including('id' => other_goal.id))
    end

    it 'filters by status' do
      active_goal = create(:goal, :active, employee: employee)
      completed_goal = create(:goal, :completed, employee: employee)

      get :index, params: { status: 'active' }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => active_goal.id))
      expect(json_response['data']).not_to include(hash_including('id' => completed_goal.id))
    end

    it 'filters by priority' do
      high_goal = create(:goal, :high_priority, employee: employee)
      low_goal = create(:goal, :low_priority, employee: employee)

      get :index, params: { priority: 'high' }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => high_goal.id))
      expect(json_response['data']).not_to include(hash_including('id' => low_goal.id))
    end

    it 'includes progress calculations' do
      goal_with_progress = create(:goal, :with_progress, employee: employee)

      get :index
      expect(response).to have_http_status(:ok)
      goal_data = json_response['data'].find { |g| g['id'] == goal_with_progress.id }
      expect(goal_data['completion_percentage']).to be_present
      expect(goal_data['progress_status']).to be_present
    end
  end

  describe 'GET #show' do
    it 'returns goal details with analytics' do
      get :show, params: { id: goal.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(
        'id' => goal.id,
        'title' => goal.title,
        'completion_percentage' => goal.completion_percentage.to_s,
        'days_until_due' => goal.days_until_due
      )
    end

    it 'includes SMART compliance analysis' do
      smart_goal = create(:smart_goal, employee: employee)

      get :show, params: { id: smart_goal.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['smart_score']).to be_present
      expect(json_response['data']['smart_compliant']).to be_present
    end
  end

  describe 'POST #create' do
    let(:valid_params) {
      {
        goal: {
          title: 'Increase Sales by 25%',
          description: 'Achieve 25% increase in quarterly sales revenue',
          target_value: 125000,
          due_date: 3.months.from_now,
          priority: 'high'
        }
      }
    }

    it 'creates a new goal' do
      expect {
        post :create, params: valid_params
      }.to change(Goal, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['data']['title']).to eq('Increase Sales by 25%')
    end

    it 'validates SMART criteria' do
      invalid_params = {
        goal: {
          title: 'Do better',
          description: 'Just improve somehow',
          target_value: 0,
          due_date: nil
        }
      }

      post :create, params: invalid_params
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['smart_violations']).to be_present
    end
  end

  describe 'PATCH #update' do
    it 'updates goal progress' do
      patch :update, params: {
        id: goal.id,
        goal: { actual_value: 75.0 }
      }

      expect(response).to have_http_status(:ok)
      goal.reload
      expect(goal.actual_value).to eq(75.0)
    end

    it 'auto-completes goal when target reached' do
      patch :update, params: {
        id: goal.id,
        goal: { actual_value: goal.target_value }
      }

      expect(response).to have_http_status(:ok)
      goal.reload
      expect(goal.status).to eq('completed')
      expect(goal.completed_at).to be_present
    end
  end

  describe 'POST #bulk_update_progress' do
    let!(:goals) { create_list(:goal, 3, employee: employee) }

    it 'updates multiple goals progress' do
      updates = goals.map.with_index { |g, i| { id: g.id, actual_value: (i + 1) * 25 } }

      post :bulk_update_progress, params: { goals: updates }
      expect(response).to have_http_status(:ok)

      goals.each_with_index do |goal, index|
        goal.reload
        expect(goal.actual_value).to eq((index + 1) * 25)
      end
    end
  end

  describe 'GET #overdue' do
    let!(:overdue_goal) { create(:goal, :overdue, employee: employee) }
    let!(:current_goal) { create(:goal, due_date: 1.month.from_now, employee: employee) }

    it 'returns only overdue goals' do
      get :overdue
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => overdue_goal.id))
      expect(json_response['data']).not_to include(hash_including('id' => current_goal.id))
    end
  end

  describe 'GET #analytics' do
    it 'returns goal analytics and insights' do
      create_list(:goal, 5, :completed, employee: employee)
      create_list(:goal, 3, :active, employee: employee)

      get :analytics
      expect(response).to have_http_status(:ok)
      
      analytics = json_response['data']
      expect(analytics['completion_rate']).to eq(62.5) # 5/8 * 100
      expect(analytics['goals_by_priority']).to be_present
      expect(analytics['average_progress']).to be_present
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end 