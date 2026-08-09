# frozen_string_literal: true

module Automator
  class Execution < ApplicationRecord
    include JsonAttr

    self.table_name = "automator_executions"

    OUTCOMES = %w[matched skipped enqueued executed cancelled failed dry_run test].freeze

    belongs_to :flow, class_name: "Automator::Flow", optional: true, inverse_of: :executions
    belongs_to :job, class_name: "Automator::Job", optional: true, inverse_of: :executions

    json_attr :detail

    validates :outcome, inclusion: { in: OUTCOMES }

    def self.record!(flow:, outcome:, event: nil, job: nil, detail: {}, tenant: nil)
      create!(
        flow: flow,
        job: job,
        event: event,
        outcome: outcome,
        detail: detail,
        tenant: tenant
      )
    end
  end
end
