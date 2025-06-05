require 'rails_helper'

RSpec.describe 'Position Bulk Operations', type: :request do
  let(:user) { create(:user, :admin) }
  let(:headers) { auth_headers(user) }
  let(:department) { create(:department) }

  describe 'POST /api/v1/positions/bulk_create' do
    let(:valid_attributes) do
      [
        { title: 'Position 1', description: 'Description 1', level: 1, department_id: department.id },
        { title: 'Position 2', description: 'Description 2', level: 2, department_id: department.id }
      ]
    end

    context 'with valid parameters' do
      it 'creates multiple positions' do
        expect {
          post bulk_create_api_v1_positions_path,
               params: { positions: valid_attributes },
               headers: headers
        }.to change(Position, :count).by(2)

        expect(response).to have_http_status(:created)
        expect(json_response.length).to eq(2)
        expect(json_response.first['title']).to eq('Position 1')
      end

      it 'respects batch_size parameter' do
        large_attributes = 10.times.map do |i|
          { title: "Position #{i}", department_id: department.id, level: i }
        end
        
        expect(BulkOperationService).to receive(:bulk_create)
          .with(Position, large_attributes, hash_including(batch_size: 5))
          .and_call_original

        post bulk_create_api_v1_positions_path,
             params: { positions: large_attributes, batch_size: 5 },
             headers: headers
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        [
          { title: 'Valid Position', department_id: department.id },
          { title: '', department_id: department.id }  # Invalid due to presence validation
        ]
      end

      it 'returns error response' do
        post bulk_create_api_v1_positions_path,
             params: { positions: invalid_attributes },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end

      it 'does not create any positions when validate_all is true' do
        expect {
          post bulk_create_api_v1_positions_path,
               params: { positions: invalid_attributes },
               headers: headers
        }.not_to change(Position, :count)
      end

      it 'creates valid positions when validate_all is false' do
        expect {
          post bulk_create_api_v1_positions_path,
               params: { positions: invalid_attributes, validate_all: false },
               headers: headers
        }.to change(Position, :count).by(1)
      end
    end

    context 'with unauthorized user' do
      let(:unauthorized_user) { create(:user) }
      let(:unauthorized_headers) { auth_headers(unauthorized_user) }

      it 'returns unauthorized status' do
        post bulk_create_api_v1_positions_path,
             params: { positions: valid_attributes },
             headers: unauthorized_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v1/positions/bulk_update' do
    let!(:positions) { create_list(:position, 2, department: department) }
    let(:valid_attributes) do
      [
        { id: positions[0].id, title: 'Updated Position 1' },
        { id: positions[1].id, title: 'Updated Position 2' }
      ]
    end

    context 'with valid parameters' do
      it 'updates multiple positions' do
        patch bulk_update_api_v1_positions_path,
              params: { positions: valid_attributes },
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(positions[0].reload.title).to eq('Updated Position 1')
        expect(positions[1].reload.title).to eq('Updated Position 2')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        [
          { id: positions[0].id, title: 'Valid Title' },
          { id: positions[1].id, title: '' }  # Invalid due to presence validation
        ]
      end

      it 'returns error response' do
        patch bulk_update_api_v1_positions_path,
              params: { positions: invalid_attributes },
              headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end

      it 'does not update any positions when validate_all is true' do
        patch bulk_update_api_v1_positions_path,
              params: { positions: invalid_attributes },
              headers: headers

        expect(positions[0].reload.title).not_to eq('Valid Title')
      end

      it 'updates valid positions when validate_all is false' do
        patch bulk_update_api_v1_positions_path,
              params: { positions: invalid_attributes, validate_all: false },
              headers: headers

        expect(positions[0].reload.title).to eq('Valid Title')
        expect(positions[1].reload.title).not_to eq('')
      end
    end
  end

  describe 'DELETE /api/v1/positions/bulk_delete' do
    let!(:positions) { create_list(:position, 3, department: department) }
    let(:position_ids) { positions.map(&:id) }

    context 'with valid parameters' do
      it 'deletes multiple positions' do
        expect {
          delete bulk_delete_api_v1_positions_path,
                 params: { ids: position_ids },
                 headers: headers
        }.to change(Position, :count).by(-3)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_ids) { [999999, 999998] }

      it 'returns error response' do
        delete bulk_delete_api_v1_positions_path,
               params: { ids: invalid_ids },
               headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end

      it 'deletes existing positions when validate_all is false' do
        mixed_ids = position_ids + invalid_ids

        expect {
          delete bulk_delete_api_v1_positions_path,
                 params: { ids: mixed_ids, validate_all: false },
                 headers: headers
        }.to change(Position, :count).by(-3)
      end
    end

    context 'with positions that have employees' do
      let!(:position_with_employee) { create(:position, department: department) }
      let!(:employee) { create(:employee, position: position_with_employee) }

      it 'prevents deletion and returns error' do
        expect {
          delete bulk_delete_api_v1_positions_path,
                 params: { ids: [position_with_employee.id] },
                 headers: headers
        }.not_to change(Position, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).not_to be_empty
      end
    end
  end

  def json_response
    JSON.parse(response.body)
  end
end 