require_relative "lib/webhookable/version"

Gem::Specification.new do |spec|
  spec.name        = "webhookable"
  spec.version     = Webhookable::VERSION
  spec.authors     = ["Code Railroad"]
  spec.email       = ["coderailroad@gmail.com"]

  spec.summary     = "Production-ready webhooks for Rails in under 5 minutes"
  spec.description = "Webhookable gives your Rails app production-ready webhooks with automatic retries, cryptographic signatures, and delivery tracking. Zero config required."
  spec.homepage    = "https://github.com/codeRailroad/webhookable"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/codeRailroad/webhookable"
  spec.metadata["changelog_uri"] = "https://github.com/codeRailroad/webhookable/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/codeRailroad/webhookable/issues"
  spec.metadata["documentation_uri"] = "https://github.com/codeRailroad/webhookable#readme"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*",
    "LICENSE.txt",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "activejob", ">= 6.1"
  spec.add_dependency "activerecord", ">= 6.1"
  spec.add_dependency "activesupport", ">= 6.1"
  spec.add_dependency "httparty", "~> 0.21"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "sqlite3", "~> 1.6"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "vcr", "~> 6.1"
  spec.add_development_dependency "factory_bot", "~> 6.2"
  spec.add_development_dependency "faker", "~> 3.2"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-rspec", "~> 2.20"
end
