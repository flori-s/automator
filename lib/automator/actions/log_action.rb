# frozen_string_literal: true

module Automator
  module Actions
    module LogAction
      module_function

      def call(action, payload, _job = nil)
        message = Interpolator.call(action.options["message"] || "Automator action", payload)
        Automator.logger.info("[Automator] #{message} payload=#{payload.inspect}")
        true
      end
    end
  end
end
