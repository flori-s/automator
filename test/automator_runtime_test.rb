# frozen_string_literal: true

require "test_helper"

class AutomatorRuntimeTest < ActiveSupport::TestCase
  setup do
    Automator.reset_config!
    Automator::Registry.clear!
    Automator::Job.delete_all
    Automator::Execution.delete_all
    Automator::Action.delete_all
    Automator::Condition.delete_all
    Automator::CancelCondition.delete_all
    Automator::Trigger.delete_all
    Automator::Flow.delete_all
  end

  test "trigger enqueues job when conditions pass" do
    flow = create_flow!
    flow.triggers.create!(event: "customer.updated")
    flow.conditions.create!(kind: "structured", config: { "attribute" => "amount", "op" => "gt", "value" => 100 })
    flow.actions.create!(kind: "builtin", builtin_name: "log", options: { "message" => "hi" })

    jobs = Automator.trigger("customer.updated", {
      "record_type" => "Customer",
      "record_id" => 1,
      "record" => { "amount" => 250 }
    })

    assert_equal 1, jobs.compact.size
    assert_equal "pending", jobs.first.status
    assert Automator::Execution.exists?(outcome: "matched")
    assert Automator::Execution.exists?(outcome: "enqueued")
  end

  test "change filter skips when attribute not changed" do
    flow = create_flow!
    flow.triggers.create!(event: "customer.updated", change_filter: { "changed" => ["status"] })
    flow.actions.create!(kind: "builtin", builtin_name: "log", options: {})

    Automator.trigger("customer.updated", { "record" => { "status" => "open" } }, changes: { "name" => %w[a b] })

    assert_equal 0, Automator::Job.count
    assert Automator::Execution.exists?(outcome: "skipped")
  end

  test "dry_run does not enqueue jobs" do
    flow = create_flow!(dry_run: true)
    flow.triggers.create!(event: "customer.updated")
    flow.actions.create!(kind: "builtin", builtin_name: "log", options: {})

    Automator.trigger("customer.updated", { "record" => {} })

    assert_equal 0, Automator::Job.count
    assert Automator::Execution.exists?(outcome: "dry_run")
  end

  test "sweep rechecks conditions and cancels" do
    flow = create_flow!
    flow.triggers.create!(event: "customer.updated")
    flow.conditions.create!(kind: "structured", config: { "attribute" => "amount", "op" => "gt", "value" => 100 })
    action = flow.actions.create!(kind: "builtin", builtin_name: "log", options: { "message" => "x" })

    job = Automator::Job.create!(
      flow: flow,
      action: action,
      status: "pending",
      run_at: 1.minute.ago,
      payload: { "record" => { "amount" => 10 }, "event" => "customer.updated" },
      idempotency_key: "test-1"
    )

    Automator.sweep
    assert_equal "cancelled", job.reload.status
  end

  test "sweep cancels when cancel condition matches" do
    flow = create_flow!
    flow.triggers.create!(event: "customer.updated")
    flow.cancel_conditions.create!(kind: "structured", config: { "attribute" => "status", "op" => "eq", "value" => "cancelled" })
    action = flow.actions.create!(kind: "builtin", builtin_name: "log", options: {})

    job = Automator::Job.create!(
      flow: flow,
      action: action,
      status: "pending",
      run_at: 1.minute.ago,
      payload: { "record" => { "status" => "cancelled" }, "event" => "customer.updated" },
      idempotency_key: "test-2"
    )

    Automator.sweep
    assert_equal "cancelled", job.reload.status
  end

  test "sweep executes log action" do
    flow = create_flow!
    action = flow.actions.create!(kind: "builtin", builtin_name: "log", options: { "message" => "done" })
    job = Automator::Job.create!(
      flow: flow,
      action: action,
      status: "pending",
      run_at: 1.minute.ago,
      payload: { "record" => {}, "event" => "x" },
      idempotency_key: "test-3"
    )

    Automator.sweep
    assert_equal "succeeded", job.reload.status
    assert Automator::Execution.exists?(outcome: "executed")
  end

  test "custom notifier callable is used" do
    delivered = []
    Automator.configure do |c|
      c.notifier = ->(job, event:) { delivered << [job.id, event]; true }
    end

    flow = create_flow!
    action = flow.actions.create!(kind: "builtin", builtin_name: "webhook", options: {})
    job = Automator::Job.create!(
      flow: flow,
      action: action,
      status: "pending",
      run_at: 1.minute.ago,
      payload: { "record" => {}, "event" => "x" },
      idempotency_key: "test-4"
    )

    Automator.sweep
    assert_equal "succeeded", job.reload.status
    assert_equal [[job.id, "automation.fired"]], delivered
  end

  test "simulator writes test execution" do
    flow = create_flow!
    flow.triggers.create!(event: "customer.updated")
    flow.conditions.create!(kind: "structured", config: { "attribute" => "amount", "op" => "gt", "value" => 1 })
    flow.actions.create!(kind: "builtin", builtin_name: "log", options: {})

    result = Automator::Simulator.test(
      flow: flow,
      payload: { "event" => "customer.updated", "record" => { "amount" => 5 } }
    )

    assert result[:would_match]
    assert Automator::Execution.exists?(outcome: "test")
  end

  test "days_before condition" do
    evaluator = Automator::ConditionEvaluator.new(
      payload: { "record" => { "due_on" => (Date.current + 7).iso8601 } }
    )
    condition = Automator::Condition.new(
      kind: "structured",
      config: { "attribute" => "due_on", "op" => "days_before", "value" => 7 }
    )
    assert evaluator.evaluate(condition)
  end

  test "tenancy each yields once when not configured" do
    names = []
    Automator::Tenancy.each { |name| names << name }
    assert_equal [nil], names
  end

  test "tenancy fans out when configured" do
    Automator.configure do |c|
      c.tenants = %w[acme beta]
      c.exclude_tenants = []
      c.tenant_switch = ->(_name, &block) { block.call }
    end

    names = []
    Automator::Tenancy.each { |name| names << name }
    assert_equal %w[acme beta], names
  end

  test "seed from dsl" do
    Automator.draw do
      flow :welcome do
        trigger "customer.created"
        condition attribute: "vip", op: "eq", value: true
        action builtin: "log", message: "welcome"
      end
    end

    flow = Automator::Flow.find_by!(key: "welcome")
    assert_equal 1, flow.triggers.count
    assert_equal 1, flow.conditions.count
    assert_equal 1, flow.actions.count
  end

  test "callback handler runs" do
    seen = nil
    Automator.register_handler(:capture) { |payload, _ctx| seen = payload["record"]["id"] }

    flow = create_flow!
    action = flow.actions.create!(kind: "callback", handler_key: "capture")
    job = Automator::Job.create!(
      flow: flow,
      action: action,
      status: "pending",
      run_at: 1.minute.ago,
      payload: { "record" => { "id" => 42 }, "event" => "x" },
      idempotency_key: "test-5"
    )

    Automator.sweep
    assert_equal 42, seen
    assert_equal "succeeded", job.reload.status
  end

  private

  def create_flow!(**attrs)
    Automator::Flow.create!({ name: "Test", key: "test-#{SecureRandom.hex(4)}", enabled: true }.merge(attrs))
  end
end
