# frozen_string_literal: true

module Automator
  class TenantsController < ApplicationController
    def index
      unless Tenancy.multi_tenant?
        redirect_to root_path, alert: "Multi-tenancy is not configured."
        return
      end

      @rows = []
      Tenancy.each do |tenant|
        @rows << {
          tenant: tenant,
          flows_enabled: Flow.enabled.count,
          flows_total: Flow.count,
          pending: Job.pending.count,
          failed: Job.failed.count
        }
      end
    end
  end
end
