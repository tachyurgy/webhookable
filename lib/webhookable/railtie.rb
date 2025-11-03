module Webhookable
  class Railtie < Rails::Railtie
    railtie_name :webhookable

    rake_tasks do
      load "tasks/webhookable.rake"
    end

    generators do
      require_relative "../generators/webhookable/install_generator"
    end

    initializer "webhookable.active_record" do
      ActiveSupport.on_load(:active_record) do
        include Webhookable::Model
      end
    end

    initializer "webhookable.logger" do
      Webhookable.configuration.logger ||= Rails.logger
    end
  end
end
