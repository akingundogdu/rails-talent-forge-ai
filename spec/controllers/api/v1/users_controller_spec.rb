require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user, password: 'Password1!') }

  describe 'POST #sign_in' do
    let(:valid_credentials) do
      {
        email: user.email,
        password: 'Password1!'
      }
    end

    context 'with valid credentials' do
      it 'returns authentication token' do
        post :sign_in, params: valid_credentials
        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized status' do
        post :sign_in, params: { email: user.email, password: 'wrong' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with non-existent user' do
      it 'returns unauthorized status' do
        post :sign_in, params: { email: 'nonexistent@example.com', password: 'password' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #sign_up' do
    let(:valid_attributes) do
      {
        email: 'new@example.com',
        password: 'Password1!',
        password_confirmation: 'Password1!'
      }
    end

    context 'with valid params' do
      it 'creates a new user' do
        expect {
          post :sign_up, params: { user: valid_attributes }
        }.to change(User, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it 'returns authentication token' do
        post :sign_up, params: { user: valid_attributes }
        expect(json_response['token']).to be_present
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity status' do
        post :sign_up, params: { user: { email: 'invalid' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with existing email' do
      before { user }

      it 'returns unprocessable entity status' do
        post :sign_up, params: { user: valid_attributes.merge(email: user.email) }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #sign_out' do
    before do
      sign_in user
    end

    it 'invalidates the token' do
      delete :sign_out
      expect(response).to have_http_status(:no_content)
      
      # Try to use the same token
      get :profile
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET #profile' do
    before do
      sign_in user
    end

    it 'returns current user profile' do
      get :profile
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(user.id)
    end
  end

  describe 'PUT #update_profile' do
    let(:new_attributes) { { email: 'updated@example.com' } }

    before do
      sign_in user
    end

    it 'updates user profile' do
      put :update_profile, params: { user: new_attributes }
      expect(response).to have_http_status(:ok)
      user.reload
      expect(user.email).to eq('updated@example.com')
    end

    context 'with invalid params' do
      it 'returns unprocessable entity status' do
        put :update_profile, params: { user: { email: 'invalid' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT #change_password' do
    let(:password_params) do
      {
        current_password: 'Password1!',
        password: 'NewPassword1!',
        password_confirmation: 'NewPassword1!'
      }
    end

    before do
      sign_in user
    end

    it 'changes user password' do
      put :change_password, params: password_params
      expect(response).to have_http_status(:ok)
      
      # Try to sign in with new password
      post :sign_in, params: { email: user.email, password: 'NewPassword1!' }
      expect(response).to have_http_status(:ok)
    end

    context 'with wrong current password' do
      it 'returns unauthorized status' do
        put :change_password, params: password_params.merge(current_password: 'wrong')
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid new password' do
      it 'returns unprocessable entity status' do
        put :change_password, params: password_params.merge(password: 'weak')
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end 