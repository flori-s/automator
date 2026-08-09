# Automator

Rails engine gem for **event-driven automation rules** — triggers, conditions, cancel conditions, actions, a DB-backed job sweep (so you don’t need per-rule Delayed Job / Sidekiq scheduling), pluggable webhooks, host mailers, and an ops dashboard.

Requires **Ruby >= 3.0** and **Rails >= 6.0**.

## Install

```ruby
# Gemfile
gem "automator", github: "flori-s/automator"
```

```bash
bundle install
rails generate automator:install
rails automator:install:migrations
rails db:migrate
```

Mount (also added by the installer):

```ruby
# config/routes.rb
mount Automator::Engine => "/automator"
```

Schedule one cron entry:

```cron
* * * * * cd /app && bin/rails automator:sweep
```

## Configure

`config/initializers/automator.rb`:

```ruby
Automator.configure do |c|
  c.webhook_url = ENV["AUTOMATOR_WEBHOOK_URL"]
  c.dashboard_base_url = ENV["AUTOMATOR_DASHBOARD_BASE_URL"]

  # Option A: host mailer class that implements #notify / #rule_notice, etc.
  # c.mailer = "AutomationMailer"

  # Option B: custom/host mailer API (any signature) via delivery callable
  # c.email_delivery = ->(message) {
  #   # message: { to:, subject:, vars:, record:, payload:, action:, ... }
  #   MyAppMailer.deliver_from_automator(message)
  # }

  # Or use your host webhook service (anomonitor-style):
  # c.notifier = ->(job, event:, url: nil) {
  #   Webhook::Broadcast.new(
  #     urls: [{ url: url.presence || ENV.fetch("AUTOMATOR_DEST_URL"), headers: [
  #       { name: "Content-Type", value: "application/json" }
  #     ] }],
  #     message: Automator::Notifiers.payload(job, event: event)
  #   ).call
  # }

  # Multi-tenant (Apartment)
  # c.tenants = -> { CustomerTenant.pluck(:name) }
  # c.exclude_tenants = %w[public]
  # c.tenant_switch = ->(name, &block) { Apartment::Tenant.switch(name, &block) }

  c.authenticate = -> {
    authenticate_or_request_with_http_basic("Automator") do |user, pass|
      ActiveSupport::SecurityUtils.secure_compare(user, ENV.fetch("AUTOMATOR_USER")) &&
        ActiveSupport::SecurityUtils.secure_compare(pass, ENV.fetch("AUTOMATOR_PASSWORD"))
    end
  }
end

Automator.register_predicate(:high_value) { |payload, _ctx|
  payload.dig("record", "amount").to_f > 1_000
}

Automator.register_handler(:notify_sales) { |payload, _ctx|
  # custom side effect
}
```

## Emit events

```ruby
Automator.trigger("customer.updated", customer, changes: customer.previous_changes)

class Customer < ApplicationRecord
  include Automator::Model
  automator_events on: [:create, :update] # customer.created / customer.updated
end
```

## Seed from YAML or DSL

```ruby
# config/automations.yml or rake automator:seed
Automator.draw do
  flow :remind_before_expiry do
    trigger "policy.updated", change_filter: { "changed" => ["expiration_date"] }
    condition attribute: "expiration_date", op: "days_before", value: 7
    cancel_condition attribute: "status", op: "eq", value: "cancelled"
    action builtin: "email", action: "rule_notice", to: "{{record.email}}",
           subject: "Expires soon", template: "rule_notice"
  end
end
```

## Dashboard

Open `/automator` for overview, flows CRUD (structured forms), job queue, executions audit, dry-run/test, and a cross-tenant overview when multi-tenancy is configured.

## Development

```bash
bundle install
bundle exec rake test
```

## License

MIT
