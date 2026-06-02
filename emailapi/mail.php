<?php
declare(strict_types=1);

use PHPMailer\PHPMailer\Exception;
use PHPMailer\PHPMailer\PHPMailer;

require __DIR__ . '/PHPMailer-master/src/Exception.php';
require __DIR__ . '/PHPMailer-master/src/PHPMailer.php';
require __DIR__ . '/PHPMailer-master/src/SMTP.php';

$config = require __DIR__ . '/config.php';
$templateMap = json_decode((string) file_get_contents(__DIR__ . '/template-map.json'), true);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['error' => 'Method not allowed']);
}

$rawBody = file_get_contents('php://input') ?: '';
$payload = json_decode($rawBody, true);

if (!is_array($payload)) {
    respond(400, ['error' => 'Invalid JSON body']);
}

if (!empty($config['api_key'])) {
    $providedKey = $_SERVER['HTTP_X_FARMSYNC_EMAIL_KEY'] ?? '';
    if (!hash_equals((string) $config['api_key'], (string) $providedKey)) {
        respond(401, ['error' => 'Unauthorized']);
    }
}

$to = trim((string) ($payload['to'] ?? ''));
$subject = trim((string) ($payload['subject'] ?? ''));
$templateId = trim((string) ($payload['template'] ?? 'system_notification'));
$html = (string) ($payload['html'] ?? '');
$text = trim((string) ($payload['text'] ?? ''));
$metadata = is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [];
$clientName = trim((string) ($payload['clientName'] ?? ($config['app_name'] ?? 'FarmSync Hub')));

if (!filter_var($to, FILTER_VALIDATE_EMAIL)) {
    respond(422, ['error' => 'Invalid recipient email address']);
}

if ($subject === '') {
    respond(422, ['error' => 'Subject is required']);
}

$templateEntry = findTemplate($templateMap, $templateId);
if ($html === '') {
    $html = renderTemplate($templateEntry, $payload, $config);
}

if ($text === '') {
    $text = trim(strip_tags($html));
}

$mail = new PHPMailer(true);

try {
    $mail->isSMTP();
    $mail->Host = (string) $config['smtp_host'];
    $mail->SMTPAuth = true;
    $mail->Username = (string) $config['smtp_username'];
    $mail->Password = (string) $config['smtp_password'];
    $mail->SMTPSecure = (string) $config['smtp_secure'];
    $mail->Port = (int) $config['smtp_port'];
    $mail->CharSet = 'UTF-8';
    $mail->isHTML(true);
    $mail->setFrom((string) $config['from_email'], $clientName);
    $mail->addAddress($to);
    $mail->Subject = $subject;
    $mail->Body = $html;
    $mail->AltBody = $text;

    if (!empty($config['reply_to']) && filter_var((string) $config['reply_to'], FILTER_VALIDATE_EMAIL)) {
        $mail->addReplyTo((string) $config['reply_to'], $clientName);
    }

    $mail->addCustomHeader('X-FarmSync-Template', $templateId);
    $mail->addCustomHeader('X-FarmSync-Client', $clientName);

    $mail->send();

    respond(200, [
        'success' => true,
        'template' => $templateId,
        'to' => $to,
    ]);
} catch (Exception $exception) {
    respond(500, [
        'success' => false,
        'error' => 'Email sending failed',
        'details' => $exception->getMessage(),
    ]);
}

function findTemplate(array $templateMap, string $templateId): array
{
    foreach (($templateMap['templates'] ?? []) as $template) {
        if (($template['id'] ?? '') === $templateId) {
            return $template;
        }
    }

    return [
        'id' => 'system_notification',
        'file' => 'templates/security-alert.html',
        'subject' => 'FarmSync notification',
        'variables' => [],
    ];
}

function renderTemplate(array $templateEntry, array $payload, array $config): string
{
    $file = __DIR__ . '/' . ($templateEntry['file'] ?? '');
    $html = is_file($file) ? (string) file_get_contents($file) : '';
    if ($html === '') {
        return '';
    }

    $now = new DateTimeImmutable('now');
    $replacements = array_merge(
        [
            'app_name' => $config['app_name'] ?? 'FarmSync Hub',
            'user_name' => (string) ($payload['recipientName'] ?? $payload['user_name'] ?? 'Farmer'),
            'login_url' => (string) ($config['login_url'] ?? 'https://farmsynchub.lbtech.site'),
            'support_email' => (string) ($config['support_email'] ?? 'support@farmsynchub.lbtech.site'),
            'current_year' => $now->format('Y'),
            'action_url' => (string) ($payload['action_url'] ?? $payload['actionUrl'] ?? $config['login_url'] ?? ''),
            'expiration_text' => (string) ($payload['expiration_text'] ?? $payload['expirationText'] ?? '24 hours'),
            'event_name' => (string) ($payload['event_name'] ?? 'Account activity'),
            'event_time' => (string) ($payload['event_time'] ?? $now->format(DATE_ATOM)),
            'event_location' => (string) ($payload['event_location'] ?? 'Unknown'),
        ],
        flattenMetadata($payload['metadata'] ?? [])
    );

    foreach ($replacements as $key => $value) {
        $html = str_replace('{{' . $key . '}}', (string) $value, $html);
    }

    return $html;
}

function flattenMetadata(array $metadata): array
{
    $flat = [];
    foreach ($metadata as $key => $value) {
        if (is_scalar($value) || $value === null) {
            $flat[(string) $key] = (string) $value;
        }
    }
    return $flat;
}

function respond(int $statusCode, array $body): void
{
    http_response_code($statusCode);
    echo json_encode($body, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}
