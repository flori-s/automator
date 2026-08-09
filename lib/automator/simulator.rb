# frozen_string_literal: true

module Automator
  class Simulator
    def self.test(flow:, payload:, event: nil)
      new(flow: flow, payload: payload, event: event).test
    end

    def initialize(flow:, payload:, event: nil)
      @flow = flow
      @payload = Payload.stringify(payload || {})
      @event = (event || @payload["event"] || @flow.triggers.first&.event).to_s
    end

    def test
      trigger = @flow.triggers.find { |t| t.event == @event }
      change_ok = trigger ? trigger.matches_changes?(@payload["changes"]) : false
      evaluator = ConditionEvaluator.new(payload: @payload, context: { flow: @flow, event: @event })
      conditions = evaluator.breakdown(@flow.conditions)
      cancel = evaluator.breakdown(@flow.cancel_conditions)
      conditions_pass = conditions.all? { |c| c[:pass] }
      would_match = trigger && change_ok && conditions_pass

      result = {
        event: @event,
        trigger_matched: !!trigger,
        change_filter_pass: change_ok,
        conditions: conditions,
        cancel_conditions: cancel,
        would_match: would_match,
        would_enqueue: would_match && !@flow.dry_run?,
        dry_run: @flow.dry_run?,
        actions: @flow.actions.map { |a|
          {
            id: a.id,
            kind: a.kind,
            builtin_name: a.builtin_name,
            handler_key: a.handler_key,
            delay_seconds: a.delay_seconds,
            options: a.options
          }
        }
      }

      Execution.record!(
        flow: @flow,
        event: @event,
        outcome: "test",
        detail: result,
        tenant: @flow.tenant
      )

      result
    end
  end
end
