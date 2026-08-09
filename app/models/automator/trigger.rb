# frozen_string_literal: true

module Automator
  class Trigger < ApplicationRecord
    include JsonAttr

    self.table_name = "automator_triggers"

    belongs_to :flow, class_name: "Automator::Flow", inverse_of: :triggers

    json_attr :change_filter

    validates :event, presence: true

    default_scope { order(:position, :id) }

    def matches_changes?(changes)
      filter = change_filter
      return true if filter.blank?

      changes = (changes || {}).transform_keys(&:to_s)

      if filter["changed"].is_a?(Array)
        return filter["changed"].any? { |attr| changes.key?(attr.to_s) }
      end

      if filter["attribute"].present?
        attr = filter["attribute"].to_s
        return false unless changes.key?(attr)

        from_to = changes[attr]
        from_val = from_to.is_a?(Array) ? from_to[0] : nil
        to_val = from_to.is_a?(Array) ? from_to[1] : from_to

        return false if filter.key?("from") && filter["from"].to_s != from_val.to_s
        return false if filter.key?("to") && filter["to"].to_s != to_val.to_s

        return true
      end

      true
    end
  end
end
