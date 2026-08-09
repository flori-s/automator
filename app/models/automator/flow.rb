# frozen_string_literal: true

module Automator
  class Flow < ApplicationRecord
    self.table_name = "automator_flows"

    has_many :triggers, class_name: "Automator::Trigger", dependent: :destroy, inverse_of: :flow
    has_many :conditions, class_name: "Automator::Condition", dependent: :destroy, inverse_of: :flow
    has_many :cancel_conditions, class_name: "Automator::CancelCondition", dependent: :destroy, inverse_of: :flow
    has_many :actions, class_name: "Automator::Action", dependent: :destroy, inverse_of: :flow
    has_many :jobs, class_name: "Automator::Job", dependent: :destroy, inverse_of: :flow
    has_many :executions, class_name: "Automator::Execution", dependent: :nullify, inverse_of: :flow

    validates :name, :key, presence: true
    validates :key, uniqueness: true

    scope :enabled, -> { where(enabled: true) }
    scope :for_tenant, ->(tenant) { tenant.present? ? where(tenant: [nil, tenant]) : all }

    accepts_nested_attributes_for :triggers, :conditions, :cancel_conditions, :actions, allow_destroy: true
  end
end
