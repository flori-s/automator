# frozen_string_literal: true

module Automator
  # Reads values from a reloaded ActiveRecord object when the serialized
  # payload only has table columns (e.g. Customer#email via emailaddresses).
  module LiveLookup
    UNSAFE = %w[
      destroy delete save update create
      destroy! delete! save! update! create!
      update_column update_columns update_attribute
      delete_all destroy_all mark_for_destruction
      really_destroy! restore restore!
    ].freeze

    module_function

    def read(payload, path, flow: nil)
      payload = Payload.stringify(payload || {})
      parts = path.to_s.split(".")
      return nil if parts.empty?

      root, rest = root_and_rest(payload, parts, flow: flow)
      return nil unless root

      rest.reduce(root) do |object, name|
        break nil unless object

        read_message(object, name)
      end
    end

    def root_and_rest(payload, parts, flow: nil)
      case parts.first
      when "subject"
        [subject_record(payload, flow: flow), parts[1..]]
      when "record"
        [Payload.reload_record(payload), parts[1..]]
      else
        [Payload.reload_record(payload), parts]
      end
    end

    def subject_record(payload, flow: nil)
      type = payload["subject_type"]
      id = payload["subject_id"]
      if type.present? && id.present?
        located = locate(type, id)
        return located if located
      end

      Subject.resolve(Payload.reload_record(payload), flow)
    end

    def locate(type, id)
      type.constantize.find_by(id: id)
    rescue StandardError
      nil
    end

    def read_message(object, name)
      name = name.to_s
      return nil if name.empty? || UNSAFE.include?(name) || name.end_with?("!")

      if object.respond_to?(name)
        method = object.method(name)
        return object.public_send(name) if method.arity.zero?
      end

      if object.respond_to?(:read_attribute) && object.respond_to?(:has_attribute?) && object.has_attribute?(name)
        object.read_attribute(name)
      elsif object.respond_to?(:[])
        object[name]
      end
    rescue StandardError
      nil
    end
  end
end
