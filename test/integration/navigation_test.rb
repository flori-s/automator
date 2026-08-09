# frozen_string_literal: true

require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  include Automator::Engine.routes.url_helpers

  setup do
    Automator::Job.delete_all
    Automator::Execution.delete_all
    Automator::Action.delete_all
    Automator::Condition.delete_all
    Automator::CancelCondition.delete_all
    Automator::Trigger.delete_all
    Automator::Flow.delete_all

    @flow = Automator::Flow.create!(name: "Demo", key: "demo", enabled: true)
    @flow.triggers.create!(event: "customer.updated")
    @flow.actions.create!(kind: "builtin", builtin_name: "log", options: { "message" => "x" })
  end

  test "dashboard" do
    get root_path
    assert_response :success
    assert_match(/Overview/, response.body)
  end

  test "flows index and show" do
    get flows_path
    assert_response :success
    get flow_path(@flow)
    assert_response :success
  end

  test "jobs index" do
    get jobs_path
    assert_response :success
  end

  test "metrics json" do
    get metrics_path
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "automator", body["gem"]
  end
end
