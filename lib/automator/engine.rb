# frozen_string_literal: true

module Automator
  class Engine < ::Rails::Engine
    isolate_namespace Automator

    config.generators do |g|
      g.test_framework :test_unit
    end

    initializer "automator.assets" do |app|
      if app.config.respond_to?(:assets) && app.config.assets
        app.config.assets.precompile += %w[automator_manifest.js automator/application.css]
      end
    end
  end
end
