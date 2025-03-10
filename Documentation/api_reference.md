# Vizion Gateway API Reference

## Authentication

All API requests must be authenticated using your API key. Include your API key in the `Authorization` header:

```bash
Authorization: Bearer vz_test_your_api_key
```

Use your test API key for development and your live API key for production.

## Base URL

```
https://api.viziongateway.com/v1
```

## Endpoints

### Transactions

#### Create a Transaction

```http
POST /transactions
```

Request body:
```json
{
  "amount": 1000,
  "currency": "XCD",
  "payment_method": "card",
  "customer": {
    "email": "customer@example.com",
    "name": "John Doe"
  },
  "card": {
    "number": "4242424242424242",
    "exp_month": 12,
    "exp_year": 2025,
    "cvc": "123"
  }
}
```

Response:
```json
{
  "id": "txn_123abc",
  "amount": 1000,
  "currency": "XCD",
  "status": "succeeded",
  "payment_method": "card",
  "created": 1642528584
}
```

#### List Transactions

```http
GET /transactions
```

Query parameters:
- `limit` (optional): Number of transactions to return (default: 10, max: 100)
- `starting_after` (optional): Cursor for pagination
- `ending_before` (optional): Cursor for pagination

Response:
```json
{
  "data": [
    {
      "id": "txn_123abc",
      "amount": 1000,
      "currency": "XCD",
      "status": "succeeded",
      "payment_method": "card",
      "created": 1642528584
    }
  ],
  "has_more": false
}
```

### Customers

#### Create a Customer

```http
POST /customers
```

Request body:
```json
{
  "email": "customer@example.com",
  "name": "John Doe",
  "phone": "+1234567890",
  "metadata": {
    "user_id": "123"
  }
}
```

Response:
```json
{
  "id": "cus_123abc",
  "email": "customer@example.com",
  "name": "John Doe",
  "phone": "+1234567890",
  "created": 1642528584
}
```

### Refunds

#### Create a Refund

```http
POST /refunds
```

Request body:
```json
{
  "transaction": "txn_123abc",
  "amount": 1000,
  "reason": "customer_requested"
}
```

Response:
```json
{
  "id": "ref_123abc",
  "transaction": "txn_123abc",
  "amount": 1000,
  "status": "succeeded",
  "created": 1642528584
}
```

## Webhooks

### Webhook Events

The following events are available for webhook notifications:

- `transaction.created`: A new transaction has been created
- `transaction.succeeded`: A transaction has been successfully processed
- `transaction.failed`: A transaction has failed
- `refund.created`: A refund has been created
- `refund.succeeded`: A refund has been successfully processed
- `customer.created`: A new customer has been created
- `customer.updated`: A customer's information has been updated

### Webhook Format

```json
{
  "id": "evt_123abc",
  "type": "transaction.succeeded",
  "created": 1642528584,
  "data": {
    "object": {
      "id": "txn_123abc",
      "amount": 1000,
      "currency": "XCD",
      "status": "succeeded"
    }
  }
}
```

### Verifying Webhooks

To verify that a webhook was sent by Vizion Gateway, compare the signature in the `Vizion-Signature` header with your webhook secret:

```python
import hmac
import hashlib

def verify_webhook(payload_body, header_signature, secret):
    expected = hmac.new(
        secret.encode('utf-8'),
        payload_body,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, header_signature)
```

## Error Handling

The API uses conventional HTTP response codes:

- `200`: Success
- `400`: Bad Request - Invalid parameters
- `401`: Unauthorized - Invalid API key
- `402`: Payment Required - Insufficient funds
- `403`: Forbidden - Insufficient permissions
- `404`: Not Found - Resource doesn't exist
- `429`: Too Many Requests - Rate limit exceeded
- `500`: Internal Server Error

Error response format:

```json
{
  "error": {
    "code": "invalid_card",
    "message": "Your card has been declined",
    "type": "card_error"
  }
}
```

## Rate Limits

The API has rate limits based on your plan:

- Test mode: 100 requests per minute
- Live mode: 1000 requests per minute

Rate limit headers are included in all responses:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642528584
```

## SDKs

Official SDKs are available for:

- iOS/Swift: [GitHub](https://github.com/viziongateway/ios-sdk)
- Android/Kotlin: [GitHub](https://github.com/viziongateway/android-sdk)
- Node.js: [GitHub](https://github.com/viziongateway/node-sdk)
- Python: [GitHub](https://github.com/viziongateway/python-sdk)

## Support

For API support, contact our developer support team:

- Email: api-support@viziongateway.com
- Developer Discord: [Join](https://discord.gg/viziongateway)
- API Status: [status.viziongateway.com](https://status.viziongateway.com) 