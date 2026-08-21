# frozen_string_literal: true

module Automator
  class ConditionEvaluator
    def initialize(payload:, context: {})
      @payload = Payload.stringify(payload || {})
      @context = context
    end

    def all_pass?(conditions)
      Array(conditions).all? { |condition| evaluate(condition) }
    end

    def any_pass?(conditions)
      list = Array(conditions)
      return false if list.empty?

      list.any? { |condition| evaluate(condition) }
    end

    def evaluate(condition)
      case condition.kind.to_s
      when "custom"
        Registry.predicate(condition.predicate_key).call(@payload, @context)
      else
        evaluate_structured(condition.config || {})
      end
    rescue StandardError => e
      Automator.logger.warn("[Automator] Condition error: #{e.message}")
      false
    end

    def breakdown(conditions)
      Array(conditions).map do |condition|
        {
          id: condition.id,
          kind: condition.kind,
          pass: evaluate(condition),
          config: condition.config,
          predicate_key: condition.predicate_key
        }
      end
    end

    private

    def evaluate_structured(config)
      op = (config["op"] || config[:op]).to_s
      attribute = config["attribute"] || config[:attribute]
      value = config.key?("value") ? config["value"] : config[:value]
      actual = dig(attribute)

      case op
      when "eq" then eq?(actual, value)
      when "neq" then neq?(actual, value)
      when "gt"
        left, right = ordered(actual, value)
        left > right
      when "gte"
        left, right = ordered(actual, value)
        left >= right
      when "lt"
        left, right = ordered(actual, value)
        left < right
      when "lte"
        left, right = ordered(actual, value)
        left <= right
      when "in" then Array(value).map { |v| cast(v) }.include?(cast(actual))
      when "present" then actual.present?
      when "blank" then actual.blank?
      when "days_before" then days_before?(actual, value)
      when "days_after" then days_after?(actual, value)
      else
        false
      end
    end

    def days_before?(target, days)
      date = parse_date(target)
      return false unless date

      Date.current == date - days.to_i
    end

    def days_after?(target, days)
      date = parse_date(target)
      return false unless date

      Date.current == date + days.to_i
    end

    def dig(path)
      return @payload if path.blank?

      from_payload = payload_dig(path)
      return from_payload unless payload_missing?(from_payload)

      live = LiveLookup.read(@payload, path, flow: @context[:flow])
      live.nil? ? from_payload : live
    end

    def payload_dig(path)
      parts = path.to_s.split(".")
      if parts.first == "record"
        @payload.dig(*parts)
      else
        @payload.dig("record", *parts) || @payload.dig(*parts)
      end
    end

    def payload_missing?(value)
      value.nil? || value == ""
    end

    # eq false matches nil/false (IS NOT TRUE). neq false matches nil/true (IS NOT FALSE).
    def eq?(actual, expected)
      return boolean_eq?(actual, expected) if boolean_compare?(actual, expected)

      cast(actual) == cast(expected)
    end

    def neq?(actual, expected)
      return boolean_neq?(actual, expected) if boolean_compare?(actual, expected)

      cast(actual) != cast(expected)
    end

    def boolean_compare?(actual, expected)
      boolean_literal?(expected) && (actual.nil? || boolean_literal?(actual))
    end

    def boolean_literal?(value)
      value == true || value == false || %w[true false].include?(value.to_s.downcase)
    end

    def boolean_eq?(actual, expected)
      expected_bool = to_bool(expected)
      actual_bool = to_bool(actual)
      if expected_bool == false
        actual_bool != true
      else
        actual_bool == true
      end
    end

    def boolean_neq?(actual, expected)
      expected_bool = to_bool(expected)
      actual_bool = to_bool(actual)
      if expected_bool == false
        actual_bool != false
      else
        actual_bool != true
      end
    end

    def to_bool(value)
      return nil if value.nil? || value == ""
      return false if value == false || value.to_s.downcase == "false"
      return true if value == true || value.to_s.downcase == "true"

      nil
    end

    def cast(value)
      return value if value.nil?
      return value.to_f if numeric?(value)

      value.to_s
    end

    def ordered(left, right)
      left_date = parse_date(left)
      right_date = parse_date(right)
      return [left_date, right_date] if left_date && right_date
      return [cast(left), cast(right)] if numeric?(left) && numeric?(right)

      [left.to_s, right.to_s]
    end

    def numeric?(value)
      value.is_a?(Numeric) || value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
    end

    def parse_date(value)
      return value if value.is_a?(Date)
      return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String) && !value.is_a?(Numeric)

      str = value.to_s
      return nil unless str.match?(/\A\d{4}-\d{2}-\d{2}/) || str.include?("/") || str.match?(/[A-Za-z]/)

      Date.parse(str)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
