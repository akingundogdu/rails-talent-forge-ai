require 'rails_helper'

RSpec.describe Api::V1::PermissionsController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:department) { create(:department) }
  let(:permission) { create(:permission, :department, user: user, action: 'read') }

  before do
    sign_in admin
  end

  describe 'GET #index' do
    let!(:permissions) { create_list(:permission, 3, user: user) }

    it 'returns a successful response' do
      get :index, params: { user_id: user.id }
      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(3)
    end

    context 'with resource filter' do
      # Override parent permissions list to avoid interference
      let!(:permissions) { nil }
      let!(:department_permission) { create(:permission, resource: 'department', user: user) }
      let!(:position_permission) { create(:permission, resource: 'position', user: user) }

      it 'filters permissions by resource' do
        get :index, params: { user_id: user.id, resource: 'department' }
        expect(json_response.length).to eq(1)
        expect(json_response.first['resource']).to eq('department')
      end
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { user_id: user.id, id: permission.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(permission.id)
    end

    context 'when permission does not exist' do
      it 'returns not found status' do
        get :show, params: { user_id: user.id, id: 999 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        resource: 'department',
        action: 'read',
        resource_id: department.id
      }
    end

    context 'with valid params' do
      it 'creates a new permission' do
        expect {
          post :create, params: { user_id: user.id, permission: valid_attributes }
        }.to change(Permission, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity status' do
        post :create, params: { user_id: user.id, permission: { resource: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid resource' do
      it 'returns unprocessable entity status' do
        post :create, params: { user_id: user.id, permission: valid_attributes.merge(resource: 'invalid') }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid action' do
      it 'returns unprocessable entity status' do
        post :create, params: { user_id: user.id, permission: valid_attributes.merge(action: 'invalid') }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT #update' do
    let(:new_attributes) { { action: 'update' } }

    context 'with valid params' do
      it 'updates the requested permission' do
        put :update, params: { user_id: user.id, id: permission.id, permission: new_attributes }
        permission.reload
        expect(permission.action).to eq('update')
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity status' do
        put :update, params: { user_id: user.id, id: permission.id, permission: { action: 'invalid' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:permission_to_delete) { create(:permission, user: user) }

    it 'destroys the requested permission' do
      expect {
        delete :destroy, params: { user_id: user.id, id: permission_to_delete.id }
      }.to change(Permission, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'POST #bulk_create' do
    let(:valid_attributes) do
      [
        {
          resource: 'department',
          action: 'read',
          resource_id: department.id
        },
        {
          resource: 'position',
          action: 'update',
          resource_id: create(:position).id
        }
      ]
    end

    it 'creates multiple permissions' do
      expect {
        post :bulk_create, params: { user_id: user.id, permissions: valid_attributes }
      }.to change(Permission, :count).by(2)
      expect(response).to have_http_status(:created)
    end

    it 'handles validation errors' do
      post :bulk_create, params: { user_id: user.id, permissions: [{ resource: '' }] }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end 