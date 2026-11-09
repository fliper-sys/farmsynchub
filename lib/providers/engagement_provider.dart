import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences_provider.dart';
import 'firebase_learning_sync.dart';

// ---------------------------------------------------------------------------
// Date helpers. Everything is keyed by the learner's LOCAL calendar day.
// ---------------------------------------------------------------------------

String dayKey(DateTime date) {
  final DateTime d = date.toLocal();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

DateTime? parseDayKey(String key) {
  final List<String> p = key.split('-');
  if (p.length != 3) return null;
  final int? y = int.tryParse(p[0]);
  final int? m = int.tryParse(p[1]);
  final int? d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

// ---------------------------------------------------------------------------
// Achievements
// ---------------------------------------------------------------------------

/// Paths of the Lottie files you download into assets/lottie/ (see README).
class LottieAssets {
  static const String trophy = 'assets/lottie/trophy.json';
  static const String confetti = 'assets/lottie/confetti.json';
  static const String streakFire = 'assets/lottie/streak_fire.json';
}

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.icon,
    required this.color,
    required this.bonusXp,
    required this.isMet,
    required this.title,
    required this.description,
    this.lottie = LottieAssets.trophy,
  });

  final String id;
  final IconData icon;
  final Color color;
  final int bonusXp;
  final String lottie;
  final bool Function(EngagementState s, DateTime now) isMet;
  final String Function(AppLanguage l) title;
  final String Function(AppLanguage l) description;
}

