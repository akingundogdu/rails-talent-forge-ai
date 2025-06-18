require 'swagger_helper'

RSpec.describe 'Api::V1::Positions', type: :request do
  let(:user) { create(:user, :admin) }
  let(:Authorization) { "Bearer #{JsonWebToken.encode(user_id: user.id)}" }

  path '/api/v1/positions' do
    get 'Lists positions' do
      tags 'Positions'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'positions found' do
        let!(:positions) { create_list(:position, 3) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(3)
        end
      end
    end

    post 'Creates a position' do
      tags 'Positions'
      consumes 'application/json'
      parameter name: :position, in: :body, schema: {
        type: :object,
        properties: {
          title: { type: :string },
          description: { type: :string },
          level: { type: :integer },
          department_id: { type: :integer },
          parent_position_id: { type: :integer, nullable: true }
        },
        required: ['title', 'level', 'department_id']
      }

      response '201', 'position created' do
        let(:department) { create(:department) }
        let(:position) { { title: 'New Position', description: 'Test position', level: 1, department_id: department.id } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['title']).to eq('New Position')
        end
      end

      response '422', 'invalid request' do
        let(:position) { { title: '' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to include("Title can't be blank")
        end
      end
    end
  end

  path '/api/v1/positions/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:existing_position) { create(:position) }
    let(:id) { existing_position.id }

    get 'Retrieves a position' do
      tags 'Positions'
      produces 'application/json'

      response '200', 'position found' do
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(existing_position.id)
        end
      end

      response '404', 'position not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end

    patch 'Updates a position' do
      tags 'Positions'
      consumes 'application/json'
      parameter name: :position, in: :body, schema: {
        type: :object,
        properties: {
          title: { type: :string },
          description: { type: :string },
          level: { type: :integer },
          department_id: { type: :integer },
          parent_position_id: { type: :integer }
        }
      }

      response '200', 'position updated' do
        let(:position) { { title: 'Updated Position' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['title']).to eq('Updated Position')
        end
      end
    end

    delete 'Deletes a position' do
      tags 'Positions'

      response '204', 'position deleted' do
        run_test!
      end
    end
  end

  path '/api/v1/positions/{id}/hierarchy' do
    parameter name: :id, in: :path, type: :integer

    get 'Retrieves position hierarchy' do
      tags 'Positions'
      produces 'application/json'

      response '200', 'hierarchy retrieved' do
        let(:parent_position) { create(:position, :with_subordinate, level: 3) }
        let(:id) { parent_position.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['subordinate_positions']).not_to be_empty
        end
      end
    end
  end

  path '/api/v1/departments/{department_id}/positions' do
    parameter name: :department_id, in: :path, type: :integer

    get 'Lists positions for a department' do
      tags 'Positions'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'positions found' do
        let(:department) { create(:department) }
        let(:department_id) { department.id }
        let!(:positions) { create_list(:position, 3, department: department) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(3)
          expect(data.all? { |p| p['department_id'] == department.id }).to be true
        end
      end
    end
  end
end 