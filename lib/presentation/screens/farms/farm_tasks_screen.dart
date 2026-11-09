import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/farm_notification_service.dart';
import '../../../core/services/farm_task_calendar_service.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../domain/models/farm.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/detail_ui.dart';
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
    final AppLanguage language = ref.watch(appLanguageProvider);
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
        title: Text(
          language.tr(
              en: 'Task center', ha: 'Cibiyar ayyuka', fr: 'Centre des taches'),
        ),
      ),
      body: SoftScreenScaffold(
        heroTitle: language.tr(
            en: 'Task center', ha: 'Cibiyar ayyuka', fr: 'Centre des taches'),
        heroSubtitle: language.tr(
          en: 'Every task across your farms, in one place — assign, schedule, and track completion.',
          ha: 'Kowanne aiki a gonakinku, a wuri daya — ba da aiki, tsara lokaci, da bin diddigin kammalawa.',
          fr: 'Chaque tache sur toutes vos fermes, en un seul endroit — assignez, planifiez et suivez l\'avancement.',
        ),
        heroIcon: Icons.checklist_rounded,
        heroVariant: FarmArtworkVariant.field,
        showHero: false,
        showArtwork: false,
        sections: <Widget>[
          FadeInUp(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF0E5A41), Color(0xFF2E9E5B)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF0E5A41).withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  ProgressRing(
                    value: stats.completionRate,
                    color: const Color(0xFFFFC800),
                    centerText:
                        '${(stats.completionRate * 100).round()}%',
                    caption: 'done',
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('Task center',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                          '${stats.total - stats.completed} open  ·  ${stats.overdueCount} overdue  ·  ${stats.completed} done',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC800),
                            foregroundColor: const Color(0xFF3A1F00),
                          ),
                          onPressed: () =>
                              _openFarmPicker(context, language, allFarms),
                          icon: const Icon(Icons.add_task_rounded),
                          label: const Text('New task'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _FilterChip(
                label: language.tr(
                    en: 'All farms', ha: 'Duk gonaki', fr: 'Toutes les fermes'),
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
                label: language.tr(en: 'All', ha: 'Duka', fr: 'Tout'),
                selected: _statusFilter == _TaskStatusFilter.all,
                onTap: () =>
                    setState(() => _statusFilter = _TaskStatusFilter.all),
              ),
              _FilterChip(
                label: language.tr(en: 'Open', ha: 'Bude', fr: 'Ouvert'),
                selected: _statusFilter == _TaskStatusFilter.open,
                onTap: () =>
                    setState(() => _statusFilter = _TaskStatusFilter.open),
              ),
              _FilterChip(
                label: language.tr(
                    en: 'Completed', ha: 'An Kammala', fr: 'Termine'),
                selected: _statusFilter == _TaskStatusFilter.completed,
                onTap: () =>
                    setState(() => _statusFilter = _TaskStatusFilter.completed),
              ),
              _FilterChip(
                label: language.tr(
                    en: 'Assigned to me',
                    ha: 'An ba ni',
                    fr: 'Qui me sont assignees'),
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
                  Text(
                      language.tr(
                          en: 'Completion', ha: 'Kammalawa', fr: 'Achevement'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SoftProgressBar(
                      progress: stats.completionRate,
                      tint: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
                  const SizedBox(height: 10),
                  Text(
                    language.tr(
                      en: '${stats.completed} of ${stats.total} tasks completed (${(stats.completionRate * 100).round()}%)',
                      ha: '${stats.completed} daga cikin ${stats.total} ayyuka an kammala (${(stats.completionRate * 100).round()}%)',
                      fr: '${stats.completed} sur ${stats.total} taches terminees (${(stats.completionRate * 100).round()}%)',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  if (stats.overdueCount > 0) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0524A).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        language.tr(
                          en: '${stats.overdueCount} overdue',
                          ha: '${stats.overdueCount} sun wuce lokaci',
                          fr: '${stats.overdueCount} en retard',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE0524A)),
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  language.tr(
                    en: 'No tasks match these filters yet.',
                    ha: 'Babu wani aiki da ya dace da wadannan tace-tace har yanzu.',
                    fr: 'Aucune tache ne correspond a ces filtres pour le moment.',
                  ),
                ),
              ),
            ),
          if (showOpenLists && overdue.isNotEmpty) ...<Widget>[
            SoftSectionTitle(
              title: language.tr(
                en: 'Overdue (${overdue.length})',
                ha: 'Sun wuce lokaci (${overdue.length})',
                fr: 'En retard (${overdue.length})',
              ),
            ),
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
            SoftSectionTitle(
              title:
                  language.tr(en: 'Completed', ha: 'An Kammala', fr: 'Termine'),
            ),
            if (completedEntries.isEmpty)
              AppCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    language.tr(
                      en: 'No completed tasks yet.',
                      ha: 'Babu wani aikin da aka kammala har yanzu.',
                      fr: 'Aucune tache terminee pour le moment.',
                    ),
                  ),
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

  void _openFarmPicker(
      BuildContext context, AppLanguage language, List<Farm> farms) {
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
                Text(
                    language.tr(
                      en: 'Which farm is this task for?',
                      ha: 'Wace gona ne wannan aiki na?',
                      fr: 'Pour quelle ferme est cette tache ?',
                    ),
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
    final DateTime now = DateTime.now();
    final bool done = task.isCompleted;
    final bool overdue = !done && task.dueAt.isBefore(now);
    final bool today = !done &&
        !overdue &&
        task.dueAt.year == now.year &&
        task.dueAt.month == now.month &&
        task.dueAt.day == now.day;
    const Color red = Color(0xFFE0524A);
    const Color amber = Color(0xFFD99A1E);
    const Color green = Color(0xFF2E9E5B);
    final Color accent = done
        ? green
        : overdue
            ? red
            : today
                ? amber
                : theme.colorScheme.primary;
    final String dueText = overdue
        ? 'Overdue · ${app_date.DateUtils.formatDateTime(task.dueAt)}'
        : today
            ? 'Today · ${app_date.DateUtils.formatDateTime(task.dueAt)}'
            : app_date.DateUtils.formatDateTime(task.dueAt);
    final String initials = task.assigneeName.trim().isEmpty
        ? ''
        : task.assigneeName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((String p) => p[0].toUpperCase())
            .join();

    Widget chip(String text, Color c, {IconData? icon}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: c.withOpacity(0.14),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 12, color: c),
                const SizedBox(width: 4),
              ],
              Text(text,
                  style: TextStyle(
                      color: c, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
        );

    return FadeInUp(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
          decoration: BoxDecoration(
            color: done
                ? theme.colorScheme.surface.withOpacity(0.7)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border(
              left: BorderSide(color: accent, width: 5),
              top: BorderSide(color: theme.colorScheme.outlineVariant),
              right: BorderSide(color: theme.colorScheme.outlineVariant),
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onToggle();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? green : Colors.transparent,
                      border: Border.all(
                          color: done ? green : accent, width: 2),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (Widget c, Animation<double> a) =>
                          ScaleTransition(scale: a, child: c),
                      child: done
                          ? const Icon(Icons.check_rounded,
                              key: ValueKey<bool>(true),
                              size: 18,
                              color: Colors.white)
                          : const SizedBox.shrink(key: ValueKey<bool>(false)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? theme.colorScheme.onSurfaceVariant : null,
                      ),
                    ),
                    if (task.details.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(task.details.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        chip(dueText, accent,
                            icon: overdue
                                ? Icons.warning_amber_rounded
                                : Icons.schedule_rounded),
                        chip(entry.farm.name,
                            theme.colorScheme.onSurfaceVariant,
                            icon: Icons.agriculture_rounded),
                        if (!done && task.status != FarmTaskStatus.open)
                          chip(
                              task.statusLabel,
                              task.status == FarmTaskStatus.blocked
                                  ? red
                                  : const Color(0xFF8B5CF6)),
                        if (initials.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              CircleAvatar(
                                radius: 11,
                                backgroundColor:
                                    theme.colorScheme.primary.withOpacity(0.2),
                                child: Text(initials,
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: theme.colorScheme.primary)),
                              ),
                              const SizedBox(width: 5),
                              Text(task.assigneeName,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700)),
                            ],
                          )
                        else
                          chip('Unassigned', amber,
                              icon: Icons.person_outline_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
