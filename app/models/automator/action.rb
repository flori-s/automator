# frozen_string_literal: true

module Automator
  class Action < ApplicationRecord
    include JsonAttr

    self.table_name = "automator_actions"

    belongs_to :flow, class_name: "Automator::Flow", inverse_of: :actions
    has_many :jobs, class_name: "Automator::Job", dependent: :destroy, inverse_of: :action

    json_attr :options

    validates :kind, inclusion: { in: %w[builtin callback] }

    default_scope { order(:position, :id) }

    def delay
      delay_seconds.to_i.seconds
    end
  end
end
