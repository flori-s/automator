# frozen_string_literal: true

module Automator
  module Payload
    module_function

    def build(record_or_hash, changes: nil, extra: {})
      base =
        case record_or_hash
        when Hash
          stringify(record_or_hash)
        when nil
          {}
        else
          from_record(record_or_hash)
        end

      base["changes"] = stringify(changes) if changes
      base.merge!(stringify(extra)) if extra && !extra.empty?
      base
    end

    def from_record(record)
      attrs =
        if record.respond_to?(:attributes)
          record.attributes
        else
          {}
        end

      payload = {
        "record_type" => record.class.name,
        "record_id" => (record.id if record.respond_to?(:id)),
        "record" => stringify(attrs)
      }

      if defined?(GlobalID) && record.respond_to?(:to_global_id)
        payload["gid"] = record.to_global_id.to_s
      end

      payload
    end

    def reload_record(payload)
      payload = stringify(payload || {})
      if payload["gid"].present? && defined?(GlobalID)
        return GlobalID::Locator.locate(payload["gid"])
      end

      type = payload["record_type"]
      id = payload["record_id"]
      return nil if type.blank? || id.blank?

      type.constantize.find_by(id: id)
    rescue StandardError
      nil
    end

    def refresh(payload)
      payload = stringify(payload || {})
      record = reload_record(payload)
      return payload unless record

      build(record, changes: payload["changes"]).merge(
        payload.slice("changes", "event", "tenant")
      )
    end

    def stringify(value)
      case value
      when Hash
        value.each_with_object({}) do |(k, v), acc|
          acc[k.to_s] =
            case v
            when Time, DateTime, ActiveSupport::TimeWithZone then v.iso8601
            when Date then v.iso8601
            when Hash then stringify(v)
            when Array then v.map { |item| item.is_a?(Hash) ? stringify(item) : item }
            else v
            end
        end
      else
        value
      end
    end
  end
end
