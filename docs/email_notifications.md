# FarmSync Hub Email Notifications

Use this app to POST email notifications to your hosted endpoint:

`https://farmsynchub.lbtech.site/api/email-notifications`

## Request

`POST /api/email-notifications`

Headers:
- `Content-Type: application/json`
- `Accept: application/json`
- `X-FarmSync-Email-Key: <optional secret key>`

Body:

```json
{
  "to": "user@example.com",
  "subject": "Message subject",
  "template": "login | welcome | password_reset | news_update | worker_log | schedule | sale | procurement | expense | system_notification",
  "html": "<html>...</html>",
  "text": "Plain text fallback",
  "clientName": "FarmSync Hub",
  "metadata": {}
}
```

## Notes

- The app already builds the HTML templates locally.
- Your server only needs to send the email and return a 2xx status code on success.
- If you want to secure the endpoint, check the `X-FarmSync-Email-Key` header on the server side.
- For production, connect this to a provider like SendGrid, Mailgun, Amazon SES, or your own SMTP relay.

