# frozen_string_literal: true

module Automator
  class Condition < ApplicationRecord
    include JsonAttr

    self.table_name = "automator_conditions"

    belongs_to :flow, class_name: "Automator::Flow", inverse_of: :conditions

    json_attr :config

    validates :kind, inclusion: { in: %w[structured custom] }

    default_scope { order(:position, :id) }
  end
end
