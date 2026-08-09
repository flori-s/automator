# frozen_string_literal: true

module Automator
  class CancelCondition < ApplicationRecord
    include JsonAttr

    self.table_name = "automator_cancel_conditions"

    belongs_to :flow, class_name: "Automator::Flow", inverse_of: :cancel_conditions

    json_attr :config

    validates :kind, inclusion: { in: %w[structured custom] }

    default_scope { order(:position, :id) }
  end
end
