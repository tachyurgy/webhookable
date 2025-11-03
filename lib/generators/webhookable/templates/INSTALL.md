===============================================================================
Webhookable has been installed!
===============================================================================

Next steps:

1. Run the migrations:

   rails db:migrate

2. Add Webhookable to your models:

   class Order < ApplicationRecord
     include Webhookable::Model
     webhook_events :completed, :cancelled, :refunded
   end

3. Create webhook endpoints (typically done by your users):

   endpoint = WebhookEndpoint.create!(
     url: "https://customer.example.com/webhooks",
     events: ["order.completed", "order.cancelled"]
   )

4. Trigger webhooks in your code:

   order = Order.find(123)
   order.trigger_webhook(:completed)

5. (Optional) Verify webhook signatures on the receiving end:

   payload = request.body.read
   signature = request.headers['X-Webhook-Signature']
   secret = "your-webhook-endpoint-secret"

   if Webhookable.verify_signature(payload, signature, secret)
     # Process webhook
   else
     # Invalid signature
   end

For more information, visit:
https://github.com/magnusfremont/webhookable

===============================================================================