class Achievements {
  static final List<AchievementDef> all = <AchievementDef>[
    AchievementDef(
      id: 'first_lesson',
      icon: Icons.flag_rounded,
      color: const Color(0xFF58CC02),
      bonusXp: 10,
      isMet: (EngagementState s, DateTime now) => s.lessonsCompleted >= 1,
      title: (AppLanguage l) =>
          l.tr(en: 'First Step', ha: 'Matakin Farko', fr: 'Premier pas'),
      description: (AppLanguage l) => l.tr(
          en: 'Complete your first lesson',
          ha: 'Kammala darasinka na farko',
          fr: 'Terminez votre première leçon'),
    ),
    AchievementDef(
      id: 'streak_3',
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFFFF9600),
      bonusXp: 15,
      lottie: LottieAssets.streakFire,
      isMet: (EngagementState s, DateTime now) =>
          s.currentStreak(now) >= 3 || s.longestStreak >= 3,
      title: (AppLanguage l) =>
          l.tr(en: 'On Fire', ha: 'Ana Ci Gaba', fr: 'En feu'),
      description: (AppLanguage l) => l.tr(
          en: 'Learn 3 days in a row',
          ha: 'Yi karatu kwana 3 a jere',
          fr: 'Apprenez 3 jours de suite'),
    ),
    AchievementDef(
      id: 'streak_7',
      icon: Icons.whatshot_rounded,
      color: const Color(0xFFFF6B00),
      bonusXp: 30,
      lottie: LottieAssets.streakFire,
      isMet: (EngagementState s, DateTime now) =>
          s.currentStreak(now) >= 7 || s.longestStreak >= 7,
      title: (AppLanguage l) => l.tr(
          en: 'Week Warrior', ha: 'Jarumin Mako', fr: 'Guerrier de la semaine'),
      description: (AppLanguage l) => l.tr(
          en: 'Learn 7 days in a row',
          ha: 'Yi karatu kwana 7 a jere',
          fr: 'Apprenez 7 jours de suite'),
    ),
    AchievementDef(
      id: 'streak_30',
      icon: Icons.workspace_premium_rounded,
      color: const Color(0xFFCE82FF),
      bonusXp: 100,
      lottie: LottieAssets.streakFire,
      isMet: (EngagementState s, DateTime now) =>
          s.currentStreak(now) >= 30 || s.longestStreak >= 30,
      title: (AppLanguage l) =>
          l.tr(en: 'Unstoppable', ha: 'Ba A Hana Ka', fr: 'Inarrêtable'),
      description: (AppLanguage l) => l.tr(
          en: 'Learn 30 days in a row',
          ha: 'Yi karatu kwana 30 a jere',
          fr: 'Apprenez 30 jours de suite'),
    ),
    AchievementDef(
      id: 'xp_100',
      icon: Icons.bolt_rounded,
      color: const Color(0xFFFFC800),
      bonusXp: 10,
      isMet: (EngagementState s, DateTime now) => s.totalXp >= 100,
      title: (AppLanguage l) =>
          l.tr(en: 'Century', ha: 'Maki 100', fr: 'Centurion'),
      description: (AppLanguage l) => l.tr(
          en: 'Earn 100 XP', ha: 'Samu maki 100 na XP', fr: 'Gagnez 100 XP'),
    ),
    AchievementDef(
      id: 'xp_500',
      icon: Icons.stars_rounded,
      color: const Color(0xFF1CB0F6),
      bonusXp: 25,
      isMet: (EngagementState s, DateTime now) => s.totalXp >= 500,
      title: (AppLanguage l) => l.tr(
          en: 'Rising Star', ha: 'Tauraruwa Mai Tashi', fr: 'Étoile montante'),
      description: (AppLanguage l) => l.tr(
          en: 'Earn 500 XP', ha: 'Samu maki 500 na XP', fr: 'Gagnez 500 XP'),
    ),
    AchievementDef(
      id: 'lessons_5',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF58CC02),
      bonusXp: 20,
      isMet: (EngagementState s, DateTime now) => s.lessonsCompleted >= 5,
      title: (AppLanguage l) =>
          l.tr(en: 'Bookworm', ha: 'Mai Karatu', fr: 'Rat de bibliothèque'),
      description: (AppLanguage l) => l.tr(
          en: 'Complete 5 lessons',
          ha: 'Kammala darussa 5',
          fr: 'Terminez 5 leçons'),
    ),
    AchievementDef(
      id: 'perfect_lesson',
      icon: Icons.verified_rounded,
      color: const Color(0xFFFF4B4B),
      bonusXp: 15,
      isMet: (EngagementState s, DateTime now) => s.perfectLessons >= 1,
      title: (AppLanguage l) =>
          l.tr(en: 'Flawless', ha: 'Babu Kuskure', fr: 'Sans faute'),
      description: (AppLanguage l) => l.tr(
          en: 'Finish a lesson with every answer correct',
          ha: 'Kammala darasi da duk amsoshi daidai',
          fr: 'Terminez une leçon sans aucune erreur'),
    ),
  ];

  static AchievementDef? byId(String id) {
    for (final AchievementDef def in all) {
      if (def.id == id) return def;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// What happened on one calendar day.
class DayActivity {
  const DayActivity({
    this.xp = 0,
    this.lessons = 0,
    this.activityCount = 0,
    this.awards = const <String>[],
    this.cloud = false,
  });

  final int xp;
  final int lessons;
  final int activityCount;

  /// True when the cloud already knows about this day (it came from, or was
  /// queued to, the cloud). A cloud-known day counts as a learning day even
  /// if its XP detail is not available on this device yet, so history from
  /// older app versions or another phone still keeps the streak alive.
  final bool cloud;

  /// Achievement ids unlocked on this day.
  final List<String> awards;

  bool get hasActivity => xp > 0 || lessons > 0 || activityCount > 0 || cloud;

  DayActivity copyWith({
    int? xp,
    int? lessons,
    int? activityCount,
    List<String>? awards,
    bool? cloud,
  }) =>
      DayActivity(
        xp: xp ?? this.xp,
        lessons: lessons ?? this.lessons,
        activityCount: activityCount ?? this.activityCount,
        awards: awards ?? this.awards,
        cloud: cloud ?? this.cloud,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'xp': xp,
        'lessons': lessons,
        'activityCount': activityCount,
        'awards': awards,
        'cloud': cloud,
      };

  factory DayActivity.fromJson(Map<String, dynamic> json) => DayActivity(
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        lessons: (json['lessons'] as num?)?.toInt() ?? 0,
        activityCount: (json['activityCount'] as num?)?.toInt() ?? 0,
        awards: ((json['awards'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<String>()
            .toList(),
        cloud: json['cloud'] == true,
      );
}

enum DayStatus {
  /// Before the learner's first ever activity - neither passed nor missed.
  beforeStart,
  future,
  todayPending,
  done,

  /// A missed day that was bridged (by a freeze or a restoration).
  frozen,
  missed,
}

enum StreakStatus {
  /// Nothing learned yet.
  none,

  /// Learned today.
  doneToday,

  /// Not yet today, but yesterday was covered - fire is still lit.
  alive,

  /// Yesterday was missed. The fire is frozen and comes back if a lesson is
  /// finished today (uses one of the restorations).
  frozen,

  /// Streak lost (missed too many days, or no restorations left).
  broken,
}

class StreakInfo {
  const StreakInfo({
    required this.count,
    required this.status,
    required this.restorationsLeft,
    this.lostCount = 0,
  });

  final int count;
  final StreakStatus status;
  final int restorationsLeft;

  /// For [StreakStatus.broken]: how long the streak was before it was lost.
  final int lostCount;
}

class EngagementState {
  const EngagementState({
    this.totalXp = 0,
    this.days = const <String, DayActivity>{},
    this.unlocked = const <String>{},
    this.rewardedLessons = const <String>{},
    this.perfectLessons = 0,
    this.frozenDays = const <String>{},
    this.restorationsUsed = 0,
    this.freezeItems = 0,
    this.gems = 0,
    this.joinedChallenges = const <String>{},
    this.claimedChallenges = const <String>{},
    this.lastSeenMs = 0,
    this.isLoaded = false,
  });

  /// Streak rule: a single missed day freezes the fire instead of ending the
  /// streak. Finishing a lesson that day restores it. Only this many
  /// restorations are allowed; after that the next miss resets the streak
  /// to the beginning (and the restorations refill).
  static const int maxRestorations = 3;
  static const int maxFreezes = 2;
  static const int freezeCostGems = 30;

  final int totalXp;
  final Map<String, DayActivity> days;
  final Set<String> unlocked;

  /// Lessons that already paid out full XP (replays pay far less).
  final Set<String> rewardedLessons;
  final int perfectLessons;

  /// Missed days that were bridged by a freeze or a restoration.
  final Set<String> frozenDays;
  final int restorationsUsed;

  /// Streak freezes owned (each protects one missed day automatically).
  final int freezeItems;
  final int gems;

  /// Weekly challenge ids the learner joined / already collected.
  final Set<String> joinedChallenges;
  final Set<String> claimedChallenges;

  /// Latest moment the app has ever trusted (epoch ms). The clock can never
  /// run behind this, so turning the phone clock back cannot re-open a past
  /// day or restore a lost streak.
  final int lastSeenMs;
  final bool isLoaded;

  /// The device time, never earlier than [lastSeenMs].
  DateTime trusted(DateTime raw) {
    if (raw.millisecondsSinceEpoch >= lastSeenMs) return raw;
    return DateTime.fromMillisecondsSinceEpoch(lastSeenMs);
  }

  int get lessonsCompleted => rewardedLessons.length;

  int get restorationsLeft {
    final int left = maxRestorations - restorationsUsed;
    return left < 0 ? 0 : left;
  }

  DayActivity activityOn(DateTime date) =>
      days[dayKey(date)] ?? const DayActivity();

  bool hasActivityOn(DateTime date) => activityOn(date).hasActivity;

  bool isFrozenDay(DateTime date) => frozenDays.contains(dayKey(date));

  /// A day keeps the streak chain intact if it was learned or bridged.
  bool isCovered(DateTime date) => hasActivityOn(date) || isFrozenDay(date);

  bool isDoneToday(DateTime now) => hasActivityOn(now);

  int xpToday(DateTime now) => activityOn(now).xp;

  /// Counts learned days walking back from [from] through covered days.
  /// Bridged days keep the chain alive but do not add to the count.
  int _chainCount(DateTime from) {
    int count = 0;
    DateTime d = dateOnly(from);
    while (isCovered(d)) {
      if (hasActivityOn(d)) count++;
      d = addDays(d, -1);
    }
    return count;
  }

  /// The latest learned-or-bridged day strictly before [day].
  DateTime? lastCoveredBefore(DateTime day) {
    DateTime? best;
    void consider(String key) {
      final DateTime? d = parseDayKey(key);
      if (d == null || !d.isBefore(dateOnly(day))) return;
      if (best == null || d.isAfter(best!)) best = d;
    }

    days.forEach((String key, DayActivity value) {
      if (value.hasActivity) consider(key);
    });
    for (final String key in frozenDays) {
      consider(key);
    }
    return best;
  }

  StreakInfo streakInfo(DateTime now) {
    final DateTime today = dateOnly(now);
    if (hasActivityOn(today)) {
      return StreakInfo(
        count: _chainCount(today),
        status: StreakStatus.doneToday,
        restorationsLeft: restorationsLeft,
      );
    }
    if (firstActivityDate == null) {
      return StreakInfo(
        count: 0,
        status: StreakStatus.none,
        restorationsLeft: restorationsLeft,
      );
    }
    final DateTime yesterday = addDays(today, -1);
    if (isCovered(yesterday)) {
      return StreakInfo(
        count: _chainCount(yesterday),
        status: StreakStatus.alive,
        restorationsLeft: restorationsLeft,
      );
    }
    final DateTime twoAgo = addDays(today, -2);
    if (isCovered(twoAgo) && restorationsUsed < maxRestorations) {
      return StreakInfo(
        count: _chainCount(twoAgo),
        status: StreakStatus.frozen,
        restorationsLeft: restorationsLeft,
      );
    }
    final DateTime? last = lastCoveredBefore(today);
    return StreakInfo(
      count: 0,
      status: StreakStatus.broken,
      restorationsLeft: restorationsLeft,
      lostCount: last == null ? 0 : _chainCount(last),
    );
  }

  int currentStreak(DateTime now) => streakInfo(now).count;

  int get longestStreak {
    final Set<DateTime> covered = <DateTime>{};
    days.forEach((String key, DayActivity value) {
      final DateTime? date = parseDayKey(key);
      if (date != null && value.hasActivity) covered.add(date);
    });
    for (final String key in frozenDays) {
      final DateTime? date = parseDayKey(key);
      if (date != null) covered.add(date);
    }
    final List<DateTime> sorted = covered.toList()..sort();
    int best = 0;
    int run = 0;
    DateTime? previous;
    for (final DateTime date in sorted) {
      if (previous == null || addDays(previous, 1) != date) run = 0;
      if (hasActivityOn(date)) run++;
      if (run > best) best = run;
      previous = date;
    }
    return best;
  }

  DateTime? get firstActivityDate {
    DateTime? first;
    days.forEach((String key, DayActivity value) {
      final DateTime? date = parseDayKey(key);
      if (date != null && value.hasActivity) {
        if (first == null || date.isBefore(first!)) first = date;
      }
    });
    return first;
  }

  DayStatus statusFor(DateTime date, DateTime now) {
    final DateTime d = dateOnly(date);
    final DateTime today = dateOnly(now);
    if (hasActivityOn(d)) return DayStatus.done;
    if (isFrozenDay(d)) return DayStatus.frozen;
    if (d.isAfter(today)) return DayStatus.future;
    if (d == today) return DayStatus.todayPending;
    final DateTime? first = firstActivityDate;
    if (first == null || d.isBefore(first)) return DayStatus.beforeStart;
    return DayStatus.missed;
  }

  EngagementState copyWith({
    int? totalXp,
    Map<String, DayActivity>? days,
    Set<String>? unlocked,
    Set<String>? rewardedLessons,
    int? perfectLessons,
    Set<String>? frozenDays,
    int? restorationsUsed,
    int? freezeItems,
    int? gems,
    Set<String>? joinedChallenges,
    Set<String>? claimedChallenges,
    int? lastSeenMs,
    bool? isLoaded,
  }) =>
      EngagementState(
        totalXp: totalXp ?? this.totalXp,
        days: days ?? this.days,
        unlocked: unlocked ?? this.unlocked,
        rewardedLessons: rewardedLessons ?? this.rewardedLessons,
        perfectLessons: perfectLessons ?? this.perfectLessons,
        frozenDays: frozenDays ?? this.frozenDays,
        restorationsUsed: restorationsUsed ?? this.restorationsUsed,
        freezeItems: freezeItems ?? this.freezeItems,
        gems: gems ?? this.gems,
        joinedChallenges: joinedChallenges ?? this.joinedChallenges,
        claimedChallenges: claimedChallenges ?? this.claimedChallenges,
        lastSeenMs: lastSeenMs ?? this.lastSeenMs,
        isLoaded: isLoaded ?? this.isLoaded,
      );
}

/// Returned to the lesson-complete screen so it can celebrate.
class LessonReward {
  const LessonReward({
    required this.xpEarned,
    required this.bonusXp,
    required this.streakBefore,
    required this.streakAfter,
    required this.newAchievements,
    required this.firstTime,
    this.gemsEarned = 0,
    this.restored = false,
    this.restorationsLeft = EngagementState.maxRestorations,
    this.streakReset = false,
    this.lostStreak = 0,
    this.freezesUsed = 0,
  });

  final int xpEarned;
  final int bonusXp;
  final int streakBefore;
  final int streakAfter;
  final List<AchievementDef> newAchievements;
  final bool firstTime;
  final int gemsEarned;

  /// The fire was frozen and this lesson restored it.
  final bool restored;
  final int restorationsLeft;

  /// The streak was lost and starts again from the beginning.
  final bool streakReset;
  final int lostStreak;

  /// Streak freezes that protected missed days since the last visit.
  final int freezesUsed;

  bool get streakExtended => streakAfter > streakBefore;
}

class _Prep {
  const _Prep({
    this.restored = false,
    this.reset = false,
    this.lost = 0,
    this.freezesUsed = 0,
  });

  final bool restored;
  final bool reset;
  final int lost;
  final int freezesUsed;
}

// ---------------------------------------------------------------------------
// Weekly streak challenge
// ---------------------------------------------------------------------------

/// "Learn on [goalDays] of the 7 days this week" - a Monday-to-Sunday
/// challenge derived purely from the calendar, so every device (and every
/// reinstall) agrees on it without any server round trip. Progress is never
/// stored as a counter: it is counted from the verified learning days, so it
/// cannot be edited, double counted or drift between devices.
class StreakChallenge {
  const StreakChallenge({
    required this.id,
    required this.start,
    required this.end,
  });

  static const int goalDays = 5;
  static const int rewardXp = 60;
  static const int rewardGems = 40;

  final String id;

  /// Monday 00:00 (local).
  final DateTime start;

  /// The following Monday 00:00 (local). The challenge ends at this moment.
  final DateTime end;

  static StreakChallenge forDate(DateTime now) {
    final DateTime today = dateOnly(now);
    final DateTime monday = addDays(today, -(today.weekday - 1));
    return StreakChallenge(
      id: 'week-${dayKey(monday)}',
      start: monday,
      end: addDays(monday, 7),
    );
  }

  List<DateTime> get days =>
      <DateTime>[for (int i = 0; i < 7; i++) addDays(start, i)];

  Duration remaining(DateTime now) {
    final Duration left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  int daysDone(EngagementState s) {
    int count = 0;
    for (final DateTime d in days) {
      if (s.hasActivityOn(d)) count++;
    }
    return count > 7 ? 7 : count;
  }

  bool isComplete(EngagementState s) => daysDone(s) >= goalDays;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Single source of truth for XP, streaks, freezes, achievements and the
/// weekly challenge.
///
/// Offline first: every change is written to this device first and the
/// streak is always computed from the local record, so it is correct with no
/// signal. When the learner is signed in, each change is also queued in the
/// learning sync outbox. Cloud history is only ever MERGED into the local
/// record (days are unioned, totals take the larger value) - a sync can add
/// to progress but never lower or rewrite it.
final engagementProvider =
    NotifierProvider<EngagementNotifier, EngagementState>(
        EngagementNotifier.new);

class EngagementNotifier extends Notifier<EngagementState> {
  static const String _legacyKey = 'engagement.v1';
  static const int _gemsPerAchievement = 10;
  static const int _maxDayXp = 2000;
  static const int _maxDayLessons = 200;

  late Future<void> _ready;
  bool _canPersist = false;
  Future<void> _pendingWrites = Future<void>.value();
  String? _loadedUid;
  String _loadedKey = 'engagement.v2.guest';
  StreamSubscription<User?>? _authSub;

  String? _currentUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null; // Firebase not initialised (tests, early start-up).
    }
  }

  @override
  EngagementState build() {
    _ready = _load();
    unawaited(_watchAccount());
    ref.onDispose(() => _authSub?.cancel());
    return const EngagementState();
  }

  Future<void> _watchAccount() async {
    await _ready;
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user?.uid != _loadedUid) unawaited(_switchAccount());
      });
    } catch (error) {
      debugPrint('EngagementNotifier: not watching account changes: $error');
    }
  }

  Future<void> _switchAccount() async {
    // Finish writing the previous account's progress before changing scope.
    await _pendingWrites;
    _canPersist = false;
    state = const EngagementState();
    _ready = _load();
    await _ready;
  }

  /// The current time, never earlier than the latest time already seen. The
  /// ratchet is stored with the progress, so rewinding the phone clock cannot
  /// reopen yesterday, replay a missed day or undo a lost streak.
  DateTime _tick([DateTime? override]) {
    final DateTime t = state.trusted(override ?? DateTime.now());
    if (t.millisecondsSinceEpoch > state.lastSeenMs) {
      state = state.copyWith(lastSeenMs: t.millisecondsSinceEpoch);
    }
    return t;
  }

  /// Time for display (countdowns, the banner). Same ratchet, no write.
  DateTime trustedNow() => state.trusted(DateTime.now());

  EngagementState _decode(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('engagement data is not a map');
    }
    final Map<String, DayActivity> days = <String, DayActivity>{};
    final Object? rawDays = decoded['days'];
    if (rawDays is Map<String, dynamic>) {
      rawDays.forEach((String key, Object? value) {
        if (value is Map<String, dynamic>) {
          days[key] = DayActivity.fromJson(value);
        }
      });
    }
    Set<String> readSet(String key) =>
        ((decoded[key] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<String>()
            .toSet();
    return EngagementState(
      totalXp: (decoded['totalXp'] as num?)?.toInt() ?? 0,
      days: days,
      unlocked: readSet('unlocked'),
      rewardedLessons: readSet('rewardedLessons'),
      perfectLessons: (decoded['perfectLessons'] as num?)?.toInt() ?? 0,
      frozenDays: readSet('frozenDays'),
      restorationsUsed: (decoded['restorationsUsed'] as num?)?.toInt() ?? 0,
      freezeItems: (decoded['freezeItems'] as num?)?.toInt() ?? 0,
      gems: (decoded['gems'] as num?)?.toInt() ?? 0,
      joinedChallenges: readSet('joinedChallenges'),
      claimedChallenges: readSet('claimedChallenges'),
      lastSeenMs: (decoded['lastSeenMs'] as num?)?.toInt() ?? 0,
      isLoaded: true,
    );
  }

  String _encode(EngagementState s) => jsonEncode(<String, dynamic>{
        'totalXp': s.totalXp,
        'days': s.days.map((String k, DayActivity v) =>
            MapEntry<String, dynamic>(k, v.toJson())),
        'unlocked': s.unlocked.toList(),
        'rewardedLessons': s.rewardedLessons.toList(),
        'perfectLessons': s.perfectLessons,
        'frozenDays': s.frozenDays.toList(),
        'restorationsUsed': s.restorationsUsed,
        'freezeItems': s.freezeItems,
        'gems': s.gems,
        'joinedChallenges': s.joinedChallenges.toList(),
        'claimedChallenges': s.claimedChallenges.toList(),
        'lastSeenMs': s.lastSeenMs,
      });

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _loadedUid = _currentUid();
      _loadedKey = 'engagement.v2.${_loadedUid ?? 'guest'}';
      String? raw = prefs.getString(_loadedKey);
      if (raw == null) {
        // One-time move of the original un-scoped record to this account.
        final String? legacy = prefs.getString(_legacyKey);
        if (legacy != null) {
          raw = legacy;
          await prefs.setString(_loadedKey, legacy);
          await prefs.remove(_legacyKey);
        }
      }
      if (raw == null) {
        state = state.copyWith(isLoaded: true);
        _canPersist = true;
        return;
      }
      state = _decode(raw);
      _canPersist = true;
      // A freeze may need to cover days missed while the app was closed.
      final DateTime t = _tick();
      if (_autoUseFreezes(t) > 0) {
        await _persist();
      }
      unawaited(_pushUnsynced());
    } catch (error) {
      // Never write after a failed read: it could erase recoverable data.
      debugPrint('EngagementNotifier: failed to load: $error');
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> _persist() {
    if (!_canPersist) return Future<void>.value();
    final String key = _loadedKey;
    _pendingWrites = _pendingWrites.then((_) async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, _encode(state));
      } catch (error) {
        debugPrint('EngagementNotifier: failed to save: $error');
      }
    });
    return _pendingWrites;
  }

  // -------------------------------------------------------------------------
  // Cloud sync (merge only - local stays authoritative)
  // -------------------------------------------------------------------------

  /// Queues one day for cloud sync. Returns without marking anything when
  /// the learner is signed out; those days are pushed after the next sign-in.
  Future<void> _emitDay(String key) async {
    if (_currentUid() == null || !_canPersist) return;
    final DayActivity? day = state.days[key];
    if (day == null || !day.hasActivity) return;
    final List<String> recentFrozen = state.frozenDays.toList()..sort();
    try {
      await FirebaseLearningSync.instance
          .record('engagementDay', <String, dynamic>{
        'entityId': key,
        'activityDate': key,
        'xp': day.xp,
        'lessons': day.lessons,
        'activityCount': day.activityCount,
        'awards': day.awards,
        'totalXp': state.totalXp,
        'gems': state.gems,
        'restorationsUsed': state.restorationsUsed,
        'freezeItems': state.freezeItems,
        'frozenDays': recentFrozen.length > 14
            ? recentFrozen.sublist(recentFrozen.length - 14)
            : recentFrozen,
      });
    } catch (error) {
      debugPrint('EngagementNotifier: could not queue day $key: $error');
      return;
    }
    if (!day.cloud) {
      state = state.copyWith(
        days: <String, DayActivity>{
          ...state.days,
          key: (state.days[key] ?? day).copyWith(cloud: true),
        },
      );
      await _persist();
    }
  }

  /// Sends days earned while signed out (or before this version) to the cloud.
  Future<void> _pushUnsynced() async {
    await _ready;
    if (_currentUid() == null) return;
    final List<String> pending = state.days.entries
        .where((MapEntry<String, DayActivity> e) =>
            !e.value.cloud && e.value.hasActivity)
        .map((MapEntry<String, DayActivity> e) => e.key)
        .toList()
      ..sort();
    final List<String> recent =
        pending.length > 60 ? pending.sublist(pending.length - 60) : pending;
    for (final String key in recent) {
      await _emitDay(key);
    }
  }

  Future<void> _emitEvent(String type, String id) async {
    if (_currentUid() == null) return;
    try {
      await FirebaseLearningSync.instance
          .record(type, <String, dynamic>{'entityId': id});
    } catch (error) {
      debugPrint('EngagementNotifier: could not queue $type: $error');
    }
  }

  /// Folds cloud history into the local record. Safe to call repeatedly with
  /// the same events: days are unioned, totals only ever go up, and future
  /// dated days (beyond one day of timezone slack) are ignored.
  Future<void> mergeRemote(List<Map<String, dynamic>> events) async {
    await _ready;
    if (events.isEmpty || !_canPersist) return;
    final DateTime now = _tick();
    final DateTime limit = addDays(dateOnly(now), 1);
    final bool fresh = state.days.isEmpty;

    final Map<String, DayActivity> days = <String, DayActivity>{...state.days};
    final Set<String> frozen = <String>{...state.frozenDays};
    final Set<String> unlocked = <String>{...state.unlocked};
    final Set<String> rewarded = <String>{...state.rewardedLessons};
    final Set<String> joined = <String>{...state.joinedChallenges};
    final Set<String> claimed = <String>{...state.claimedChallenges};
    int totalXp = state.totalXp;
    int gems = state.gems;
    Map<String, dynamic>? latest;
    String latestAt = '';

    bool dayOk(Object? value) {
      if (value is! String) return false;
      final DateTime? d = parseDayKey(value);
      return d != null && !d.isAfter(limit);
    }

    int clampInt(Object? v, int max) {
      final int n = (v as num?)?.toInt() ?? 0;
      return n < 0 ? 0 : (n > max ? max : n);
    }

    for (final Map<String, dynamic> event in events) {
      final String type = event['type']?.toString() ?? '';
      final String id = event['entityId']?.toString() ?? '';
      final Object? date = event['activityDate'];

      if (type == 'engagementDay' && dayOk(date)) {
        final String key = date as String;
        final DayActivity? cur = days[key];
        days[key] = DayActivity(
          xp: math.max(cur?.xp ?? 0, clampInt(event['xp'], _maxDayXp)),
          lessons: math.max(
              cur?.lessons ?? 0, clampInt(event['lessons'], _maxDayLessons)),
          activityCount: math.max(cur?.activityCount ?? 0,
              clampInt(event['activityCount'], _maxDayLessons)),
          awards: <String>{
            ...?cur?.awards,
            ...((event['awards'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<String>(),
          }.toList(),
          cloud: true,
        );
        totalXp = math.max(totalXp, clampInt(event['totalXp'], 1000000));
        gems = math.max(gems, clampInt(event['gems'], 1000000));
        for (final Object? f
            in (event['frozenDays'] as List<dynamic>?) ?? const <dynamic>[]) {
          if (dayOk(f)) frozen.add(f as String);
        }
        for (final String award
            in ((event['awards'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<String>()) {
          if (Achievements.byId(award) != null) unlocked.add(award);
        }
        final String at = event['occurredAt']?.toString() ?? '';
        if (at.compareTo(latestAt) >= 0) {
          latestAt = at;
          latest = event;
        }
      } else if ((type == 'lessonCompleted' ||
              type == 'practiceCompleted' ||
              type == 'questionAnswered') &&
          dayOk(date)) {
        // Activity recorded by the learning module (older app versions, or
        // another device): it keeps the day, even without XP detail.
        final String key = date as String;
        final DayActivity? cur = days[key];
        days[key] = cur == null
            ? const DayActivity(cloud: true)
            : (cur.cloud ? cur : cur.copyWith(cloud: true));
      }

      if (type == 'lessonCompleted' && id.isNotEmpty) rewarded.add(id);
      if (type == 'challengeJoined' && id.startsWith('week-')) joined.add(id);
      if (type == 'challengeClaimed' && id.startsWith('week-')) {
        joined.add(id);
        claimed.add(id);
      }
    }

    state = state.copyWith(
      days: days,
      frozenDays: frozen,
      unlocked: unlocked,
      rewardedLessons: rewarded,
      joinedChallenges: joined,
      claimedChallenges: claimed,
      totalXp: totalXp,
      gems: gems,
      // Only a brand-new device adopts the cloud's allowance counters; an
      // existing local record keeps its own.
      restorationsUsed: (fresh && latest != null)
          ? clampInt(
              latest['restorationsUsed'], EngagementState.maxRestorations)
          : state.restorationsUsed,
      freezeItems: (fresh && latest != null)
          ? clampInt(latest['freezeItems'], EngagementState.maxFreezes)
          : state.freezeItems,
    );
    await _persist();
    await _pushUnsynced();
  }

  /// Uses owned streak freezes to bridge days missed since the last learned
  /// or bridged day. All-or-nothing: freezes are only spent when they cover
  /// every missed day, so none are wasted on a streak that is lost anyway.
  /// Returns how many freezes were used.
  int _autoUseFreezes(DateTime now) {
    if (state.freezeItems <= 0) return 0;
    final DateTime today = dateOnly(now);
    final DateTime? last = state.lastCoveredBefore(today);
    if (last == null) return 0;
    final List<String> gap = <String>[];
    DateTime d = addDays(last, 1);
    while (d.isBefore(today)) {
      gap.add(dayKey(d));
      d = addDays(d, 1);
    }
    if (gap.isEmpty || gap.length > state.freezeItems) return 0;
    state = state.copyWith(
      frozenDays: <String>{...state.frozenDays, ...gap},
      freezeItems: state.freezeItems - gap.length,
    );
    return gap.length;
  }

  /// Runs before the first activity of a day: spends freezes, restores a
  /// frozen fire (using one of the restorations), or resets a lost streak.
  _Prep _beginActivity(DateTime t) {
    final int freezesUsed = _autoUseFreezes(t);
    final StreakInfo info = state.streakInfo(t);
    if (info.status == StreakStatus.frozen) {
      state = state.copyWith(
        frozenDays: <String>{
          ...state.frozenDays,
          dayKey(addDays(dateOnly(t), -1)),
        },
        restorationsUsed: state.restorationsUsed + 1,
      );
      return _Prep(restored: true, freezesUsed: freezesUsed);
    }
    if (info.status == StreakStatus.broken) {
      // Back to the beginning, with all restorations available again.
      state = state.copyWith(restorationsUsed: 0);
      return _Prep(
        reset: info.lostCount > 0,
        lost: info.lostCount,
        freezesUsed: freezesUsed,
      );
    }
    return _Prep(freezesUsed: freezesUsed);
  }

  /// Unlocks every achievement that is now met. Bonus XP can unlock more, so
  /// this repeats until nothing new unlocks. Returns the new ones.
  List<AchievementDef> _unlockAchievements(DateTime now) {
    final List<AchievementDef> newlyUnlocked = <AchievementDef>[];
    bool changed = true;
    int guard = 0;
    while (changed && guard < 10) {
      changed = false;
      guard++;
      for (final AchievementDef def in Achievements.all) {
        if (state.unlocked.contains(def.id)) continue;
        if (!def.isMet(state, now)) continue;
        final String key = dayKey(now);
        final DayActivity day = state.days[key] ?? const DayActivity();
        state = state.copyWith(
          unlocked: <String>{...state.unlocked, def.id},
          totalXp: state.totalXp + def.bonusXp,
          gems: state.gems + _gemsPerAchievement,
          days: <String, DayActivity>{
            ...state.days,
            key: day.copyWith(
              xp: day.xp + def.bonusXp,
              awards: <String>[...day.awards, def.id],
            ),
          },
        );
        newlyUnlocked.add(def);
        changed = true;
      }
    }
    return newlyUnlocked;
  }

  /// Call once when a lesson is finished. Pays out XP and gems, extends or
  /// restores the streak, unlocks achievements and returns what happened.
  Future<LessonReward> recordLessonComplete({
    required String lessonId,
    required int correctAnswers,
    required int totalQuestions,
    DateTime? now,
  }) async {
    await _ready;
    final DateTime t = _tick(now);
    final _Prep prep = _beginActivity(t);
    final int streakBefore = state.streakInfo(t).count;
    final bool firstTime = !state.rewardedLessons.contains(lessonId);
    final bool perfect = totalQuestions > 0 && correctAnswers >= totalQuestions;

    // First completion: 10 base + 2 per correct answer + 5 for a perfect run.
    // Replays only pay 5 so the same lesson can't be farmed for points.
    final int xp =
        firstTime ? 10 + (correctAnswers * 2) + (perfect ? 5 : 0) : 5;
    final int gems = firstTime ? 5 + (perfect ? 5 : 0) : 1;

    final String key = dayKey(t);
    final DayActivity day = state.days[key] ?? const DayActivity();
    state = state.copyWith(
      totalXp: state.totalXp + xp,
      gems: state.gems + gems,
      days: <String, DayActivity>{
        ...state.days,
        key: day.copyWith(xp: day.xp + xp, lessons: day.lessons + 1),
      },
      rewardedLessons: <String>{...state.rewardedLessons, lessonId},
      perfectLessons: state.perfectLessons + ((perfect && firstTime) ? 1 : 0),
    );

    final List<AchievementDef> unlocked = _unlockAchievements(t);
    final int bonus =
        unlocked.fold<int>(0, (int sum, AchievementDef d) => sum + d.bonusXp);
    await _persist();
    await _emitDay(key);

    return LessonReward(
      xpEarned: xp,
      bonusXp: bonus,
      streakBefore: streakBefore,
      streakAfter: state.currentStreak(t),
      newAchievements: unlocked,
      firstTime: firstTime,
      gemsEarned: gems + unlocked.length * _gemsPerAchievement,
      restored: prep.restored,
      restorationsLeft: state.restorationsLeft,
      streakReset: prep.reset,
      lostStreak: prep.lost,
      freezesUsed: prep.freezesUsed,
    );
  }

  /// Small XP rewards for other actions (practice tasks, sharing, ...).
  /// Counts as activity for the day, so it keeps or restores the streak too.
  Future<List<AchievementDef>> awardXp(int xp, {DateTime? now}) async {
    await _ready;
    if (xp <= 0) return const <AchievementDef>[];
    final DateTime t = _tick(now);
    _beginActivity(t);
    final String key = dayKey(t);
    final DayActivity day = state.days[key] ?? const DayActivity();
    state = state.copyWith(
      totalXp: state.totalXp + xp,
      days: <String, DayActivity>{
        ...state.days,
        key: day.copyWith(xp: day.xp + xp),
      },
    );
    final List<AchievementDef> unlocked = _unlockAchievements(t);
    await _persist();
    await _emitDay(key);
    return unlocked;
  }

  /// Records a qualifying learning action without awarding repeat XP.
  Future<void> recordActivity({DateTime? now}) async {
    await _ready;
    final DateTime t = _tick(now);
    _beginActivity(t);
    final String key = dayKey(t);
    final DayActivity day = state.days[key] ?? const DayActivity();
    state = state.copyWith(
      days: <String, DayActivity>{
        ...state.days,
        key: day.copyWith(activityCount: day.activityCount + 1),
      },
    );
    await _persist();
    await _emitDay(key);
  }

  /// Joins this week's streak challenge. Returns false if already joined.
  Future<bool> joinChallenge({DateTime? now}) async {
    await _ready;
    final StreakChallenge challenge = StreakChallenge.forDate(_tick(now));
    if (state.joinedChallenges.contains(challenge.id)) return false;
    state = state.copyWith(
      joinedChallenges: <String>{...state.joinedChallenges, challenge.id},
    );
    await _persist();
    await _emitEvent('challengeJoined', challenge.id);
    return true;
  }

  /// Collects this week's reward once the goal is reached. The reward is
  /// paid straight to the totals (it is not a learning day, so it can never
  /// extend a streak by itself). Returns false if there is nothing to claim.
  Future<bool> claimChallenge({DateTime? now}) async {
    await _ready;
    final StreakChallenge challenge = StreakChallenge.forDate(_tick(now));
    if (!state.joinedChallenges.contains(challenge.id) ||
        state.claimedChallenges.contains(challenge.id) ||
        !challenge.isComplete(state)) {
      return false;
    }
    state = state.copyWith(
      claimedChallenges: <String>{...state.claimedChallenges, challenge.id},
      totalXp: state.totalXp + StreakChallenge.rewardXp,
      gems: state.gems + StreakChallenge.rewardGems,
    );
    await _persist();
    await _emitEvent('challengeClaimed', challenge.id);
    return true;
  }

  /// Buys one streak freeze with gems. Returns false if the learner can't
  /// afford it or already owns the maximum.
  Future<bool> buyFreeze() async {
    await _ready;
    if (state.gems < EngagementState.freezeCostGems ||
        state.freezeItems >= EngagementState.maxFreezes) {
      return false;
    }
    state = state.copyWith(
      gems: state.gems - EngagementState.freezeCostGems,
      freezeItems: state.freezeItems + 1,
    );
    await _persist();
    return true;
  }
}
