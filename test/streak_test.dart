import 'package:farmsynchub/providers/engagement_provider.dart';
import 'package:flutter_test/flutter_test.dart';

EngagementState stateWith(
  List<DateTime> learned, {
  List<DateTime> frozen = const <DateTime>[],
  int restorationsUsed = 0,
}) {
  return EngagementState(
    days: <String, DayActivity>{
      for (final DateTime d in learned)
        dayKey(d): const DayActivity(xp: 10, lessons: 1),
    },
    frozenDays: <String>{for (final DateTime d in frozen) dayKey(d)},
    restorationsUsed: restorationsUsed,
    isLoaded: true,
  );
}

void main() {
  final DateTime today = DateTime(2026, 11, 3, 12);
  DateTime ago(int n) => addDays(today, -n);

  test('no activity means no streak', () {
    final StreakInfo info = stateWith(<DateTime>[]).streakInfo(today);
    expect(info.count, 0);
    expect(info.status, StreakStatus.none);
  });

  test('learning today counts the whole chain', () {
    final StreakInfo info =
        stateWith(<DateTime>[ago(2), ago(1), today]).streakInfo(today);
    expect(info.count, 3);
    expect(info.status, StreakStatus.doneToday);
  });

  test('yesterday learned, today not yet: streak is alive', () {
    final StreakInfo info =
        stateWith(<DateTime>[ago(2), ago(1)]).streakInfo(today);
    expect(info.count, 2);
    expect(info.status, StreakStatus.alive);
  });

  test('one missed day freezes the fire instead of ending it', () {
    final StreakInfo info =
        stateWith(<DateTime>[ago(3), ago(2)]).streakInfo(today);
    expect(info.status, StreakStatus.frozen);
    expect(info.count, 2);
  });

  test('two missed days break the streak', () {
    final StreakInfo info = stateWith(<DateTime>[ago(4), ago(3)]).streakInfo(today);
    expect(info.status, StreakStatus.broken);
    expect(info.count, 0);
    expect(info.lostCount, 2);
  });

  test('no restorations left means a single miss breaks the streak', () {
    final StreakInfo info = stateWith(<DateTime>[ago(3), ago(2)],
            restorationsUsed: EngagementState.maxRestorations)
        .streakInfo(today);
    expect(info.status, StreakStatus.broken);
  });

  test('a bridged day keeps the chain but does not add to the count', () {
    final StreakInfo info = stateWith(<DateTime>[ago(3), today],
            frozen: <DateTime>[ago(2), ago(1)])
        .streakInfo(today);
    expect(info.count, 2);
    expect(info.status, StreakStatus.doneToday);
  });

  test('longest streak counts learned days across bridged gaps', () {
    final EngagementState s = stateWith(
        <DateTime>[ago(5), ago(4), ago(2)],
        frozen: <DateTime>[ago(3)]);
    expect(s.longestStreak, 3);
  });

  test('the trusted clock never runs behind the last seen time', () {
    final EngagementState s = EngagementState(
      lastSeenMs: today.millisecondsSinceEpoch,
      isLoaded: true,
    );
    expect(s.trusted(ago(5)), today);
  });
}
