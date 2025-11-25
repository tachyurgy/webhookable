# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :webhook_endpoints, force: true do |t|
    t.string :url, null: false
    t.string :secret, null: false
    t.boolean :enabled, default: true, null: false
    t.text :description
    t.json :events, default: []
    t.json :metadata, default: {}
    t.timestamps
  end

  create_table :webhook_events, force: true do |t|
    t.string :event_type, null: false
    t.references :eventable, polymorphic: true, null: false
    t.json :payload, null: false
    t.string :idempotency_key, null: false
    t.timestamps
  end

  create_table :webhook_deliveries, force: true do |t|
    t.references :webhook_endpoint, null: false
    t.references :webhook_event, null: false
    t.string :status, null: false, default: 'pending'
    t.integer :attempt_count, default: 0, null: false
    t.datetime :last_attempt_at
    t.datetime :next_retry_at
    t.integer :response_code
    t.text :response_body
    t.text :error_message
    t.json :request_headers, default: {}
    t.json :response_headers, default: {}
    t.timestamps
  end

  create_table :webhookable_inbox_entries, force: true do |t|
    t.references :webhook_delivery
    t.string :url, null: false
    t.json :payload, null: false
    t.json :headers, default: {}
    t.datetime :replayed_at
    t.integer :replay_response_code
    t.text :replay_response_body
    t.timestamps
  end

  # Test model
  create_table :orders, force: true do |t|
    t.string :status
    t.decimal :amount
    t.timestamps
  end
end

# Define test model
class Order < ActiveRecord::Base
  include Webhookable::Model

  webhook_events :completed, :cancelled, :refunded
end
