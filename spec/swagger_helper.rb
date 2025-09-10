# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join("swagger").to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Heimdall API",
        description: "A comprehensive API for filtering and validating prompts sent to Large Language Models (LLMs). This firewall service helps protect against prompt injection attacks, jailbreak attempts, sensitive information extraction, harmful content generation requests, and command/SQL injection attempts.",
        version: "1.0.0",
        contact: {
          name: "Heimdall API Support",
          url: "https://github.com/your-username/llm-fw"
        },
        license: {
          name: "MIT",
          url: "https://opensource.org/licenses/MIT"
        }
      },
      paths: {},
      servers: [
        {
          url: "http://localhost:3000",
          description: "Development server"
        },
        {
          url: "https://your-domain.com",
          description: "Production server"
        }
      ],
      components: {
        schemas: {
          ValidationResponse: {
            type: :object,
            required: [ :allowed, :action, :message, :matched_patterns, :timestamp ],
            properties: {
              allowed: {
                type: :boolean,
                description: "Whether the prompt is allowed through the firewall",
                example: true
              },
              action: {
                type: :string,
                enum: [ "allow", "block", "warn" ],
                description: "The action taken by the firewall",
                example: "allow"
              },
              message: {
                type: :string,
                description: "Human-readable message describing the result",
                example: "Prompt is safe"
              },
              matched_patterns: {
                type: :array,
                description: "List of patterns that matched the prompt",
                items: { "$ref" => "#/components/schemas/MatchedPattern" }
              },
              timestamp: {
                type: :string,
                format: "date-time",
                description: "ISO 8601 timestamp of the validation",
                example: "2024-01-01T12:00:00Z"
              }
            }
          },
          MatchedPattern: {
            type: :object,
            required: [ :name, :action, :description ],
            properties: {
              name: {
                type: :string,
                description: "Name of the matched pattern",
                example: "Ignore Instructions"
              },
              action: {
                type: :string,
                enum: [ "block", "warn", "log" ],
                description: "Action associated with this pattern",
                example: "block"
              },
              description: {
                type: :string,
                description: "Description of what this pattern detects",
                example: "Detects attempts to ignore system instructions"
              }
            }
          },
          ErrorResponse: {
            type: :object,
            required: [ :error ],
            properties: {
              error: {
                type: :string,
                description: "Error message",
                example: "param is missing or the value is empty or invalid: prompt"
              }
            }
          }
        }
      },
      tags: [
        {
          name: "Prompt Validation",
          description: "Operations for validating prompts against firewall rules"
        },
        {
          name: "Configuration",
          description: "Operations for managing firewall configuration"
        },
        {
          name: "Health",
          description: "Health check and monitoring operations"
        }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
