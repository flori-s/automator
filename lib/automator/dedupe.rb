# frozen_string_literal: true

module Automator
  # Lifetime uniqueness across jobs that share a once_per_group + interpolated key.
  module Dedupe
    BLOCKING_STATUSES = %w[pending running succeeded].freeze

    module_function

    def key_for(flow:, payload:, tenant: nil)
      template = flow.once_per.to_s.strip
      return nil if template.blank?

      interpolated = Interpolator.call(template, payload).to_s.strip
      return nil if interpolated.blank?

      group = flow.once_per_group_key
      [tenant, group, interpolated].compact.join(":")
    end

    def blocking_job(dedupe_key, except_id: nil)
      return nil if dedupe_key.blank?

      scope = Job.where(dedupe_key: dedupe_key, status: BLOCKING_STATUSES)
      scope = scope.where.not(id: except_id) if except_id
      scope.order(:id).first
    end
  end
end
