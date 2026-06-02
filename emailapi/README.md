# FarmSync Hub Email API

This folder is ready to upload as a standalone PHP email relay for FarmSync Hub.

## Upload target

Upload the contents of this folder to your hosting so the endpoint resolves to:

`https://farmsynchub.lbtech.site/api/email-notifications`

If your hosting exposes a different base path, update the app endpoint in `lib/core/services/farm_email_service.dart`.

## Files

- `mail.php` is the JSON API endpoint.
- `config.php` loads SMTP and app settings from environment variables.
- `.htaccess` rewrites `/email-notifications` to `mail.php`.
- `template-map.json` documents the supported template ids.
- `templates/` contains the fallback HTML templates.

## Required environment variables

Set these on your hosting panel or in the server environment:

- `FARMSYNCHUB_SMTP_HOST`
- `FARMSYNCHUB_SMTP_PORT`
- `FARMSYNCHUB_SMTP_SECURE`
- `FARMSYNCHUB_SMTP_USERNAME`
- `FARMSYNCHUB_SMTP_PASSWORD`
- `FARMSYNCHUB_FROM_EMAIL`
- `FARMSYNCHUB_SUPPORT_EMAIL`
- `FARMSYNCHUB_LOGIN_URL`
- `FARMSYNCHUB_APP_NAME`
- `FARMSYNCHUB_EMAIL_API_KEY` if you want request authentication

## Request format

The app sends JSON like this:

```json
{
  "to": "user@example.com",
  "subject": "Message subject",
  "template": "login",
  "html": "<html>...</html>",
  "text": "Plain text fallback",
  "clientName": "FarmSync Hub",
  "metadata": {}
}
```

## Security

If `FARMSYNCHUB_EMAIL_API_KEY` is set, the endpoint will require the
`X-FarmSync-Email-Key` header from the app.

## Deployment notes

- Keep `PHPMailer-master/` in the same folder as `mail.php`.
- Make sure your hosting allows PHP to connect to your SMTP server.
- Use a valid `from_email` on the same domain or a permitted sender for your SMTP provider.
- If your host uses Apache, the included `.htaccess` should route the endpoint automatically.
