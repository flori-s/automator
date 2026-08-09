# frozen_string_literal: true

module Automator
  class FlowsController < ApplicationController
    before_action :set_flow, only: %i[show edit update destroy toggle simulate run_simulate]

    def index
      @flows = Flow.includes(:triggers, :actions).order(:name)
    end

    def show
      @jobs = @flow.jobs.order(created_at: :desc).limit(25)
      @executions = @flow.executions.order(created_at: :desc).limit(25)
    end

    def new
      @flow = Flow.new(enabled: true)
      @flow.triggers.build
      @flow.conditions.build
      @flow.cancel_conditions.build
      @flow.actions.build
    end


    def create
      @flow = Flow.new(flow_params)
      if @flow.save
        redirect_to @flow, notice: "Flow created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @flow.triggers.build if @flow.triggers.empty?
      @flow.conditions.build if @flow.conditions.empty?
      @flow.cancel_conditions.build if @flow.cancel_conditions.empty?
      @flow.actions.build if @flow.actions.empty?
    end


    def update
      if @flow.update(flow_params)
        redirect_to @flow, notice: "Flow updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @flow.destroy!
      redirect_to flows_path, notice: "Flow deleted."
    end

    def toggle
      @flow.update!(enabled: !@flow.enabled?)
      redirect_back fallback_location: flows_path, notice: "Flow #{@flow.enabled? ? 'enabled' : 'disabled'}."
    end

    def simulate
      @sample = {
        "event" => @flow.triggers.first&.event,
        "record_type" => @flow.triggers.first&.record_type,
        "record_id" => 1,
        "record" => {},
        "changes" => {}
      }
    end

    def run_simulate
      payload = parse_payload_param
      @result = Simulator.test(flow: @flow, payload: payload, event: params[:event].presence)
      render :simulate
    end

    private

    def set_flow
      @flow = Flow.find(params[:id])
    end

    def flow_params
      params.require(:flow).permit(
        :name, :key, :enabled, :dry_run, :description, :tenant,
        triggers_attributes: [:id, :event, :record_type, :change_filter, :position, :_destroy],
        conditions_attributes: [:id, :kind, :config, :predicate_key, :position, :_destroy],
        cancel_conditions_attributes: [:id, :kind, :config, :predicate_key, :position, :_destroy],
        actions_attributes: [:id, :kind, :builtin_name, :handler_key, :options, :delay_seconds, :position, :_destroy]
      ).tap do |permitted|
        %i[triggers_attributes conditions_attributes cancel_conditions_attributes actions_attributes].each do |key|
          next unless permitted[key]

          permitted[key].each_value do |attrs|
            %w[change_filter config options].each do |json_key|
              next unless attrs[json_key].is_a?(String) && attrs[json_key].present?

              attrs[json_key] = JSON.parse(attrs[json_key])
            rescue JSON::ParserError
              nil
            end
          end
        end
      end
    end

    def parse_payload_param
      raw = params[:payload].to_s
      return {} if raw.blank?

      JSON.parse(raw)
    rescue JSON::ParserError
      flash.now[:alert] = "Invalid JSON payload"
      {}
    end
  end
end
