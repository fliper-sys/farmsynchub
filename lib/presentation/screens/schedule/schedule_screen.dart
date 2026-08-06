import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/services/farm_notification_service.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../common/widgets/todo_edit_sheet.dart';
import '../farms/farm_detail_screen.dart';

enum _ScheduleSourceType { farm, crop, livestock }

/// A single calendar entry, unified across farm workspace tasks, crop
/// reminders, and livestock reminders so they can share one schedule list.
class _ScheduleEntry {
  const _ScheduleEntry({
    required this.title,
    required this.dueDate,
    required this.isCompleted,
    required this.sourceType,
    required this.sourceLabel,
    required this.onTap,
  });

  final String title;
  final DateTime dueDate;
  final bool isCompleted;
  final _ScheduleSourceType sourceType;
  final String sourceLabel;
  final VoidCallback onTap;
}

/// A simple, friendly schedule list showing every farm, crop, and livestock
/// reminder grouped as Overdue / Today / Tomorrow / This week / Later - the
/// same day-label language used across the rest of the app - instead of a
/// numeric calendar grid.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Crop> crops = ref.watch(cropsProvider).valueOrNull ?? <Crop>[];
    final List<Livestock> livestock =
        ref.watch(livestockProvider).valueOrNull ?? <Livestock>[];

    final List<_ScheduleEntry> entries = <_ScheduleEntry>[
      for (final Farm farm in farms)
        for (final FarmWorkspaceTask task in farm.workspaceTasks)
          if (!task.isCompleted)
            _ScheduleEntry(
              title: task.title,
              dueDate: task.dueAt,
              isCompleted: task.isCompleted,
              sourceType: _ScheduleSourceType.farm,
              sourceLabel: farm.name,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FarmDetailScreen(
                    farmId: farm.id,
                    initialSection: 'taskCalendar',
                  ),
                ),
              ),
            ),
      for (final Crop crop in crops)
        for (final FarmTodoItem task in crop.todoItems)
          if (!task.isCompleted)
            _ScheduleEntry(
              title: task.title,
              dueDate: task.dueDate,
              isCompleted: task.isCompleted,
              sourceType: _ScheduleSourceType.crop,
              sourceLabel: crop.name,
              onTap: () => _editCropTask(context, ref, crop, task),
            ),
      for (final Livestock item in livestock)
        for (final FarmTodoItem task in item.todoItems)
          if (!task.isCompleted)
            _ScheduleEntry(
              title: task.title,
              dueDate: task.dueDate,
              isCompleted: task.isCompleted,
              sourceType: _ScheduleSourceType.livestock,
              sourceLabel: _speciesLabel(item.species),
              onTap: () => _editLivestockTask(context, ref, item, task),
            ),
    ]..sort(
        (_ScheduleEntry a, _ScheduleEntry b) => a.dueDate.compareTo(b.dueDate));

    final Map<String, List<_ScheduleEntry>> grouped = _groupByFriendlyLabel(
      entries,
      referenceDate: DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? GoRouterHelper(context).pop() : context.go('/dashboard'),
        ),
        title: const Text('Schedule'),
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No reminders scheduled yet. Add one from a crop, animal group, or farm.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                for (final MapEntry<String, List<_ScheduleEntry>> group
                    in grouped.entries) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 6),
                    child: Text(
                      group.key,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: group.key == 'Overdue'
                              ? Theme.of(context).colorScheme.error
                              : null),
                    ),
                  ),
                  for (final _ScheduleEntry entry in group.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EntryTile(entry: entry),
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  Map<String, List<_ScheduleEntry>> _groupByFriendlyLabel(
    List<_ScheduleEntry> entries, {
    required DateTime referenceDate,
  }) {
    final DateTime today =
        DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final DateTime tomorrow = today.add(const Duration(days: 1));
    final DateTime endOfThisWeek = today.add(Duration(days: 7 - today.weekday));

    final Map<String, List<_ScheduleEntry>> grouped = <String, List<_ScheduleEntry>>{
      'Overdue': <_ScheduleEntry>[],
      'Today': <_ScheduleEntry>[],
      'Tomorrow': <_ScheduleEntry>[],
      'This week': <_ScheduleEntry>[],
      'Later': <_ScheduleEntry>[],
    };

    for (final _ScheduleEntry entry in entries) {
      final DateTime day =
          DateTime(entry.dueDate.year, entry.dueDate.month, entry.dueDate.day);
      if (day.isBefore(today)) {
        grouped['Overdue']!.add(entry);
      } else if (day == today) {
        grouped['Today']!.add(entry);
      } else if (day == tomorrow) {
        grouped['Tomorrow']!.add(entry);
      } else if (!day.isAfter(endOfThisWeek)) {
        grouped['This week']!.add(entry);
      } else {
        grouped['Later']!.add(entry);
      }
    }

    grouped.removeWhere(
        (String key, List<_ScheduleEntry> bucket) => bucket.isEmpty);
    return grouped;
  }

  Future<void> _editCropTask(
      BuildContext context, WidgetRef ref, Crop crop, FarmTodoItem task) async {
    final FarmTodoItem? updated = await showModalBottomSheet<FarmTodoItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => TodoEditSheet(
        entityName: crop.name,
        initialTask: task,
        onDelete: () => _deleteCropTask(context, ref, crop, task),
      ),
    );
    if (updated == null) return;

    await FarmNotificationService.instance.cancel(task.id.hashCode);
    await ref.read(cropsProvider.notifier).updateCrop(
          crop.copyWith(
            todoItems: crop.todoItems
                .map((FarmTodoItem item) =>
                    item.id == updated.id ? updated : item)
                .toList(),
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );
    if (updated.pushNotificationEnabled && !updated.isCompleted) {
      final DateTime scheduledAt = updated.dueDate.isBefore(DateTime.now())
          ? DateTime.now().add(const Duration(minutes: 1))
          : updated.dueDate;
      await FarmNotificationService.instance.scheduleAt(
        id: updated.id.hashCode,
        title: 'Crop reminder: ${updated.title}',
        body: updated.notes.isEmpty ? '${crop.name} is due.' : updated.notes,
        scheduledAt: scheduledAt,
        payload: '/crops',
      );
    }
    if (context.mounted) context.showSnackBar('Reminder updated.');
  }

  Future<void> _deleteCropTask(
      BuildContext context, WidgetRef ref, Crop crop, FarmTodoItem task) async {
    await FarmNotificationService.instance.cancel(task.id.hashCode);
    await ref.read(cropsProvider.notifier).updateCrop(
          crop.copyWith(
            todoItems: crop.todoItems
                .where((FarmTodoItem item) => item.id != task.id)
                .toList(),
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );
    if (context.mounted) context.showSnackBar('Reminder deleted.');
  }

  Future<void> _editLivestockTask(BuildContext context, WidgetRef ref,
      Livestock item, FarmTodoItem task) async {
    final FarmTodoItem? updated = await showModalBottomSheet<FarmTodoItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => TodoEditSheet(
        entityName: _speciesLabel(item.species),
        initialTask: task,
        onDelete: () => _deleteLivestockTask(context, ref, item, task),
      ),
    );
    if (updated == null) return;

    await FarmNotificationService.instance.cancel(task.id.hashCode);
    await ref.read(livestockProvider.notifier).updateLivestock(
          item.copyWith(
            todoItems: item.todoItems
                .map((FarmTodoItem existing) =>
                    existing.id == updated.id ? updated : existing)
                .toList(),
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );
    if (updated.pushNotificationEnabled && !updated.isCompleted) {
      final DateTime scheduledAt = updated.dueDate.isBefore(DateTime.now())
          ? DateTime.now().add(const Duration(minutes: 1))
          : updated.dueDate;
      await FarmNotificationService.instance.scheduleAt(
        id: updated.id.hashCode,
        title: 'Animal reminder: ${updated.title}',
        body: updated.notes.isEmpty
            ? '${_speciesLabel(item.species)} reminder is due.'
            : updated.notes,
        scheduledAt: scheduledAt,
        payload: '/livestock',
      );
    }
    if (context.mounted) context.showSnackBar('Reminder updated.');
  }

  Future<void> _deleteLivestockTask(BuildContext context, WidgetRef ref,
      Livestock item, FarmTodoItem task) async {
    await FarmNotificationService.instance.cancel(task.id.hashCode);
    await ref.read(livestockProvider.notifier).updateLivestock(
          item.copyWith(
            todoItems: item.todoItems
                .where((FarmTodoItem existing) => existing.id != task.id)
                .toList(),
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );
    if (context.mounted) context.showSnackBar('Reminder deleted.');
  }

  static String _speciesLabel(LivestockSpecies species) {
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

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final _ScheduleEntry entry;

  IconData get _sourceIcon {
    switch (entry.sourceType) {
      case _ScheduleSourceType.farm:
        return Icons.agriculture_rounded;
      case _ScheduleSourceType.crop:
        return Icons.spa_rounded;
      case _ScheduleSourceType.livestock:
        return Icons.pets_rounded;
    }
  }

  Color _tint(ThemeData theme) {
    switch (entry.sourceType) {
      case _ScheduleSourceType.farm:
        return const Color(0xFFFFEBD0);
      case _ScheduleSourceType.crop:
        return const Color(0xFFE8F4D8);
      case _ScheduleSourceType.livestock:
        return const Color(0xFFDFF1FF);
    }
  }

  String _timeLabel() {
    final String hh = entry.dueDate.hour.toString().padLeft(2, '0');
    final String mm = entry.dueDate.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _tint(theme),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_sourceIcon, size: 20, color: const Color(0xFF2E3A32)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.sourceLabel} · ${_timeLabel()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
