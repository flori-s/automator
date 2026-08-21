# frozen_string_literal: true

module Automator
  # Resolves the record an action should act on (often a related customer)
  # and copies it onto the payload as `subject` / `subject_id` / `subject_type`.
  module Subject
    module_function

    def enrich(payload, flow:)
      payload = Payload.stringify(payload || {})
      record = Payload.reload_record(payload)
      subject_record = resolve(record, flow)

      if subject_record
        payload["subject_type"] = subject_record.class.name
        payload["subject_id"] = subject_record.id if subject_record.respond_to?(:id)
        payload["subject"] = attributes_for(subject_record)
      else
        payload["subject"] ||= payload["record"]
        payload["subject_type"] ||= payload["record_type"]
        payload["subject_id"] ||= payload["record_id"] || payload.dig("record", "id")
      end

      payload
    end

    def resolve(record, flow)
      return nil unless record

      association = flow&.subject_association.to_s.strip
      if association.present?
        record.public_send(association)
      else
        record
      end
    rescue StandardError => e
      Automator.logger.warn("[Automator] Subject association #{association.inspect} failed: #{e.message}")
      nil
    end

    def attributes_for(record)
      if record.respond_to?(:attributes)
        Payload.stringify(record.attributes)
      else
        {}
      end
    end
  end
end
