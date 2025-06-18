require 'rails_helper'

RSpec.describe Api::V1::PerformanceReviewsController, type: :controller do
  let(:user) { create(:user) }
  let(:employee) { create(:employee, user: user) }
  let(:manager) { create(:employee, :manager) }
  let(:performance_review) { create(:performance_review, employee: employee) }

  before do
    sign_in(user)
    allow(controller).to receive(:current_employee).and_return(employee)
  end

  describe 'GET #index' do
    let!(:own_review) { create(:performance_review, employee: employee) }
    let!(:other_review) { create(:performance_review) }

    context 'as employee' do
      it 'returns own performance reviews' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to include(
          hash_including('id' => own_review.id)
        )
        expect(json_response['data']).not_to include(
          hash_including('id' => other_review.id)
        )
      end

      it 'filters by status' do
        completed_review = create(:performance_review, :completed, employee: employee)
        draft_review = create(:performance_review, :draft, employee: employee)

        get :index, params: { status: 'completed' }
        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to include(
          hash_including('id' => completed_review.id)
        )
        expect(json_response['data']).not_to include(
          hash_including('id' => draft_review.id)
        )
      end

      it 'filters by review type' do
        annual_review = create(:performance_review, employee: employee, review_type: :annual)
        quarterly_review = create(:performance_review, employee: employee, review_type: :quarterly)

        get :index, params: { review_type: 'annual' }
        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to include(
          hash_including('id' => annual_review.id)
        )
        expect(json_response['data']).not_to include(
          hash_including('id' => quarterly_review.id)
        )
      end
    end

    context 'as manager' do
      before do
        employee.update!(manager: manager)
        allow(controller).to receive(:current_employee).and_return(manager)
      end

      it 'returns subordinate reviews' do
        subordinate_review = create(:performance_review, employee: employee)
        other_review = create(:performance_review)

        get :index
        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to include(
          hash_including('id' => subordinate_review.id)
        )
        expect(json_response['data']).not_to include(
          hash_including('id' => other_review.id)
        )
      end
    end

    it 'includes pagination metadata' do
      create_list(:performance_review, 15, employee: employee)
      
      get :index, params: { page: 1, per_page: 10 }
      expect(response).to have_http_status(:ok)
      expect(json_response['meta']).to include(
        'current_page' => 1,
        'total_pages' => 2,
        'total_count' => 16
      )
    end
  end

  describe 'GET #show' do
    context 'own performance review' do
      it 'returns performance review details' do
        get :show, params: { id: performance_review.id }
        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to include(
          'id' => performance_review.id.to_s,
          'title' => performance_review.title,
          'status' => performance_review.status
        )
      end

      it 'includes associated data' do
        create_list(:goal, 2, performance_review: performance_review)
        create_list(:rating, 3, performance_review: performance_review)

        get :show, params: { id: performance_review.id }
        expect(response).to have_http_status(:ok)
        expect(json_response['data']['goals']).to be_present
        expect(json_response['data']['ratings']).to be_present
      end
    end

    context 'unauthorized access' do
      let(:other_review) { create(:performance_review) }

      it 'returns forbidden for other employee reviews' do
        get :show, params: { id: other_review.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'non-existent review' do
      it 'returns not found' do
        get :show, params: { id: 999999 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) {
      {
        performance_review: {
          title: '2024 Annual Review',
          description: 'Annual performance review for 2024',
          start_date: Date.current,
          end_date: 3.months.from_now,
          review_type: 'annual',
          reviewer_id: manager.id
        }
      }
    }

    context 'with valid parameters' do
      it 'creates a new performance review' do
        expect {
          post :create, params: valid_params
        }.to change(PerformanceReview, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['data']['title']).to eq('2024 Annual Review')
      end

      it 'sets the current employee as the review subject' do
        post :create, params: valid_params
        
        created_review = PerformanceReview.last
        expect(created_review.employee).to eq(employee)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) {
        {
          performance_review: {
            title: '',
            start_date: Date.current,
            end_date: Date.current - 1.day
          }
        }
      }

      it 'returns validation errors' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('title')
        expect(json_response['errors']).to include('end_date')
      end
    end
  end

  describe 'PATCH #update' do
    context 'own performance review' do
      let(:update_params) {
        {
          id: performance_review.id,
          performance_review: {
            title: 'Updated Review Title',
            description: 'Updated description'
          }
        }
      }

      it 'updates the performance review' do
        patch :update, params: update_params
        expect(response).to have_http_status(:ok)
        
        performance_review.reload
        expect(performance_review.title).to eq('Updated Review Title')
        expect(performance_review.description).to eq('Updated description')
      end

      it 'prevents updating completed reviews' do
        performance_review.update!(status: :completed)
        
        patch :update, params: update_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('cannot be updated')
      end
    end

    context 'unauthorized update' do
      let(:other_review) { create(:performance_review) }

      it 'returns forbidden' do
        patch :update, params: {
          id: other_review.id,
          performance_review: { title: 'Hacked Title' }
        }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'own performance review' do
      it 'deletes draft performance review' do
        draft_review = create(:performance_review, :draft, employee: employee)
        
        expect {
          delete :destroy, params: { id: draft_review.id }
        }.to change(PerformanceReview, :count).by(-1)
        
        expect(response).to have_http_status(:no_content)
      end

      it 'prevents deletion of completed reviews' do
        completed_review = create(:performance_review, :completed, employee: employee)
        
        delete :destroy, params: { id: completed_review.id }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('cannot be deleted')
      end
    end
  end

  describe 'POST #submit' do
    let(:draft_review) { create(:performance_review, :draft, employee: employee) }

    it 'submits draft review for approval' do
      post :submit, params: { id: draft_review.id }
      expect(response).to have_http_status(:ok)
      
      draft_review.reload
      expect(draft_review.status).to eq('in_progress')
    end

    it 'prevents submitting non-draft reviews' do
      completed_review = create(:performance_review, :completed, employee: employee)
      
      post :submit, params: { id: completed_review.id }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'validates required data before submission' do
      empty_review = create(:performance_review, :draft, employee: employee)
      
      post :submit, params: { id: empty_review.id }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to include('insufficient data')
    end
  end

  describe 'POST #approve' do
    let(:in_progress_review) { create(:performance_review, :in_progress, employee: employee) }

    context 'as manager' do
      before do
        employee.update!(manager: manager)
        allow(controller).to receive(:current_employee).and_return(manager)
      end

      it 'approves subordinate review' do
        post :approve, params: { id: in_progress_review.id }
        expect(response).to have_http_status(:ok)
        
        in_progress_review.reload
        expect(in_progress_review.status).to eq('completed')
        expect(in_progress_review.completed_at).to be_present
      end
    end

    context 'as non-manager' do
      it 'returns forbidden' do
        post :approve, params: { id: in_progress_review.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #complete' do
    let(:in_progress_review) { create(:performance_review, :in_progress, employee: employee) }

    it 'completes own performance review' do
      post :complete, params: { id: in_progress_review.id }
      expect(response).to have_http_status(:ok)
      
      in_progress_review.reload
      expect(in_progress_review.status).to eq('completed')
    end

    it 'validates completion requirements' do
      # Review without sufficient ratings/feedback
      post :complete, params: { id: in_progress_review.id }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to include('completion requirements')
    end
  end

  describe 'GET #summary' do
    it 'returns performance review summary with analytics' do
      create_list(:goal, 3, :completed, performance_review: performance_review)
      create_list(:rating, 5, performance_review: performance_review, score: 4.0)
      create_list(:feedback, 4, performance_review: performance_review, rating: 4.2)

      get :summary, params: { id: performance_review.id }
      expect(response).to have_http_status(:ok)
      
      summary = json_response['data']
      expect(summary['overall_score']).to be_present
      expect(summary['goals_completion_rate']).to be_present
      expect(summary['feedback_summary']).to be_present
      expect(summary['competency_scores']).to be_present
    end
  end

  describe 'GET #analytics' do
    it 'returns comprehensive performance analytics' do
      # Create historical data
      create_list(:performance_review, 3, :completed, employee: employee)
      
      get :analytics, params: { employee_id: employee.id }
      expect(response).to have_http_status(:ok)
      
      analytics = json_response['data']
      expect(analytics['performance_trends']).to be_present
      expect(analytics['competency_analysis']).to be_present
      expect(analytics['goal_achievement_history']).to be_present
    end

    it 'includes comparison with department averages' do
      get :analytics, params: { employee_id: employee.id, include_benchmarks: true }
      expect(response).to have_http_status(:ok)
      
      analytics = json_response['data']
      expect(analytics['department_comparison']).to be_present
      expect(analytics['position_benchmarks']).to be_present
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      allow(PerformanceReview).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      
      get :show, params: { id: 123 }
      expect(response).to have_http_status(:not_found)
      expect(json_response['error']).to eq('Performance review not found')
    end

    it 'handles validation errors with detailed messages' do
      allow_any_instance_of(PerformanceReview).to receive(:save).and_return(false)
      allow_any_instance_of(PerformanceReview).to receive(:errors).and_return(
        double(full_messages: ['Title is required', 'End date must be after start date'])
      )

      post :create, params: { performance_review: { title: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to include('Title is required')
    end
  end

  describe 'caching' do
    it 'caches expensive analytics calculations' do
      review_id = performance_review.id
      
      # First request should hit database
      expect(Rails.cache).to receive(:fetch).with(
        "performance_review_#{review_id}_analytics", 
        expires_in: 1.hour
      ).and_call_original

      get :analytics, params: { employee_id: employee.id }
      expect(response).to have_http_status(:ok)
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end 