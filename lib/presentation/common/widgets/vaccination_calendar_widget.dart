import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/farm_notification_service.dart';
import '../../../core/services/vaccination_schedule_service.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/livestock_provider.dart';

/// Displays the vaccination and health calendar for a livestock group.
class VaccinationCalendarWidget extends ConsumerStatefulWidget {
  const VaccinationCalendarWidget({
    super.key,
    required this.livestock,
  });

  final Livestock livestock;

  @override
  ConsumerState<VaccinationCalendarWidget> createState() =>
      _VaccinationCalendarWidgetState();
}

class _VaccinationCalendarWidgetState
    extends ConsumerState<VaccinationCalendarWidget> {
  late List<VaccinationScheduleItem> _schedule;
  bool _isBatchScheduling = false;

  @override
  void initState() {
    super.initState();
    _schedule =
        VaccinationScheduleService.generateSchedule(widget.livestock);
  }

  /// Re-checked against the live livestock group on every build instead of
  /// tracked in local widget state, which used to reset to "nothing
  /// scheduled yet" every time this widget was rebuilt (e.g. navigating
  /// back to the screen) even though the reminder had actually been saved.
  bool _isScheduled(VaccinationScheduleItem item) {
    return widget.livestock.todoItems.any((FarmTodoItem todo) =>
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
              child: Icon(Icons.health_and_safety_rounded,
                  size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Vaccination & Health', style: theme.textTheme.titleLarge),
                  Text(
                    '${_schedule.length} interventions for ${_speciesLabel(widget.livestock.species)}',
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
              label: Text(_isBatchScheduling ? 'Creating...' : 'Schedule all'),
            ),
          ),
        ],
        const SizedBox(height: 14),
        ..._schedule.map(_buildTile),
        if (_schedule.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                'No health interventions generated. Add age and species details.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTile(VaccinationScheduleItem item) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isScheduled = _isScheduled(item);

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
          onTap: isScheduled ? null : () => _scheduleSingle(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Text(item.vaccineEmoji,
                        style: const TextStyle(fontSize: 18)),
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
                      const SizedBox(height: 3),
                      Text(
                        item.detail,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Icon(Icons.event_rounded,
                              size: 13, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '${item.ageMonths}mo · ${item.suggestedDate.day}/${item.suggestedDate.month}/${item.suggestedDate.year}',
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
                      onTap: () => _scheduleSingle(item),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Text(
                          'Add',
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

  Future<void> _batchCreateReminders() async {
    if (_isBatchScheduling) return;

    final List<VaccinationScheduleItem> remaining = _schedule
        .where((VaccinationScheduleItem item) => !_isScheduled(item))
        .toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All health reminders are already created.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isBatchScheduling = true);

    try {
      final List<FarmTodoItem> todos = remaining
          .map((VaccinationScheduleItem item) => item.toTodoItem())
          .toList();

      final List<FarmTodoItem> updated =
          List<FarmTodoItem>.from(widget.livestock.todoItems);
      updated.addAll(todos);

      await ref.read(livestockProvider.notifier).updateLivestock(
            widget.livestock.copyWith(
              todoItems: updated,
              updatedAt: DateTime.now(),
              isSynced: false,
            ),
          );

      for (final FarmTodoItem todo in todos) {
        if (!todo.pushNotificationEnabled) continue;
        final DateTime scheduledAt = todo.dueDate.isBefore(DateTime.now())
            ? DateTime.now().add(const Duration(minutes: 1))
            : todo.dueDate;
        await FarmNotificationService.instance.scheduleAt(
          id: todo.id.hashCode,
          title: 'Health reminder: ${todo.title}',
          body: todo.notes.isEmpty
              ? '${_speciesLabel(widget.livestock.species)} health task is due.'
              : todo.notes,
          scheduledAt: scheduledAt,
          payload: '/livestock',
        );
      }

      if (!mounted) return;
      setState(() => _isBatchScheduling = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${todos.length} health reminders created!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBatchScheduling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _scheduleSingle(VaccinationScheduleItem item) async {
    if (_isScheduled(item)) return;

    try {
      final FarmTodoItem todo = item.toTodoItem();
      final List<FarmTodoItem> updated =
          List<FarmTodoItem>.from(widget.livestock.todoItems);
      updated.add(todo);

      await ref.read(livestockProvider.notifier).updateLivestock(
            widget.livestock.copyWith(
              todoItems: updated,
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
          title: 'Health reminder: ${todo.title}',
          body: todo.notes.isEmpty
              ? '${_speciesLabel(widget.livestock.species)} health task is due.'
              : todo.notes,
          scheduledAt: scheduledAt,
          payload: '/livestock',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item.title}" added!'),
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

  String _speciesLabel(LivestockSpecies species) {
    switch (species) {
      case LivestockSpecies.goat:
        return 'Goats';
      case LivestockSpecies.chicken:
        return 'Chickens';
      case LivestockSpecies.pig:
        return 'Pigs';
      case LivestockSpecies.cattle:
        return 'Cattle';
      case LivestockSpecies.sheep:
        return 'Sheep';
      case LivestockSpecies.rabbit:
        return 'Rabbits';
      case LivestockSpecies.duck:
        return 'Ducks';
      case LivestockSpecies.fish:
        return 'Fish';
      case LivestockSpecies.snail:
        return 'Snails';
    }
  }
}
