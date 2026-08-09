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
  end
end
