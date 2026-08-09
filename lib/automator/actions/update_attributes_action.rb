# frozen_string_literal: true

module Automator
  module Actions
    module UpdateAttributesAction
      module_function

      def call(action, payload, _job = nil)
        record = Payload.reload_record(payload)
        raise "Record not found for update_attributes" unless record

        attrs = Interpolator.call(action.options["attributes"] || {}, payload)
        record.update!(attrs)
        true
      end
    end
  end
end
