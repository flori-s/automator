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

    accepts_nested_attributes_for :triggers, allow_destroy: true,
                                  reject_if: ->(attrs) { attrs["id"].blank? && attrs["event"].blank? }
    accepts_nested_attributes_for :conditions, allow_destroy: true,
                                  reject_if: :blank_nested_condition?
    accepts_nested_attributes_for :cancel_conditions, allow_destroy: true,
                                  reject_if: :blank_nested_condition?
    accepts_nested_attributes_for :actions, allow_destroy: true,
                                  reject_if: ->(attrs) {
                                    attrs["id"].blank? &&
                                      attrs["builtin_name"].blank? &&
                                      attrs["handler_key"].blank?
                                  }

    private

    def blank_nested_condition?(attrs)
      return false if attrs["id"].present?

      config = attrs["config"].to_s.strip
      attrs["predicate_key"].blank? && (config.blank? || config == "{}" || config == "{\n}")
    end
  end
end
