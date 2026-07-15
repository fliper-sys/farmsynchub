import '../../domain/models/farm.dart';

class FarmTaskCalendarService {
  static Map<String, List<FarmWorkspaceTask>> groupTasksByDay(
    List<FarmWorkspaceTask> tasks, {
    required DateTime referenceDate,
  }) {
    final Map<String, List<FarmWorkspaceTask>> grouped = <String, List<FarmWorkspaceTask>>{};
    final List<FarmWorkspaceTask> activeTasks = tasks.where((FarmWorkspaceTask task) => !task.isCompleted).toList(growable: false);

    for (final FarmWorkspaceTask task in activeTasks) {
      final String key = _dayKey(task.dueAt);
      grouped.putIfAbsent(key, () => <FarmWorkspaceTask>[]).add(task);
    }

    for (final List<FarmWorkspaceTask> dayTasks in grouped.values) {
      dayTasks.sort((FarmWorkspaceTask a, FarmWorkspaceTask b) => a.dueAt.compareTo(b.dueAt));
    }

    return grouped;
  }

  static List<FarmWorkspaceTask> upcomingTasks(
    List<FarmWorkspaceTask> tasks, {
    required DateTime referenceDate,
    int maxDays = 7,
  }) {
    final DateTime start = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final DateTime end = start.add(Duration(days: maxDays));
    return tasks
        .where((FarmWorkspaceTask task) => !task.isCompleted)
        .where((FarmWorkspaceTask task) => !task.dueAt.isBefore(start) && task.dueAt.isBefore(end.add(const Duration(days: 1))))
        .toList(growable: false)
      ..sort((FarmWorkspaceTask a, FarmWorkspaceTask b) => a.dueAt.compareTo(b.dueAt));
  }

  static List<FarmWorkspaceTask> todayAndUpcomingTasks(
    List<FarmWorkspaceTask> tasks, {
      required DateTime referenceDate,
      int maxDays = 7,
      int maxItems = 4,
    }) {
    final List<FarmWorkspaceTask> filtered = upcomingTasks(tasks, referenceDate: referenceDate, maxDays: maxDays);
    final DateTime today = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final List<FarmWorkspaceTask> prioritized = <FarmWorkspaceTask>[];

    for (final FarmWorkspaceTask task in filtered) {
      final DateTime taskDay = DateTime(task.dueAt.year, task.dueAt.month, task.dueAt.day);
      if (taskDay == today) {
        prioritized.add(task);
      }
    }

    for (final FarmWorkspaceTask task in filtered) {
      final DateTime taskDay = DateTime(task.dueAt.year, task.dueAt.month, task.dueAt.day);
      if (taskDay != today && prioritized.length < maxItems) {
        prioritized.add(task);
      }
    }

    return prioritized.take(maxItems).toList(growable: false);
  }

  static String _dayKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
