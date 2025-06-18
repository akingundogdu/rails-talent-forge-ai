require 'swagger_helper'

RSpec.describe 'Api::V1::Departments', type: :request do
  let(:user) { create(:user, :admin) }
  let(:Authorization) { "Bearer #{JsonWebToken.encode(user_id: user.id)}" }

  path '/api/v1/departments' do
    get 'Lists departments' do
      tags 'Departments'
      security [bearer_auth: []]
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'departments found' do
        let!(:departments) { create_list(:department, 3) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(3)
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end
    end

    post 'Creates a department' do
      tags 'Departments'
      security [bearer_auth: []]
      consumes 'application/json'
      parameter name: :department, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          parent_department_id: { type: :integer, nullable: true },
          manager_id: { type: :integer, nullable: true }
        },
        required: ['name']
      }

      response '201', 'department created' do
        let(:department) { { name: 'New Department', description: 'Test department' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('New Department')
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:department) { { name: 'New Department' } }
        run_test!
      end

      response '403', 'forbidden' do
        let(:user) { create(:user) }
        let(:department) { { name: 'New Department' } }
        run_test!
      end

      response '422', 'invalid request' do
        let(:department) { { name: '' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to include("Name can't be blank")
        end
      end
    end
  end

  path '/api/v1/departments/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:existing_department) { create(:department) }
    let(:id) { existing_department.id }

    get 'Retrieves a department' do
      tags 'Departments'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'department found' do
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(existing_department.id)
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end

      response '404', 'department not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end

    patch 'Updates a department' do
      tags 'Departments'
      security [bearer_auth: []]
      consumes 'application/json'
      parameter name: :department, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          parent_department_id: { type: :integer },
          manager_id: { type: :integer }
        }
      }

      response '200', 'department updated' do
        let(:department) { { name: 'Updated Department' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Updated Department')
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:department) { { name: 'Updated Department' } }
        run_test!
      end

      response '403', 'forbidden' do
        let(:user) { create(:user) }
        let(:department) { { name: 'Updated Department' } }
        run_test!
      end
    end

    delete 'Deletes a department' do
      tags 'Departments'
      security [bearer_auth: []]

      response '204', 'department deleted' do
        let(:user) { create(:user, :super_admin) }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end

      response '403', 'forbidden' do
        let(:user) { create(:user) }
        run_test!
      end
    end
  end

  path '/api/v1/departments/tree' do
    get 'Retrieves department tree' do
      tags 'Departments'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'department tree retrieved' do
        let!(:parent) { create(:department) }
        let!(:child) { create(:department, parent_department: parent) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.first['sub_departments']).not_to be_empty
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path '/api/v1/departments/{id}/org_chart' do
    parameter name: :id, in: :path, type: :integer

    get 'Retrieves department organization chart' do
      tags 'Departments'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'organization chart retrieved' do
        let(:department) { create(:department) }
        let(:id) { department.id }
        let!(:position) { create(:position, department: department) }
        let!(:employee) { create(:employee, position: position) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['positions']).not_to be_empty
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end

      response '403', 'forbidden' do
        let(:user) { create(:user) }
        run_test!
      end
    end
  end
end 