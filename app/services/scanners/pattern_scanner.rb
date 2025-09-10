# frozen_string_literal: true

require_relative "base_scanner"

module Scanners
  class PatternScanner < BaseScanner
    def initialize(config = {})
      super(config)
      @patterns = @config.fetch("patterns", [])
      @default_action = @config.fetch("default_action", "block")
    end

    def scan(prompt)
      return create_result unless enabled?
      return create_result if prompt.nil? || prompt.empty?

      matches = []

      @patterns.each do |pattern_config|
        if matches_pattern?(prompt, pattern_config["pattern"])
          match = create_match(
            name: pattern_config["name"],
            action: pattern_config["action"] || @default_action,
            description: pattern_config["description"],
            metadata: {
              pattern: pattern_config["pattern"],
              scanner_type: "regex",
            },
          )
          matches << match
        end
      end

      result = create_result(matches: matches)
      log_scan(prompt, result)
      result
    end

    def scanner_name
      "Pattern Scanner"
    end

    private

    def matches_pattern?(text, pattern)
      return false if text.nil? || pattern.nil?

      begin
        regex = Regexp.new(pattern)
        regex.match?(text)
      rescue RegexpError => e
        @logger.error "Invalid regex pattern '#{pattern}': #{e.message}"
        false
      end
    end
  end
end
