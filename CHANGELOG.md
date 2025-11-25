# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned for v0.2
- Customer-facing delivery log UI (mountable engine)
- Web interface for viewing delivery history
- Retry button in UI
- Signature verification documentation in UI

### Planned for v0.3
- Rate limiting support
- Webhook event filtering
- Payload transformation

## [0.1.0] - 2025-01-29

Initial release of Webhookable.

### Added

#### Core Functionality
- **Webhookable::Model** concern for easy integration with ActiveRecord models
- **Automatic webhook delivery** with configurable retry logic
- **HMAC-SHA256 signatures** for webhook security
- **Exponential backoff** retry strategy with configurable delays
- **Delivery tracking** with full history of attempts

#### Models & Database
- `WebhookEndpoint` model for managing customer webhook URLs
- `WebhookEvent` model for tracking triggered events
- `WebhookDelivery` model for tracking individual delivery attempts
- Database migrations with proper indexes for performance

#### Background Processing
- `WebhookDeliveryJob` using ActiveJob for async delivery
- Compatible with any ActiveJob backend (Sidekiq, Solid Queue, Delayed Job, etc.)
- Automatic job scheduling for retries

#### Development Tools
- **Webhook Inbox** for testing without hitting real endpoints
- `InboxEntry` model for storing development webhooks
- Replay functionality for debugging

#### Testing Support
- Comprehensive RSpec test helpers
- Custom RSpec matchers (`have_triggered_webhook`, `enqueue_webhook`)
- Helper methods for test assertions
- FactoryBot factories for all models

#### Configuration
- Zero-config defaults that work out of the box
- Customizable retry attempts, delays, and timeouts
- Configurable secret key base for signatures
- Custom logger support
- User agent customization

#### Rails Integration
- Rails generator (`rails generate webhookable:install`)
- Automatic Rails integration via Railtie
- Rake tasks for webhook management:
  - `webhookable:retry_failed` - Retry failed deliveries
  - `webhookable:process_retries` - Process pending retries
  - `webhookable:cleanup` - Clean up old deliveries
  - `webhookable:stats` - Show webhook statistics
  - `webhookable:clear_inbox` - Clear development inbox
  - `webhookable:list_inbox` - List inbox entries

#### Instrumentation
- ActiveSupport::Notifications integration
- `webhook.triggered` event
- `webhook.delivered` event
- Easy subscription API for monitoring

#### Documentation
- Comprehensive README with examples
- Comparison with existing solutions
- Quick start guide
- Advanced usage documentation
- Testing guide
- Architecture overview

### Features

- **Production Ready**: Robust error handling and retry logic
- **Secure**: Cryptographic signatures on every webhook
- **Observable**: Full instrumentation and logging
- **Testable**: Comprehensive testing tools included
- **Flexible**: Works with any ActiveJob backend
- **Simple**: Zero-config defaults with easy customization
- **Reliable**: Automatic retries with exponential backoff
- **Debuggable**: Webhook inbox for development

### Technical Highlights

- Test coverage for core delivery and signature verification (~49%, ongoing improvements)
- Ruby 3.0+ support
- Rails 6.1+ support
- Thread-safe configuration
- Constant-time signature comparison (timing attack prevention)
- Efficient database queries with proper indexing
- Response body truncation for large responses
- Idempotency key generation for event deduplication

### Dependencies

- activejob >= 6.1
- activerecord >= 6.1
- activesupport >= 6.1
- httparty ~> 0.21

### Development Dependencies

- rspec ~> 3.12
- rspec-rails ~> 6.0
- sqlite3 ~> 1.6
- webmock ~> 3.18
- vcr ~> 6.1
- factory_bot ~> 6.2
- faker ~> 3.2
- simplecov ~> 0.22
- rubocop ~> 1.50
- rubocop-rspec ~> 2.20

---

## Future Roadmap

The following features are under consideration for future releases:

- **v0.2**: Customer-facing delivery log UI (mountable engine)
- **v0.3**: Rate limiting and webhook event filtering
- **v0.4**: Batch webhook delivery and templates
- **v0.5**: GraphQL webhook support and versioning

---

[Unreleased]: https://github.com/magnusfremont/webhookable/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/magnusfremont/webhookable/releases/tag/v0.1.0
