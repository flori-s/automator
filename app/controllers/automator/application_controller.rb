# frozen_string_literal: true

module Automator
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    before_action :run_engine_authentication

    helper Automator::ApplicationHelper

    private

    def run_engine_authentication
      auth = Automator.config.authenticate
      return unless auth

      instance_exec(&auth)
    end
  end
end
