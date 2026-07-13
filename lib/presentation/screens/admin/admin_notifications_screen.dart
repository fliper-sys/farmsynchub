import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/admin_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import 'admin_locked_view.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  NotificationTypeChoice _type = NotificationTypeChoice.info;
  NotificationAudienceChoice _audience = NotificationAudienceChoice.all;
  String _targetUserId = 'all';
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdminWorkspaceState> adminAsync = ref.watch(adminWorkspaceProvider);
    final AdminWorkspaceState? adminState = adminAsync.valueOrNull;
    if (adminAsync.isLoading || adminState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (adminState.currentAdmin == null) {
      return const AdminLockedView(
        message: 'Use the hidden admin login to broadcast notifications to users.',
      );
    }

    final ThemeData theme = Theme.of(context);
    final List<UserProfile> users = adminState.users;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop() ? GoRouterHelper(context).pop() : context.go('/admin-dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Broadcast notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          AppCard(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Send a notification', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  AppTextField(controller: _titleController, label: 'Title', hint: 'Field reminder'),
                  const SizedBox(height: 12),
                  AppTextField(controller: _messageController, label: 'Message', hint: 'Explain the alert or update', maxLines: 4),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<NotificationTypeChoice>(
                          value: _type,
                          items: NotificationTypeChoice.values
                              .map((NotificationTypeChoice value) => DropdownMenuItem<NotificationTypeChoice>(
                                    value: value,
                                    child: Text(value.label),
                                  ))
                              .toList(growable: false),
                          onChanged: (NotificationTypeChoice? value) {
                            if (value != null) {
                              setState(() => _type = value);
                            }
                          },
                          decoration: const InputDecoration(labelText: 'Type'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<NotificationAudienceChoice>(
                          value: _audience,
                          items: NotificationAudienceChoice.values
                              .map((NotificationAudienceChoice value) => DropdownMenuItem<NotificationAudienceChoice>(
                                    value: value,
                                    child: Text(value.label),
                                  ))
                              .toList(growable: false),
                          onChanged: (NotificationAudienceChoice? value) {
                            if (value != null) {
                              setState(() {
                                _audience = value;
                                if (value == NotificationAudienceChoice.all) {
                                  _targetUserId = 'all';
                                }
                              });
                            }
                          },
                          decoration: const InputDecoration(labelText: 'Audience'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_audience == NotificationAudienceChoice.singleUser)
                    if (users.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('No user accounts are available yet.'),
                      )
                    else
                    DropdownButtonFormField<String>(
                      value: users.any((UserProfile user) => user.uid == _targetUserId) ? _targetUserId : null,
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: 'all',
                          child: Text('Select a user'),
                        ),
                        ...users.map(
                          (UserProfile user) => DropdownMenuItem<String>(
                            value: user.uid,
                            child: Text(
                              user.fullName.isNotEmpty
                                  ? '${user.fullName} (${user.email})'
                                  : user.email,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => _targetUserId = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Target user'),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _sending ? null : () => _send(context),
                    child: Text(_sending ? 'Sending...' : 'Send notification'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(BuildContext context) async {
    final String title = _titleController.text.trim();
    final String message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      context.showSnackBar('Title and message are required.', isError: true);
      return;
    }
    if (_audience == NotificationAudienceChoice.singleUser &&
        _targetUserId == 'all') {
      context.showSnackBar('Select a target user for a single-user notification.', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(adminWorkspaceProvider.notifier).sendBroadcastNotification(
            title: title,
            message: message,
            type: _type.firestoreValue,
            audience: _audience.firestoreValue,
            targetUserId: _audience == NotificationAudienceChoice.singleUser ? _targetUserId : null,
          );
      if (!mounted) return;
      context.showSnackBar('Notification sent.');
      _titleController.clear();
      _messageController.clear();
    } catch (error) {
      if (!mounted) return;
      context.showSnackBar('Could not send notification.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }
}

enum NotificationTypeChoice {
  info,
  warning,
  success,
  error,
}

extension on NotificationTypeChoice {
  String get label {
    switch (this) {
      case NotificationTypeChoice.info:
        return 'Info';
      case NotificationTypeChoice.warning:
        return 'Warning';
      case NotificationTypeChoice.success:
        return 'Success';
      case NotificationTypeChoice.error:
        return 'Error';
    }
  }

  String get firestoreValue => name;
}

enum NotificationAudienceChoice {
  all,
  singleUser,
}

extension on NotificationAudienceChoice {
  String get label {
    switch (this) {
      case NotificationAudienceChoice.all:
        return 'All users';
      case NotificationAudienceChoice.singleUser:
        return 'Single user';
    }
  }

  String get firestoreValue {
    switch (this) {
      case NotificationAudienceChoice.all:
        return 'all';
      case NotificationAudienceChoice.singleUser:
        return 'single';
    }
  }
}
