import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/farm_notification_service.dart';
import '../../../core/services/farm_task_calendar_service.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../domain/models/farm.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_progress_bar.dart';
import '../../common/widgets/soft_screen_scaffold.dart';
import 'farm_detail_screen.dart';

enum _TaskStatusFilter { all, open, completed }

class FarmTasksScreen extends ConsumerStatefulWidget {
  const FarmTasksScreen({super.key});

  @override
  ConsumerState<FarmTasksScreen> createState() => _FarmTasksScreenState();
}

class _FarmTasksScreenState extends ConsumerState<FarmTasksScreen> {
  String? _selectedFarmId;
  _TaskStatusFilter _statusFilter = _TaskStatusFilter.all;
  bool _assignedToMeOnly = false;

  @override
  Widget build(BuildContext context) {
    final List<FarmTaskEntry> allEntries =
        ref.watch(allFarmTaskEntriesProvider);
    final String? currentUid =
        ref.watch(firebaseServiceProvider).currentUser?.uid;
    final List<Farm> allFarms =
        ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final DateTime now = DateTime.now();

    final List<Farm> farmsWithTasks = <Farm>{
      for (final FarmTaskEntry entry in allEntries) entry.farm
    }.toList()
      ..sort((Farm a, Farm b) => a.name.compareTo(b.name));

    final List<FarmTaskEntry> statsEntries =
        allEntries.where((FarmTaskEntry entry) {
      if (_selectedFarmId != null && entry.farm.id != _selectedFarmId) {
        return false;
      }
      if (_assignedToMeOnly &&
          (currentUid == null || entry.task.assigneeId != currentUid)) {
        return false;
      }
      return true;
    }).toList(growable: false);

    final FarmTaskCompletionStats stats =
        FarmTaskCalendarService.completionStats(statsEntries,
            referenceDate: now);
    final List<FarmTaskEntry> overdue = FarmTaskCalendarService.overdueEntries(
        statsEntries,
        referenceDate: now);
    final Map<String, List<FarmTaskEntry>> weekGroups =
        FarmTaskCalendarService.groupEntriesByWeek(statsEntries,
            referenceDate: now);
    final List<FarmTaskEntry> completedEntries = statsEntries
        .where((FarmTaskEntry entry) => entry.task.isCompleted)
        .toList(growable: false)
      ..sort(
        (FarmTaskEntry a, FarmTaskEntry b) =>
            (b.task.completedAt ?? b.task.updatedAt)
                .compareTo(a.task.completedAt ?? a.task.updatedAt),
      );

    final bool showOpenLists = _statusFilter != _TaskStatusFilter.completed;
    final bool showCompletedList = _statusFilter != _TaskStatusFilter.open;
    final bool nothingToShow = statsEntries.isEmpty ||
        (!showOpenLists && completedEntries.isEmpty) ||
        (!showCompletedList && overdue.isEmpty && weekGroups.isEmpty);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go('/farms'),
        ),
        title: const Text('Task center'),
      ),
      body: SoftScreenScaffold(
        heroTitle: 'Task center',
        heroSubtitle:
            'Every task across your farms, in one place — assign, schedule, and track completion.',
        heroIcon: Icons.checklist_rounded,
        heroVariant: FarmArtworkVariant.field,
        heroBadge: '${stats.total - stats.completed} open tasks',
        trailing: _AddTaskButton(
          onTap: () => _openFarmPicker(context, allFarms),
        ),
        sections: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _FilterChip(
                label: 'All farms',
                selected: _selectedFarmId == null,
                onTap: () => setState(() => _selectedFarmId = null),
              ),
              for (final Farm farm in farmsWithTasks)
                _FilterChip(
                  label: farm.name,
                  selected: _selectedFarmId == farm.id,
                  onTap: () => setState(() => _selectedFarmId = farm.id),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _FilterChip(
                label: 'All',
                selected: _statusFilter == _TaskStatusFilter.all,
                onTap: () =>
                    setState(() => _statusFilter = _TaskStatusFilter.all),
              ),
              _FilterChip(
                label: 'Open',
                selected: _statusFilter == _TaskStatusFilter.open,
                onTap: () =>
                    setState(() => _statusFilter = _TaskStatusFilter.open),
              ),
              _FilterChip(
                label: 'Completed',
                selected: _statusFilter == _TaskStatusFilter.completed,
                onTap: () =>
                    setState(() => _statusFilter = _TaskStatusFilter.completed),
              ),
              _FilterChip(
                label: 'Assigned to me',
                selected: _assignedToMeOnly,
                onTap: () =>
                    setState(() => _assignedToMeOnly = !_assignedToMeOnly),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Completion',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SoftProgressBar(
                      progress: stats.completionRate,
                      tint: const Color(0xFFE5F5D8)),
                  const SizedBox(height: 10),
                  Text(
                    '${stats.completed} of ${stats.total} tasks completed (${(stats.completionRate * 100).round()}%)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  if (stats.overdueCount > 0) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBD0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${stats.overdueCount} overdue',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF284231)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (nothingToShow)
            AppCard(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No tasks match these filters yet.'),
              ),
            ),
          if (showOpenLists && overdue.isNotEmpty) ...<Widget>[
            SoftSectionTitle(title: 'Overdue (${overdue.length})'),
            ...overdue.map(
              (FarmTaskEntry entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FarmTaskRow(
                  entry: entry,
                  warm: true,
                  onToggle: () => _toggleComplete(entry),
                  onTap: () => _openFarm(entry.farm),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (showOpenLists)
            for (final MapEntry<String, List<FarmTaskEntry>> group
                in weekGroups.entries) ...<Widget>[
              SoftSectionTitle(title: group.key),
              ...group.value.map(
                (FarmTaskEntry entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FarmTaskRow(
                    entry: entry,
                    onToggle: () => _toggleComplete(entry),
                    onTap: () => _openFarm(entry.farm),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          if (showCompletedList) ...<Widget>[
            const SoftSectionTitle(title: 'Completed'),
            if (completedEntries.isEmpty)
              AppCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No completed tasks yet.'),
                ),
              )
            else
              ...completedEntries.take(30).map(
                    (FarmTaskEntry entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FarmTaskRow(
                        entry: entry,
                        onToggle: () => _toggleComplete(entry),
                        onTap: () => _openFarm(entry.farm),
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleComplete(FarmTaskEntry entry) async {
    final Farm farm = entry.farm;
    final FarmWorkspaceTask task = entry.task;
    final DateTime now = DateTime.now();
    final bool markDone = !task.isCompleted;
    final FarmWorkspaceTask updatedTask = task.copyWith(
      status: markDone ? FarmTaskStatus.done : FarmTaskStatus.open,
      completedAt: markDone ? now : null,
      clearCompletedAt: !markDone,
      updatedBy: 'Workspace',
      updatedAt: now,
    );
    final List<FarmWorkspaceTask> nextTasks = farm.workspaceTasks
        .map((FarmWorkspaceTask current) =>
            current.id == task.id ? updatedTask : current)
        .toList(growable: false);
    await ref.read(farmsProvider.notifier).updateFarm(
          farm.copyWith(
              workspaceTasks: nextTasks, updatedAt: now, isSynced: false),
        );
    if (markDone) {
      await FarmNotificationService.instance
          .cancel(updatedTask.id.hashCode.abs());
    }
  }

  void _openFarm(Farm farm) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FarmDetailScreen(farmId: farm.id, initialSection: 'taskCalendar'),
      ),
    );
  }

  void _openFarmPicker(BuildContext context, List<Farm> farms) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Which farm is this task for?',
                    style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: farms
                        .map(
                          (Farm farm) => ListTile(
                            title: Text(farm.name),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _openFarm(farm);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  const _AddTaskButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color selectedBackground = isDark
        ? Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.28),
            theme.colorScheme.surface)
        : theme.colorScheme.primary.withOpacity(0.14);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? selectedBackground : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _FarmTaskRow extends StatelessWidget {
  const _FarmTaskRow({
    required this.entry,
    required this.onToggle,
    required this.onTap,
    this.warm = false,
  });

  final FarmTaskEntry entry;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FarmWorkspaceTask task = entry.task;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: warm
              ? const Color(0xFFFFEBD0).withOpacity(0.35)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.35)),
        ),
        child: Row(
          children: <Widget>[
            Checkbox(value: task.isCompleted, onChanged: (_) => onToggle()),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(task.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.farm.name} • ${app_date.DateUtils.formatDateTime(task.dueAt)}${task.assigneeName.isNotEmpty ? ' • ${task.assigneeName}' : ''}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
