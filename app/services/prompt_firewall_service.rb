# frozen_string_literal: true

class PromptFirewallService
  class FilterResult
    attr_reader :allowed, :action, :matched_patterns, :message

    def initialize(allowed:, action:, matched_patterns: [], message: nil)
      @allowed = allowed
      @action = action
      @matched_patterns = matched_patterns
      @message = message
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
      }
    end
  end

  class MatchedPattern
    attr_reader :name, :pattern, :action, :description

    def initialize(name:, pattern:, action:, description:)
      @name = name
      @pattern = pattern
      @action = action
      @description = description
    end

    def to_h
      {
        name: name,
        pattern: pattern,
        action: action,
        description: description,
      }
    end
  end

  def initialize
    @config = load_config
    @logger = Rails.logger
  end

  def filter_prompt(prompt)
    return FilterResult.new(allowed: true, action: "allow") unless firewall_enabled?

    matched_patterns = []
    highest_severity_action = "allow"

    @config["patterns"]&.each do |pattern_config|
      if matches_pattern?(prompt, pattern_config["pattern"])
        matched_pattern = MatchedPattern.new(
          name: pattern_config["name"],
          pattern: pattern_config["pattern"],
          action: pattern_config["action"] || @config["default_action"],
          description: pattern_config["description"],
        )
        matched_patterns << matched_pattern

        # Determine the highest severity action
        action = matched_pattern.action
        highest_severity_action = determine_highest_severity(highest_severity_action, action)
      end
    end

    # If no patterns matched, allow the prompt
    if matched_patterns.empty?
      result = FilterResult.new(allowed: true, action: "allow")
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
    )

    log_result(prompt, result) if should_log_result?(result)
    result
  end

  def reload_config!
    @config = load_config
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
        "log_allowed" => false,
      },
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
      timestamp: Time.now.iso8601,
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
