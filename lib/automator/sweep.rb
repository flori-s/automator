# frozen_string_literal: true

module Automator
  class Sweep
    def self.run(limit: Automator.config.sweep_batch_size)
      new(limit: limit).run
    end

    def initialize(limit:)
      @limit = limit
      @processed = []
    end

    def run
      PollLock.with_lock do
        Tenancy.each do |tenant|
          process_tenant(tenant)
        end
        @processed
      end
    end

    private

    def process_tenant(tenant)
      jobs = Job.pending_due.order(:run_at, :id).limit(@limit).to_a
      jobs.each { |job| process_job(job, tenant) }
    end

    def process_job(job, tenant)
      return unless job.claim!

      payload = Subject.enrich(Payload.refresh(job.payload), flow: job.flow)
      flow = job.flow
      evaluator = ConditionEvaluator.new(payload: payload, context: { flow: flow, job: job })

      unless evaluator.all_pass?(flow.conditions)
        job.cancel!("conditions failed on re-check")
        Execution.record!(flow: flow, job: job, event: payload["event"], outcome: "cancelled",
                          detail: { reason: "recheck_failed", breakdown: evaluator.breakdown(flow.conditions) },
                          tenant: tenant)
        @processed << job
        return
      end

      if evaluator.any_pass?(flow.cancel_conditions)
        job.cancel!("cancel condition matched")
        Execution.record!(flow: flow, job: job, event: payload["event"], outcome: "cancelled",
                          detail: { reason: "cancel_condition", breakdown: evaluator.breakdown(flow.cancel_conditions) },
                          tenant: tenant)
        @processed << job
        return
      end

      if (existing = Dedupe.blocking_job(job.dedupe_key, except_id: job.id))
        job.cancel!("once_per already #{existing.status}")
        Execution.record!(flow: flow, job: job, event: payload["event"], outcome: "cancelled",
                          detail: { reason: "once_per", dedupe_key: job.dedupe_key, existing_job_id: existing.id },
                          tenant: tenant)
        @processed << job
        return
      end

      Actions.run(job.action, payload: payload, job: job)
      job.succeed!
      Execution.record!(flow: flow, job: job, event: payload["event"], outcome: "executed",
                        detail: { action_id: job.action_id }, tenant: tenant)
      @processed << job
    rescue StandardError => e
      handle_failure(job, e, tenant)
      @processed << job if job
    end

    def handle_failure(job, error, tenant)
      Automator.logger.warn("[Automator] Job #{job&.id} failed: #{error.message}")
      return unless job

      max = Automator.config.max_attempts.to_i
      if job.attempts < max
        backoff = [2**job.attempts, 60].min.minutes
        job.requeue!(run_at: Time.current + backoff)
        job.update!(error: error.message)
      else
        job.fail!(error.message)
      end

      Execution.record!(flow: job.flow, job: job, event: job.payload["event"], outcome: "failed",
                        detail: { error: error.message, attempts: job.attempts }, tenant: tenant)
    end
  end
end
