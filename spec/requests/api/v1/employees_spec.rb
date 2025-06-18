require 'swagger_helper'

RSpec.describe 'Api::V1::Employees', type: :request do
  let(:user) { create(:user, :admin) }
  let(:Authorization) { "Bearer #{JsonWebToken.encode(user_id: user.id)}" }

  path '/api/v1/employees' do
    get 'Lists employees' do
      tags 'Employees'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'employees found' do
        let!(:employees) { create_list(:employee, 3) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(3)
        end
      end
    end

    post 'Creates an employee' do
      tags 'Employees'
      consumes 'application/json'
      parameter name: :employee, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string },
          last_name: { type: :string },
          email: { type: :string },
          position_id: { type: :integer },
          manager_id: { type: :integer, nullable: true }
        },
        required: ['first_name', 'last_name', 'email', 'position_id']
      }

      response '201', 'employee created' do
        let(:position) { create(:position) }
        let(:employee) { { first_name: 'John', last_name: 'Doe', email: 'john@example.com', position_id: position.id } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('john@example.com')
        end
      end

      response '422', 'invalid request' do
        let(:employee) { { first_name: '' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to include("First name can't be blank")
        end
      end
    end
  end

  path '/api/v1/employees/{id}' do
    parameter name: :id, in: :path, type: :integer

    let(:existing_employee) { create(:employee) }
    let(:id) { existing_employee.id }

    get 'Retrieves an employee' do
      tags 'Employees'
      produces 'application/json'

      response '200', 'employee found' do
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(existing_employee.id)
        end
      end

      response '404', 'employee not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end

    patch 'Updates an employee' do
      tags 'Employees'
      consumes 'application/json'
      parameter name: :employee, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string },
          last_name: { type: :string },
          email: { type: :string },
          position_id: { type: :integer },
          manager_id: { type: :integer }
        }
      }

      response '200', 'employee updated' do
        let(:employee) { { first_name: 'Updated' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['first_name']).to eq('Updated')
        end
      end
    end

    delete 'Deletes an employee' do
      tags 'Employees'

      response '204', 'employee deleted' do
        run_test!
      end
    end
  end

  path '/api/v1/employees/{id}/subordinates' do
    parameter name: :id, in: :path, type: :integer

    get 'Retrieves employee subordinates' do
      tags 'Employees'
      produces 'application/json'

      response '200', 'subordinates retrieved' do
        let(:manager) { create(:employee, :with_subordinate) }
        let(:id) { manager.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['subordinates']).not_to be_empty
        end
      end
    end
  end

  path '/api/v1/departments/{department_id}/employees' do
    parameter name: :department_id, in: :path, type: :integer

    get 'Lists employees for a department' do
      tags 'Employees'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'employees found' do
        let(:department) { create(:department) }
        let(:department_id) { department.id }
        let(:position) { create(:position, department: department) }
        let!(:employees) { create_list(:employee, 3, position: position) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(3)
          expect(data.all? { |e| e['position']['department_id'] == department.id }).to be true
        end
      end
    end
  end

  path '/api/v1/positions/{position_id}/employees' do
    parameter name: :position_id, in: :path, type: :integer

    get 'Lists employees for a position' do
      tags 'Employees'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'employees found' do
        let(:position) { create(:position) }
        let(:position_id) { position.id }
        let!(:employees) { create_list(:employee, 3, position: position) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(3)
          expect(data.all? { |e| e['position_id'] == position.id }).to be true
        end
      end
    end
  end
end 