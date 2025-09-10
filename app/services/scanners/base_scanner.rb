# frozen_string_literal: true

module Scanners
  class BaseScanner
    class ScanResult
      attr_reader :matches, :scanner_name

      def initialize(matches: [], scanner_name:)
        @matches = matches
        @scanner_name = scanner_name
      end

      def has_matches?
        !matches.empty?
      end

      def to_h
        {
          scanner_name: scanner_name,
          matches: matches.map(&:to_h),
        }
      end
    end

    class Match
      attr_reader :name, :action, :description, :metadata

      def initialize(name:, action:, description:, metadata: {})
        @name = name
        @action = action
        @description = description
        @metadata = metadata
      end

      def to_h
        {
          name: name,
          action: action,
          description: description,
          metadata: metadata,
        }
      end
    end

    def initialize(config = {})
      @config = config
      @logger = Rails.logger
    end

    # Abstract method to be implemented by subclasses
    def scan(prompt)
      raise NotImplementedError, "Subclasses must implement the scan method"
    end

    # Abstract method to return scanner name
    def scanner_name
      raise NotImplementedError, "Subclasses must implement the scanner_name method"
    end

    # Check if scanner is enabled
    def enabled?
      @config.fetch("enabled", true)
    end

    protected

    def create_match(name:, action:, description:, metadata: {})
      Match.new(
        name: name,
        action: action,
        description: description,
        metadata: metadata,
      )
    end

    def create_result(matches: [])
      ScanResult.new(matches: matches, scanner_name: scanner_name)
    end

    def log_scan(prompt, result)
      return unless @logger

      if result.has_matches?
        @logger.info "#{scanner_name} scanner found #{result.matches.size} matches in prompt"
      else
        @logger.debug "#{scanner_name} scanner found no matches in prompt"
      end
    end
  end
end
