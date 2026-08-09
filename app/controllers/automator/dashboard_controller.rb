# frozen_string_literal: true

module Automator
  class DashboardController < ApplicationController
    def show
      @enabled_flows = Flow.enabled.count
      @total_flows = Flow.count
      @pending_jobs = Job.pending.count
      @failed_jobs = Job.failed.count
      @running_jobs = Job.where(status: "running").count
      @recent_failures = Job.failed.order(finished_at: :desc).limit(10)
      @upcoming_jobs = Job.pending.order(:run_at).limit(10)
      @recent_executions = Execution.order(created_at: :desc).limit(15)
      @last_sweep_execution = Execution.where(outcome: %w[executed failed cancelled]).order(created_at: :desc).first
      @multi_tenant = Tenancy.multi_tenant?
    end

    def sweep
      results = Automator.sweep
      redirect_to root_path, notice: "Sweep processed #{Array(results).size} job(s)."
    end

    def metrics
      render json: {
        gem: "automator",
        flows: { total: Flow.count, enabled: Flow.enabled.count },
        jobs: {
          pending: Job.pending.count,
          running: Job.where(status: "running").count,
          failed: Job.failed.count,
          succeeded: Job.where(status: "succeeded").count
        },
        multi_tenant: Tenancy.multi_tenant?
      }
    end
  end
end
