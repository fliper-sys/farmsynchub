import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/crop_schedule_service.dart';
import '../../../core/services/farm_notification_service.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../providers/crop_provider.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Displays a week-by-week auto-generated calendar schedule for a crop,
/// with fertilizer, pesticide, irrigation, weeding, and harvest reminders.
class CropCalendarScheduleWidget extends ConsumerStatefulWidget {
  const CropCalendarScheduleWidget({
    super.key,
    required this.crop,
  });

  final Crop crop;

  @override
  ConsumerState<CropCalendarScheduleWidget> createState() =>
      _CropCalendarScheduleWidgetState();
}

class _CropCalendarScheduleWidgetState
    extends ConsumerState<CropCalendarScheduleWidget> {
  late List<CropScheduleItem> _schedule;
  final Set<int> _scheduledIndices = <int>{};
  bool _isBatchScheduling = false;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _schedule = CropScheduleService.generateSchedule(widget.crop);
    _summary = _schedule.isNotEmpty
        ? CropScheduleService.scheduleSummary(_schedule, widget.crop.name)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.calendar_month_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              'Calendar Schedule',
              style: theme.textTheme.titleLarge,
            ),
            const Spacer(),
            if (_schedule.isNotEmpty)
              TextButton.icon(
                onPressed: _batchCreateReminders,
                icon: _isBatchScheduling
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.event_note_rounded, size: 18),
                label: Text(
                    _isBatchScheduling ? 'Creating...' : 'Create all'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (_summary != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _summary!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        // Week-by-week grouped schedule
        ..._buildWeekGroups(context, theme),
        if (_schedule.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No schedule items generated for ${widget.crop.name}. '
                  'Add a planting date and variety to get suggestions.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildWeekGroups(
      BuildContext context, ThemeData theme) {
    final Map<String, List<CropScheduleItem>> grouped =
        CropScheduleService.groupByWeek(_schedule);
    final List<Widget> widgets = <Widget>[];

    for (final MapEntry<String, List<CropScheduleItem>> entry
        in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    entry.key,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${entry.value.length} items',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...entry.value.map((CropScheduleItem item) {
                final int index = _schedule.indexOf(item);
                final bool isScheduled = _scheduledIndices.contains(index);
                return _ScheduleActionTile(
                  item: item,
                  isScheduled: isScheduled,
                  onTap: () => _scheduleSingleReminder(item, index),
                );
              }),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Future<void> _batchCreateReminders() async {
    if (_isBatchScheduling) return;
    setState(() => _isBatchScheduling = true);

    try {
      final List<FarmTodoItem> todoItems =
          CropScheduleService.scheduleToTodoItems(_schedule);

      // Add all todo items to the crop
      final List<FarmTodoItem> updatedTodos =
          List<FarmTodoItem>.from(widget.crop.todoItems);
      updatedTodos.addAll(todoItems);

      await ref.read(cropsProvider.notifier).updateCrop(
            widget.crop.copyWith(
              todoItems: updatedTodos,
              updatedAt: DateTime.now(),
              isSynced: false,
            ),
          );

      for (final FarmTodoItem todo in todoItems) {
        if (!todo.pushNotificationEnabled) continue;
        final DateTime scheduledAt = todo.dueDate.isBefore(DateTime.now())
            ? DateTime.now().add(const Duration(minutes: 1))
            : todo.dueDate;
        await FarmNotificationService.instance.scheduleAt(
          id: todo.id.hashCode,
          title: 'Crop reminder: ${todo.title}',
          body: todo.notes.isEmpty
              ? '${widget.crop.name} task is due.'
              : todo.notes,
          scheduledAt: scheduledAt,
          payload: '/crops',
        );
      }

      if (!mounted) return;
      setState(() {
        _scheduledIndices
            .addAll(List<int>.generate(_schedule.length, (int i) => i));
        _isBatchScheduling = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${todoItems.length} reminders created for ${widget.crop.name}!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBatchScheduling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create reminders: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _scheduleSingleReminder(
      CropScheduleItem item, int index) async {
    if (_scheduledIndices.contains(index)) return;

    try {
      final FarmTodoItem todo = item.toTodoItem();
      final List<FarmTodoItem> updatedTodos =
          List<FarmTodoItem>.from(widget.crop.todoItems);
      updatedTodos.add(todo);

      await ref.read(cropsProvider.notifier).updateCrop(
            widget.crop.copyWith(
              todoItems: updatedTodos,
              updatedAt: DateTime.now(),
              isSynced: false,
            ),
          );

      if (todo.pushNotificationEnabled) {
        final DateTime scheduledAt = todo.dueDate.isBefore(DateTime.now())
            ? DateTime.now().add(const Duration(minutes: 1))
            : todo.dueDate;
        await FarmNotificationService.instance.scheduleAt(
          id: todo.id.hashCode,
          title: 'Crop reminder: ${todo.title}',
          body: todo.notes.isEmpty
              ? '${widget.crop.name} task is due.'
              : todo.notes,
          scheduledAt: scheduledAt,
          payload: '/crops',
        );
      }

      if (!mounted) return;
      setState(() => _scheduledIndices.add(index));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item.title}" added to tasks!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _ScheduleActionTile extends StatelessWidget {
  const _ScheduleActionTile({
    required this.item,
    required this.isScheduled,
    required this.onTap,
  });

  final CropScheduleItem item;
  final bool isScheduled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        color: isScheduled
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isScheduled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                // Action emoji badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isScheduled
                        ? theme.colorScheme.primary.withOpacity(0.15)
                        : _actionColor(theme, item.actionType).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      item.actionEmoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: isScheduled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Day ${item.dayOffset} — ${item.suggestedDate.day}/${item.suggestedDate.month}/${item.suggestedDate.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isScheduled)
                  Icon(Icons.check_circle_rounded,
                      size: 22, color: theme.colorScheme.primary)
                else
                  TextButton(
                    onPressed: onTap,
                    child: const Text('Schedule'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _actionColor(ThemeData theme, CropScheduleActionType type) {
    switch (type) {
      case CropScheduleActionType.planting:
        return Colors.green;
      case CropScheduleActionType.fertilizer:
        return Colors.orange;
      case CropScheduleActionType.pesticide:
        return Colors.red;
      case CropScheduleActionType.irrigation:
        return Colors.blue;
      case CropScheduleActionType.weeding:
        return Colors.brown;
      case CropScheduleActionType.scouting:
        return Colors.teal;
      case CropScheduleActionType.harvest:
        return Colors.amber;
      case CropScheduleActionType.general:
        return Colors.grey;
    }
  }
}
