require 'swagger_helper'

RSpec.describe 'Api::V1::Permissions', type: :request do
  let(:user) { create(:user, :admin) }
  let(:Authorization) { "Bearer #{JsonWebToken.encode(user_id: user.id)}" }

  path '/api/v1/users/{user_id}/permissions' do
    parameter name: :user_id, in: :path, type: :integer

    get 'Lists user permissions' do
      tags 'Permissions'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'permissions found' do
        let(:user) { create(:user) }
        let(:user_id) { user.id }
        let!(:permission) { create(:permission, user: user) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).not_to be_empty
        end
      end

      response '401', 'unauthorized' do
        let(:headers) { {} }
        let(:user_id) { create(:user).id }
        run_test!
      end

      response '403', 'forbidden' do
        let(:headers) { auth_headers(create(:user)) }
        let(:user_id) { create(:user).id }
        run_test!
      end
    end

    post 'Creates a permission' do
      tags 'Permissions'
      security [bearer_auth: []]
      consumes 'application/json'
      parameter name: :permission, in: :body, schema: {
        type: :object,
        properties: {
          resource: { type: :string, enum: Permission::RESOURCES },
          action: { type: :string, enum: Permission::ACTIONS },
          resource_id: { type: :integer, nullable: true }
        },
        required: ['resource', 'action']
      }

      response '201', 'permission created' do
        let(:user) { create(:user) }
        let(:user_id) { user.id }
        let(:permission) { { resource: 'department', action: 'read', resource_id: create(:department).id } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['resource']).to eq('department')
        end
      end

      response '401', 'unauthorized' do
        let(:headers) { {} }
        let(:user_id) { create(:user).id }
        let(:permission) { { resource: 'department', action: 'read' } }
        run_test!
      end

      response '403', 'forbidden' do
        let(:headers) { auth_headers(create(:user)) }
        let(:user_id) { create(:user).id }
        let(:permission) { { resource: 'department', action: 'read' } }
        run_test!
      end

      response '422', 'invalid request' do
        let(:user) { create(:user) }
        let(:user_id) { user.id }
        let(:permission) { { resource: 'invalid', action: 'invalid' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).not_to be_empty
        end
      end
    end
  end

  path '/api/v1/users/{user_id}/permissions/{id}' do
    parameter name: :user_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    delete 'Deletes a permission' do
      tags 'Permissions'
      security [bearer_auth: []]

      response '204', 'permission deleted' do
        let(:user) { create(:user) }
        let(:user_id) { user.id }
        let(:permission) { create(:permission, user: user) }
        let(:id) { permission.id }

        run_test!
      end

      response '401', 'unauthorized' do
        let(:headers) { {} }
        let(:user) { create(:user) }
        let(:user_id) { user.id }
        let(:permission) { create(:permission, user: user) }
        let(:id) { permission.id }
        run_test!
      end

      response '403', 'forbidden' do
        let(:headers) { auth_headers(create(:user)) }
        let(:user) { create(:user) }
        let(:user_id) { user.id }
        let(:permission) { create(:permission, user: user) }
        let(:id) { permission.id }
        run_test!
      end
    end
  end
end 