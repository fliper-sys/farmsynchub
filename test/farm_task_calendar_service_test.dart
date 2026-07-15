import 'package:flutter_test/flutter_test.dart';
import 'package:farmsynchub/domain/models/farm.dart';
import 'package:farmsynchub/core/services/farm_task_calendar_service.dart';

void main() {
  group('FarmTaskCalendarService', () {
    test('groups open tasks by day and filters completed items', () {
      final DateTime reference = DateTime(2026, 7, 14, 9, 0);
      final List<FarmWorkspaceTask> tasks = <FarmWorkspaceTask>[
        FarmWorkspaceTask(
          id: '1',
          title: 'Watering',
          dueAt: reference.add(const Duration(hours: 2)),
          createdAt: reference,
          updatedAt: reference,
        ),
        FarmWorkspaceTask(
          id: '2',
          title: 'Fertilizer',
          dueAt: reference.add(const Duration(days: 1)),
          createdAt: reference,
          updatedAt: reference,
        ),
        FarmWorkspaceTask(
          id: '3',
          title: 'Done task',
          dueAt: reference.add(const Duration(days: 2)),
          createdAt: reference,
          updatedAt: reference,
          status: FarmTaskStatus.done,
        ),
      ];

      final Map<String, List<FarmWorkspaceTask>> grouped = FarmTaskCalendarService.groupTasksByDay(tasks, referenceDate: reference);
      final List<FarmWorkspaceTask> upcoming = FarmTaskCalendarService.upcomingTasks(tasks, referenceDate: reference, maxDays: 2);
      final List<FarmWorkspaceTask> todayAndUpcoming = FarmTaskCalendarService.todayAndUpcomingTasks(
        tasks,
        referenceDate: reference,
        maxDays: 2,
        maxItems: 2,
      );

      expect(grouped.containsKey('2026-07-14'), isTrue);
      expect(grouped['2026-07-14']!.length, 1);
      expect(upcoming.length, 2);
      expect(todayAndUpcoming.length, 2);
      expect(todayAndUpcoming.every((FarmWorkspaceTask task) => !task.isCompleted), isTrue);
    });
  });
}
