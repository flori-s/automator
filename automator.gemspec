# frozen_string_literal: true

require_relative "lib/automator/version"

Gem::Specification.new do |spec|
  spec.name        = "automator"
  spec.version     = Automator::VERSION
  spec.authors     = ["Floris Christiaansen"]
  spec.email       = ["floris@example.com"]
  spec.homepage    = "https://github.com/flori-s/automator"
  spec.summary     = "Event-driven automation rules engine for Rails"
  spec.description = "Mountable Rails engine for automation flows with conditions, actions, sweep jobs, webhooks, and an ops dashboard."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/flori-s/automator"
  spec.metadata["changelog_uri"] = "https://github.com/flori-s/automator/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 6.0"
end
