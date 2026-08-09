# frozen_string_literal: true

module Automator
  class Job < ApplicationRecord
    include JsonAttr

    self.table_name = "automator_jobs"

    STATUSES = %w[pending running succeeded failed cancelled dry_run].freeze

    belongs_to :flow, class_name: "Automator::Flow", inverse_of: :jobs
    belongs_to :action, class_name: "Automator::Action", inverse_of: :jobs
    has_many :executions, class_name: "Automator::Execution", dependent: :nullify, inverse_of: :job

    json_attr :payload

    validates :status, inclusion: { in: STATUSES }
    validates :run_at, presence: true

    scope :pending_due, -> { where(status: "pending").where("run_at <= ?", Time.current) }
    scope :failed, -> { where(status: "failed") }
    scope :pending, -> { where(status: "pending") }

    def claim!
      updated = self.class.where(id: id, status: "pending").update_all(
        status: "running",
        started_at: Time.current,
        attempts: attempts + 1,
        updated_at: Time.current
      )
      return false if updated.zero?

      reload
      true
    end

    def succeed!
      update!(status: "succeeded", finished_at: Time.current, error: nil)
    end

    def fail!(message)
      update!(status: "failed", finished_at: Time.current, error: message.to_s)
    end

    def cancel!(message = nil)
      update!(status: "cancelled", finished_at: Time.current, error: message.to_s.presence)
    end

    def requeue!(run_at: Time.current)
      update!(status: "pending", run_at: run_at, error: nil, started_at: nil, finished_at: nil)
    end
  end
end
