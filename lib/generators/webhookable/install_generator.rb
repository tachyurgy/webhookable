require "rails/generators"
require "rails/generators/active_record"

module Webhookable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates Webhookable initializer and migrations"

      def copy_initializer
        template "initializer.rb", "config/initializers/webhookable.rb"
      end

      def create_migrations
        migration_template "create_webhook_endpoints.rb.erb",
                          "db/migrate/create_webhook_endpoints.rb"

        migration_template "create_webhook_deliveries.rb.erb",
                          "db/migrate/create_webhook_deliveries.rb"

        migration_template "create_webhook_events.rb.erb",
                          "db/migrate/create_webhook_events.rb"
      end

      def show_readme
        readme "INSTALL.md"
      end
    end
  end
end
