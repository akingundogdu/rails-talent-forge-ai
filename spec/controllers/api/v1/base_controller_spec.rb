require 'rails_helper'

RSpec.describe Api::V1::BaseController, type: :controller do
  controller do
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
      render json: { message: 'success' }
    end

    def show
      raise ActiveRecord::RecordNotFound, "Record not found"
    end

    def create
      raise ActionController::ParameterMissing.new(:required_param)
    end

    def update
      record = OpenStruct.new
      record.errors = OpenStruct.new(full_messages: ['Invalid data'])
      raise ActiveRecord::RecordInvalid.new(record)
    end

    def destroy
      raise StandardError.new('Something went wrong')
    end
  end

  let(:user) { create(:user, :admin) }

  before do
    routes.draw do
      get 'index' => 'api/v1/base#index'
      get 'show' => 'api/v1/base#show'
      post 'create' => 'api/v1/base#create'
      put 'update' => 'api/v1/base#update'
      delete 'destroy' => 'api/v1/base#destroy'
    end
  end

  describe 'authentication' do
    context 'with valid token' do
      before do
        sign_in user
      end

      it 'allows access to the action' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without token' do
      it 'returns unauthorized status' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      before do
        request.headers['Authorization'] = 'Bearer invalid_token'
      end

      it 'returns unauthorized status' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'error handling' do
    before do
      sign_in user
    end

    it 'handles RecordNotFound errors' do
      get :show
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Record not found')
    end

    it 'handles ParameterMissing errors' do
      post :create
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to include('required_param')
    end

    it 'handles RecordInvalid errors' do
      put :update
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors']).to eq(['Invalid data'])
    end

    it 'handles StandardError' do
      delete :destroy
      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)['error']).to eq('Something went wrong')
    end
  end
end 