# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webhookable::WebhookEndpoint do
  describe 'validations' do
    it 'requires url' do
      endpoint = build(:webhook_endpoint, url: nil)
      expect(endpoint).not_to be_valid
      expect(endpoint.errors[:url]).to include("can't be blank")
    end

    it 'requires valid URL format' do
      endpoint = build(:webhook_endpoint, url: 'not-a-url')
      expect(endpoint).not_to be_valid
    end

    it 'accepts http URLs' do
      endpoint = build(:webhook_endpoint, url: 'http://example.com/webhook')
      expect(endpoint).to be_valid
    end

    it 'accepts https URLs' do
      endpoint = build(:webhook_endpoint, url: 'https://example.com/webhook')
      expect(endpoint).to be_valid
    end

    it 'requires secret on update' do
      endpoint = create(:webhook_endpoint)
      endpoint.secret = nil
      expect(endpoint).not_to be_valid
    end

    context 'SSRF protection' do
      it 'rejects localhost URLs' do
        endpoint = build(:webhook_endpoint, url: 'http://localhost/webhook')
        expect(endpoint).not_to be_valid
        expect(endpoint.errors[:url]).to include('URL hostname contains blocked keyword')
      end

      it 'rejects 127.0.0.1 URLs' do
        endpoint = build(:webhook_endpoint, url: 'http://127.0.0.1/webhook')
        expect(endpoint).not_to be_valid
        expect(endpoint.errors[:url]).to include('URL uses a blocked IP address')
      end

      it 'rejects private network 10.x.x.x URLs' do
        endpoint = build(:webhook_endpoint, url: 'http://10.0.0.1/webhook')
        expect(endpoint).not_to be_valid
        expect(endpoint.errors[:url]).to include('URL uses a blocked IP address')
      end

      it 'rejects private network 192.168.x.x URLs' do
        endpoint = build(:webhook_endpoint, url: 'http://192.168.1.1/webhook')
        expect(endpoint).not_to be_valid
        expect(endpoint.errors[:url]).to include('URL uses a blocked IP address')
      end

      it 'rejects internal hostname URLs' do
        endpoint = build(:webhook_endpoint, url: 'http://internal.company.com/webhook')
        expect(endpoint).not_to be_valid
        expect(endpoint.errors[:url]).to include('URL hostname contains blocked keyword')
      end

      it 'rejects metadata URLs' do
        endpoint = build(:webhook_endpoint, url: 'http://metadata.aws.amazon.com/')
        expect(endpoint).not_to be_valid
        expect(endpoint.errors[:url]).to include('URL hostname contains blocked keyword')
      end

      it 'accepts legitimate external URLs' do
        endpoint = build(:webhook_endpoint, url: 'https://api.example.com/webhook')
        expect(endpoint).to be_valid
      end
    end
  end

  describe 'callbacks' do
    it 'generates secret before validation on create' do
      endpoint = described_class.new(url: 'https://example.com/webhook')
      expect(endpoint.secret).to be_nil
      endpoint.valid?
      expect(endpoint.secret).not_to be_nil
      expect(endpoint.secret.length).to eq(64)
    end

    it 'does not override provided secret' do
      custom_secret = 'my-custom-secret'
      endpoint = create(:webhook_endpoint, secret: custom_secret)
      expect(endpoint.secret).to eq(custom_secret)
    end
  end

  describe 'scopes' do
    let!(:enabled_endpoint) { create(:webhook_endpoint, enabled: true) }
    let!(:disabled_endpoint) { create(:webhook_endpoint, enabled: false) }

    describe '.enabled' do
      it 'returns only enabled endpoints' do
        expect(described_class.enabled).to include(enabled_endpoint)
        expect(described_class.enabled).not_to include(disabled_endpoint)
      end
    end

    describe '.for_event' do
      let!(:order_endpoint) { create(:webhook_endpoint, events: ['order.completed']) }
      let!(:user_endpoint) { create(:webhook_endpoint, events: ['user.created']) }

      it 'returns endpoints subscribed to the event' do
        results = described_class.for_event('order.completed')
        expect(results).to include(order_endpoint)
        expect(results).not_to include(user_endpoint)
      end
    end
  end

  describe '#subscribed_to?' do
    let(:endpoint) { create(:webhook_endpoint, events: ['order.completed', 'order.cancelled']) }

    it 'returns true for subscribed events' do
      expect(endpoint.subscribed_to?('order.completed')).to be(true)
      expect(endpoint.subscribed_to?(:order_completed)).to be(false) # Must be exact match
    end

    it 'returns false for non-subscribed events' do
      expect(endpoint.subscribed_to?('order.refunded')).to be(false)
    end
  end

  describe '#enable!' do
    it 'enables the endpoint' do
      endpoint = create(:webhook_endpoint, enabled: false)
      endpoint.enable!
      expect(endpoint.reload.enabled).to be(true)
    end
  end

  describe '#disable!' do
    it 'disables the endpoint' do
      endpoint = create(:webhook_endpoint, enabled: true)
      endpoint.disable!
      expect(endpoint.reload.enabled).to be(false)
    end
  end

  describe '#successful_deliveries_count' do
    let(:endpoint) { create(:webhook_endpoint) }

    it 'returns count of successful deliveries' do
      event = create(:webhook_event)
      create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event, status: 'success')
      create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event, status: 'success')
      create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event, status: 'failed')

      expect(endpoint.successful_deliveries_count).to eq(2)
    end
  end

  describe '#failed_deliveries_count' do
    let(:endpoint) { create(:webhook_endpoint) }

    it 'returns count of failed deliveries' do
      event = create(:webhook_event)
      create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event, status: 'failed')
      create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event, status: 'failed')
      create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event, status: 'success')

      expect(endpoint.failed_deliveries_count).to eq(2)
    end
  end

  describe '#success_rate' do
    let(:endpoint) { create(:webhook_endpoint) }

    it 'returns 0 when no deliveries' do
      expect(endpoint.success_rate).to eq(0.0)
    end

    it 'calculates success rate percentage' do
      event = create(:webhook_event)
      create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event, status: 'success')
      create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event, status: 'success')
      create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event, status: 'success')
      create(:webhook_delivery, webhook_endpoint: endpoint, webhook_event: event, status: 'failed')

      expect(endpoint.success_rate).to eq(75.0)
    end
  end
end
