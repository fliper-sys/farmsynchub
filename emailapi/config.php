<?php
return [
    'app_name' => getenv('FARMSYNCHUB_APP_NAME') ?: 'FarmSync Hub',
    'login_url' => getenv('FARMSYNCHUB_LOGIN_URL') ?: 'https://farmsynchub.lbtech.site',
    'support_email' => getenv('FARMSYNCHUB_SUPPORT_EMAIL') ?: 'support@farmsynchub.lbtech.site',
    'reply_to' => getenv('FARMSYNCHUB_REPLY_TO') ?: '',

    'smtp_host' => getenv('FARMSYNCHUB_SMTP_HOST') ?: 'smtp.hostinger.com',
    'smtp_port' => (int) (getenv('FARMSYNCHUB_SMTP_PORT') ?: 465),
    'smtp_secure' => getenv('FARMSYNCHUB_SMTP_SECURE') ?: 'ssl',
    'smtp_username' => getenv('FARMSYNCHUB_SMTP_USERNAME') ?: 'support@farmsynchub.lbtech.site',
    'smtp_password' => getenv('FARMSYNCHUB_SMTP_PASSWORD') ?: 'Xanther839@',
    'from_email' => getenv('FARMSYNCHUB_FROM_EMAIL') ?: 'support@farmsynchub.lbtech.site',
    'api_key' => getenv('FARMSYNCHUB_EMAIL_API_KEY') ?: '',
];
