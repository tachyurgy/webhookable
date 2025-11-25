# frozen_string_literal: true

module Webhookable
  class Railtie < Rails::Railtie
    railtie_name :webhookable

    rake_tasks do
      load "tasks/webhookable.rake"
    end

    generators do
      require_relative "../generators/webhookable/install_generator"
    end

    # NOTE: Models must explicitly include Webhookable::Model
    # This is intentional to avoid namespace pollution and unexpected behavior
    # Example:
    #   class Order < ApplicationRecord
    #     include Webhookable::Model
    #     triggers_webhook "order.created", on: :create
    #   end

    initializer "webhookable.logger" do
      Webhookable.configuration.logger ||= Rails.logger
    end
  end
end
