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
    let(:base_controller) { Api::V1::BaseController.new }

    describe '#not_found' do
      it 'renders not found response' do
        exception = ActiveRecord::RecordNotFound.new('Record not found')
        allow(base_controller).to receive(:render)
        
        base_controller.send(:not_found, exception)
        
        expect(base_controller).to have_received(:render).with(
          json: { error: 'Record not found' }, 
          status: :not_found
        )
      end
    end

    describe '#bad_request' do
      it 'renders bad request response' do
        exception = ActionController::ParameterMissing.new(:required_param)
        allow(base_controller).to receive(:render)
        
        base_controller.send(:bad_request, exception)
        
        expect(base_controller).to have_received(:render).with(
          json: { error: exception.message }, 
          status: :bad_request
        )
      end
    end

    describe '#unprocessable_entity' do
      it 'renders unprocessable entity response' do
        invalid_user = User.new(email: 'invalid-email')
        invalid_user.valid? # This will populate errors
        exception = ActiveRecord::RecordInvalid.new(invalid_user)
        allow(base_controller).to receive(:render)
        
        base_controller.send(:unprocessable_entity, exception)
        
        expect(base_controller).to have_received(:render).with(
          json: { errors: invalid_user.errors.full_messages }, 
          status: :unprocessable_entity
        )
      end
    end

    describe '#internal_server_error' do
      it 'renders internal server error response' do
        exception = StandardError.new('Something went wrong')
        allow(base_controller).to receive(:render)
        
        base_controller.send(:internal_server_error, exception)
        
        expect(base_controller).to have_received(:render).with(
          json: { error: 'Something went wrong' }, 
          status: :internal_server_error
        )
      end
    end
  end
end 