# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Organization Chart API',
        version: 'v1',
        description: 'API documentation for Organization Chart management'
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:3500',
          description: 'Development server'
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT'
          }
        },
        schemas: {
          department: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              name: { type: 'string' },
              description: { type: 'string' },
              parent_department_id: { type: 'integer', nullable: true },
              manager_id: { type: 'integer', nullable: true }
            }
          },
          position: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              title: { type: 'string' },
              description: { type: 'string' },
              level: { type: 'integer' },
              department_id: { type: 'integer' },
              parent_position_id: { type: 'integer', nullable: true }
            }
          },
          employee: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              first_name: { type: 'string' },
              last_name: { type: 'string' },
              email: { type: 'string' },
              position_id: { type: 'integer' },
              manager_id: { type: 'integer', nullable: true }
            }
          },
          user: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              email: { type: 'string' },
              role: { type: 'string', enum: ['user', 'admin', 'super_admin'] }
            }
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
