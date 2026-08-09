# frozen_string_literal: true

module Automator
  module Model
    extend ActiveSupport::Concern

    class_methods do
      def automator_events(on: %i[create update], as: nil)
        events = Array(on).map(&:to_sym)
        prefix = as || name.underscore.tr("/", ".")

        if events.include?(:create)
          after_create_commit do
            Automator.trigger("#{prefix}.created", self)
          end
        end

        if events.include?(:update)
          after_update_commit do
            Automator.trigger("#{prefix}.updated", self, changes: previous_changes)
          end
        end

        if events.include?(:destroy)
          after_destroy_commit do
            Automator.trigger("#{prefix}.destroyed", {
              "record_type" => self.class.name,
              "record_id" => id,
              "record" => attributes
            })
          end
        end
      end
    end
  end
end
