import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/farm_notification_service.dart';
import '../../../core/services/vaccination_schedule_service.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/livestock_provider.dart';
import 'app_button.dart';
import 'app_card.dart';

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
  final Set<int> _scheduledIndices = <int>{};
  bool _isBatchScheduling = false;

  @override
  void initState() {
    super.initState();
    _schedule =
        VaccinationScheduleService.generateSchedule(widget.livestock);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.health_and_safety_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              'Vaccination & Health',
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
                    _isBatchScheduling ? 'Creating...' : 'Schedule all'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_schedule.length} interventions recommended for ${_speciesLabel(widget.livestock.species)}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        ..._schedule.map(_buildTile),
        if (_schedule.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No health interventions generated. Add age and species details.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTile(VaccinationScheduleItem item) {
    final ThemeData theme = Theme.of(context);
    final int index = _schedule.indexOf(item);
    final bool isScheduled = _scheduledIndices.contains(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        color: isScheduled
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isScheduled ? null : () => _scheduleSingle(item, index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _vaccineColor(theme, item.vaccineType)
                        .withOpacity(0.12),
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
                      const SizedBox(height: 4),
                      Text(
                        'Age: ${item.ageMonths} months | Due: ${item.suggestedDate.day}/${item.suggestedDate.month}/${item.suggestedDate.year}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isScheduled)
                  Icon(Icons.check_circle_rounded,
                      size: 20, color: theme.colorScheme.primary)
                else
                  TextButton(
                    onPressed: () => _scheduleSingle(item, index),
                    child: const Text('Add'),
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
    setState(() => _isBatchScheduling = true);

    try {
      final List<FarmTodoItem> todos = _schedule
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
      setState(() {
        _scheduledIndices
            .addAll(List<int>.generate(_schedule.length, (int i) => i));
        _isBatchScheduling = false;
      });

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

  Future<void> _scheduleSingle(VaccinationScheduleItem item, int index) async {
    if (_scheduledIndices.contains(index)) return;

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
      setState(() => _scheduledIndices.add(index));

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

  Color _vaccineColor(ThemeData theme, VaccineType type) {
    switch (type) {
      case VaccineType.core:
        return Colors.blue;
      case VaccineType.deworming:
        return Colors.brown;
      case VaccineType.booster:
        return Colors.orange;
      case VaccineType.healthCheck:
        return Colors.teal;
      case VaccineType.vitamin:
        return Colors.green;
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
    }
  }
}
