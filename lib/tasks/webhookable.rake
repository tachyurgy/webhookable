namespace :webhookable do
  desc "Retry all failed webhook deliveries"
  task retry_failed: :environment do
    failed_count = Webhookable::WebhookDelivery.failed.count
    puts "Found #{failed_count} failed webhook deliveries"

    Webhookable::WebhookDelivery.failed.find_each do |delivery|
      delivery.update!(status: "pending", next_retry_at: Time.current)
      Webhookable::WebhookDeliveryJob.perform_later(delivery.id)
      puts "Enqueued delivery #{delivery.id} for retry"
    end

    puts "Done! Enqueued #{failed_count} deliveries for retry"
  end

  desc "Process pending webhook deliveries ready for retry"
  task process_retries: :environment do
    ready_count = Webhookable::WebhookDelivery.ready_for_retry.count
    puts "Found #{ready_count} webhook deliveries ready for retry"

    Webhookable::WebhookDelivery.ready_for_retry.find_each do |delivery|
      Webhookable::WebhookDeliveryJob.perform_later(delivery.id)
      puts "Enqueued delivery #{delivery.id}"
    end

    puts "Done! Enqueued #{ready_count} deliveries"
  end

  desc "Clean up old successful webhook deliveries (older than 30 days)"
  task cleanup: :environment do
    cutoff_date = 30.days.ago
    deleted_count = Webhookable::WebhookDelivery
      .where(status: "success")
      .where("created_at < ?", cutoff_date)
      .delete_all

    puts "Deleted #{deleted_count} old successful webhook deliveries"
  end

  desc "Show webhook statistics"
  task stats: :environment do
    total_events = Webhookable::WebhookEvent.count
    total_deliveries = Webhookable::WebhookDelivery.count
    pending_deliveries = Webhookable::WebhookDelivery.pending.count
    successful_deliveries = Webhookable::WebhookDelivery.successful.count
    failed_deliveries = Webhookable::WebhookDelivery.failed.count
    total_endpoints = Webhookable::WebhookEndpoint.count
    enabled_endpoints = Webhookable::WebhookEndpoint.enabled.count

    puts "\nWebhookable Statistics"
    puts "=" * 50
    puts "Webhook Events:       #{total_events}"
    puts "Total Deliveries:     #{total_deliveries}"
    puts "  - Pending:          #{pending_deliveries}"
    puts "  - Successful:       #{successful_deliveries}"
    puts "  - Failed:           #{failed_deliveries}"
    puts "Webhook Endpoints:    #{total_endpoints}"
    puts "  - Enabled:          #{enabled_endpoints}"
    puts "  - Disabled:         #{total_endpoints - enabled_endpoints}"

    if total_deliveries > 0
      success_rate = (successful_deliveries.to_f / total_deliveries * 100).round(2)
      puts "\nSuccess Rate:         #{success_rate}%"
    end

    puts "=" * 50
  end

  desc "Clear inbox entries (development/testing only)"
  task clear_inbox: :environment do
    if Rails.env.production?
      puts "This task cannot be run in production"
      exit 1
    end

    count = Webhookable::InboxEntry.count
    Webhookable::InboxEntry.delete_all
    puts "Cleared #{count} inbox entries"
  end

  desc "List inbox entries"
  task list_inbox: :environment do
    entries = Webhookable::InboxEntry.recent.limit(20)

    if entries.empty?
      puts "No inbox entries found"
      exit
    end

    puts "\nRecent Inbox Entries (last 20)"
    puts "=" * 100

    entries.each do |entry|
      puts "ID: #{entry.id} | Event: #{entry.event_type} | URL: #{entry.url} | Created: #{entry.created_at}"
    end

    puts "=" * 100
    puts "Total entries: #{Webhookable::InboxEntry.count}"
  end
end
