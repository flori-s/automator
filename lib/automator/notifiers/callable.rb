# frozen_string_literal: true

module Automator
  module Notifiers
    class Callable
      def initialize(callable)
        @callable = callable
      end

      def deliver(job_or_payload, event:, url: nil)
        if @callable.parameters.any? { |_, name| name == :url }
          @callable.call(job_or_payload, event: event, url: url)
        else
          @callable.call(job_or_payload, event: event)
        end
      end
    end
  end
end
