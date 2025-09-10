# frozen_string_literal: true

require_relative "scanners/pattern_scanner"
require_relative "scanners/morse_code_scanner"

class PromptFirewallService
  class FilterResult
    attr_reader :allowed, :action, :matched_patterns, :message, :scanner_results

    def initialize(allowed:, action:, matched_patterns: [], message: nil, scanner_results: [])
      @allowed = allowed
      @action = action
      @matched_patterns = matched_patterns
      @message = message
      @scanner_results = scanner_results
    end

    def blocked?
      !allowed
    end

    def to_h
      {
        allowed: allowed,
        action: action,
        matched_patterns: matched_patterns.map(&:to_h),
        message: message,
        scanner_results: scanner_results.map(&:to_h)
      }
    end
  end

  class MatchedPattern
    attr_reader :name, :pattern, :action, :description, :metadata

    def initialize(name:, pattern: nil, action:, description:, metadata: {})
      @name = name
      @pattern = pattern
      @action = action
      @description = description
      @metadata = metadata
    end

    def to_h
      {
        name: name,
        pattern: pattern,
        action: action,
        description: description,
        metadata: metadata
      }
    end
  end

  def initialize
    @config = load_config
    @logger = Rails.logger
    @scanners = initialize_scanners
  end

  def filter_prompt(prompt)
    return FilterResult.new(allowed: true, action: "allow") unless firewall_enabled?

    matched_patterns = []
    scanner_results = []
    highest_severity_action = "allow"

    # Run all enabled scanners
    @scanners.each do |scanner|
      next unless scanner.enabled?

      scan_result = scanner.scan(prompt)
      scanner_results << scan_result

      # Process matches from this scanner
      scan_result.matches.each do |match|
        matched_pattern = MatchedPattern.new(
          name: match.name,
          pattern: match.metadata[:pattern],
          action: match.action,
          description: match.description,
          metadata: match.metadata,
        )
        matched_patterns << matched_pattern

        # Determine the highest severity action
        highest_severity_action = determine_highest_severity(highest_severity_action, match.action)
      end
    end

    # If no patterns matched, allow the prompt
    if matched_patterns.empty?
      result = FilterResult.new(
        allowed: true,
        action: "allow",
        scanner_results: scanner_results,
      )
      log_result(prompt, result) if should_log_allowed?
      return result
    end

    # Determine if the prompt should be allowed based on the highest severity action
    allowed = highest_severity_action != "block"
    result = FilterResult.new(
      allowed: allowed,
      action: highest_severity_action,
      matched_patterns: matched_patterns,
      message: generate_message(highest_severity_action, matched_patterns),
      scanner_results: scanner_results,
    )

    log_result(prompt, result) if should_log_result?(result)
    result
  end

  def reload_config!
    @config = load_config
    @scanners = initialize_scanners
    @logger.info "Prompt firewall configuration reloaded"
  end

  def firewall_enabled?
    @config["enabled"] == true
  end

  def get_patterns
    @config["patterns"] || []
  end

  def get_config
    @config.dup
  end

  private

  def initialize_scanners
    scanners = []

    # Initialize pattern scanner with existing patterns configuration
    pattern_config = {
      "enabled" => @config.fetch("enabled", true),
      "patterns" => @config.fetch("patterns", []),
      "default_action" => @config.fetch("default_action", "block")
    }
    scanners << Scanners::PatternScanner.new(pattern_config)

    # Initialize morse code scanner
    morse_config = @config.fetch("morse_code_scanner", {})
    morse_config["enabled"] = morse_config.fetch("enabled", true)
    scanners << Scanners::MorseCodeScanner.new(morse_config)

    scanners
  end

  def load_config
    config_file = Rails.root.join("config", "prompt_filters.yml")
    unless File.exist?(config_file)
      Rails.logger.warn "Prompt filters configuration file not found: #{config_file}"
      return default_config
    end

    begin
      yaml_content = ERB.new(File.read(config_file)).result
      config = YAML.safe_load(yaml_content, aliases: true)
      environment_config = config[Rails.env] || config["default"] || {}

      # Ensure required keys exist
      environment_config["enabled"] = true if environment_config["enabled"].nil?
      environment_config["default_action"] ||= "block"
      environment_config["patterns"] ||= []
      environment_config["logging"] ||= {}

      environment_config
    rescue StandardError => e
      Rails.logger.error "Error loading prompt filters configuration: #{e.message}"
      default_config
    end
  end

  def default_config
    {
      "enabled" => true,
      "default_action" => "block",
      "patterns" => [],
      "logging" => {
        "enabled" => true,
        "level" => "info",
        "log_blocked" => true,
        "log_allowed" => false
      }
    }
  end

  def matches_pattern?(text, pattern)
    return false if text.nil? || pattern.nil?

    begin
      regex = Regexp.new(pattern)
      regex.match?(text)
    rescue RegexpError => e
      Rails.logger.error "Invalid regex pattern '#{pattern}': #{e.message}"
      false
    end
  end

  def determine_highest_severity(current, new_action)
    severity_order = { "allow" => 0, "log" => 1, "warn" => 2, "block" => 3 }

    current_severity = severity_order[current] || 0
    new_severity = severity_order[new_action] || 0

    new_severity > current_severity ? new_action : current
  end

  def generate_message(action, matched_patterns)
    case action
    when "block"
      "Prompt blocked due to security policy violations: #{matched_patterns.map(&:name).join(", ")}"
    when "warn"
      "Prompt flagged for review: #{matched_patterns.map(&:name).join(", ")}"
    when "log"
      "Prompt logged for monitoring: #{matched_patterns.map(&:name).join(", ")}"
    else
      nil
    end
  end

  def should_log_result?(result)
    return false unless logging_enabled?

    (result.blocked? && should_log_blocked?) || (result.allowed && should_log_allowed?)
  end

  def should_log_allowed?
    logging_enabled? && @config.dig("logging", "log_allowed") == true
  end

  def should_log_blocked?
    logging_enabled? && @config.dig("logging", "log_blocked") == true
  end

  def logging_enabled?
    @config.dig("logging", "enabled") == true
  end

  def log_result(prompt, result)
    log_level = @config.dig("logging", "level") || "info"

    log_data = {
      prompt_length: prompt.length,
      action: result.action,
      allowed: result.allowed,
      matched_patterns: result.matched_patterns.map(&:name),
      timestamp: Time.now.iso8601
    }

    case log_level
    when "debug"
      log_data[:prompt_preview] = prompt[0..100] # First 100 chars for debugging
    end

    message = if result.blocked?
        "BLOCKED: #{result.message}"
    elsif result.action == "warn"
        "WARNING: #{result.message}"
    else
        "ALLOWED: Prompt passed firewall checks"
    end

    case log_level
    when "debug"
      @logger.debug "#{message} | #{log_data.to_json}"
    when "info"
      @logger.info "#{message} | #{log_data.except(:prompt_preview).to_json}"
    when "warn"
      @logger.warn "#{message} | #{log_data.except(:prompt_preview).to_json}" if result.action != "allow"
    when "error"
      @logger.error "#{message} | #{log_data.except(:prompt_preview).to_json}" if result.blocked?
    end
  end
end
