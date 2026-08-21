# frozen_string_literal: true

Automator.configure do |c|
  # Built-in webhook destination (optional if you set c.notifier)
  # c.webhook_url = ENV["AUTOMATOR_WEBHOOK_URL"]
  # c.dashboard_base_url = ENV["AUTOMATOR_DASHBOARD_BASE_URL"]

  # Host webhook service (anomonitor-style), e.g.:
  # c.notifier = ->(job, event:, url: nil) {
  #   Webhook::Broadcast.new(
  #     urls: [{ url: url.presence || ENV.fetch("AUTOMATOR_DEST_URL"), headers: [
  #       { name: "Content-Type", value: "application/json" }
  #     ] }],
  #     message: Automator::Notifiers.payload(job, event: event)
  #   ).call
  # }

  # Host mailer for builtin email actions
  # c.mailer = "AutomationMailer"
  # c.email_deliver_later = false
  #
  # Or a host adapter (e.g. DocumentTemplate + DocumentMailer):
  # c.email_sender = ->(options, payload, context) {
  #   YourMailAdapter.call(options: options, payload: payload, context: context)
  # }

  # Multi-tenant (Apartment)
  # c.tenants = -> { CustomerTenant.pluck(:name) }
  # c.exclude_tenants = %w[public]
  # c.tenant_switch = ->(name, &block) { Apartment::Tenant.switch(name, &block) }

  # Protect the dashboard
  # c.authenticate = -> {
  #   authenticate_or_request_with_http_basic("Automator") do |user, pass|
  #     ActiveSupport::SecurityUtils.secure_compare(user, ENV.fetch("AUTOMATOR_USER")) &&
  #       ActiveSupport::SecurityUtils.secure_compare(pass, ENV.fetch("AUTOMATOR_PASSWORD"))
  #   end
  # }

  c.poll_lock = true
  c.max_attempts = 5
  c.sweep_batch_size = 50
end

# Automator.register_predicate(:high_value) { |payload, _ctx| payload.dig("record", "amount").to_f > 1000 }
# Automator.register_handler(:notify_sales) { |payload, _ctx| Rails.logger.info(payload) }
