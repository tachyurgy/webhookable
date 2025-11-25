# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require "active_record"
require "active_job"
require "httparty"
require "logger"

require_relative "webhookable/version"
require_relative "webhookable/configuration"
require_relative "webhookable/signature"
require_relative "webhookable/url_validator"
require_relative "webhookable/delivery"
require_relative "webhookable/model"
require_relative "webhookable/webhook_delivery_job"
require_relative "webhookable/instrumentation"
require_relative "webhookable/test_helpers"

module Webhookable
  class Error < StandardError; end
  class DeliveryError < Error; end
  class SignatureError < Error; end
  class ConfigurationError < Error; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Verify a webhook signature
    def verify_signature(payload, signature, secret)
      Signature.verify(payload, signature, secret)
    end

    # Generate a webhook signature
    def generate_signature(payload, secret)
      Signature.generate(payload, secret)
    end

    def logger
      configuration.logger
    end
  end
end

# Auto-load models if ActiveRecord is available
if defined?(ActiveRecord::Base)
  require_relative "webhookable/models/webhook_delivery"
  require_relative "webhookable/models/webhook_endpoint"
  require_relative "webhookable/models/webhook_event"
  require_relative "webhookable/inbox_entry"
end

# Auto-load Rails integration if Rails is available
require_relative "webhookable/railtie" if defined?(Rails)
