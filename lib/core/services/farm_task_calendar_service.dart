import '../../domain/models/farm.dart';

/// A workspace task paired with the farm it belongs to, used for cross-farm views.
class FarmTaskEntry {
  const FarmTaskEntry({
    required this.farm,
    required this.task,
  });

  final Farm farm;
  final FarmWorkspaceTask task;
}

/// Completion/overdue summary for a set of [FarmTaskEntry] items.
class FarmTaskCompletionStats {
  const FarmTaskCompletionStats({
    required this.total,
    required this.completed,
    required this.overdueCount,
  });

  final int total;
  final int completed;
  final int overdueCount;

  double get completionRate => total == 0 ? 0 : completed / total;
}

class FarmTaskCalendarService {
  static Map<String, List<FarmWorkspaceTask>> groupTasksByDay(
    List<FarmWorkspaceTask> tasks, {
    required DateTime referenceDate,
  }) {
    final Map<String, List<FarmWorkspaceTask>> grouped =
        <String, List<FarmWorkspaceTask>>{};
    final List<FarmWorkspaceTask> activeTasks = tasks
        .where((FarmWorkspaceTask task) => !task.isCompleted)
        .toList(growable: false);

    for (final FarmWorkspaceTask task in activeTasks) {
      final String key = _dayKey(task.dueAt);
      grouped.putIfAbsent(key, () => <FarmWorkspaceTask>[]).add(task);
    }

    for (final List<FarmWorkspaceTask> dayTasks in grouped.values) {
      dayTasks.sort((FarmWorkspaceTask a, FarmWorkspaceTask b) =>
          a.dueAt.compareTo(b.dueAt));
    }

    return grouped;
  }

  static List<FarmWorkspaceTask> upcomingTasks(
    List<FarmWorkspaceTask> tasks, {
    required DateTime referenceDate,
    int maxDays = 7,
  }) {
    final DateTime start =
        DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final DateTime end = start.add(Duration(days: maxDays));
    return tasks
        .where((FarmWorkspaceTask task) => !task.isCompleted)
        .where((FarmWorkspaceTask task) =>
            !task.dueAt.isBefore(start) &&
            task.dueAt.isBefore(end.add(const Duration(days: 1))))
        .toList(growable: false)
      ..sort((FarmWorkspaceTask a, FarmWorkspaceTask b) =>
          a.dueAt.compareTo(b.dueAt));
  }

  static List<FarmWorkspaceTask> todayAndUpcomingTasks(
    List<FarmWorkspaceTask> tasks, {
    required DateTime referenceDate,
    int maxDays = 7,
    int maxItems = 4,
  }) {
    final List<FarmWorkspaceTask> filtered =
        upcomingTasks(tasks, referenceDate: referenceDate, maxDays: maxDays);
    final DateTime today =
        DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final List<FarmWorkspaceTask> prioritized = <FarmWorkspaceTask>[];

    for (final FarmWorkspaceTask task in filtered) {
      final DateTime taskDay =
          DateTime(task.dueAt.year, task.dueAt.month, task.dueAt.day);
      if (taskDay == today) {
        prioritized.add(task);
      }
    }

    for (final FarmWorkspaceTask task in filtered) {
      final DateTime taskDay =
          DateTime(task.dueAt.year, task.dueAt.month, task.dueAt.day);
      if (taskDay != today && prioritized.length < maxItems) {
        prioritized.add(task);
      }
    }

    return prioritized.take(maxItems).toList(growable: false);
  }

  static String _dayKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  /// Incomplete entries whose due date has already passed, oldest first.
  static List<FarmTaskEntry> overdueEntries(
    List<FarmTaskEntry> entries, {
    required DateTime referenceDate,
  }) {
    final DateTime today =
        DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    return entries
        .where((FarmTaskEntry entry) =>
            !entry.task.isCompleted && entry.task.dueAt.isBefore(today))
        .toList(growable: false)
      ..sort((FarmTaskEntry a, FarmTaskEntry b) =>
          a.task.dueAt.compareTo(b.task.dueAt));
  }

  /// Incomplete, non-overdue entries grouped into "This week", "Next week",
  /// and "Later" buckets, each sorted by due date.
  static Map<String, List<FarmTaskEntry>> groupEntriesByWeek(
    List<FarmTaskEntry> entries, {
    required DateTime referenceDate,
  }) {
    final DateTime today =
        DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final DateTime endOfThisWeek = today.add(Duration(days: 7 - today.weekday));
    final DateTime endOfNextWeek = endOfThisWeek.add(const Duration(days: 7));

    final Map<String, List<FarmTaskEntry>> grouped =
        <String, List<FarmTaskEntry>>{
      'This week': <FarmTaskEntry>[],
      'Next week': <FarmTaskEntry>[],
      'Later': <FarmTaskEntry>[],
    };

    for (final FarmTaskEntry entry in entries) {
      if (entry.task.isCompleted || entry.task.dueAt.isBefore(today)) {
        continue;
      }
      if (entry.task.dueAt
          .isBefore(endOfThisWeek.add(const Duration(days: 1)))) {
        grouped['This week']!.add(entry);
      } else if (entry.task.dueAt
          .isBefore(endOfNextWeek.add(const Duration(days: 1)))) {
        grouped['Next week']!.add(entry);
      } else {
        grouped['Later']!.add(entry);
      }
    }

    for (final List<FarmTaskEntry> bucket in grouped.values) {
      bucket.sort((FarmTaskEntry a, FarmTaskEntry b) =>
          a.task.dueAt.compareTo(b.task.dueAt));
    }

    grouped.removeWhere(
        (String key, List<FarmTaskEntry> bucket) => bucket.isEmpty);
    return grouped;
  }

  /// Completion/overdue summary across the given entries.
  static FarmTaskCompletionStats completionStats(
    List<FarmTaskEntry> entries, {
    DateTime? referenceDate,
  }) {
    final DateTime today = referenceDate ?? DateTime.now();
    final int completed =
        entries.where((FarmTaskEntry entry) => entry.task.isCompleted).length;
    final int overdueCount =
        overdueEntries(entries, referenceDate: today).length;
    return FarmTaskCompletionStats(
      total: entries.length,
      completed: completed,
      overdueCount: overdueCount,
    );
  }
}
