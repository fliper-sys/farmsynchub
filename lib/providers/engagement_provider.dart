import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences_provider.dart';

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
      title: (AppLanguage l) =>
          l.tr(en: 'Week Warrior', ha: 'Jarumin Mako', fr: 'Guerrier de la semaine'),
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
          en: 'Earn 100 XP',
          ha: 'Samu maki 100 na XP',
          fr: 'Gagnez 100 XP'),
    ),
    AchievementDef(
      id: 'xp_500',
      icon: Icons.stars_rounded,
      color: const Color(0xFF1CB0F6),
      bonusXp: 25,
      isMet: (EngagementState s, DateTime now) => s.totalXp >= 500,
      title: (AppLanguage l) =>
          l.tr(en: 'Rising Star', ha: 'Tauraruwa Mai Tashi', fr: 'Étoile montante'),
      description: (AppLanguage l) => l.tr(
          en: 'Earn 500 XP',
          ha: 'Samu maki 500 na XP',
          fr: 'Gagnez 500 XP'),
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
    this.awards = const <String>[],
  });

  final int xp;
  final int lessons;

  /// Achievement ids unlocked on this day.
  final List<String> awards;

  bool get hasActivity => xp > 0 || lessons > 0;

  DayActivity copyWith({int? xp, int? lessons, List<String>? awards}) =>
      DayActivity(
        xp: xp ?? this.xp,
        lessons: lessons ?? this.lessons,
        awards: awards ?? this.awards,
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'xp': xp, 'lessons': lessons, 'awards': awards};

  factory DayActivity.fromJson(Map<String, dynamic> json) => DayActivity(
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        lessons: (json['lessons'] as num?)?.toInt() ?? 0,
        awards: ((json['awards'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<String>()
            .toList(),
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
  final bool isLoaded;

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
// Notifier
// ---------------------------------------------------------------------------

final engagementProvider =
    NotifierProvider<EngagementNotifier, EngagementState>(
        EngagementNotifier.new);

class EngagementNotifier extends Notifier<EngagementState> {
  static const String _storageKey = 'engagement.v1';
  static const int _gemsPerAchievement = 10;

  late Future<void> _ready;
  bool _canPersist = false;
  Future<void> _pendingWrites = Future<void>.value();

  @override
  EngagementState build() {
    _ready = _load();
    return const EngagementState();
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storageKey);
      if (raw == null) {
        state = state.copyWith(isLoaded: true);
        _canPersist = true;
        return;
      }
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
      state = EngagementState(
        totalXp: (decoded['totalXp'] as num?)?.toInt() ?? 0,
        days: days,
        unlocked: readSet('unlocked'),
        rewardedLessons: readSet('rewardedLessons'),
        perfectLessons: (decoded['perfectLessons'] as num?)?.toInt() ?? 0,
        frozenDays: readSet('frozenDays'),
        restorationsUsed: (decoded['restorationsUsed'] as num?)?.toInt() ?? 0,
        freezeItems: (decoded['freezeItems'] as num?)?.toInt() ?? 0,
        gems: (decoded['gems'] as num?)?.toInt() ?? 0,
        isLoaded: true,
      );
      _canPersist = true;
      // A freeze may need to cover days missed while the app was closed.
      if (_autoUseFreezes(DateTime.now()) > 0) {
        await _persist();
      }
    } catch (error) {
      // Never write after a failed read: it could erase recoverable data.
      debugPrint('EngagementNotifier: failed to load: $error');
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> _persist() {
    if (!_canPersist) return Future<void>.value();
    _pendingWrites = _pendingWrites.then((_) async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final EngagementState s = state;
        await prefs.setString(
          _storageKey,
          jsonEncode(<String, dynamic>{
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
          }),
        );
      } catch (error) {
        debugPrint('EngagementNotifier: failed to save: $error');
      }
    });
    return _pendingWrites;
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
    final DateTime t = now ?? DateTime.now();
    final _Prep prep = _beginActivity(t);
    final int streakBefore = state.streakInfo(t).count;
    final bool firstTime = !state.rewardedLessons.contains(lessonId);
    final bool perfect =
        totalQuestions > 0 && correctAnswers >= totalQuestions;

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
      perfectLessons:
          state.perfectLessons + ((perfect && firstTime) ? 1 : 0),
    );

    final List<AchievementDef> unlocked = _unlockAchievements(t);
    final int bonus =
        unlocked.fold<int>(0, (int sum, AchievementDef d) => sum + d.bonusXp);
    await _persist();

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
    final DateTime t = now ?? DateTime.now();
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
    return unlocked;
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
