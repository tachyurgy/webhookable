# Security Policy

## Supported Versions

We release security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

We take the security of Webhookable seriously. If you believe you have found a security vulnerability, please report it to us responsibly.

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please email us at: **security@webhookable.dev**

Include as much information as possible:
- Type of vulnerability
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit or URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the vulnerability

### What to Expect

- We will acknowledge receipt of your vulnerability report within 48 hours
- We will send a more detailed response within 7 days
- We will work with you to understand and validate the vulnerability
- We will release a fix as soon as possible
- We will credit you in the security advisory (if desired)

## Security Best Practices

When using Webhookable:

1. **Keep secrets secure**: Never commit webhook endpoint secrets to version control
2. **Use HTTPS**: Always use HTTPS URLs for webhook endpoints
3. **Verify signatures**: Always verify webhook signatures on the receiving end
4. **Rate limit**: Consider implementing rate limiting for your webhook endpoints
5. **Update regularly**: Keep Webhookable and all dependencies up to date
6. **Monitor deliveries**: Set up monitoring for failed webhook deliveries

## Known Security Considerations

### Signature Verification

Webhookable uses HMAC-SHA256 signatures to sign all webhook payloads. Recipients should always verify these signatures before processing webhooks.

Example verification:

```ruby
payload = request.body.read
signature = request.headers['X-Webhook-Signature']
secret = ENV['WEBHOOK_SECRET']

if Webhookable.verify_signature(payload, signature, secret)
  # Process webhook
else
  head :unauthorized
end
```

### Timing Attack Prevention

Webhookable uses constant-time string comparison for signature verification to prevent timing attacks.

### Secret Storage

- Webhook endpoint secrets are automatically generated using `SecureRandom.hex(32)`
- Secrets should be stored encrypted at rest (use Rails encrypted credentials or similar)
- Consider rotating secrets periodically

## Security Updates

Security updates will be released as patch versions and announced via:
- GitHub Security Advisories
- RubyGems security announcements
- Email to security@webhookable.dev subscribers

## Contact

For security-related questions: security@webhookable.dev

For general questions: hello@webhookable.dev
