Webhookable.configure do |config|
  # Maximum number of retry attempts for failed webhook deliveries
  # Default: 5
  # config.max_retry_attempts = 5

  # Initial retry delay in seconds (will increase exponentially)
  # Default: 60 (1 minute)
  # config.initial_retry_delay = 60

  # Maximum retry delay in seconds (cap for exponential backoff)
  # Default: 3600 (1 hour)
  # config.max_retry_delay = 3600

  # Timeout for HTTP requests in seconds
  # Default: 30
  # config.timeout = 30

  # Secret key base for generating webhook signatures
  # Default: Rails.application.secret_key_base (in Rails apps)
  # config.secret_key_base = "your-secret-key"

  # Enable webhook inbox for development/testing
  # When enabled, webhooks are stored locally instead of delivered
  # Default: false
  # config.enable_inbox = Rails.env.development? || Rails.env.test?

  # Custom logger
  # Default: Rails.logger (in Rails apps) or Logger.new(STDOUT)
  # config.logger = Logger.new(STDOUT)

  # Custom user agent for webhook requests
  # Default: "Webhookable/#{VERSION}"
  # config.user_agent = "MyApp Webhooks"
end
