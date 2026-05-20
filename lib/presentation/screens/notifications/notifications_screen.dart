import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/models/notification.dart';
import '../../../providers/notification_provider.dart';
import 'widgets/notification_item.dart';

/// Notifications screen displaying all app notifications.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(notificationsProvider.notifier).unreadCount;
    final readCount = ref.watch(notificationsProvider.notifier).readCount;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/dashboard'),
              ),
        title: Text(
          'Notifications',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Read all'),
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _showClearAllDialog(context, ref),
              tooltip: 'Clear all notifications',
            ),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unreadCount',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(context)
          : _buildNotificationsList(context, ref, notifications, unreadCount, readCount),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
              borderRadius: BorderRadius.circular(34),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No notifications yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see important updates here',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    WidgetRef ref,
    List<Notification> notifications,
    int unreadCount,
    int readCount,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _InboxSummary(
          totalCount: notifications.length,
          unreadCount: unreadCount,
          readCount: readCount,
          onReadAll: unreadCount == 0 ? null : () => ref.read(notificationsProvider.notifier).markAllAsRead(),
          onClearAll: () => _showClearAllDialog(context, ref),
        ),
        const SizedBox(height: 14),
        ...notifications.map((Notification notification) {
          return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NotificationItem(
            notification: notification,
            onTap: () => _onNotificationTap(context, ref, notification),
            onToggleRead: () => ref.read(notificationsProvider.notifier).toggleRead(notification.id),
            onDismiss: () => _removeNotification(context, ref, notification),
          ),
        );
        }),
      ],
    );
  }

  void _onNotificationTap(BuildContext context, WidgetRef ref, Notification notification) {
    ref.read(notificationsProvider.notifier).markAsRead(notification.id);
    context.go('/notifications/${notification.id}', extra: notification);
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(notificationsProvider.notifier).clearAllNotifications();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications cleared')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _removeNotification(BuildContext context, WidgetRef ref, Notification notification) {
    ref.read(notificationsProvider.notifier).removeNotification(notification.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(notificationsProvider.notifier).restoreNotification(notification);
          },
        ),
      ),
    );
  }
}

class _InboxSummary extends StatelessWidget {
  const _InboxSummary({
    required this.totalCount,
    required this.unreadCount,
    required this.readCount,
    required this.onReadAll,
    required this.onClearAll,
  });

  final int totalCount;
  final int unreadCount;
  final int readCount;
  final VoidCallback? onReadAll;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: <Color>[
            theme.colorScheme.primaryContainer.withOpacity(0.42),
            theme.colorScheme.secondaryContainer.withOpacity(0.24),
          ],
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.notifications_active_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$unreadCount unread of $totalCount',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _SummaryPill(label: 'Unread', value: '$unreadCount'),
              _SummaryPill(label: 'Read', value: '$readCount'),
              _SummaryPill(label: 'Total', value: '$totalCount'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReadAll,
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Mark all read'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClearAll,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}
