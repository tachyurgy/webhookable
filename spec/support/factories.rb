# frozen_string_literal: true

FactoryBot.define do
  factory :webhook_endpoint, class: 'Webhookable::WebhookEndpoint' do
    url { Faker::Internet.url }
    secret { SecureRandom.hex(32) }
    enabled { true }
    events { ['order.completed', 'order.cancelled'] }
  end

  factory :webhook_event, class: 'Webhookable::WebhookEvent' do
    event_type { 'completed' }
    association :eventable, factory: :order
    payload { { id: 1, status: 'completed', amount: 100.0 } }
    idempotency_key { SecureRandom.uuid }
  end

  factory :webhook_delivery, class: 'Webhookable::WebhookDelivery' do
    association :webhook_endpoint
    association :webhook_event
    status { 'pending' }
    attempt_count { 0 }
  end

  factory :order do
    status { 'pending' }
    amount { 100.0 }
  end
end
