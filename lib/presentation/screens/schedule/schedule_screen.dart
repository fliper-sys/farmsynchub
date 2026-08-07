import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/services/farm_notification_service.dart';
import '../../../core/theme/app_colors.dart';
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

enum _ScheduleViewMode { list, calendar }

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

  DateTime get day => DateTime(dueDate.year, dueDate.month, dueDate.day);
}

/// A friendly schedule showing every farm, crop, and livestock reminder.
/// Offers two views: a grouped list (Overdue / Today / Tomorrow / This
/// week / Later - the same day-label language used across the rest of the
/// app) and a calendar, where tapping a day expands to show that day's
/// items and lets the farmer create a new task for it.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  _ScheduleViewMode _viewMode = _ScheduleViewMode.list;
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: () => _openCropTaskSheet(context, ref, crop, task: task),
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
              onTap: () =>
                  _openLivestockTaskSheet(context, ref, item, task: task),
            ),
    ]..sort(
        (_ScheduleEntry a, _ScheduleEntry b) => a.dueDate.compareTo(b.dueDate));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? GoRouterHelper(context).pop() : context.go('/dashboard'),
        ),
        title: const Text('Schedule'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ViewModeToggle(
              mode: _viewMode,
              onChanged: (_ScheduleViewMode mode) =>
                  setState(() => _viewMode = mode),
            ),
          ),
        ],
      ),
      floatingActionButton: _viewMode == _ScheduleViewMode.calendar
          ? FloatingActionButton.extended(
              onPressed: () => _pickTaskTarget(
                context,
                ref,
                farms: farms,
                crops: crops,
                livestock: livestock,
                day: _selectedDay ?? DateTime.now(),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add task'),
            )
          : null,
      body: _viewMode == _ScheduleViewMode.list
          ? _ListView(entries: entries)
          : _CalendarView(
              entries: entries,
              focusedMonth: _focusedMonth,
              selectedDay: _selectedDay,
              onMonthChanged: (DateTime month) =>
                  setState(() => _focusedMonth = month),
              onDaySelected: (DateTime day) =>
                  setState(() => _selectedDay = day),
              onAddForDay: (DateTime day) => _pickTaskTarget(
                context,
                ref,
                farms: farms,
                crops: crops,
                livestock: livestock,
                day: day,
              ),
            ),
    );
  }

  Future<void> _pickTaskTarget(
    BuildContext context,
    WidgetRef ref, {
    required List<Farm> farms,
    required List<Crop> crops,
    required List<Livestock> livestock,
    required DateTime day,
  }) async {
    final DateTime seededDueDate =
        DateTime(day.year, day.month, day.day, 9);

    final String? target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _TaskTargetSheet(
        hasFarms: farms.isNotEmpty,
        hasCrops: crops.isNotEmpty,
        hasLivestock: livestock.isNotEmpty,
      ),
    );
    if (target == null || !context.mounted) return;

    switch (target) {
      case 'farm':
        if (farms.isEmpty) return;
        final Farm? farm = farms.length == 1
            ? farms.first
            : await _pickEntity<Farm>(
                context,
                title: 'Choose a farm',
                items: farms,
                labelBuilder: (Farm f) => f.name,
              );
        if (farm == null || !context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FarmDetailScreen(
              farmId: farm.id,
              initialSection: 'taskCalendar',
            ),
          ),
        );
        break;
      case 'crop':
        if (crops.isEmpty) return;
        final Crop? crop = crops.length == 1
            ? crops.first
            : await _pickEntity<Crop>(
                context,
                title: 'Choose a crop',
                items: crops,
                labelBuilder: (Crop c) => c.name,
              );
        if (crop == null || !context.mounted) return;
        await _openCropTaskSheet(context, ref, crop,
            initialDueDate: seededDueDate);
        break;
      case 'livestock':
        if (livestock.isEmpty) return;
        final Livestock? item = livestock.length == 1
            ? livestock.first
            : await _pickEntity<Livestock>(
                context,
                title: 'Choose an animal group',
                items: livestock,
                labelBuilder: (Livestock l) => _speciesLabel(l.species),
              );
        if (item == null || !context.mounted) return;
        await _openLivestockTaskSheet(context, ref, item,
            initialDueDate: seededDueDate);
        break;
    }
  }

  Future<T?> _pickEntity<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required String Function(T) labelBuilder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _EntityPickerSheet<T>(
        title: title,
        items: items,
        labelBuilder: labelBuilder,
      ),
    );
  }

  Future<void> _openCropTaskSheet(
    BuildContext context,
    WidgetRef ref,
    Crop crop, {
    FarmTodoItem? task,
    DateTime? initialDueDate,
  }) async {
    final FarmTodoItem? updated = await showModalBottomSheet<FarmTodoItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => TodoEditSheet(
        entityName: crop.name,
        initialTask: task,
        initialDueDate: initialDueDate,
        onDelete: task == null
            ? null
            : () => _deleteCropTask(context, ref, crop, task),
      ),
    );
    if (updated == null) return;

    await FarmNotificationService.instance.cancel(updated.id.hashCode);
    final List<FarmTodoItem> items = List<FarmTodoItem>.of(crop.todoItems);
    final int idx =
        items.indexWhere((FarmTodoItem item) => item.id == updated.id);
    if (idx >= 0) {
      items[idx] = updated;
    } else {
      items.add(updated);
    }
    await ref.read(cropsProvider.notifier).updateCrop(
          crop.copyWith(
            todoItems: items,
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
    if (context.mounted) {
      context.showSnackBar(task == null ? 'Reminder created.' : 'Reminder updated.');
    }
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

  Future<void> _openLivestockTaskSheet(
    BuildContext context,
    WidgetRef ref,
    Livestock item, {
    FarmTodoItem? task,
    DateTime? initialDueDate,
  }) async {
    final FarmTodoItem? updated = await showModalBottomSheet<FarmTodoItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => TodoEditSheet(
        entityName: _speciesLabel(item.species),
        initialTask: task,
        initialDueDate: initialDueDate,
        onDelete: task == null
            ? null
            : () => _deleteLivestockTask(context, ref, item, task),
      ),
    );
    if (updated == null) return;

    await FarmNotificationService.instance.cancel(updated.id.hashCode);
    final List<FarmTodoItem> items = List<FarmTodoItem>.of(item.todoItems);
    final int idx =
        items.indexWhere((FarmTodoItem existing) => existing.id == updated.id);
    if (idx >= 0) {
      items[idx] = updated;
    } else {
      items.add(updated);
    }
    await ref.read(livestockProvider.notifier).updateLivestock(
          item.copyWith(
            todoItems: items,
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
    if (context.mounted) {
      context.showSnackBar(task == null ? 'Reminder created.' : 'Reminder updated.');
    }
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

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onChanged});

  final _ScheduleViewMode mode;
  final ValueChanged<_ScheduleViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ToggleSegment(
            icon: Icons.view_agenda_rounded,
            selected: mode == _ScheduleViewMode.list,
            onTap: () => onChanged(_ScheduleViewMode.list),
          ),
          _ToggleSegment(
            icon: Icons.calendar_month_rounded,
            selected: mode == _ScheduleViewMode.calendar,
            onTap: () => onChanged(_ScheduleViewMode.calendar),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.entries});

  final List<_ScheduleEntry> entries;

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
      final DateTime day = entry.day;
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

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No reminders scheduled yet. Add one from a crop, animal group, or farm.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final Map<String, List<_ScheduleEntry>> grouped =
        _groupByFriendlyLabel(entries, referenceDate: DateTime.now());

    return ListView(
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
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.entries,
    required this.focusedMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
    required this.onAddForDay,
  });

  final List<_ScheduleEntry> entries;
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onAddForDay;

  Map<DateTime, List<_ScheduleEntry>> get _entriesByDay {
    final Map<DateTime, List<_ScheduleEntry>> map = <DateTime, List<_ScheduleEntry>>{};
    for (final _ScheduleEntry entry in entries) {
      map.putIfAbsent(entry.day, () => <_ScheduleEntry>[]).add(entry);
    }
    return map;
  }

  List<DateTime> _daysToDisplay() {
    final DateTime firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month);
    final DateTime lastOfMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final int leadingBlanks = firstOfMonth.weekday - DateTime.monday;
    final DateTime gridStart =
        firstOfMonth.subtract(Duration(days: leadingBlanks));
    final int totalCells =
        ((leadingBlanks + lastOfMonth.day) / 7).ceil() * 7;
    return List<DateTime>.generate(
        totalCells, (int i) => gridStart.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<DateTime, List<_ScheduleEntry>> byDay = _entriesByDay;
    final DateTime today = DateTime.now();
    final DateTime todayKey = DateTime(today.year, today.month, today.day);
    final List<DateTime> days = _daysToDisplay();
    final List<_ScheduleEntry> selectedEntries = selectedDay == null
        ? <_ScheduleEntry>[]
        : (byDay[selectedDay] ?? <_ScheduleEntry>[]);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => onMonthChanged(
                  DateTime(focusedMonth.year, focusedMonth.month - 1)),
            ),
            Expanded(
              child: Text(
                _monthLabel(focusedMonth),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => onMonthChanged(
                  DateTime(focusedMonth.year, focusedMonth.month + 1)),
            ),
          ],
        ),
        Row(
          children: <String>['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
              .map((String label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 46,
          ),
          itemBuilder: (BuildContext context, int index) {
            final DateTime day = days[index];
            final bool inMonth = day.month == focusedMonth.month;
            final bool isToday = day == todayKey;
            final bool isSelected = selectedDay != null && day == selectedDay;
            final int itemCount = byDay[day]?.length ?? 0;
            return Padding(
              padding: const EdgeInsets.all(2),
              child: InkWell(
                onTap: () => onDaySelected(day),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : isToday
                            ? theme.colorScheme.primary.withOpacity(0.12)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${day.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              isToday || isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : inMonth
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant
                                      .withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (itemCount > 0)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        if (selectedDay != null) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _dayHeaderLabel(selectedDay!),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => onAddForDay(selectedDay!),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add task'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (selectedEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nothing scheduled for this day yet.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (final _ScheduleEntry entry in selectedEntries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EntryTile(entry: entry),
              ),
          const SizedBox(height: 72),
        ],
      ],
    );
  }

  String _monthLabel(DateTime month) {
    const List<String> names = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${names[month.month - 1]} ${month.year}';
  }

  String _dayHeaderLabel(DateTime day) {
    final DateTime today = DateTime.now();
    final DateTime todayKey = DateTime(today.year, today.month, today.day);
    if (day == todayKey) return 'Today';
    if (day == todayKey.add(const Duration(days: 1))) return 'Tomorrow';
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${day.day} ${months[day.month - 1]} ${day.year}';
  }
}

class _TaskTargetSheet extends StatelessWidget {
  const _TaskTargetSheet({
    required this.hasFarms,
    required this.hasCrops,
    required this.hasLivestock,
  });

  final bool hasFarms;
  final bool hasCrops;
  final bool hasLivestock;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('New task for this day', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            ListTile(
              enabled: hasFarms,
              leading: const Icon(Icons.agriculture_rounded),
              title: const Text('Farm task'),
              subtitle: hasFarms ? null : const Text('Add a farm first'),
              onTap: hasFarms ? () => Navigator.of(context).pop('farm') : null,
            ),
            ListTile(
              enabled: hasCrops,
              leading: const Icon(Icons.spa_rounded),
              title: const Text('Crop reminder'),
              subtitle: hasCrops ? null : const Text('Add a crop first'),
              onTap: hasCrops ? () => Navigator.of(context).pop('crop') : null,
            ),
            ListTile(
              enabled: hasLivestock,
              leading: const Icon(Icons.pets_rounded),
              title: const Text('Livestock reminder'),
              subtitle: hasLivestock ? null : const Text('Add an animal group first'),
              onTap: hasLivestock
                  ? () => Navigator.of(context).pop('livestock')
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntityPickerSheet<T> extends StatelessWidget {
  const _EntityPickerSheet({
    required this.title,
    required this.items,
    required this.labelBuilder,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (BuildContext context, int index) => ListTile(
                  title: Text(labelBuilder(items[index])),
                  onTap: () => Navigator.of(context).pop(items[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Color _pastel() {
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
    final bool isDark = theme.brightness == Brightness.dark;
    final Color badgeColor = AppColors.chipBackgroundFor(
      _pastel(),
      isDark: isDark,
      surface: theme.colorScheme.surface,
    );
    final Color badgeIconColor = AppColors.chipForegroundFor(
      isDark: isDark,
      onSurface: theme.colorScheme.onSurface,
    );
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
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_sourceIcon, size: 20, color: badgeIconColor),
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
