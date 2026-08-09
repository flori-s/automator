# frozen_string_literal: true

module Automator
  class JobsController < ApplicationController
    before_action :set_job, only: %i[show retry cancel]

    def index
      @jobs = Job.includes(:flow, :action).order(created_at: :desc)
      @jobs = @jobs.where(status: params[:status]) if params[:status].present?
      @jobs = @jobs.where(flow_id: params[:flow_id]) if params[:flow_id].present?
      if params[:q].present?
        q = "%#{params[:q]}%"
        @jobs = @jobs.joins(:flow).where("automator_flows.name LIKE ? OR automator_jobs.error LIKE ? OR automator_jobs.idempotency_key LIKE ?", q, q, q)
      end
      @jobs = @jobs.limit(200)
      @flows = Flow.order(:name)
    end

    def show; end

    def retry
      @job.requeue!(run_at: Time.current)
      redirect_to job_path(@job), notice: "Job requeued."
    end

    def cancel
      @job.cancel!("cancelled from dashboard")
      redirect_to job_path(@job), notice: "Job cancelled."
    end

    private

    def set_job
      @job = Job.find(params[:id])
    end
  end
end
