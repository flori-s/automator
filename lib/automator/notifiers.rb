# frozen_string_literal: true

module Automator
  module Notifiers
    FIRED = "automation.fired"
    FAILED = "automation.failed"

    module_function

    def build(config = Automator.config)
      raw = config.notifier
      if raw.nil?
        Webhook.new
      else
        list = Array(raw).map { |entry| wrap(entry) }
        list.size == 1 ? list.first : Composite.new(list)
      end
    end

    def wrap(entry)
      case entry
      when Class
        entry.new
      else
        if entry.respond_to?(:deliver)
          entry
        elsif entry.respond_to?(:call)
          Callable.new(entry)
        else
          raise ArgumentError, "Automator notifier must respond to #deliver or #call (got #{entry.class})"
        end
      end
    end

    def payload(job_or_payload, event: FIRED)
      if job_or_payload.respond_to?(:payload) && job_or_payload.respond_to?(:flow)
        job = job_or_payload
        data = Payload.stringify(job.payload || {})
        {
          gem: "automator",
          event: event.to_s,
          flow_key: job.flow&.key,
          flow_id: job.flow_id,
          action_id: job.action_id,
          job_id: job.id,
          status: job.status,
          tenant: job.tenant || data["tenant"],
          payload: data,
          dashboard_url: Automator.config.dashboard_url("/jobs/#{job.id}"),
          run_at: job.run_at&.iso8601,
          finished_at: job.finished_at&.iso8601
        }
      else
        data = Payload.stringify(job_or_payload || {})
        {
          gem: "automator",
          event: event.to_s,
          tenant: data["tenant"],
          payload: data,
          dashboard_url: Automator.config.dashboard_url
        }
      end
    end
  end
end
