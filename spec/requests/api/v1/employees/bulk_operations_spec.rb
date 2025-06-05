require 'rails_helper'

RSpec.describe 'Employee Bulk Operations', type: :request do
  let(:user) { create(:user, :admin) }
  let(:headers) { auth_headers(user) }
  let(:department) { create(:department) }
  let(:position) { create(:position, department: department) }

  describe 'POST /api/v1/employees/bulk_create' do
    let(:valid_attributes) do
      [
        {
          first_name: 'John',
          last_name: 'Doe',
          email: 'john@example.com',
          position_id: position.id
        },
        {
          first_name: 'Jane',
          last_name: 'Smith',
          email: 'jane@example.com',
          position_id: position.id
        }
      ]
    end

    context 'with valid parameters' do
      it 'creates multiple employees' do
        expect {
          post bulk_create_api_v1_employees_path,
               params: { employees: valid_attributes },
               headers: headers
        }.to change(Employee, :count).by(2)

        expect(response).to have_http_status(:created)
        expect(json_response.length).to eq(2)
        expect(json_response.first['email']).to eq('john@example.com')
      end

      it 'respects batch_size parameter' do
        large_attributes = 10.times.map do |i|
          {
            first_name: "Employee#{i}",
            last_name: "Last#{i}",
            email: "employee#{i}@example.com",
            position_id: position.id
          }
        end
        
        expect(BulkOperationService).to receive(:bulk_create)
          .with(Employee, large_attributes, hash_including(batch_size: 5))
          .and_call_original

        post bulk_create_api_v1_employees_path,
             params: { employees: large_attributes, batch_size: 5 },
             headers: headers
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        [
          {
            first_name: 'John',
            last_name: 'Doe',
            email: 'john@example.com',
            position_id: position.id
          },
          {
            first_name: '',  # Invalid due to presence validation
            last_name: 'Smith',
            email: 'invalid@example.com',
            position_id: position.id
          }
        ]
      end

      it 'returns error response' do
        post bulk_create_api_v1_employees_path,
             params: { employees: invalid_attributes },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end

      it 'does not create any employees when validate_all is true' do
        expect {
          post bulk_create_api_v1_employees_path,
               params: { employees: invalid_attributes },
               headers: headers
        }.not_to change(Employee, :count)
      end

      it 'creates valid employees when validate_all is false' do
        expect {
          post bulk_create_api_v1_employees_path,
               params: { employees: invalid_attributes, validate_all: false },
               headers: headers
        }.to change(Employee, :count).by(1)
      end
    end

    context 'with unauthorized user' do
      let(:unauthorized_user) { create(:user) }
      let(:unauthorized_headers) { auth_headers(unauthorized_user) }

      it 'returns unauthorized status' do
        post bulk_create_api_v1_employees_path,
             params: { employees: valid_attributes },
             headers: unauthorized_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v1/employees/bulk_update' do
    let!(:employees) { create_list(:employee, 2, position: position) }
    let(:valid_attributes) do
      [
        { id: employees[0].id, first_name: 'Updated First 1' },
        { id: employees[1].id, first_name: 'Updated First 2' }
      ]
    end

    context 'with valid parameters' do
      it 'updates multiple employees' do
        patch bulk_update_api_v1_employees_path,
              params: { employees: valid_attributes },
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(employees[0].reload.first_name).to eq('Updated First 1')
        expect(employees[1].reload.first_name).to eq('Updated First 2')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        [
          { id: employees[0].id, first_name: 'Valid Name' },
          { id: employees[1].id, first_name: '' }  # Invalid due to presence validation
        ]
      end

      it 'returns error response' do
        patch bulk_update_api_v1_employees_path,
              params: { employees: invalid_attributes },
              headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end

      it 'does not update any employees when validate_all is true' do
        patch bulk_update_api_v1_employees_path,
              params: { employees: invalid_attributes },
              headers: headers

        expect(employees[0].reload.first_name).not_to eq('Valid Name')
      end

      it 'updates valid employees when validate_all is false' do
        patch bulk_update_api_v1_employees_path,
              params: { employees: invalid_attributes, validate_all: false },
              headers: headers

        expect(employees[0].reload.first_name).to eq('Valid Name')
        expect(employees[1].reload.first_name).not_to eq('')
      end
    end
  end

  describe 'DELETE /api/v1/employees/bulk_delete' do
    let!(:employees) { create_list(:employee, 3, position: position) }
    let(:employee_ids) { employees.map(&:id) }

    context 'with valid parameters' do
      it 'deletes multiple employees' do
        expect {
          delete bulk_delete_api_v1_employees_path,
                 params: { ids: employee_ids },
                 headers: headers
        }.to change(Employee, :count).by(-3)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_ids) { [999999, 999998] }

      it 'returns error response' do
        delete bulk_delete_api_v1_employees_path,
               params: { ids: invalid_ids },
               headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end

      it 'deletes existing employees when validate_all is false' do
        mixed_ids = employee_ids + invalid_ids

        expect {
          delete bulk_delete_api_v1_employees_path,
                 params: { ids: mixed_ids, validate_all: false },
                 headers: headers
        }.to change(Employee, :count).by(-3)
      end
    end

    context 'with employees who are managers' do
      let!(:manager) { create(:employee, position: position) }
      let!(:subordinate) { create(:employee, position: position, manager: manager) }

      it 'prevents deletion and returns error' do
        expect {
          delete bulk_delete_api_v1_employees_path,
                 params: { ids: [manager.id] },
                 headers: headers
        }.not_to change(Employee, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end
    end
  end

  def json_response
    JSON.parse(response.body)
  end
end 