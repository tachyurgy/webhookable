module Webhookable
  module Instrumentation
    # Subscribe to webhook events
    # Example:
    #   Webhookable::Instrumentation.subscribe do |event, data|
    #     Rails.logger.info "Webhook event: #{event} - #{data.inspect}"
    #   end
    def self.subscribe(pattern = /^webhook\./, &block)
      ActiveSupport::Notifications.subscribe(pattern) do |name, start, finish, id, payload|
        duration = finish - start
        block.call(name, payload.merge(duration: duration))
      end
    end

    # Available events:
    # - webhook.triggered: When a webhook event is created
    # - webhook.delivered: When a webhook delivery attempt is made
    # - webhook.inbox_stored: When a webhook is stored in the inbox (development mode)
  end
end
