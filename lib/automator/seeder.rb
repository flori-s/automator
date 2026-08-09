# frozen_string_literal: true

require "yaml"

module Automator
  class Seeder
    def self.from_yaml(path)
      data = YAML.safe_load(File.read(path), permitted_classes: [Symbol], aliases: true)
      new(data).call
    end

    def self.from_hash(data)
      new(data).call
    end

    def initialize(data)
      @data = data.is_a?(Hash) ? data : {}
      @flows = Array(@data["flows"] || @data[:flows])
    end

    def call
      @flows.map { |definition| upsert_flow(Payload.stringify(definition)) }
    end

    private

    def upsert_flow(definition)
      flow = Flow.find_or_initialize_by(key: definition["key"])
      flow.assign_attributes(
        name: definition["name"] || definition["key"],
        enabled: definition.key?("enabled") ? definition["enabled"] : true,
        dry_run: definition["dry_run"] || false,
        description: definition["description"],
        tenant: definition["tenant"]
      )
      flow.save!

      sync_children(flow, :triggers, definition["triggers"]) do |attrs|
        {
          event: attrs["event"],
          record_type: attrs["record_type"],
          change_filter: attrs["change_filter"] || {},
          position: attrs["position"] || 0
        }
      end

      sync_children(flow, :conditions, definition["conditions"]) do |attrs|
        {
          kind: attrs["kind"] || "structured",
          config: attrs["config"] || attrs.except("kind", "predicate_key", "position"),
          predicate_key: attrs["predicate_key"],
          position: attrs["position"] || 0
        }
      end

      sync_children(flow, :cancel_conditions, definition["cancel_conditions"]) do |attrs|
        {
          kind: attrs["kind"] || "structured",
          config: attrs["config"] || attrs.except("kind", "predicate_key", "position"),
          predicate_key: attrs["predicate_key"],
          position: attrs["position"] || 0
        }
      end

      sync_children(flow, :actions, definition["actions"]) do |attrs|
        {
          kind: attrs["kind"] || (attrs["handler_key"] ? "callback" : "builtin"),
          builtin_name: attrs["builtin_name"],
          handler_key: attrs["handler_key"],
          options: attrs["options"] || {},
          delay_seconds: attrs["delay_seconds"] || 0,
          position: attrs["position"] || 0
        }
      end

      flow
    end

    def sync_children(flow, association, definitions)
      return unless definitions

      flow.public_send(association).destroy_all
      Array(definitions).each_with_index.map do |definition, index|
        attrs = yield(Payload.stringify(definition))
        attrs["position"] ||= index
        flow.public_send(association).create!(attrs)
      end
    end
  end

  module DSL
    def self.draw(&block)
      builder = Builder.new
      builder.instance_eval(&block)
      Seeder.from_hash("flows" => builder.flows)
    end

    class Builder
      attr_reader :flows

      def initialize
        @flows = []
      end

      def flow(key, name: nil, enabled: true, dry_run: false, tenant: nil, description: nil, &block)
        fb = FlowBuilder.new(key, name: name || key.to_s.humanize, enabled: enabled, dry_run: dry_run,
                                  tenant: tenant, description: description)
        fb.instance_eval(&block) if block
        @flows << fb.to_h
      end
    end

    class FlowBuilder
      def initialize(key, name:, enabled:, dry_run:, tenant:, description:)
        @key = key.to_s
        @name = name
        @enabled = enabled
        @dry_run = dry_run
        @tenant = tenant
        @description = description
        @triggers = []
        @conditions = []
        @cancel_conditions = []
        @actions = []
      end

      def trigger(event, record_type: nil, change_filter: {})
        @triggers << { "event" => event.to_s, "record_type" => record_type, "change_filter" => change_filter }
      end

      def condition(config = nil, kind: "structured", predicate_key: nil, **kwargs)
        @conditions << {
          "kind" => kind,
          "predicate_key" => predicate_key,
          "config" => config || kwargs
        }
      end

      def cancel_condition(config = nil, kind: "structured", predicate_key: nil, **kwargs)
        @cancel_conditions << {
          "kind" => kind,
          "predicate_key" => predicate_key,
          "config" => config || kwargs
        }
      end

      def action(builtin: nil, handler: nil, delay_seconds: 0, **options)
        @actions << {
          "kind" => handler ? "callback" : "builtin",
          "builtin_name" => builtin&.to_s,
          "handler_key" => handler&.to_s,
          "delay_seconds" => delay_seconds,
          "options" => options
        }
      end

      def to_h
        {
          "key" => @key,
          "name" => @name,
          "enabled" => @enabled,
          "dry_run" => @dry_run,
          "tenant" => @tenant,
          "description" => @description,
          "triggers" => @triggers,
          "conditions" => @conditions,
          "cancel_conditions" => @cancel_conditions,
          "actions" => @actions
        }
      end
    end
  end
end
