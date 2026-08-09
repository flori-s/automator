# frozen_string_literal: true

module Automator
  module Registry
    module_function

    def predicates
      @predicates ||= {}
    end

    def handlers
      @handlers ||= {}
    end

    def register_predicate(key, callable = nil, &block)
      predicates[key.to_s] = callable || block
    end

    def register_handler(key, callable = nil, &block)
      handlers[key.to_s] = callable || block
    end

    def predicate(key)
      predicates[key.to_s] || raise(ArgumentError, "Unknown Automator predicate: #{key}")
    end

    def handler(key)
      handlers[key.to_s] || raise(ArgumentError, "Unknown Automator handler: #{key}")
    end

    def clear!
      @predicates = {}
      @handlers = {}
    end
  end
end
