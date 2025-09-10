# frozen_string_literal: true

require_relative "base_scanner"

module Scanners
  class MorseCodeScanner < BaseScanner
    # Morse code dictionary
    MORSE_CODE_MAP = {
      ".-" => "A", "-..." => "B", "-.-." => "C", "-.." => "D", "." => "E",
      "..-." => "F", "--." => "G", "...." => "H", ".." => "I", ".---" => "J",
      "-.-" => "K", ".-.." => "L", "--" => "M", "-." => "N", "---" => "O",
      ".--." => "P", "--.-" => "Q", ".-." => "R", "..." => "S", "-" => "T",
      "..-" => "U", "...-" => "V", ".--" => "W", "-..-" => "X", "-.--" => "Y",
      "--.." => "Z", ".----" => "1", "..---" => "2", "...--" => "3",
      "....-" => "4", "....." => "5", "-...." => "6", "--..." => "7",
      "---.." => "8", "----." => "9", "-----" => "0", "--..--" => ",",
      ".-.-.-" => ".", "..--.." => "?", "-.-.--" => "!", "-....-" => "-",
      "-..-." => "/", ".--.-." => "@", "---..." => ":", "-.-.." => ";",
      "-...-" => "=", ".-.-." => "+", "-.--." => "(", "-.--.-" => ")",
      ".-..-." => "\"", "...-..-" => "$", "..--.-" => "_"
    }.freeze

    # Suspicious patterns to look for in decoded morse code
    SUSPICIOUS_PATTERNS = [
      {
        name: "Morse Code Injection Attempt",
        pattern: /(?i)(ignore\s+(all\s+)?(previous|above)\s+(instructions|prompts|rules)|forget\s+(everything|all|previous))/,
        action: "block",
        description: "Detected instruction override attempt hidden in morse code"
      },
      {
        name: "Morse Code Role Override",
        pattern: /(?i)(you\s+are\s+now|act\s+as\s+if|pretend\s+to\s+be|roleplay\s+as)/,
        action: "warn",
        description: "Detected role override attempt hidden in morse code"
      },
      {
        name: "Morse Code System Prompt Extraction",
        pattern: /(?i)(show\s+me\s+your|what\s+is\s+your|reveal\s+your)\s+(system\s+prompt|instructions|rules)/,
        action: "block",
        description: "Detected system prompt extraction attempt hidden in morse code"
      },
      {
        name: "Morse Code Jailbreak Attempt",
        pattern: /(?i)(jailbreak|dan\s+mode|developer\s+mode|god\s+mode|admin\s+mode)/,
        action: "block",
        description: "Detected jailbreak attempt hidden in morse code"
      },
      {
        name: "Morse Code Harmful Content",
        pattern: /(?i)(how\s+to\s+(kill|murder|harm|hurt)|instructions\s+for\s+(violence|weapons))/,
        action: "block",
        description: "Detected harmful content request hidden in morse code"
      }
    ].freeze

    def initialize(config = {})
      super(config)
      @min_morse_length = @config.fetch("min_morse_length", 10)
      @max_decode_length = @config.fetch("max_decode_length", 1000)
    end

    def scan(prompt)
      return create_result unless enabled?
      return create_result if prompt.nil? || prompt.empty?

      matches = []
      morse_sequences = extract_morse_sequences(prompt)

      morse_sequences.each do |morse_data|
        decoded_text = decode_morse(morse_data[:sequence])
        next if decoded_text.nil? || decoded_text.length < 3

        # Check decoded text against suspicious patterns
        SUSPICIOUS_PATTERNS.each do |pattern_config|
          if pattern_config[:pattern].match?(decoded_text)
            match = create_match(
              name: pattern_config[:name],
              action: pattern_config[:action],
              description: pattern_config[:description],
              metadata: {
                morse_sequence: morse_data[:sequence],
                decoded_text: decoded_text,
                original_position: morse_data[:position],
                scanner_type: "morse_code"
              },
            )
            matches << match
          end
        end
      end

      result = create_result(matches: matches)
      log_scan(prompt, result)
      result
    end

    def scanner_name
      "Morse Code Scanner"
    end

    private

    def extract_morse_sequences(text)
      sequences = []

      # Look for sequences of dots, dashes, and spaces that could be morse code
      # Pattern matches sequences with dots, dashes, and spaces, minimum length
      morse_pattern = /[.\-\s]{#{@min_morse_length},}/

      text.scan(morse_pattern).each_with_index do |sequence, index|
        # Clean up the sequence - remove extra spaces and validate
        cleaned = sequence.strip.gsub(/\s+/, " ")

        # Check if it looks like morse code (has dots and dashes)
        if cleaned.match?(/[.\-]/) && looks_like_morse?(cleaned)
          sequences << {
            sequence: cleaned,
            position: index
          }
        end
      end

      # Also look for common morse code separators like / or |
      alt_pattern = /[.\-\/\|\s]{#{@min_morse_length},}/
      text.scan(alt_pattern).each_with_index do |sequence, index|
        cleaned = sequence.strip.gsub(/[\/\|]/, " ").gsub(/\s+/, " ")

        if cleaned.match?(/[.\-]/) && looks_like_morse?(cleaned)
          sequences << {
            sequence: cleaned,
            position: index + sequences.length
          }
        end
      end

      sequences.uniq { |s| s[:sequence] }
    end

    def looks_like_morse?(sequence)
      # Basic heuristics to determine if a sequence looks like morse code
      dots_and_dashes = sequence.count(".-")
      total_chars = sequence.gsub(/\s/, "").length

      # Should be mostly dots and dashes
      return false if total_chars == 0

      ratio = dots_and_dashes.to_f / total_chars
      ratio > 0.7 # At least 70% dots and dashes
    end

    def decode_morse(morse_sequence)
      return nil if morse_sequence.nil? || morse_sequence.empty?

      # Split by multiple spaces to get words, then by single spaces to get characters
      words = morse_sequence.split(/\s{2,}/)  # Split on 2+ spaces for word boundaries
      decoded_words = []

      words.each do |word|
        morse_chars = word.split(/\s+/)
        decoded_chars = []

        morse_chars.each do |morse_char|
          next if morse_char.empty?

          # Look up the morse character in our dictionary
          if MORSE_CODE_MAP.key?(morse_char)
            decoded_chars << MORSE_CODE_MAP[morse_char]
          else
            # If we can't decode a character, add a placeholder
            decoded_chars << "?"
          end
        end

        decoded_words << decoded_chars.join if decoded_chars.any?

        # Prevent extremely long decoded strings
        break if decoded_words.join(" ").length > @max_decode_length
      end

      # If we didn't find word boundaries, try decoding as one word but add spaces intelligently
      if decoded_words.length == 1 && decoded_words[0].length > 10
        # For long single words, try to add spaces at logical points
        decoded_text = add_word_boundaries(decoded_words[0])
      else
        decoded_text = decoded_words.join(" ")
      end

      # Only return if we successfully decoded a reasonable amount
      if decoded_text.gsub("?", "").length >= 3
        decoded_text
      else
        nil
      end
    end

    def add_word_boundaries(text)
      # Add spaces around common words first (before splitting sequences)
      common_words = %w[IGNORE ALL PREVIOUS INSTRUCTIONS FORGET EVERYTHING JAILBREAK MODE DEVELOPER GOD ADMIN SHOW REVEAL YOUR SYSTEM PROMPT RULES]
      common_words.sort_by(&:length).reverse.each do |word|
        text = text.gsub(/#{Regexp.escape(word)}/, " #{word} ")
      end

      # Clean up extra spaces
      text.gsub(/\s+/, " ").strip
    end
  end
end
