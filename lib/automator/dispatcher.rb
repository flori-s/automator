# frozen_string_literal: true

module Automator
  class Dispatcher
    def self.trigger(event, record_or_hash = nil, changes: nil, tenant: nil, **extra)
      new(event, record_or_hash, changes: changes, tenant: tenant, extra: extra).call
    end

    def initialize(event, record_or_hash, changes: nil, tenant: nil, extra: {})
      @event = event.to_s
      @record_or_hash = record_or_hash
      @changes = changes
      @tenant = tenant
      @extra = extra
    end

    def call
      payload = Payload.build(@record_or_hash, changes: @changes, extra: @extra.merge("event" => @event))
      payload["tenant"] ||= @tenant if @tenant

      flows = matching_flows
      results = []

      flows.find_each do |flow|
        results.concat(process_flow(flow, payload))
      end

      results
    end

    private

    def matching_flows
      scope = Flow.enabled.includes(:triggers, :conditions, :actions)
      scope = scope.for_tenant(@tenant) if @tenant
      scope.joins(:triggers).where(automator_triggers: { event: @event }).distinct
    end

    def process_flow(flow, payload)
      trigger = flow.triggers.find { |t| t.event == @event }
      return [] unless trigger

      if trigger.record_type.present? && payload["record_type"].present?
        return [] unless trigger.record_type == payload["record_type"]
      end

      unless trigger.matches_changes?(payload["changes"])
        Execution.record!(flow: flow, event: @event, outcome: "skipped",
                          detail: { reason: "change_filter" }, tenant: @tenant)
        return []
      end

      evaluator = ConditionEvaluator.new(payload: payload, context: { flow: flow, event: @event })
      unless evaluator.all_pass?(flow.conditions)
        Execution.record!(flow: flow, event: @event, outcome: "skipped",
                          detail: { reason: "conditions", breakdown: evaluator.breakdown(flow.conditions) },
                          tenant: @tenant)
        return []
      end

      Execution.record!(flow: flow, event: @event, outcome: "matched",
                        detail: { conditions: evaluator.breakdown(flow.conditions) }, tenant: @tenant)

      flow.actions.map do |action|
        Enqueuer.enqueue(flow: flow, action: action, payload: payload, event: @event, tenant: @tenant)
      end
    end
  end
end
