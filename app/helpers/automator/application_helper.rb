# frozen_string_literal: true

module Automator
  module ApplicationHelper
    def automator_status_badge(status)
      content_tag(:span, status, class: "badge badge-#{status}")
    end

    def pretty_json(value)
      JSON.pretty_generate(value.is_a?(String) ? (JSON.parse(value) rescue value) : value)
    rescue StandardError
      value.inspect
    end

    # Empty hashes/arrays stay blank so placeholders remain visible in forms.
    def json_field_value(value)
      return "" if value.blank?

      pretty_json(value)
    end
  end
end

