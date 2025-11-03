module Webhookable
  module TestHelpers
    # Clear all webhook data (useful for test cleanup)
    def clear_webhooks
      Webhookable::WebhookDelivery.delete_all
      Webhookable::WebhookEvent.delete_all
      Webhookable::InboxEntry.delete_all if defined?(Webhookable::InboxEntry)
    end

    # Assert that a webhook was triggered
    def assert_webhook_triggered(event_type, model: nil)
      query = Webhookable::WebhookEvent.where(event_type: event_type.to_s)
      query = query.where(eventable: model) if model

      if defined?(RSpec)
        expect(query.exists?).to be(true), "Expected webhook '#{event_type}' to be triggered"
      else
        assert query.exists?, "Expected webhook '#{event_type}' to be triggered"
      end
    end

    # Assert that a webhook was not triggered
    def refute_webhook_triggered(event_type, model: nil)
      query = Webhookable::WebhookEvent.where(event_type: event_type.to_s)
      query = query.where(eventable: model) if model

      if defined?(RSpec)
        expect(query.exists?).to be(false), "Expected webhook '#{event_type}' not to be triggered"
      else
        refute query.exists?, "Expected webhook '#{event_type}' not to be triggered"
      end
    end

    # Get the last triggered webhook event
    def last_webhook_event(event_type = nil)
      query = Webhookable::WebhookEvent.order(created_at: :desc)
      query = query.where(event_type: event_type.to_s) if event_type
      query.first
    end

    # Get the last webhook delivery
    def last_webhook_delivery
      Webhookable::WebhookDelivery.order(created_at: :desc).first
    end

    # RSpec matchers
    if defined?(RSpec)
      RSpec::Matchers.define :have_triggered_webhook do |event_type|
        match do |model|
          Webhookable::WebhookEvent.exists?(
            event_type: event_type.to_s,
            eventable: model
          )
        end

        failure_message do |model|
          "expected #{model.class}##{model.id} to trigger webhook '#{event_type}'"
        end

        failure_message_when_negated do |model|
          "expected #{model.class}##{model.id} not to trigger webhook '#{event_type}'"
        end
      end

      RSpec::Matchers.define :enqueue_webhook do |event_type|
        supports_block_expectations

        match do |block|
          before_count = Webhookable::WebhookEvent.where(event_type: event_type.to_s).count
          block.call
          after_count = Webhookable::WebhookEvent.where(event_type: event_type.to_s).count
          @triggered_count = after_count - before_count
          @triggered_count > 0
        end

        failure_message do
          "expected block to trigger webhook '#{event_type}', but it didn't"
        end

        failure_message_when_negated do
          "expected block not to trigger webhook '#{event_type}', but it triggered #{@triggered_count}"
        end
      end
    end
  end
end

# Auto-include in RSpec if available
if defined?(RSpec)
  RSpec.configure do |config|
    config.include Webhookable::TestHelpers
  end
end
