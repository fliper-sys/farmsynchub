Production-ready auth email templates for deployment to `lbtech.site/emailapi/`.

Suggested structure:
- `templates/` contains the HTML files your email service can load directly.
- `template-map.json` describes expected variables for each template.

Placeholder format:
- `{{app_name}}`
- `{{user_name}}`
- `{{action_url}}`
- `{{support_email}}`
- `{{current_year}}`

Recommended server behavior:
1. Load the requested template file.
2. Replace placeholders with trusted backend values.
3. Send the final rendered HTML through your email provider.

Templates included:
- `welcome.html`
- `verify-email.html`
- `reset-password.html`
- `security-alert.html`
