# frozen_string_literal: true

# Example: Testing Webhooks
#
# This example demonstrates how to test webhook functionality

require 'webhookable'
require 'rspec'

RSpec.describe 'Webhook Testing Examples' do
  include Webhookable::TestHelpers

  let(:order) { create(:order) }
  let!(:endpoint) { create(:webhook_endpoint, events: ['order.completed']) }

  describe 'testing webhook triggers' do
    it 'triggers webhook when order is completed' do
      # Using the custom matcher
      expect do
        order.update!(status: 'completed')
        order.trigger_webhook(:completed)
      end.to enqueue_webhook(:completed)
    end

    it 'includes correct payload' do
      order.trigger_webhook(:completed)

      event = last_webhook_event(:completed)
      expect(event.payload['id']).to eq(order.id)
      expect(event.payload['status']).to eq('completed')
    end

    it 'creates deliveries for subscribed endpoints' do
      expect do
        order.trigger_webhook(:completed)
      end.to change { WebhookDelivery.count }.by(1)
    end
  end

  describe 'testing in development mode' do
    before do
      Webhookable.configure do |config|
        config.enable_inbox = true
      end
    end

    it 'stores webhooks in inbox instead of sending' do
      order.trigger_webhook(:completed)

      inbox_entry = Webhookable::InboxEntry.last
      expect(inbox_entry.payload['id']).to eq(order.id)
      expect(inbox_entry.url).to eq(endpoint.url)
    end

    it 'allows replaying webhooks from inbox' do
      stub_request(:post, endpoint.url).to_return(status: 200)

      order.trigger_webhook(:completed)
      inbox_entry = Webhookable::InboxEntry.last

      expect(inbox_entry.replay!).to be(true)
    end
  end

  describe 'testing signature verification' do
    it 'generates valid signatures' do
      payload = { id: 123, status: 'completed' }
      secret = 'test-secret'

      signature = Webhookable.generate_signature(payload, secret)
      expect(signature).to start_with('sha256=')
      expect(Webhookable.verify_signature(payload, signature, secret)).to be(true)
    end

    it 'rejects invalid signatures' do
      payload = { id: 123, status: 'completed' }
      invalid_signature = 'sha256=invalid'
      secret = 'test-secret'

      expect(Webhookable.verify_signature(payload, invalid_signature, secret)).to be(false)
    end
  end

  describe 'testing delivery tracking' do
    it 'tracks delivery attempts' do
      endpoint = create(:webhook_endpoint, url: 'https://example.com/webhooks')
      event = create(:webhook_event, eventable: order)
      delivery = create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event)

      stub_request(:post, 'https://example.com/webhooks').to_return(status: 200)

      Webhookable::Delivery.deliver(delivery)

      delivery.reload
      expect(delivery.status).to eq('success')
      expect(delivery.attempt_count).to eq(1)
      expect(delivery.response_code).to eq(200)
    end
  end
end
