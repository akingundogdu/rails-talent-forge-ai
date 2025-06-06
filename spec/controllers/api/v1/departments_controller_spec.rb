require 'rails_helper'

RSpec.describe Api::V1::DepartmentsController, type: :controller do
  let(:user) { create(:user, :admin) }
  let(:department) { create(:department) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:departments) { create_list(:department, 3) }

    it 'returns a successful response' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(3)
    end

    it 'returns departments in the correct order' do
      get :index
      expect(json_response.first['id']).to eq(departments.first.id)
    end

    context 'with pagination' do
      let!(:departments) { create_list(:department, 5) }

      it 'respects page and per_page parameters' do
        get :index, params: { page: 2, per_page: 2 }
        expect(json_response.length).to eq(2)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: department.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(department.id)
    end

    context 'when department does not exist' do
      it 'returns not found status' do
        get :show, params: { id: 999 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) { { name: 'New Department', description: 'Test department' } }

    context 'with valid params' do
      it 'creates a new department' do
        expect {
          post :create, params: { department: valid_attributes }
        }.to change(Department, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity status' do
        post :create, params: { department: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT #update' do
    let(:new_attributes) { { name: 'Updated Department' } }

    context 'with valid params' do
      it 'updates the requested department' do
        put :update, params: { id: department.id, department: new_attributes }
        department.reload
        expect(department.name).to eq('Updated Department')
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity status' do
        put :update, params: { id: department.id, department: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:department_to_delete) { create(:department) }

    it 'destroys the requested department' do
      expect {
        delete :destroy, params: { id: department_to_delete.id }
      }.to change(Department, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'GET #tree' do
    let!(:parent_department) { create(:department) }
    let!(:child_department) { create(:department, parent_department: parent_department) }

    it 'returns departments in tree structure' do
      get :tree
      expect(response).to have_http_status(:ok)
      expect(json_response.first['sub_departments']).to be_present
    end
  end

  describe 'GET #employees' do
    let!(:employee) { create(:employee, position: create(:position, department: department)) }

    it 'returns employees in the department' do
      get :employees, params: { id: department.id }
      expect(response).to have_http_status(:ok)
      expect(json_response.first['id']).to eq(employee.id)
    end
  end

  describe 'GET #positions' do
    let!(:position) { create(:position, department: department) }

    it 'returns positions in the department' do
      get :positions, params: { id: department.id }
      expect(response).to have_http_status(:ok)
      expect(json_response.first['id']).to eq(position.id)
    end
  end

  describe 'POST #bulk_create' do
    let(:valid_attributes) do
      [
        { name: 'Department 1', description: 'Description 1' },
        { name: 'Department 2', description: 'Description 2' }
      ]
    end

    it 'creates multiple departments' do
      expect {
        post :bulk_create, params: { departments: valid_attributes }
      }.to change(Department, :count).by(2)
      expect(response).to have_http_status(:created)
    end

    it 'handles validation errors' do
      post :bulk_create, params: { departments: [{ name: '' }] }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end 