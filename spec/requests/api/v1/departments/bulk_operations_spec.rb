require 'rails_helper'
require 'swagger_helper'

RSpec.describe 'Department Bulk Operations', type: :request do
  let(:user) { create(:user, :admin) }
  let(:Authorization) { "Bearer #{JsonWebToken.encode(user_id: user.id)}" }

  describe 'POST /api/v1/departments/bulk_create' do
    let(:valid_attributes) do
      [
        { name: 'Department 1', description: 'Description 1' },
        { name: 'Department 2', description: 'Description 2' }
      ]
    end

    context 'with valid parameters' do
      it 'creates multiple departments' do
        expect {
                  post bulk_create_api_v1_departments_path,
             params: { departments: valid_attributes },
             headers: { Authorization: Authorization }
        }.to change(Department, :count).by(2)

        expect(response).to have_http_status(:created)
        expect(json_response.length).to eq(2)
        expect(json_response.first['name']).to eq('Department 1')
      end

      it 'respects batch_size parameter' do
        large_attributes = 10.times.map { |i| { name: "Department #{i}" } }
        
        expect(BulkOperationService).to receive(:bulk_create)
          .with(Department, large_attributes, hash_including(batch_size: 5))
          .and_call_original

        post bulk_create_api_v1_departments_path,
             params: { departments: large_attributes, batch_size: 5 },
             headers: { Authorization: Authorization }
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        [
          { name: 'Valid Department' },
          { name: '' }  # Invalid due to presence validation
        ]
      end

      it 'returns error response' do
        post bulk_create_api_v1_departments_path,
             params: { departments: invalid_attributes },
             headers: { Authorization: Authorization }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end

      it 'does not create any departments when validate_all is true' do
        expect {
          post bulk_create_api_v1_departments_path,
               params: { departments: invalid_attributes },
               headers: { Authorization: Authorization }
        }.not_to change(Department, :count)
      end

      it 'creates valid departments when validate_all is false' do
        expect {
          post bulk_create_api_v1_departments_path,
               params: { departments: invalid_attributes, validate_all: false },
               headers: { Authorization: Authorization }
        }.to change(Department, :count).by(1)
      end
    end

    context 'with unauthorized user' do
      let(:unauthorized_user) { create(:user) }
      let(:unauthorized_Authorization) { "Bearer #{JsonWebToken.encode(user_id: unauthorized_user.id)}" }

      it 'returns unauthorized status' do
        post bulk_create_api_v1_departments_path,
             params: { departments: valid_attributes },
             headers: { Authorization: unauthorized_Authorization }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v1/departments/bulk_update' do
    let!(:departments) { create_list(:department, 2) }
    let(:valid_attributes) do
      [
        { id: departments[0].id, name: 'Updated Department 1' },
        { id: departments[1].id, name: 'Updated Department 2' }
      ]
    end

    context 'with valid parameters' do
      it 'updates multiple departments' do
        patch bulk_update_api_v1_departments_path,
              params: { departments: valid_attributes },
              headers: { Authorization: Authorization }

        expect(response).to have_http_status(:ok)
        expect(departments[0].reload.name).to eq('Updated Department 1')
        expect(departments[1].reload.name).to eq('Updated Department 2')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        [
          { id: departments[0].id, name: 'Valid Name' },
          { id: departments[1].id, name: '' }  # Invalid due to presence validation
        ]
      end

      it 'returns error response' do
        patch bulk_update_api_v1_departments_path,
              params: { departments: invalid_attributes },
              headers: { Authorization: Authorization }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end

      it 'does not update any departments when validate_all is true' do
        patch bulk_update_api_v1_departments_path,
              params: { departments: invalid_attributes },
              headers: { Authorization: Authorization }

        expect(departments[0].reload.name).not_to eq('Valid Name')
      end

      it 'updates valid departments when validate_all is false' do
        patch bulk_update_api_v1_departments_path,
              params: { departments: invalid_attributes, validate_all: false },
              headers: { Authorization: Authorization }

        expect(departments[0].reload.name).to eq('Valid Name')
        expect(departments[1].reload.name).not_to eq('')
      end
    end
  end

  describe 'DELETE /api/v1/departments/bulk_delete' do
    let!(:departments) { create_list(:department, 3) }
    let(:department_ids) { departments.map(&:id) }

    context 'with valid parameters' do
      it 'deletes multiple departments' do
        expect {
          delete bulk_delete_api_v1_departments_path,
                 params: { ids: department_ids },
                 headers: { Authorization: Authorization }
        }.to change(Department, :count).by(-3)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_ids) { [999999, 999998] }

      it 'returns error response' do
        delete bulk_delete_api_v1_departments_path,
               params: { ids: invalid_ids },
               headers: { Authorization: Authorization }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end

      it 'deletes existing departments when validate_all is false' do
        mixed_ids = department_ids + invalid_ids

        expect {
          delete bulk_delete_api_v1_departments_path,
                 params: { ids: mixed_ids, validate_all: false },
                 headers: { Authorization: Authorization }
        }.to change(Department, :count).by(-3)
      end
    end
  end

  def json_response
    JSON.parse(response.body)
  end
end 