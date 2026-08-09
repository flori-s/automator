# frozen_string_literal: true

module Automator
  module Actions
    module WebhookAction
      module_function

      def call(action, payload, job = nil)
        url = Interpolator.call(action.options["url"], payload) if action.options["url"]
        event = (action.options["event"].presence || Notifiers::FIRED).to_s
        notifier = Notifiers.build(Automator.config)
        result =
          if notifier.method(:deliver).arity == -1 || notifier.method(:deliver).parameters.any? { |t, n| n == :url }
            begin
              notifier.deliver(job || payload, event: event, url: url)
            rescue ArgumentError
              notifier.deliver(job || payload, event: event)
            end
          else
            notifier.deliver(job || payload, event: event)
          end

        accepted =
          case result
          when TrueClass, FalseClass then result
          when Hash then result[:accepted] != false && result["accepted"] != false
          else !result.nil?
          end

        raise "Webhook delivery rejected" unless accepted

        true
      end
    end
  end
end
