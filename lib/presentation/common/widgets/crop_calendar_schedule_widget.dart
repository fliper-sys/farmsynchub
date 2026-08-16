import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/crop_schedule_service.dart';
import '../../../core/services/farm_notification_service.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../providers/crop_provider.dart';

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

  /// A schedule item is "already created" when a matching reminder (same
  /// title, same day) already exists in the crop's todo list. This is
  /// re-checked against the live crop on every build instead of tracked in
  /// local widget state, which used to reset to "nothing scheduled yet"
  /// every time this widget was rebuilt (e.g. navigating back to the
  /// screen) even though the reminder had actually been saved.
  bool _isScheduled(CropScheduleItem item) {
    return widget.crop.todoItems.any((FarmTodoItem todo) =>
        todo.title == item.title && _isSameDay(todo.dueDate, item.suggestedDate));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.calendar_month_rounded,
                  size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Calendar Schedule', style: theme.textTheme.titleLarge),
                  if (_summary != null)
                    Text(
                      _summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_schedule.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isBatchScheduling ? null : _batchCreateReminders,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              icon: _isBatchScheduling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.event_note_rounded, size: 18),
              label: Text(_isBatchScheduling ? 'Creating...' : 'Create all'),
            ),
          ),
        ],
        const SizedBox(height: 14),
        // Week-by-week grouped schedule
        ..._buildWeekGroups(context, theme),
        if (_schedule.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                'No schedule items generated for ${widget.crop.name}. '
                'Add a planting date and variety to get suggestions.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
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
                  Text(
                    '${entry.value.length} item${entry.value.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...entry.value.map((CropScheduleItem item) {
                final bool isScheduled = _isScheduled(item);
                return _ScheduleActionTile(
                  item: item,
                  isScheduled: isScheduled,
                  onTap: () => _scheduleSingleReminder(item),
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

    final List<CropScheduleItem> remaining =
        _schedule.where((CropScheduleItem item) => !_isScheduled(item)).toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All reminders are already created.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isBatchScheduling = true);

    try {
      final List<FarmTodoItem> todoItems =
          CropScheduleService.scheduleToTodoItems(remaining);

      final List<FarmTodoItem> updatedTodos =
          List<FarmTodoItem>.from(widget.crop.todoItems)..addAll(todoItems);

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
      setState(() => _isBatchScheduling = false);

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

  Future<void> _scheduleSingleReminder(CropScheduleItem item) async {
    if (_isScheduled(item)) return;

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
    final ColorScheme scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isScheduled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isScheduled
                        ? scheme.primary.withOpacity(0.16)
                        : scheme.primary.withOpacity(0.10),
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
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(Icons.event_rounded,
                              size: 13, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'Day ${item.dayOffset} · ${item.suggestedDate.day}/${item.suggestedDate.month}/${item.suggestedDate.year}',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isScheduled)
                  Icon(Icons.check_circle_rounded,
                      size: 22, color: scheme.primary)
                else
                  Material(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onTap,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Text(
                          'Schedule',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
