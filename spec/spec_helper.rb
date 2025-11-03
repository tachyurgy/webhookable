require "bundler/setup"
require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
end

require "webhookable"
require "active_record"
require "webmock/rspec"
require "vcr"
require "factory_bot"
require "faker"

# Configure ActiveRecord for testing
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Load schema
load File.expand_path("support/schema.rb", __dir__)

# Configure VCR
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = { record: :new_episodes }
end

# Load FactoryBot factories
require_relative "support/factories"

# Configure RSpec
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = "doc" if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed

  # Reset configuration before each test
  config.before(:each) do
    Webhookable.reset_configuration!
  end

  # Clean database after each test
  config.after(:each) do
    Webhookable::WebhookDelivery.delete_all
    Webhookable::WebhookEvent.delete_all
    Webhookable::WebhookEndpoint.delete_all
    Webhookable::InboxEntry.delete_all if defined?(Webhookable::InboxEntry)
  end

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
end
