# frozen_string_literal: true

module Automator
  class ExecutionsController < ApplicationController
    def index
      @executions = Execution.includes(:flow, :job).order(created_at: :desc)
      @executions = @executions.where(outcome: params[:outcome]) if params[:outcome].present?
      @executions = @executions.where(flow_id: params[:flow_id]) if params[:flow_id].present?
      @executions = @executions.limit(200)
      @flows = Flow.order(:name)
    end

    def show
      @execution = Execution.find(params[:id])
    end
  end
end
