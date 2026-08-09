# frozen_string_literal: true

require "logger"
require "digest"
require "automator/version"
require "automator/configuration"
require "automator/registry"
require "automator/payload"
require "automator/interpolator"
require "automator/condition_evaluator"
require "automator/enqueuer"
require "automator/dispatcher"
require "automator/actions"
require "automator/actions/log_action"
require "automator/actions/update_attributes_action"
require "automator/actions/email_action"
require "automator/actions/webhook_action"
require "automator/notifiers"
require "automator/notifiers/callable"
require "automator/notifiers/composite"
require "automator/notifiers/webhook"
require "automator/tenancy"
require "automator/poll_lock"
require "automator/sweep"
require "automator/simulator"
require "automator/model"
require "automator/seeder"
require "automator/engine"

module Automator
  class << self
    def configure
      yield config
    end

    def config
      @config ||= Configuration.new
    end

    def reset_config!
      @config = Configuration.new
    end

    def logger
      @logger ||= (defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger) || Logger.new($stdout)
    end

    def trigger(event, record_or_hash = nil, changes: nil, tenant: nil, **extra)
      Dispatcher.trigger(event, record_or_hash, changes: changes, tenant: tenant, **extra)
    end

    def sweep(limit: config.sweep_batch_size)
      Sweep.run(limit: limit)
    end

    def register_predicate(key, callable = nil, &block)
      Registry.register_predicate(key, callable, &block)
    end

    def register_handler(key, callable = nil, &block)
      Registry.register_handler(key, callable, &block)
    end

    def draw(&block)
      DSL.draw(&block)
    end

    def seed_from_yaml(path)
      Seeder.from_yaml(path)
    end
  end
end
