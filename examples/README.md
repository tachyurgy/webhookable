# Webhookable Examples

This directory contains complete, runnable examples demonstrating various Webhookable features.

## Available Examples

### Basic Usage (`basic_usage.rb`)
The simplest possible webhook setup - perfect for getting started quickly.

**Demonstrates:**
- Including Webhookable in models
- Creating webhook endpoints
- Triggering webhooks

### Custom Payloads (`custom_payload.rb`)
Shows how to customize webhook payloads for your specific needs.

**Demonstrates:**
- Overriding `default_webhook_payload`
- Sending custom payloads per-trigger
- Including related data in webhooks

### Receiving Webhooks (`receiving_webhooks.rb`)
Complete example of how your customers should receive and verify webhooks.

**Demonstrates:**
- Signature verification
- Payload parsing
- Error handling
- Event routing

### Testing (`testing.rb`)
Comprehensive testing examples using RSpec and Webhookable's test helpers.

**Demonstrates:**
- Custom RSpec matchers
- Testing webhook triggers
- Inbox mode for development
- Signature verification tests
- Delivery tracking tests

## Running Examples

These examples are for reference and demonstration. To try them in your own application:

1. Install Webhookable:
   ```bash
   gem install webhookable
   ```

2. Run the install generator:
   ```bash
   rails generate webhookable:install
   rails db:migrate
   ```

3. Copy and adapt the example code to your models and controllers

## Need Help?

- Read the main [README](../README.md) for complete documentation
- Check [CONTRIBUTING.md](../CONTRIBUTING.md) for development guidelines
- Open an issue on [GitHub](https://github.com/magnusfremont/webhookable/issues)
- Email us at hello@webhookable.dev
