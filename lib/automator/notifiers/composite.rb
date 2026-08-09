# frozen_string_literal: true

module Automator
  module Notifiers
    class Composite
      def initialize(notifiers)
        @notifiers = notifiers
      end

      def deliver(job_or_payload, event:, url: nil)
        @notifiers.map do |notifier|
          if notifier.method(:deliver).parameters.any? { |_, name| name == :url }
            notifier.deliver(job_or_payload, event: event, url: url)
          else
            notifier.deliver(job_or_payload, event: event)
          end
        end.all?
      end
    end
  end
end
