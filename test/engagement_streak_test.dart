import 'package:flutter_test/flutter_test.dart';

import 'package:farmsynchub/providers/engagement_provider.dart';

void main() {
  group('learning streak activity', () {
    test('persists repeat activity as a qualifying day', () {
      const DayActivity activity = DayActivity(activityCount: 1);
      final DayActivity restored = DayActivity.fromJson(activity.toJson());

      expect(restored.activityCount, 1);
      expect(restored.hasActivity, isTrue);
    });

    test('counts consecutive learning days in the current streak', () {
      final DateTime yesterday = DateTime(2026, 11, 2);
      final DateTime today = DateTime(2026, 11, 3);
      final EngagementState state = EngagementState(
        days: <String, DayActivity>{
          dayKey(yesterday): const DayActivity(xp: 10),
          dayKey(today): const DayActivity(activityCount: 1),
        },
      );

      final StreakInfo info = state.streakInfo(today);

      expect(info.status, StreakStatus.doneToday);
      expect(info.count, 2);
    });
  });
}
