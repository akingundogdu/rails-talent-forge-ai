require 'rails_helper'

RSpec.describe Api::V1::PositionsController, type: :controller do
  let(:user) { create(:user, :admin) }
  let(:department) { create(:department) }
  let(:position) { create(:position, department: department, level: 2) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:positions) { create_list(:position, 3, department: department) }

    it 'returns a successful response' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(3)
    end

    context 'with department_id filter' do
      let(:another_department) { create(:department) }
      let!(:another_position) { create(:position, department: another_department) }

      it 'filters positions by department' do
        get :index, params: { department_id: department.id }
        expect(json_response.length).to eq(3)
        expect(json_response.map { |p| p['department_id'] }).to all(eq(department.id))
      end
    end

    context 'with pagination' do
      let!(:positions) { create_list(:position, 5, department: department) }

      it 'respects page and per_page parameters' do
        get :index, params: { page: 2, per_page: 2 }
        expect(json_response.length).to eq(2)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: position.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(position.id)
    end

    context 'when position does not exist' do
      it 'returns not found status' do
        get :show, params: { id: 999 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        title: 'New Position',
        description: 'Test position',
        level: 1,
        department_id: department.id
      }
    end

    context 'with valid params' do
      it 'creates a new position' do
        expect {
          post :create, params: { position: valid_attributes }
        }.to change(Position, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity status' do
        post :create, params: { position: { title: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT #update' do
    let(:new_attributes) { { title: 'Updated Position' } }

    context 'with valid params' do
      it 'updates the requested position' do
        put :update, params: { id: position.id, position: new_attributes }
        position.reload
        expect(position.title).to eq('Updated Position')
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity status' do
        put :update, params: { id: position.id, position: { title: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:position_to_delete) { create(:position, department: department) }

    it 'destroys the requested position' do
      expect {
        delete :destroy, params: { id: position_to_delete.id }
      }.to change(Position, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'GET #tree' do
    let!(:parent_position) { create(:position, department: department, level: 3) }
    let!(:child_position) { create(:position, department: department, level: 2, parent_position: parent_position) }

    it 'returns positions in tree structure' do
      get :tree
      expect(response).to have_http_status(:ok)
      expect(json_response.first['children']).to be_present
    end
  end

  describe 'GET #employees' do
    let!(:employee) { create(:employee, position: position) }

    it 'returns employees in the position' do
      get :employees, params: { id: position.id }
      expect(response).to have_http_status(:ok)
      expect(json_response.first['id']).to eq(employee.id)
    end
  end

  describe 'POST #bulk_create' do
    let(:valid_attributes) do
      [
        {
          title: 'Position 1',
          description: 'Description 1',
          level: 1,
          department_id: department.id
        },
        {
          title: 'Position 2',
          description: 'Description 2',
          level: 2,
          department_id: department.id
        }
      ]
    end

    it 'creates multiple positions' do
      expect {
        post :bulk_create, params: { positions: valid_attributes }
      }.to change(Position, :count).by(2)
      expect(response).to have_http_status(:created)
    end

    it 'handles validation errors' do
      post :bulk_create, params: { positions: [{ title: '' }] }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end 