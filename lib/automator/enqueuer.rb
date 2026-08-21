# frozen_string_literal: true

module Automator
  class Enqueuer
    def self.enqueue(flow:, action:, payload:, event:, tenant: nil)
      new(flow: flow, action: action, payload: payload, event: event, tenant: tenant).enqueue
    end

    def initialize(flow:, action:, payload:, event:, tenant: nil)
      @flow = flow
      @action = action
      @payload = Payload.stringify(payload || {})
      @event = event
      @tenant = tenant
    end

    def enqueue
      if @flow.dry_run?
        Execution.record!(
          flow: @flow,
          event: @event,
          outcome: "dry_run",
          detail: { action_id: @action.id, payload: @payload },
          tenant: @tenant
        )
        return nil
      end

      payload = Subject.enrich(@payload, flow: @flow)
      dedupe_key = Dedupe.key_for(flow: @flow, payload: payload, tenant: @tenant)
      if (existing = Dedupe.blocking_job(dedupe_key))
        Execution.record!(
          flow: @flow, job: existing, event: @event, outcome: "skipped",
          detail: { reason: "once_per", dedupe_key: dedupe_key, existing_job_id: existing.id },
          tenant: @tenant
        )
        return existing
      end

      run_at = Time.current + @action.delay_seconds.to_i
      key = idempotency_key(run_at)

      job = Job.find_or_initialize_by(idempotency_key: key)
      if job.persisted?
        Execution.record!(flow: @flow, job: job, event: @event, outcome: "skipped",
                          detail: { reason: "duplicate", idempotency_key: key }, tenant: @tenant)
        return job
      end

      job.assign_attributes(
        flow: @flow,
        action: @action,
        status: "pending",
        run_at: run_at,
        payload: payload.merge("event" => @event),
        tenant: @tenant,
        attempts: 0,
        dedupe_key: dedupe_key
      )
      job.save!

      Execution.record!(flow: @flow, job: job, event: @event, outcome: "enqueued",
                        detail: { action_id: @action.id, run_at: run_at.iso8601, dedupe_key: dedupe_key },
                        tenant: @tenant)
      job
    end

    private

    def idempotency_key(run_at)
      parts = [
        @tenant,
        @flow.id,
        @action.id,
        @payload["record_type"],
        @payload["record_id"],
        @event,
        run_at.utc.strftime("%Y%m%d%H%M")
      ]
      Digest::SHA256.hexdigest(parts.compact.join(":"))
    end
  end
end
