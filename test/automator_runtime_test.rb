# frozen_string_literal: true

require "test_helper"

class AutomatorRuntimeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

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

  test "eq false matches nil boolean columns" do
    evaluator = Automator::ConditionEvaluator.new(
      payload: { "record" => { "prospect" => nil, "deceased" => nil } }
    )
    refute evaluator.evaluate(Automator::Condition.new(kind: "structured", config: { "attribute" => "prospect", "op" => "eq", "value" => true }))
    assert evaluator.evaluate(Automator::Condition.new(kind: "structured", config: { "attribute" => "prospect", "op" => "eq", "value" => false }))
    assert evaluator.evaluate(Automator::Condition.new(kind: "structured", config: { "attribute" => "deceased", "op" => "eq", "value" => false }))
  end

  test "neq false still matches nil" do
    evaluator = Automator::ConditionEvaluator.new(
      payload: { "record" => { "emailcommunication" => nil } }
    )
    assert evaluator.evaluate(Automator::Condition.new(kind: "structured", config: { "attribute" => "emailcommunication", "op" => "neq", "value" => false }))
  end

  test "present reads a live method missing from attributes" do
    person_class = Class.new do
      def self.find_by(id:)
        @records&.[](id.to_i)
      end

      def self.store(record)
        @records ||= {}
        @records[record.id] = record
      end

      attr_reader :id, :attributes

      def initialize(id)
        @id = id
        @attributes = { "id" => id, "prospect" => nil }
      end

      def email
        "pat@example.com"
      end
    end

    Object.send(:remove_const, :PersonStub) if Object.const_defined?(:PersonStub)
    Object.const_set(:PersonStub, person_class)
    PersonStub.store(PersonStub.new(3))

    evaluator = Automator::ConditionEvaluator.new(
      payload: { "record_type" => "PersonStub", "record_id" => 3, "record" => { "id" => 3, "prospect" => nil } }
    )
    assert evaluator.evaluate(Automator::Condition.new(kind: "structured", config: { "attribute" => "email", "op" => "present" }))
    assert_equal "pat@example.com", Automator::Interpolator.call("{{record.email}}", {
      "record_type" => "PersonStub", "record_id" => 3, "record" => { "id" => 3 }
    })
  ensure
    Object.send(:remove_const, :PersonStub) if Object.const_defined?(:PersonStub)
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

  test "once_per skips a second flow in the same group" do
    first = create_flow!(key: "review-a-#{SecureRandom.hex(4)}", once_per: "{{subject.id}}", once_per_group: "review_request")
    first.triggers.create!(event: "customer.created")
    first.actions.create!(kind: "builtin", builtin_name: "log", options: {})

    second = create_flow!(key: "review-b-#{SecureRandom.hex(4)}", once_per: "{{subject.id}}", once_per_group: "review_request")
    second.triggers.create!(event: "schade.updated")
    second.actions.create!(kind: "builtin", builtin_name: "log", options: {})

    payload = { "record_type" => "Customer", "record_id" => 7, "record" => { "id" => 7, "email" => "a@b.c" } }

    jobs = Automator.trigger("customer.created", payload)
    assert_equal 1, jobs.compact.size
    assert_equal "pending", jobs.first.status
    refute_nil jobs.first.dedupe_key

    Automator.trigger("schade.updated", payload)
    assert_equal 1, Automator::Job.count
    assert Automator::Execution.where(outcome: "skipped").any? { |e| e.detail["reason"] == "once_per" }
  end

  test "once_per allows a new job after the previous one was cancelled" do
    flow = create_flow!(once_per: "{{subject.id}}", once_per_group: "review_request")
    flow.triggers.create!(event: "customer.created")
    flow.actions.create!(kind: "builtin", builtin_name: "log", options: {})

    payload = { "record_id" => 8, "record" => { "id" => 8 } }
    first = Automator.trigger("customer.created", payload).compact.first
    first.cancel!("no longer eligible")

    travel 2.minutes do
      second_jobs = Automator.trigger("customer.created", payload)
      assert_equal 2, Automator::Job.count
      assert_equal "pending", second_jobs.compact.first.status
    end
  end

  test "sweep cancels when another job in the group already succeeded" do
    group = "review_request"
    winner = create_flow!(once_per: "{{subject.id}}", once_per_group: group)
    winner_action = winner.actions.create!(kind: "builtin", builtin_name: "log", options: {})
    Automator::Job.create!(
      flow: winner,
      action: winner_action,
      status: "succeeded",
      run_at: 1.hour.ago,
      payload: { "subject" => { "id" => 9 } },
      idempotency_key: "winner-1",
      dedupe_key: "#{group}:9"
    )

    loser = create_flow!(once_per: "{{subject.id}}", once_per_group: group)
    loser_action = loser.actions.create!(kind: "builtin", builtin_name: "log", options: {})
    pending = Automator::Job.create!(
      flow: loser,
      action: loser_action,
      status: "pending",
      run_at: 1.minute.ago,
      payload: { "subject" => { "id" => 9 }, "event" => "x" },
      idempotency_key: "loser-1",
      dedupe_key: "#{group}:9"
    )

    Automator.sweep
    assert_equal "cancelled", pending.reload.status
  end

  test "email_sender is used for builtin email actions" do
    seen = nil
    Automator.configure do |c|
      c.email_sender = ->(options, payload, _context) { seen = [options["to"], payload.dig("subject", "id")] }
    end

    flow = create_flow!
    action = flow.actions.create!(
      kind: "builtin",
      builtin_name: "email",
      options: { "to" => "{{subject.email}}", "template_tag" => "review_request" }
    )
    job = Automator::Job.create!(
      flow: flow,
      action: action,
      status: "pending",
      run_at: 1.minute.ago,
      payload: { "subject" => { "id" => 11, "email" => "pat@example.com" }, "event" => "x" },
      idempotency_key: "email-1"
    )

    Automator.sweep
    assert_equal "succeeded", job.reload.status
    assert_equal ["pat@example.com", 11], seen
  end

  test "subject association is copied onto the payload" do
    customer = Struct.new(:id, :email, :attributes).new(42, "pat@example.com", { "id" => 42, "email" => "pat@example.com" })
    claim_class = Class.new do
      def self.find_by(id:)
        @records&.[](id.to_i)
      end

      def self.store(record)
        @records ||= {}
        @records[record.id] = record
      end

      attr_reader :id, :customer, :attributes

      def initialize(id, customer)
        @id = id
        @customer = customer
        @attributes = { "id" => id }
      end
    end

    Object.send(:remove_const, :ClaimStub) if Object.const_defined?(:ClaimStub)
    Object.const_set(:ClaimStub, claim_class)
    claim = ClaimStub.new(5, customer)
    ClaimStub.store(claim)

    flow = create_flow!(subject_association: "customer", once_per: "{{subject.id}}")
    payload = Automator::Subject.enrich(
      { "record_type" => "ClaimStub", "record_id" => 5, "record" => { "id" => 5 } },
      flow: flow
    )

    assert_equal 42, payload["subject_id"]
    assert_equal "pat@example.com", payload.dig("subject", "email")
    assert_equal "42", Automator::Dedupe.key_for(flow: flow, payload: payload).split(":").last
  ensure
    Object.send(:remove_const, :ClaimStub) if Object.const_defined?(:ClaimStub)
  end

  test "seed from dsl stores once_per fields" do
    Automator.draw do
      flow :review, once_per: "{{subject.id}}", once_per_group: "review_request", subject_association: "customer" do
        trigger "schade.updated"
        action builtin: "log", message: "review"
      end
    end

    flow = Automator::Flow.find_by!(key: "review")
    assert_equal "{{subject.id}}", flow.once_per
    assert_equal "review_request", flow.once_per_group
    assert_equal "customer", flow.subject_association
  end

  private

  def create_flow!(**attrs)
    Automator::Flow.create!({ name: "Test", key: "test-#{SecureRandom.hex(4)}", enabled: true }.merge(attrs))
  end
end
