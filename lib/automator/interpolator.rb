# frozen_string_literal: true

module Automator
  class Interpolator
    TOKEN = /\{\{\s*([\w.]+)\s*\}\}/.freeze

    def self.call(template, payload, flow: nil)
      new(payload, flow: flow).call(template)
    end

    def initialize(payload, flow: nil)
      @payload = Payload.stringify(payload || {})
      @flow = flow
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
      from_payload = @payload.dig(*parts)
      return from_payload unless from_payload.nil? || from_payload == ""

      live = LiveLookup.read(@payload, path, flow: @flow)
      live.nil? ? from_payload : live
    end
  end
end
