# frozen_string_literal: true

module Api
  module V1
    class PromptsController < ApplicationController
      before_action :initialize_firewall_service

      # POST /api/v1/prompts/validate
      # Validates a prompt against the firewall rules
      def validate
        prompt_text = params.require(:prompt)

        if prompt_text.blank?
          render json: { error: "Prompt cannot be empty" }, status: :bad_request
          return
        end

        result = @firewall_service.filter_prompt(prompt_text)

        response_data = {
          allowed: result.allowed,
          action: result.action,
          message: result.message,
          matched_patterns: result.matched_patterns.map(&:to_h),
          timestamp: Time.current.iso8601,
        }

        status = result.blocked? ? :forbidden : :ok
        render json: response_data, status: status
      rescue ActionController::ParameterMissing => e
        render json: { error: e.message }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Error validating prompt: #{e.message}"
        render json: { error: "Internal server error" }, status: :internal_server_error
      end

      # POST /api/v1/prompts/batch_validate
      # Validates multiple prompts in a single request
      def batch_validate
        prompts = params.require(:prompts)

        unless prompts.is_a?(Array)
          render json: { error: "Prompts must be an array" }, status: :bad_request
          return
        end

        if prompts.empty?
          render json: { error: "Prompts array cannot be empty" }, status: :bad_request
          return
        end

        if prompts.length > 100
          render json: { error: "Maximum 100 prompts allowed per batch" }, status: :bad_request
          return
        end

        results = prompts.map.with_index do |prompt_text, index|
          if prompt_text.blank?
            {
              index: index,
              error: "Prompt cannot be empty",
              allowed: false,
              action: "error",
            }
          else
            result = @firewall_service.filter_prompt(prompt_text)
            {
              index: index,
              allowed: result.allowed,
              action: result.action,
              message: result.message,
              matched_patterns: result.matched_patterns.map(&:to_h),
            }
          end
        end

        response_data = {
          results: results,
          summary: {
            total: results.length,
            allowed: results.count { |r| r[:allowed] },
            blocked: results.count { |r| !r[:allowed] && r[:action] != "error" },
            errors: results.count { |r| r[:action] == "error" },
          },
          timestamp: Time.current.iso8601,
        }

        render json: response_data, status: :ok
      rescue ActionController::ParameterMissing => e
        render json: { error: e.message }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Error batch validating prompts: #{e.message}"
        render json: { error: "Internal server error" }, status: :internal_server_error
      end

      # GET /api/v1/prompts/config
      # Returns the current firewall configuration (without sensitive data)
      def config
        config_data = {
          enabled: @firewall_service.firewall_enabled?,
          patterns_count: @firewall_service.get_patterns.length,
          patterns: @firewall_service.get_patterns.map do |pattern|
            {
              name: pattern["name"],
              action: pattern["action"],
              description: pattern["description"],
            # Note: We don't expose the actual regex patterns for security
            }
          end,
          timestamp: Time.current.iso8601,
        }

        render json: config_data, status: :ok
      rescue StandardError => e
        Rails.logger.error "Error retrieving firewall config: #{e.message}"
        render json: { error: "Internal server error" }, status: :internal_server_error
      end

      # POST /api/v1/prompts/reload_config
      # Reloads the firewall configuration from the YAML file
      def reload_config
        @firewall_service.reload_config!

        render json: {
          message: "Configuration reloaded successfully",
          enabled: @firewall_service.firewall_enabled?,
          patterns_count: @firewall_service.get_patterns.length,
          timestamp: Time.current.iso8601,
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error "Error reloading firewall config: #{e.message}"
        render json: { error: "Internal server error" }, status: :internal_server_error
      end

      # GET /api/v1/prompts/health
      # Health check endpoint
      def health
        health_data = {
          status: "healthy",
          firewall_enabled: @firewall_service.firewall_enabled?,
          patterns_loaded: @firewall_service.get_patterns.length,
          timestamp: Time.current.iso8601,
          version: "1.0.0",
        }

        render json: health_data, status: :ok
      rescue StandardError => e
        Rails.logger.error "Health check failed: #{e.message}"
        render json: {
          status: "unhealthy",
          error: "Service unavailable",
          timestamp: Time.current.iso8601,
        }, status: :service_unavailable
      end

      private

      def initialize_firewall_service
        @firewall_service = PromptFirewallService.new
      end
    end
  end
end
