import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FarmEmailService {
  const FarmEmailService({
    this.endpoint = 'https://farmsynchub.lbtech.site/api/email-notifications',
    this.appBaseUrl = 'https://farmsynchub.lbtech.site',
    this.clientName = 'FarmSync Hub',
    this.apiKey = 'Xanther839@FarmSyncEmail2026',
  });

  final String endpoint;
  final String appBaseUrl;
  final String clientName;
  final String apiKey;

  Future<bool> sendLoginNotification({
    required String toEmail,
    required String recipientName,
    required String signInMethod,
    String location = '',
  }) {
    const String subject = 'New login to your FarmSync account';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'login',
      html: _shell(
        subject: subject,
        eyebrow: 'Account activity',
        headline: 'You just signed in to FarmSync',
        body:
            'Hello $recipientName, this is a confirmation that your FarmSync account was accessed using $signInMethod${location.isNotEmpty ? ' from $location' : ''}. If this was not you, please change your password immediately and review your account security.',
        accents: const <String>['Login', 'Security', 'Account activity'],
      ),
      text:
          'Hello $recipientName, this is a confirmation that your FarmSync account was accessed using $signInMethod${location.isNotEmpty ? ' from $location' : ''}. If this was not you, please change your password immediately and review your account security.',
      metadata: <String, dynamic>{
        'signInMethod': signInMethod,
        if (location.isNotEmpty) 'location': location,
      },
    );
  }

  Future<bool> sendWelcomeNotification({
    required String toEmail,
    required String recipientName,
  }) {
    const String subject = 'Welcome to FarmSync Hub';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'welcome',
      html: _shell(
        subject: subject,
        eyebrow: 'Welcome',
        headline: 'Your workspace is ready',
        body:
            'Hello $recipientName, your FarmSync account has been created successfully. You can now manage farms, record sales, follow news, and keep your work organised in one place.',
        accents: const <String>['Workspace ready', 'Farms', 'Finance', 'News'],
      ),
      text:
          'Hello $recipientName, your FarmSync account has been created successfully. You can now manage farms, record sales, follow news, and keep your work organised in one place.',
      metadata: <String, dynamic>{
        'audience': 'new_user',
      },
    );
  }

  Future<bool> sendInviteNotification({
    required String toEmail,
    required String recipientName,
    required String inviterName,
    required String farmName,
    required String inviteToken,
    required String role,
  }) {
    final String subject = 'You are invited to join $farmName on FarmSync';
    final String inviteUrl = '$appBaseUrl/invite/$inviteToken';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'invite',
      html: '${_shell(
        subject: subject,
        eyebrow: 'Invitation',
        headline: 'Join $farmName',
        body:
            'Hello $recipientName, $inviterName invited you to join the workspace for $farmName as $role. Click the link below to accept the invitation and create your account. If the button does not open, paste this URL into your browser: $inviteUrl',
        accents: const <String>['Invitation', 'Workspace', 'Farm'],
      )}<p><a href="$inviteUrl">Accept invitation</a></p>',
      text:
          'Hello $recipientName, $inviterName invited you to join the workspace for $farmName as $role. Visit $inviteUrl to accept the invitation and create your account.',
      metadata: <String, dynamic>{
        'inviterName': inviterName,
        'farmName': farmName,
        'role': role,
      },
    );
  }

  Future<bool> sendPasswordResetNotification({
    required String toEmail,
    required String recipientName,
  }) {
    const String subject = 'Password reset requested';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'password_reset',
      html: _shell(
        subject: subject,
        eyebrow: 'Security',
        headline: 'Password reset started',
        body:
            'Hello $recipientName, a password reset was requested for your FarmSync account. If you made this request, please use the Firebase reset email and choose a strong new password. If not, you can ignore this message and review your account security.',
        accents: const <String>['Reset', 'Security', 'Verification'],
      ),
      text:
          'Hello $recipientName, a password reset was requested for your FarmSync account. If you made this request, please use the Firebase reset email and choose a strong new password. If not, you can ignore this message and review your account security.',
      metadata: <String, dynamic>{
        'audience': 'account_owner',
      },
    );
  }

  Future<bool> sendNewsUpdateNotification({
    required String toEmail,
    required String recipientName,
    required String title,
    required String category,
    required String summary,
  }) {
    final String subject = 'News update: $title';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'news_update',
      html: _shell(
        subject: subject,
        eyebrow: category,
        headline: title,
        body:
            'Hello $recipientName, a new update has been published in FarmSync. $summary You can open the news feed to read the full post, follow the author, or repost it for your farm network.',
        accents: const <String>['News', 'Feed', 'Follow', 'Repost'],
      ),
      text:
          'Hello $recipientName, a new update has been published in FarmSync. $summary You can open the news feed to read the full post, follow the author, or repost it for your farm network.',
      metadata: <String, dynamic>{
        'category': category,
      },
    );
  }

  Future<bool> sendVerifiedBadgeRequestNotification({
    required String toEmail,
    required String recipientName,
    required String applicantName,
    required String ward,
    required String primaryFocus,
  }) {
    const String subject = 'Verified badge request received';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'verified_badge_request',
      html: _shell(
        subject: subject,
        eyebrow: 'Verification',
        headline: 'A farmer requested a verified badge',
        body:
            'Hello $recipientName, $applicantName has submitted a verified badge application in FarmSync. Ward: $ward. Focus: $primaryFocus. Please open the admin review screen to approve or decline the request.',
        accents: const <String>['Verified', 'Review', 'Admin', 'Profile'],
      ),
      text:
          'Hello $recipientName, $applicantName has submitted a verified badge application in FarmSync. Ward: $ward. Focus: $primaryFocus. Please open the admin review screen to approve or decline the request.',
      metadata: <String, dynamic>{
        'applicantName': applicantName,
        'ward': ward,
        'primaryFocus': primaryFocus,
      },
    );
  }

  Future<bool> sendVerifiedBadgeDecisionNotification({
    required String toEmail,
    required String recipientName,
    required bool approved,
    required String reviewerName,
    required String note,
  }) {
    final String subject = approved ? 'Verified badge approved' : 'Verified badge declined';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: approved ? 'verified_badge_approved' : 'verified_badge_declined',
      html: _shell(
        subject: subject,
        eyebrow: 'Verification result',
        headline: approved ? 'Your verified badge was approved' : 'Your verified badge request was declined',
        body: approved
            ? 'Hello $recipientName, your verified badge request has been approved by $reviewerName. The verified badge will now appear on your news posts and reposts.'
            : 'Hello $recipientName, your verified badge request was reviewed by $reviewerName and was declined${note.isNotEmpty ? '. Note: $note' : '.'}. You can update your profile and reapply later.',
        accents: approved
            ? const <String>['Approved', 'Verified', 'Badge', 'News']
            : const <String>['Declined', 'Profile', 'Reapply', 'Review'],
      ),
      text: approved
          ? 'Hello $recipientName, your verified badge request has been approved by $reviewerName. The verified badge will now appear on your news posts and reposts.'
          : 'Hello $recipientName, your verified badge request was reviewed by $reviewerName and was declined${note.isNotEmpty ? '. Note: $note' : '.'}. You can update your profile and reapply later.',
      metadata: <String, dynamic>{
        'approved': approved,
        'reviewerName': reviewerName,
        if (note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<bool> sendWorkerLogNotification({
    required String toEmail,
    required String recipientName,
    required String farmName,
    required String action,
    required String detail,
  }) {
    final String subject = 'Farm activity update for $farmName';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'worker_log',
      html: _shell(
        subject: subject,
        eyebrow: 'Work log',
        headline: '$action recorded',
        body:
            'Hello $recipientName, an activity update was recorded for $farmName. $detail This email helps keep owners, co-owners, and managers aligned with what happened on the farm.',
        accents: const <String>['Workers', 'Owners', 'Activity', 'Log'],
      ),
      text:
          'Hello $recipientName, an activity update was recorded for $farmName. $detail This email helps keep owners, co-owners, and managers aligned with what happened on the farm.',
      metadata: <String, dynamic>{
        'farmName': farmName,
        'action': action,
      },
    );
  }

  Future<bool> sendScheduleNotification({
    required String toEmail,
    required String recipientName,
    required String farmName,
    required String taskTitle,
    required String dueLabel,
    required String detail,
  }) {
    final String subject = 'Schedule update for $farmName';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'schedule',
      html: _shell(
        subject: subject,
        eyebrow: 'Schedule',
        headline: taskTitle,
        body:
            'Hello $recipientName, a scheduled task for $farmName is now ready to review. Due: $dueLabel. $detail Use this reminder to keep the work on track and update the team when it is completed.',
        accents: const <String>['Reminder', 'Due date', 'Task', 'Farm'],
      ),
      text:
          'Hello $recipientName, a scheduled task for $farmName is now ready to review. Due: $dueLabel. $detail Use this reminder to keep the work on track and update the team when it is completed.',
      metadata: <String, dynamic>{
        'farmName': farmName,
        'taskTitle': taskTitle,
        'dueLabel': dueLabel,
      },
    );
  }

  Future<bool> sendSaleNotification({
    required String toEmail,
    required String recipientName,
    required String farmName,
    required String productName,
    required double quantity,
    required String unit,
    required double amount,
  }) {
    final String subject = 'Sale recorded for $farmName';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'sale',
      html: _shell(
        subject: subject,
        eyebrow: 'Finance',
        headline: 'Sale recorded successfully',
        body:
            'Hello $recipientName, a sale has been recorded for $farmName. Product: $productName. Quantity: ${quantity.toStringAsFixed(2)} $unit. Value: ${amount.toStringAsFixed(2)}. The email record helps with profit tracking and stock reconciliation.',
        accents: const <String>['Sale', 'Stock', 'Profit', 'Receipt'],
      ),
      text:
          'Hello $recipientName, a sale has been recorded for $farmName. Product: $productName. Quantity: ${quantity.toStringAsFixed(2)} $unit. Value: ${amount.toStringAsFixed(2)}. The email record helps with profit tracking and stock reconciliation.',
      metadata: <String, dynamic>{
        'farmName': farmName,
        'productName': productName,
        'amount': amount,
      },
    );
  }

  Future<bool> sendProcurementNotification({
    required String toEmail,
    required String recipientName,
    required String farmName,
    required String productName,
    required double quantity,
    required String unit,
    required double amount,
  }) {
    final String subject = 'Procurement recorded for $farmName';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'procurement',
      html: _shell(
        subject: subject,
        eyebrow: 'Finance',
        headline: 'Procurement logged',
        body:
            'Hello $recipientName, a procurement record has been saved for $farmName. Product: $productName. Quantity: ${quantity.toStringAsFixed(2)} $unit. Total cost: ${amount.toStringAsFixed(2)}. This keeps supply history and receipts easy to review later.',
        accents: const <String>['Procurement', 'Receipt', 'Inventory', 'Cost'],
      ),
      text:
          'Hello $recipientName, a procurement record has been saved for $farmName. Product: $productName. Quantity: ${quantity.toStringAsFixed(2)} $unit. Total cost: ${amount.toStringAsFixed(2)}. This keeps supply history and receipts easy to review later.',
      metadata: <String, dynamic>{
        'farmName': farmName,
        'productName': productName,
        'amount': amount,
      },
    );
  }

  Future<bool> sendExpenseNotification({
    required String toEmail,
    required String recipientName,
    required String farmName,
    required String title,
    required double amount,
  }) {
    final String subject = 'Expense recorded for $farmName';
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'expense',
      html: _shell(
        subject: subject,
        eyebrow: 'Expense',
        headline: 'Expense saved',
        body:
            'Hello $recipientName, an expense entry has been recorded for $farmName. Title: $title. Amount: ${amount.toStringAsFixed(2)}. If you attached a receipt, it is stored with this record for review and reporting.',
        accents: const <String>['Expense', 'Receipt', 'Report', 'Review'],
      ),
      text:
          'Hello $recipientName, an expense entry has been recorded for $farmName. Title: $title. Amount: ${amount.toStringAsFixed(2)}. If you attached a receipt, it is stored with this record for review and reporting.',
      metadata: <String, dynamic>{
        'farmName': farmName,
        'title': title,
        'amount': amount,
      },
    );
  }

  Future<bool> sendSystemNotification({
    required String toEmail,
    required String recipientName,
    required String subject,
    required String headline,
    required String body,
    List<String> accents = const <String>[],
    String eyebrow = 'System notice',
  }) {
    return _send(
      toEmail: toEmail,
      subject: subject,
      template: 'system_notification',
      html: _shell(
        subject: subject,
        eyebrow: eyebrow,
        headline: headline,
        body: 'Hello $recipientName, $body',
        accents: accents.isEmpty ? const <String>['FarmSync', 'Update', 'Notice'] : accents,
      ),
      text: 'Hello $recipientName, $body',
      metadata: <String, dynamic>{
        'audience': 'system',
      },
    );
  }

  Future<bool> _send({
    required String toEmail,
    required String subject,
    required String template,
    required String html,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    if (endpoint.trim().isEmpty || toEmail.trim().isEmpty) {
      return false;
    }
    try {
      final http.Response response = await http.post(
        Uri.parse(endpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (apiKey.trim().isNotEmpty) 'X-FarmSync-Email-Key': apiKey.trim(),
        },
        body: jsonEncode(<String, dynamic>{
          'to': toEmail.trim(),
          'subject': subject,
          'template': template,
          'html': html,
          'text': text,
          'clientName': clientName,
          'metadata': metadata ?? <String, dynamic>{},
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint('[Email] send failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (error) {
      debugPrint('[Email] send error: $error');
      return false;
    }
  }

  String _shell({
    required String subject,
    required String eyebrow,
    required String headline,
    required String body,
    required List<String> accents,
  }) {
    final String accentHtml = accents
        .map(
          (String item) => '<span style="display:inline-block;margin:0 8px 8px 0;padding:8px 12px;border-radius:999px;background:#E8F4D8;color:#23452D;font-weight:600;font-size:12px;">$item</span>',
        )
        .join();
    return '''
<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#f6f8f3;font-family:Arial,Helvetica,sans-serif;color:#203026;">
    <div style="max-width:640px;margin:0 auto;padding:24px;">
      <div style="background:linear-gradient(135deg,#173221,#274c32 60%,#8cbf72);border-radius:28px;padding:28px 26px;color:#fff;box-shadow:0 14px 36px rgba(18,39,24,.18);">
        <div style="font-size:12px;letter-spacing:.16em;text-transform:uppercase;opacity:.8;">$eyebrow</div>
        <h1 style="margin:14px 0 10px;font-size:32px;line-height:1.15;">$headline</h1>
        <p style="margin:0;font-size:15px;line-height:1.7;max-width:520px;opacity:.94;">$body</p>
      </div>
      <div style="background:#fff;border-radius:24px;margin-top:18px;padding:22px;border:1px solid #e5eadf;">
        <div style="font-size:18px;font-weight:700;margin-bottom:10px;">$subject</div>
        <div style="font-size:14px;line-height:1.75;color:#46564c;">FarmSync keeps your work visible, your records organized, and your team in the loop.</div>
        <div style="margin-top:16px;">$accentHtml</div>
      </div>
      <div style="text-align:center;color:#6b776d;font-size:12px;line-height:1.7;padding:18px 12px;">Sent by $clientName. If you did not expect this email, contact your farm admin or support team.</div>
    </div>
  </body>
</html>
''';
  }
}
