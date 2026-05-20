import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/notification.dart';
import '../../../providers/notification_provider.dart';

/// Detailed view of a single notification.
class NotificationDetailScreen extends ConsumerWidget {
  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  final Notification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Notification currentNotification = ref
        .watch(notificationsProvider)
        .firstWhere((Notification item) => item.id == notification.id, orElse: () => notification);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }
            context.go('/notifications');
          },
        ),
        title: Text(
          'Notification Details',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: currentNotification.isRead ? 'Mark as unread' : 'Mark as read',
            onPressed: () => ref.read(notificationsProvider.notifier).toggleRead(currentNotification.id),
            icon: Icon(currentNotification.isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined),
          ),
          IconButton(
            tooltip: 'Delete notification',
            onPressed: () => _confirmDelete(context, ref, currentNotification),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          if (currentNotification.actionUrl != null)
            TextButton(
              onPressed: () => _handleAction(context, currentNotification),
              child: Text(
                'Take Action',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(context, currentNotification),
            const SizedBox(height: 24),
            _buildContent(context, currentNotification),
            const SizedBox(height: 24),
            _buildMetadata(context, currentNotification),
            if (currentNotification.metadata != null) ...<Widget>[
              const SizedBox(height: 24),
              _buildAdditionalInfo(context, currentNotification),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Notification notification) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildLargeIcon(context, notification),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                notification.title,
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getTypeColor(context, notification).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getTypeColor(context, notification).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  notification.type.name.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getTypeColor(context, notification),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLargeIcon(BuildContext context, Notification notification) {
    IconData iconData;
    final Color iconColor = _getTypeColor(context, notification);

    switch (notification.type) {
      case NotificationType.info:
        iconData = Icons.info;
      case NotificationType.warning:
        iconData = Icons.warning_amber;
      case NotificationType.success:
        iconData = Icons.check_circle;
      case NotificationType.error:
        iconData = Icons.error;
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 32,
      ),
    );
  }

  Widget _buildContent(BuildContext context, Notification notification) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Message',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            notification.message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, Notification notification) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.access_time,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Received ${_formatDetailedTimestamp(notification.timestamp)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: notification.isRead
                  ? theme.colorScheme.secondary.withOpacity(0.1)
                  : theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              notification.isRead ? 'Read' : 'Unread',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: notification.isRead
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo(BuildContext context, Notification notification) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Additional Information',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...notification.metadata!.entries.map((MapEntry<String, dynamic> entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${entry.key}: ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getTypeColor(BuildContext context, Notification notification) {
    final ThemeData theme = Theme.of(context);

    switch (notification.type) {
      case NotificationType.info:
        return theme.colorScheme.primary;
      case NotificationType.warning:
        return theme.colorScheme.tertiary;
      case NotificationType.success:
        return theme.colorScheme.secondary;
      case NotificationType.error:
        return theme.colorScheme.error;
    }
  }

  String _formatDetailedTimestamp(DateTime timestamp) {
    return DateFormat('EEEE, MMMM d, y \'at\' h:mm a').format(timestamp);
  }

  void _handleAction(BuildContext context, Notification notification) {
    if (notification.actionUrl == null || notification.actionUrl!.isEmpty) {
      return;
    }
    context.go(notification.actionUrl!);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Notification notification) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete notification?'),
        content: const Text('This notification will be removed from your inbox.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    ref.read(notificationsProvider.notifier).removeNotification(notification.id);
    if (context.mounted) {
      context.go('/notifications');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => ref.read(notificationsProvider.notifier).restoreNotification(notification),
          ),
        ),
      );
    }
  }
}
