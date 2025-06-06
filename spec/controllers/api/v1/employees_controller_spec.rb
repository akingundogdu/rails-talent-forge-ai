require 'rails_helper'

RSpec.describe Api::V1::EmployeesController, type: :controller do
  let(:user) { create(:user, :admin) }
  let(:department) { create(:department) }
  let(:position) { create(:position, department: department, level: 3) }
  let(:employee) { create(:employee, position: position) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:employees) { create_list(:employee, 3, position: position) }

    it 'returns a successful response' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(3)
    end

    context 'with search params' do
      let!(:john) { create(:employee, first_name: 'John', last_name: 'Doe', position: position) }
      
      it 'filters by name' do
        get :index, params: { search: 'John' }
        expect(json_response.length).to eq(1)
        expect(json_response.first['first_name']).to eq('John')
      end
    end

    context 'with pagination' do
      let!(:employees) { create_list(:employee, 5, position: position) }

      it 'respects page and per_page parameters' do
        get :index, params: { page: 2, per_page: 2 }
        expect(json_response.length).to eq(2)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: employee.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(employee.id)
    end

    context 'when employee does not exist' do
      it 'returns not found status' do
        get :show, params: { id: 999 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:employee_user) { create(:user) }
    let(:valid_attributes) do
      {
        first_name: 'John',
        last_name: 'Doe',
        email: 'john@example.com',
        position_id: position.id,
        user_id: employee_user.id
      }
    end

    context 'with valid params' do
      it 'creates a new employee' do
        expect {
          post :create, params: { employee: valid_attributes }
        }.to change(Employee, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity status' do
        post :create, params: { employee: { first_name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT #update' do
    let(:new_attributes) { { first_name: 'Updated Name' } }

    context 'with valid params' do
      it 'updates the requested employee' do
        put :update, params: { id: employee.id, employee: new_attributes }
        employee.reload
        expect(employee.first_name).to eq('Updated Name')
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity status' do
        put :update, params: { id: employee.id, employee: { first_name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:employee_to_delete) { create(:employee, position: position) }

    it 'destroys the requested employee' do
      expect {
        delete :destroy, params: { id: employee_to_delete.id }
      }.to change(Employee, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'GET #subordinates' do
    let!(:subordinate_position) { create(:position, department: department, level: position.level - 1, parent_position: position) }
    let!(:subordinate) { create(:employee, position: subordinate_position, manager: employee) }

    it 'returns subordinates of the employee' do
      get :subordinates, params: { id: employee.id }
      expect(response).to have_http_status(:ok)
      expect(json_response.first['id']).to eq(subordinate.id)
    end
  end

  describe 'GET #manager' do
    let!(:manager_position) { create(:position, department: department, level: position.level + 1) }
    let!(:manager) { create(:employee, position: manager_position) }
    let!(:employee_with_manager) { create(:employee, position: create(:position, department: department, level: manager_position.level - 1, parent_position: manager_position)) }

    it 'returns the manager of the employee' do
      get :manager, params: { id: employee_with_manager.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(manager.id)
    end
  end

  describe 'POST #bulk_create' do
    let(:employee_user1) { create(:user) }
    let(:employee_user2) { create(:user) }
    let(:valid_attributes) do
      [
        {
          first_name: 'John',
          last_name: 'Doe',
          email: 'john@example.com',
          position_id: position.id,
          user_id: employee_user1.id
        },
        {
          first_name: 'Jane',
          last_name: 'Smith',
          email: 'jane@example.com',
          position_id: position.id,
          user_id: employee_user2.id
        }
      ]
    end

    it 'creates multiple employees' do
      expect {
        post :bulk_create, params: { employees: valid_attributes }
      }.to change(Employee, :count).by(2)
      expect(response).to have_http_status(:created)
    end

    it 'handles validation errors' do
      post :bulk_create, params: { employees: [{ first_name: '' }] }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET #search' do
    let!(:john) { create(:employee, first_name: 'John', last_name: 'Doe', position: position) }
    let!(:jane) { create(:employee, first_name: 'Jane', last_name: 'Smith', position: position) }

    it 'returns matching employees' do
      get :search, params: { query: 'John' }
      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(1)
      expect(json_response.first['first_name']).to eq('John')
    end
  end
end 