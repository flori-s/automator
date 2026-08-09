# frozen_string_literal: true

module Automator
  class Interpolator
    TOKEN = /\{\{\s*([\w.]+)\s*\}\}/.freeze

    def self.call(template, payload)
      new(payload).call(template)
    end

    def initialize(payload)
      @payload = Payload.stringify(payload || {})
    end

    def call(template)
      case template
      when Hash
        template.transform_values { |v| call(v) }
      when Array
        template.map { |v| call(v) }
      when String
        template.gsub(TOKEN) { |*| dig(::Regexp.last_match(1)).to_s }
      else
        template
      end
    end

    private

    def dig(path)
      parts = path.to_s.split(".")
      @payload.dig(*parts)
    end
  end
end
