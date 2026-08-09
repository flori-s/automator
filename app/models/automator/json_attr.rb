# frozen_string_literal: true

module Automator
  module JsonAttr
    extend ActiveSupport::Concern

    class_methods do
      def json_attr(*names)
        names.each do |name|
          define_method(name) do
            raw = self[name]
            return raw if raw.is_a?(Hash) || raw.is_a?(Array)
            return {} if raw.blank?

            JSON.parse(raw)
          rescue JSON::ParserError
            {}
          end

          define_method("#{name}=") do |value|
            self[name] =
              case value
              when String then value
              when nil then nil
              else value.to_json
              end
          end
        end
      end
    end
  end
end
