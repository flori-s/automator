# frozen_string_literal: true

module Automator
  module Tenancy
    module_function

    def tenant_names
      cfg = Automator.config
      raw = cfg.tenants
      list =
        case raw
        when Proc then Array(raw.call)
        when nil then []
        else Array(raw)
        end

      excluded = Array(cfg.exclude_tenants).map(&:to_s)
      list.map(&:to_s).reject { |name| name.empty? || excluded.include?(name) }.uniq.sort
    rescue StandardError => e
      Automator.logger.warn("[Automator] Failed to resolve tenants: #{e.message}")
      []
    end

    def switch(name, &block)
      switcher = Automator.config.tenant_switch
      if switcher
        switcher.call(name, &block)
      elsif defined?(::Apartment::Tenant)
        ::Apartment::Tenant.switch(name, &block)
      else
        yield
      end
    end

    def multi_tenant?
      tenant_names.any?
    end

    def each
      return enum_for(:each) unless block_given?

      names = tenant_names
      if names.empty?
        yield nil
      else
        names.each do |name|
          switch(name) { yield name }
        end
      end
    end

    def current_name
      if defined?(::Apartment::Tenant) && ::Apartment::Tenant.respond_to?(:current)
        ::Apartment::Tenant.current
      end
    rescue StandardError
      nil
    end
  end
end
