# frozen_string_literal: true

module Automator
  module Actions
    module_function

    def run(action, payload:, job: nil)
      Runner.new(action, payload: payload, job: job).run
    end

    class Runner
      def initialize(action, payload:, job: nil)
        @action = action
        @payload = Payload.stringify(payload || {})
        @job = job
      end

      def run
        case @action.kind.to_s
        when "callback"
          run_callback
        else
          run_builtin
        end
      end

      private

      def run_callback
        handler = Registry.handler(@action.handler_key)
        if handler.respond_to?(:call)
          handler.call(@payload, context)
        elsif handler.respond_to?(:perform)
          handler.perform(@payload, context)
        else
          raise ArgumentError, "Handler #{@action.handler_key} must respond to #call"
        end
      end

      def run_builtin
        name = @action.builtin_name.to_s
        case name
        when "webhook" then WebhookAction.call(@action, @payload, @job)
        when "email" then EmailAction.call(@action, @payload, @job)
        when "update_attributes" then UpdateAttributesAction.call(@action, @payload, @job)
        when "log" then LogAction.call(@action, @payload, @job)
        else
          raise ArgumentError, "Unknown Automator builtin: #{name}"
        end
      end

      def context
        { action: @action, job: @job, flow: @action.flow }
      end
    end
  end
end
