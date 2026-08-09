# frozen_string_literal: true

module Automator
  class Configuration
    attr_accessor :webhook_url, :dashboard_path, :dashboard_base_url,
                  :tenants, :exclude_tenants, :tenant_switch,
                  :authenticate, :notifier, :mailer, :mailer_deliver,
                  :email_delivery, :poll_lock, :max_attempts, :sweep_batch_size,
                  :email_deliver_later

    def initialize
      @webhook_url = nil
      @notifier = nil
      @mailer = nil
      @mailer_deliver = :deliver_now
      @email_delivery = nil
      @email_deliver_later = false
      @dashboard_path = "/automator"
      @dashboard_base_url = nil
      @authenticate = nil
      @poll_lock = true
      @max_attempts = 5
      @sweep_batch_size = 50
      @tenants = nil
      @exclude_tenants = %w[public]
      @tenant_switch = nil
    end

    def dashboard_url(path = nil)
      base = dashboard_base_url.to_s.strip.sub(%r{/+\z}, "")
      root = dashboard_path.to_s.sub(%r{/+\z}, "")
      root = "/#{root}" unless root.start_with?("/")
      suffix = path.to_s
      suffix = "/#{suffix}" unless suffix.empty? || suffix.start_with?("/")
      full = "#{root}#{suffix}"
      base.empty? ? full : "#{base}#{full}"
    end

    def resolve_mailer(action = nil)
      override = action && action.options.is_a?(Hash) && action.options["mailer"]
      raw = override.presence || mailer
      case raw
      when nil then nil
      when String, Symbol then raw.to_s.constantize
      when Proc then raw.call(action)
      when Class then raw
      else
        raise ArgumentError, "Automator mailer must be a class name, Class, or Proc"
      end
    end

    def multi_tenant?
      !tenants.nil?
    end
  end
end
