require "test_helper"

class AutomatorTest < ActiveSupport::TestCase
  test "version" do
    assert_not_nil Automator::VERSION
  end

  test "configure yields configuration" do
    Automator.configure { |c| c.webhook_url = "https://example.com/hook" }
    assert_equal "https://example.com/hook", Automator.config.webhook_url
  end
end
