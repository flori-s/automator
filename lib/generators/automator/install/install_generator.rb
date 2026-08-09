# frozen_string_literal: true

require "rails/generators"

module Automator
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "initializer.rb", "config/initializers/automator.rb"
      end

      def mount_engine
        route 'mount Automator::Engine => "/automator"'
      end

      def show_readme
        say <<~MSG

          Automator installed.

          Next:
            1. rails automator:install:migrations && rails db:migrate
            2. Review config/initializers/automator.rb
            3. Schedule: * * * * * cd /app && bin/rails automator:sweep
            4. For Apartment, include automator migrations in tenant migrations

        MSG
      end
    end
  end
end
