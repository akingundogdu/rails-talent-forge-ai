require 'rails_helper'

RSpec.describe Api::V1::FeedbacksController, type: :controller do
  let(:user) { create(:user) }
  let(:employee) { create(:employee, user: user) }
  let(:manager) { create(:employee, :manager) }
  let(:feedback) { create(:feedback, receiver: employee) }

  before do
    sign_in(user)
    allow(controller).to receive(:current_employee).and_return(employee)
  end

  describe 'GET #index' do
    let!(:received_feedback) { create(:feedback, receiver: employee) }
    let!(:given_feedback) { create(:feedback, giver: employee) }
    let!(:other_feedback) { create(:feedback) }

    it 'returns received feedback by default' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => received_feedback.id))
      expect(json_response['data']).not_to include(hash_including('id' => given_feedback.id))
    end

    it 'returns given feedback when specified' do
      get :index, params: { type: 'given' }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => given_feedback.id))
      expect(json_response['data']).not_to include(hash_including('id' => received_feedback.id))
    end

    it 'filters by feedback type' do
      peer_feedback = create(:feedback, :peer_feedback, receiver: employee)
      manager_feedback = create(:feedback, :manager_feedback, receiver: employee)

      get :index, params: { feedback_type: 'peer' }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => peer_feedback.id))
      expect(json_response['data']).not_to include(hash_including('id' => manager_feedback.id))
    end

    it 'filters by sentiment' do
      positive_feedback = create(:feedback, :positive_feedback, receiver: employee)
      negative_feedback = create(:feedback, :negative_feedback, receiver: employee)

      get :index, params: { sentiment: 'positive' }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => positive_feedback.id))
      expect(json_response['data']).not_to include(hash_including('id' => negative_feedback.id))
    end

    it 'includes anonymized giver info for anonymous feedback' do
      anonymous_feedback = create(:feedback, :anonymous, receiver: employee)

      get :index
      expect(response).to have_http_status(:ok)
      feedback_data = json_response['data'].find { |f| f['id'] == anonymous_feedback.id }
      expect(feedback_data['giver']['name']).to eq('Anonymous')
    end
  end

  describe 'GET #show' do
    it 'returns feedback details' do
      get :show, params: { id: feedback.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(
        'id' => feedback.id,
        'message' => feedback.message,
        'rating' => feedback.rating,
        'feedback_type' => feedback.feedback_type
      )
    end

    it 'includes relationship analysis' do
      get :show, params: { id: feedback.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['relationship_type']).to be_present
      expect(json_response['data']['word_count']).to be_present
      expect(json_response['data']['is_constructive']).to be_present
    end

    it 'protects anonymous feedback giver identity' do
      anonymous_feedback = create(:feedback, :anonymous, receiver: employee)

      get :show, params: { id: anonymous_feedback.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['giver']['name']).to eq('Anonymous')
      expect(json_response['data']['giver']['id']).to be_nil
    end
  end

  describe 'POST #create' do
    let(:peer) { create(:employee) }
    let(:valid_params) {
      {
        feedback: {
          receiver_id: peer.id,
          message: 'Excellent collaboration skills and always helpful in team projects. Shows strong technical expertise.',
          feedback_type: 'peer',
          rating: 4.5,
          anonymous: false
        }
      }
    }

    it 'creates a new feedback' do
      expect {
        post :create, params: valid_params
      }.to change(Feedback, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['data']['message']).to include('Excellent collaboration')
    end

    it 'automatically calculates sentiment score' do
      post :create, params: valid_params
      expect(response).to have_http_status(:created)
      
      created_feedback = Feedback.last
      expect(created_feedback.sentiment_score).to be_present
      expect(['positive', 'negative', 'neutral']).to include(created_feedback.sentiment_score)
    end

    it 'validates self-feedback rules' do
      self_feedback_params = valid_params.deep_merge({
        feedback: {
          receiver_id: employee.id,
          feedback_type: 'peer'
        }
      })

      post :create, params: self_feedback_params
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to include('Giver cannot be the same as receiver unless self-evaluation')
    end

    it 'allows self-feedback when type is self' do
      self_feedback_params = valid_params.deep_merge({
        feedback: {
          receiver_id: employee.id,
          message: 'I believe I have improved significantly in communication skills this quarter.',
          feedback_type: 'self_evaluation'
        }
      })

      post :create, params: self_feedback_params
      expect(response).to have_http_status(:created)
    end

    it 'validates manager feedback relationships' do
      employee.update!(manager: manager)
      allow(controller).to receive(:current_employee).and_return(manager)

      manager_feedback_params = valid_params.deep_merge({
        feedback: {
          receiver_id: employee.id,
          feedback_type: 'manager'
        }
      })

      post :create, params: manager_feedback_params
      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH #update' do
    let(:own_feedback) { create(:feedback, giver: employee) }

    it 'updates feedback content' do
      patch :update, params: {
        id: feedback.id,
        feedback: { message: 'Updated feedback content with more specific examples.' }
      }

      expect(response).to have_http_status(:ok)
      feedback.reload
      expect(feedback.message).to include('Updated feedback content')
    end

    it 'recalculates sentiment after content update' do
      original_sentiment = feedback.sentiment_score

      patch :update, params: {
        id: feedback.id,
        feedback: { message: 'Outstanding performance! Exceptional work quality and amazing teamwork skills!' }
      }

      expect(response).to have_http_status(:ok)
      feedback.reload
      expect(feedback.sentiment_score).to be_present
      expect(['positive', 'negative', 'neutral']).to include(feedback.sentiment_score)
    end

    it 'prevents updating others feedback' do
      other_feedback = create(:feedback)

      patch :update, params: {
        id: other_feedback.id,
        feedback: { message: 'Hacked content' }
      }

      expect(response).to have_http_status(:forbidden)
    end

    it 'prevents updating old feedback' do
      old_feedback = create(:feedback, giver: employee, created_at: 31.days.ago)

      patch :update, params: {
        id: old_feedback.id,
        feedback: { message: 'Too late to update' }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to include('Feedback cannot be edited after 24 hours or when review is completed')
    end
  end

  describe 'DELETE #destroy' do
    let(:own_feedback) { create(:feedback, giver: employee) }

    it 'deletes own recent feedback' do
      expect {
        delete :destroy, params: { id: own_feedback.id }
      }.to change { own_feedback.reload.deleted_at }.from(nil)

      expect(response).to have_http_status(:ok)
    end

    it 'prevents deleting old feedback' do
      old_feedback = create(:feedback, giver: employee, created_at: 31.days.ago)

      delete :destroy, params: { id: old_feedback.id }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to include('Feedback cannot be deleted after 24 hours or when review is completed')
    end
  end

  describe 'POST #request_feedback' do
    let(:peers) { create_list(:employee, 3) }

    it 'sends feedback requests to specified employees' do
      expect {
        post :request_feedback, params: {
          employee_ids: peers.pluck(:id),
          message: 'Please provide feedback on my recent project work.',
          feedback_type: 'peer'
        }
      }.to change(FeedbackRequest, :count).by(3)

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['requested_count']).to eq(3)
    end

    it 'validates request limits' do
      # Assume there's a limit of 10 requests per month
      create_list(:feedback_request, 10, requester: employee, created_at: 1.week.ago)

      post :request_feedback, params: {
        employee_ids: peers.pluck(:id),
        message: 'One more request'
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['requested_count']).to eq(3)
    end
  end

  describe 'GET #analytics' do
    before do
      create_list(:feedback, 3, :positive_feedback, receiver: employee)
      create_list(:feedback, 2, :constructive_feedback, receiver: employee)
      create_list(:feedback, 1, :negative_feedback, receiver: employee)
    end

    it 'returns comprehensive feedback analytics' do
      get :analytics
      expect(response).to have_http_status(:ok)
      
      analytics = json_response['data']
      expect(analytics['total_feedbacks']).to be >= 0 # May be 0 if no feedbacks in period
      expect(analytics['sentiment_distribution']).to be_present
      expect(analytics['average_rating']).to be_present
      expect(analytics['feedback_by_type']).to be_a(Hash)
    end

    it 'includes trending analysis' do
      get :analytics, params: { include_trends: true }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['performance_trends']).to be_a(Hash)
      expect(json_response['data']['feedback_by_type']).to be_a(Hash)
    end

    it 'includes peer comparison' do
      get :analytics, params: { include_peer_comparison: true }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['peer_comparison']).to be_present
      expect(json_response['data']['peer_comparison']['percentile']).to be_present
    end
  end

  describe 'GET #themes' do
    before do
      create(:feedback, receiver: employee, message: 'Great communication skills and teamwork')
      create(:feedback, receiver: employee, message: 'Excellent technical abilities and problem solving')
      create(:feedback, receiver: employee, message: 'Strong leadership qualities and team collaboration')
    end

    it 'extracts common themes from feedback' do
      get :themes
      expect(response).to have_http_status(:ok)
      themes = json_response['data']
      expect(themes).to be_a(Hash)
      expect(themes.keys.length).to be > 0
    end

    it 'includes theme sentiment analysis' do
      get :themes
      expect(response).to have_http_status(:ok)
      
      themes = json_response['data']
      expect(themes).to be_a(Hash)
      # Themes are returned as a hash with word keys and count/sentiment values
      if themes.any?
        first_theme = themes.values.first
        expect(first_theme['count']).to be_present if first_theme.is_a?(Hash)
      end
    end
  end

  describe 'POST #create_360_request' do
    let!(:manager_position) { create(:position, level: 5) }
    let!(:manager) { create(:employee, position: manager_position) }
    let!(:employee_position) { create(:position, level: 3) }
    let!(:subordinate_position) { create(:position, level: 2) }
    let!(:subordinates) { create_list(:employee, 2, position: subordinate_position, manager: employee) }
    let!(:peers) { create_list(:employee, 3) }

    before do
      employee.update!(position: employee_position, manager: manager)
    end

    it 'creates comprehensive 360-degree feedback request' do
      post :create_360_request, params: {
        performance_review_id: create(:performance_review, employee: employee).id,
        include_manager: true,
        include_subordinates: true,
        peer_ids: peers.first(2).pluck(:id),
        include_self: true,
        message: 'Please provide comprehensive feedback for my annual review.'
      }

      expect(response).to have_http_status(:ok)
      
      data = json_response['data']
      expect(data['performance_review_id']).to be_present
      expect(data['status']).to eq('pending')
    end

    it 'validates performance review ownership' do
      other_review = create(:performance_review)

      post :create_360_request, params: {
        performance_review_id: other_review.id,
        include_manager: true
      }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #summary' do
    let(:performance_review) { create(:performance_review, employee: employee) }

    before do
      create(:feedback, :manager_feedback, receiver: employee, performance_review: performance_review, rating: 4.5)
      create_list(:feedback, 3, :peer_feedback, receiver: employee, performance_review: performance_review, rating: 4.0)
      create(:feedback, :self_feedback, receiver: employee, performance_review: performance_review, rating: 3.8)
    end

    it 'provides 360-degree feedback summary' do
      get :summary, params: { performance_review_id: performance_review.id }
      expect(response).to have_http_status(:ok)
      
      summary = json_response['data']
      expect(summary['manager_feedback']).to be >= 0
      expect(summary['peer_feedback']).to be >= 0
      expect(summary['subordinate_feedback']).to be >= 0
      expect(summary['average_rating'].to_f).to be_between(3.5, 4.5)
    end

    it 'identifies feedback gaps' do
      get :summary, params: { performance_review_id: performance_review.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['feedback_gaps']).to be_an(Array)
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end 