# frozen_string_literal: true

module Webhookable
  class WebhookEndpoint < ActiveRecord::Base
    self.table_name = "webhook_endpoints"

    has_many :webhook_deliveries, dependent: :destroy

    validates :url, presence: true, format: {with: URI::DEFAULT_PARSER.make_regexp(%w[http https])}
    validate :validate_url_security
    validates :secret, presence: true, on: :update

    before_validation :generate_secret, on: :create

    scope :enabled, -> { where(enabled: true) }
    scope :for_event, lambda { |event_type|
      case ActiveRecord::Base.connection.adapter_name.downcase
      when "postgresql"
        # PostgreSQL - use native JSON containment operator
        where("events @> ?", [event_type].to_json)
      when /mysql/
        # MySQL - use JSON_CONTAINS function
        where("JSON_CONTAINS(events, ?)", [event_type].to_json)
      else
        # SQLite and others - find matching IDs and return Relation
        # This ensures we always return an ActiveRecord::Relation, not an Array
        matching_ids = all.select { |endpoint| endpoint.subscribed_to?(event_type) }.map(&:id)
        where(id: matching_ids)
      end
    }

    # Check if this endpoint is subscribed to a specific event
    def subscribed_to?(event_type)
      events.include?(event_type.to_s)
    end

    # Enable the endpoint
    def enable!
      update!(enabled: true)
    end

    # Disable the endpoint
    def disable!
      update!(enabled: false)
    end

    # Get successful deliveries count
    def successful_deliveries_count
      webhook_deliveries.where(status: "success").count
    end

    # Get failed deliveries count
    def failed_deliveries_count
      webhook_deliveries.where(status: "failed").count
    end

    # Calculate success rate as percentage
    def success_rate
      total = webhook_deliveries.count
      return 0.0 if total.zero?

      (successful_deliveries_count.to_f / total * 100).round(2)
    end

    private

    def generate_secret
      self.secret ||= SecureRandom.hex(32)
    end

    def validate_url_security
      return if url.blank? # Presence is validated separately

      valid, error_message = Webhookable::UrlValidator.validate(url)
      errors.add(:url, error_message) unless valid
    end
  end
end
