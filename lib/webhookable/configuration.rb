# frozen_string_literal: true

module Webhookable
  class Configuration
    attr_accessor :max_retry_attempts,
      :initial_retry_delay,
      :max_retry_delay,
      :timeout,
      :secret_key_base,
      :enable_inbox,
      :logger,
      :user_agent

    def initialize
      @max_retry_attempts = 5
      @initial_retry_delay = 60 # seconds
      @max_retry_delay = 3600 # seconds (1 hour)
      @timeout = 30 # seconds
      @secret_key_base = default_secret_key_base
      @enable_inbox = false
      @logger = default_logger
      @user_agent = "Webhookable/#{Webhookable::VERSION}"
    end

    private

    def default_secret_key_base
      if defined?(Rails) && Rails.application
        Rails.application.secret_key_base
      else
        ENV["WEBHOOKABLE_SECRET_KEY_BASE"] || SecureRandom.hex(64)
      end
    end

    def default_logger
      if defined?(Rails) && Rails.logger
        Rails.logger
      else
        Logger.new($stdout)
      end
    end
  end
end
