import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engagement_provider.dart';
import 'firebase_learning_sync.dart';

class CertificateRecord {
  const CertificateRecord({
    required this.lessonId,
    required this.lessonTitle,
    required this.completedAt,
  });

  final String lessonId;
  final String lessonTitle;
  final DateTime completedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lessonId': lessonId,
      'lessonTitle': lessonTitle,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory CertificateRecord.fromJson(Map<String, dynamic> json) {
    return CertificateRecord(
      lessonId: json['lessonId'] as String? ?? '',
      lessonTitle: json['lessonTitle'] as String? ?? '',
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// The awards shown on the learning hub. This is the single source of truth:
/// the awards board and the "awards earned" counter both read from here.
enum LearningAward { firstLesson, cropScholar, fieldDoer, communityHelper }

class LearningState {
  const LearningState({
    this.completedLessons = const <String>{},
    this.completedPractices = const <String>{},
    this.sharedItems = const <String>{},
    this.reviewedQuestions = const <String>{},
    this.correctQuestions = const <String>{},
    this.skippedQuestions = const <String>{},
    this.skippedLessons = const <String>{},
    this.earnedCertificates = const <CertificateRecord>[],
    this.learnerName = '',
    this.activeDays = const <String>{},
    this.isLoaded = false,
  });

  final Set<String> completedLessons;
  final Set<String> completedPractices;
  final Set<String> sharedItems;

  /// Questions the learner has answered (keys look like `lessonId::questionId`).
  /// Skipped questions are NOT in this set.
  final Set<String> reviewedQuestions;

  /// Questions answered correctly at least once.
  final Set<String> correctQuestions;

  /// Questions the learner skipped and has not answered since.
  final Set<String> skippedQuestions;

  final Set<String> skippedLessons;
  final List<CertificateRecord> earnedCertificates;

  /// Name printed on certificates. Empty until the learner sets it.
  final String learnerName;

  /// Local calendar dates (yyyy-MM-dd) on which the learner completed a
  /// qualifying learning action. Dates are captured before any cloud sync.
  final Set<String> activeDays;

  // Streaks are NOT computed here. `engagementProvider` is the single source
  // of truth (it also knows about freezes, restorations and the clock guard);
  // `activeDays` is only the activity log that is synced to the cloud.

  /// False until saved progress has been read from disk.
  final bool isLoaded;

  bool hasAward(LearningAward award) {
    switch (award) {
      case LearningAward.firstLesson:
        return completedLessons.isNotEmpty;
      case LearningAward.cropScholar:
        return completedLessons.length >= 3;
      case LearningAward.fieldDoer:
        return completedPractices.length >= 2;
      case LearningAward.communityHelper:
        return sharedItems.isNotEmpty;
    }
  }
  Set<LearningAward> get unlockedAwards =>
      LearningAward.values.where(hasAward).toSet();

  int get awardCount => unlockedAwards.length;

  CertificateRecord? certificateForLesson(String lessonId) {
    for (final CertificateRecord record in earnedCertificates) {
      if (record.lessonId == lessonId) {
        return record;
      }
    }
    return null;
  }

  LearningState copyWith({
    Set<String>? completedLessons,
    Set<String>? completedPractices,
    Set<String>? sharedItems,
    Set<String>? reviewedQuestions,
    Set<String>? correctQuestions,
    Set<String>? skippedQuestions,
    Set<String>? skippedLessons,
    List<CertificateRecord>? earnedCertificates,
    String? learnerName,
    Set<String>? activeDays,
    bool? isLoaded,
  }) {
    return LearningState(
      completedLessons: completedLessons ?? this.completedLessons,
      completedPractices: completedPractices ?? this.completedPractices,
      sharedItems: sharedItems ?? this.sharedItems,
      reviewedQuestions: reviewedQuestions ?? this.reviewedQuestions,
      correctQuestions: correctQuestions ?? this.correctQuestions,
      skippedQuestions: skippedQuestions ?? this.skippedQuestions,
      skippedLessons: skippedLessons ?? this.skippedLessons,
      earnedCertificates: earnedCertificates ?? this.earnedCertificates,
      learnerName: learnerName ?? this.learnerName,
      activeDays: activeDays ?? this.activeDays,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

final learningProvider =
    NotifierProvider<LearningNotifier, LearningState>(LearningNotifier.new);

class LearningNotifier extends Notifier<LearningState> {
  String? _loadedUid;
  StreamSubscription<User?>? _accountSubscription;

  String get _scope => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  String get _completedLessonsKey => 'learning.$_scope.completed_lessons';
  String get _completedPracticesKey => 'learning.$_scope.completed_practices';
  String get _sharedItemsKey => 'learning.$_scope.shared_items';
  String get _reviewedQuestionsKey => 'learning.$_scope.reviewed_questions';
  String get _correctQuestionsKey => 'learning.$_scope.correct_questions';
  String get _skippedQuestionsKey => 'learning.$_scope.skipped_questions';
  String get _skippedLessonsKey => 'learning.$_scope.skipped_lessons';
  String get _earnedCertificatesKey => 'learning.$_scope.earned_certificates';
  String get _learnerNameKey => 'learning.$_scope.learner_name';
  String get _activeDaysKey => 'learning.$_scope.active_days';

  static const Map<String, String> _legacyStorageKeys = <String, String>{
    'learning.completed_lessons': 'completed_lessons',
    'learning.completed_practices': 'completed_practices',
    'learning.shared_items': 'shared_items',
    'learning.reviewed_questions': 'reviewed_questions',
    'learning.correct_questions': 'correct_questions',
    'learning.skipped_questions': 'skipped_questions',
    'learning.skipped_lessons': 'skipped_lessons',
    'learning.earned_certificates': 'earned_certificates',
    'learning.learner_name': 'learner_name',
    'learning.active_days': 'active_days',
  };

  /// One-time migration for question IDs that were reused by different lessons.
  /// The first occurrence keeps its historical ID; later lessons receive unique IDs.
  static const Map<String, String> _legacyQuestionKeyMigrations = <String, String>{
    "extra-014::nursery-1": "extra-014::extra-014-nursery-1",
    "extra-014::nursery-2": "extra-014::extra-014-nursery-2",
    "extra-014::nursery-3": "extra-014::extra-014-nursery-3",
    "extra-033::graft-1": "extra-033::extra-033-graft-1",
    "extra-033::graft-2": "extra-033::extra-033-graft-2",
    "extra-033::graft-3": "extra-033::extra-033-graft-3",
    "extra-052::sc-1": "extra-052::extra-052-sc-1",
    "extra-052::sc-2": "extra-052::extra-052-sc-2",
    "extra-052::sc-3": "extra-052::extra-052-sc-3",
    "extra-059::tc-1": "extra-059::extra-059-tc-1",
    "extra-059::tc-2": "extra-059::extra-059-tc-2",
    "extra-059::tc-3": "extra-059::extra-059-tc-3",
    "extra-062::cc-1": "extra-062::extra-062-cc-1",
    "extra-062::cc-2": "extra-062::extra-062-cc-2",
    "extra-062::cc-3": "extra-062::extra-062-cc-3",
    "extra-066::fc-1": "extra-066::extra-066-fc-1",
    "extra-066::fc-2": "extra-066::extra-066-fc-2",
    "extra-066::fc-3": "extra-066::extra-066-fc-3",
    "extra-069::sc-1": "extra-069::extra-069-sc-1",
    "extra-069::sc-2": "extra-069::extra-069-sc-2",
    "extra-069::sc-3": "extra-069::extra-069-sc-3",
    "extra-074::dr-1": "extra-074::extra-074-dr-1",
    "extra-074::dr-2": "extra-074::extra-074-dr-2",
    "extra-074::dr-3": "extra-074::extra-074-dr-3",
    "extra-079::pc-1": "extra-079::extra-079-pc-1",
    "extra-079::pc-2": "extra-079::extra-079-pc-2",
    "extra-079::pc-3": "extra-079::extra-079-pc-3",
    "extra-083::ss-1": "extra-083::extra-083-ss-1",
    "extra-083::ss-2": "extra-083::extra-083-ss-2",
    "extra-083::ss-3": "extra-083::extra-083-ss-3",
    "extra-084::st-1": "extra-084::extra-084-st-1",
    "extra-084::st-2": "extra-084::extra-084-st-2",
    "extra-084::st-3": "extra-084::extra-084-st-3",
    "extra-086::fs-1": "extra-086::extra-086-fs-1",
    "extra-086::fs-2": "extra-086::extra-086-fs-2",
    "extra-086::fs-3": "extra-086::extra-086-fs-3",
    "extra-087::pt-1": "extra-087::extra-087-pt-1",
    "extra-087::pt-2": "extra-087::extra-087-pt-2",
    "extra-087::pt-3": "extra-087::extra-087-pt-3",
    "extra-091::dr-1": "extra-091::extra-091-dr-1",
    "extra-091::dr-2": "extra-091::extra-091-dr-2",
    "extra-091::dr-3": "extra-091::extra-091-dr-3",
    "extra-093::pc-1": "extra-093::extra-093-pc-1",
    "extra-093::pc-2": "extra-093::extra-093-pc-2",
    "extra-093::pc-3": "extra-093::extra-093-pc-3",
    "extra-095::sc-1": "extra-095::extra-095-sc-1",
    "extra-095::sc-2": "extra-095::extra-095-sc-2",
    "extra-095::sc-3": "extra-095::extra-095-sc-3",
    "extra-096::tc-1": "extra-096::extra-096-tc-1",
    "extra-096::tc-2": "extra-096::extra-096-tc-2",
    "extra-096::tc-3": "extra-096::extra-096-tc-3",
    "extra-097::ps-1": "extra-097::extra-097-ps-1",
    "extra-097::ps-2": "extra-097::extra-097-ps-2",
    "extra-097::ps-3": "extra-097::extra-097-ps-3",
    "extra-099::fs-1": "extra-099::extra-099-fs-1",
    "extra-099::fs-2": "extra-099::extra-099-fs-2",
    "extra-099::fs-3": "extra-099::extra-099-fs-3",
    "inventory-stock-control-advanced::inventory-stock-control-1": "inventory-stock-control-advanced::inventory-stock-control-advanced-inventory-stock-control-1",
    "inventory-stock-control-advanced::inventory-stock-control-2": "inventory-stock-control-advanced::inventory-stock-control-advanced-inventory-stock-control-2",
    "inventory-stock-control-advanced::inventory-stock-control-3": "inventory-stock-control-advanced::inventory-stock-control-advanced-inventory-stock-control-3",
    "inventory-stock-control-advanced::inventory-stock-control-4": "inventory-stock-control-advanced::inventory-stock-control-advanced-inventory-stock-control-4",
    "inventory-stock-control-advanced::inventory-stock-control-5": "inventory-stock-control-advanced::inventory-stock-control-advanced-inventory-stock-control-5",
    "livestock-body-condition-review::livestock-body-condition-1": "livestock-body-condition-review::livestock-body-condition-review-livestock-body-condition-1",
    "livestock-body-condition-review::livestock-body-condition-2": "livestock-body-condition-review::livestock-body-condition-review-livestock-body-condition-2",
    "livestock-body-condition-review::livestock-body-condition-3": "livestock-body-condition-review::livestock-body-condition-review-livestock-body-condition-3",
    "livestock-body-condition-review::livestock-body-condition-4": "livestock-body-condition-review::livestock-body-condition-review-livestock-body-condition-4",
    "livestock-body-condition-review::livestock-body-condition-5": "livestock-body-condition-review::livestock-body-condition-review-livestock-body-condition-5"
  };

  /// Completes when saved progress has been read. Every action awaits this so
  /// nothing can run (and save) against the empty initial state.
  late Future<void> _ready;

  /// Only true after a successful load. If loading failed we never write,
  /// because writing could overwrite saved data we were unable to read.
  bool _canPersist = false;

  /// Writes are chained so they happen one at a time, in order.
  Future<void> _pendingWrites = Future<void>.value();

  @override
  LearningState build() {
    _ready = _load();
    unawaited(_startFirebaseSync());
    return const LearningState();
  }

  Future<void> _startFirebaseSync() async {
    await _ready;
    _accountSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid != _loadedUid) unawaited(_switchAccount());
    });
    ref.onDispose(() => _accountSubscription?.cancel());
    await FirebaseLearningSync.instance.start(onRemoteEvents: _mergeRemoteEvents);
  }

  Future<void> _switchAccount() async {
    // Finish writes for the previous account before changing the storage scope.
    await _pendingWrites;
    _canPersist = false;
    state = const LearningState();
    _ready = _load();
    await _ready;
    await FirebaseLearningSync.instance.syncNow();
  }

  Future<void> _migrateLegacyStorage(SharedPreferences prefs) async {
    for (final MapEntry<String, String> entry in _legacyStorageKeys.entries) {
      final String oldKey = entry.key;
      final String newKey = 'learning.$_scope.${entry.value}';
      if (prefs.containsKey(newKey) || !prefs.containsKey(oldKey)) continue;
      try {
        if (entry.value == 'learner_name') {
          await prefs.setString(newKey, prefs.getString(oldKey) ?? '');
        } else {
          await prefs.setStringList(newKey, prefs.getStringList(oldKey) ?? <String>[]);
        }
        await prefs.remove(oldKey);
      } catch (error) {
        debugPrint('LearningNotifier: legacy progress migration failed for $oldKey: $error');
      }
    }
  }

  /// Rebuilds progress from immutable cloud events. All collections are merged
  /// as sets, so downloading the same history repeatedly never double-counts.
  Future<void> _mergeRemoteEvents(List<Map<String, dynamic>> events) async {
    await _ready;
    final Set<String> lessons = <String>{...state.completedLessons};
    final Set<String> practices = <String>{...state.completedPractices};
    final Set<String> shares = <String>{...state.sharedItems};
    final Set<String> reviewed = <String>{...state.reviewedQuestions};
    final Set<String> correct = <String>{...state.correctQuestions};
    final Set<String> skipped = <String>{...state.skippedQuestions};
    final Set<String> skippedLessons = <String>{...state.skippedLessons};
    final Map<String, CertificateRecord> certificates = <String, CertificateRecord>{
      for (final CertificateRecord c in state.earnedCertificates) c.lessonId: c,
    };
    String learnerName = state.learnerName;
    final Set<String> activeDays = <String>{...state.activeDays};
    final List<Map<String, dynamic>> ordered = <Map<String, dynamic>>[...events]
      ..sort((a, b) => (a['occurredAt'] ?? '').toString().compareTo((b['occurredAt'] ?? '').toString()));

    for (final Map<String, dynamic> event in ordered) {
      final String type = event['type']?.toString() ?? '';
      final String id = event['entityId']?.toString() ?? '';
      final String at = event['occurredAt']?.toString() ?? '';
      final DateTime occurredAt = DateTime.tryParse(at) ?? DateTime.now();
      if (event['activityDate'] is String &&
          <String>{'lessonCompleted', 'practiceCompleted', 'questionAnswered'}.contains(type)) {
        activeDays.add(event['activityDate'] as String);
      }
      switch (type) {
        case 'lessonCompleted':
          if (id.isNotEmpty) {
            lessons.add(id);
            certificates.putIfAbsent(id, () => CertificateRecord(
              lessonId: id,
              lessonTitle: event['lessonTitle']?.toString() ?? id,
              completedAt: occurredAt,
            ));
            skippedLessons.remove(id);
          }
          break;
        case 'practiceCompleted':
          if (id.isNotEmpty) practices.add(id);
          break;
        case 'practiceUncompleted':
          practices.remove(id);
          break;
        case 'itemShared':
          if (id.isNotEmpty) shares.add(id);
          break;
        case 'questionAnswered':
          final String key = '$id::${event['questionId'] ?? ''}';
          if (id.isNotEmpty && event['questionId'] != null) {
            reviewed.add(key);
            if (event['correct'] == true) correct.add(key);
            skipped.remove(key);
            skippedLessons.remove(id);
          }
          break;
        case 'questionSkipped':
          final String key = '$id::${event['questionId'] ?? ''}';
          if (id.isNotEmpty && event['questionId'] != null && !reviewed.contains(key)) skipped.add(key);
          break;
        case 'lessonSkipped':
          if (id.isNotEmpty && !lessons.contains(id)) skippedLessons.add(id);
          break;
        case 'learnerNameChanged':
          learnerName = event['name']?.toString() ?? learnerName;
          break;
      }
    }
    state = state.copyWith(
      completedLessons: lessons,
      completedPractices: practices,
      sharedItems: shares,
      reviewedQuestions: reviewed,
      correctQuestions: correct,
      skippedQuestions: skipped,
      skippedLessons: skippedLessons,
      earnedCertificates: certificates.values.toList(),
      learnerName: learnerName,
      activeDays: activeDays,
    );
    await _persist(<String>{
      _completedLessonsKey, _completedPracticesKey, _sharedItemsKey,
      _reviewedQuestionsKey, _correctQuestionsKey, _skippedQuestionsKey,
      _skippedLessonsKey, _earnedCertificatesKey, _learnerNameKey, _activeDaysKey,
    });
    // The same cloud history feeds the engagement record, which owns the
    // streak. It is merged in (never replaced), so offline progress stays.
    await ref.read(engagementProvider.notifier).mergeRemote(ordered);
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _loadedUid = FirebaseAuth.instance.currentUser?.uid;
      await _migrateLegacyStorage(prefs);

      Set<String> readSet(String key) {
        try {
          return (prefs.getStringList(key) ?? const <String>[]).toSet();
        } catch (error) {
          debugPrint('LearningNotifier: could not read $key: $error');
          return <String>{};
        }
      }

      final List<CertificateRecord> certificates = <CertificateRecord>[];
      try {
        for (final String raw
            in prefs.getStringList(_earnedCertificatesKey) ?? const <String>[]) {
          try {
            final Object? decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              final CertificateRecord record =
                  CertificateRecord.fromJson(decoded);
              if (record.lessonId.isNotEmpty) {
                certificates.add(record);
              }
            }
          } catch (error) {
            // One corrupt record must not discard everything else.
            debugPrint('LearningNotifier: skipped a corrupt certificate: $error');
          }
        }
      } catch (error) {
        debugPrint('LearningNotifier: could not read certificates: $error');
      }

      String learnerName = '';
      try {
        learnerName = prefs.getString(_learnerNameKey) ?? '';
      } catch (_) {}

      final Set<String> oldReviewed = readSet(_reviewedQuestionsKey);
      final Set<String> oldCorrect = readSet(_correctQuestionsKey);
      final Set<String> oldSkipped = readSet(_skippedQuestionsKey);
      final Set<String> reviewed = oldReviewed
          .map((String key) => _legacyQuestionKeyMigrations[key] ?? key)
          .toSet();
      final Set<String> correct = oldCorrect
          .map((String key) => _legacyQuestionKeyMigrations[key] ?? key)
          .toSet();
      final Set<String> skipped = oldSkipped
          .map((String key) => _legacyQuestionKeyMigrations[key] ?? key)
          .toSet();

      state = LearningState(
        completedLessons: readSet(_completedLessonsKey),
        completedPractices: readSet(_completedPracticesKey),
        sharedItems: readSet(_sharedItemsKey),
        reviewedQuestions: reviewed,
        correctQuestions: correct,
        skippedQuestions: skipped,
        skippedLessons: readSet(_skippedLessonsKey),
        earnedCertificates: certificates,
        learnerName: learnerName,
        activeDays: readSet(_activeDaysKey),
        isLoaded: true,
      );
      _canPersist = true;
      if (!setEquals(oldReviewed, reviewed) ||
          !setEquals(oldCorrect, correct) ||
          !setEquals(oldSkipped, skipped)) {
        await _persist(<String>{
          _reviewedQuestionsKey,
          _correctQuestionsKey,
          _skippedQuestionsKey,
        });
      }
    } catch (error) {
      debugPrint('LearningNotifier: failed to load saved progress: $error');
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> _writeKey(SharedPreferences prefs, String key) async {
    if (key == _completedLessonsKey) {
      await prefs.setStringList(key, state.completedLessons.toList());
    } else if (key == _completedPracticesKey) {
      await prefs.setStringList(key, state.completedPractices.toList());
    } else if (key == _sharedItemsKey) {
      await prefs.setStringList(key, state.sharedItems.toList());
    } else if (key == _reviewedQuestionsKey) {
      await prefs.setStringList(key, state.reviewedQuestions.toList());
    } else if (key == _correctQuestionsKey) {
      await prefs.setStringList(key, state.correctQuestions.toList());
    } else if (key == _skippedQuestionsKey) {
      await prefs.setStringList(key, state.skippedQuestions.toList());
    } else if (key == _skippedLessonsKey) {
      await prefs.setStringList(key, state.skippedLessons.toList());
    } else if (key == _earnedCertificatesKey) {
      await prefs.setStringList(
        key,
        state.earnedCertificates
            .map((CertificateRecord record) => jsonEncode(record.toJson()))
            .toList(),
      );
    } else if (key == _learnerNameKey) {
      await prefs.setString(key, state.learnerName);
    } else if (key == _activeDaysKey) {
      await prefs.setStringList(key, state.activeDays.toList()..sort());
    }
  }

  /// Saves only the given keys, using the latest state at the time of writing.
  Future<void> _persist(Set<String> keys) {
    if (!_canPersist) {
      return Future<void>.value();
    }
    _pendingWrites = _pendingWrites.then((_) async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        for (final String key in keys) {
          await _writeKey(prefs, key);
        }
      } catch (error) {
        debugPrint('LearningNotifier: failed to save progress: $error');
      }
    });
    return _pendingWrites;
  }

  String _todayActivityDate() {
    final DateTime now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  Future<String> _recordActivityDay() async {
    await _ready;
    final String date = _todayActivityDate();
    if (!state.activeDays.contains(date)) {
      state = state.copyWith(activeDays: <String>{...state.activeDays, date});
      await _persist(<String>{_activeDaysKey});
    }
    return date;
  }

  /// Marks a lesson complete, issues its certificate and pays XP / streak
  /// credit through the engagement record. [correctAnswers] and
  /// [totalQuestions] default to what the learner actually answered in this
  /// lesson. Returns the reward so the caller can celebrate it.
  Future<LessonReward> completeLesson(
    String lessonId, {
    String? lessonTitle,
    int? correctAnswers,
    int? totalQuestions,
  }) async {
    await _ready;
    final Set<String> completedLessons = <String>{
      ...state.completedLessons,
      lessonId,
    };
    final Set<String> skippedLessons = <String>{...state.skippedLessons}
      ..remove(lessonId);
    final List<CertificateRecord> earnedCertificates = <CertificateRecord>[
      ...state.earnedCertificates,
    ];

    final bool certificateExists = earnedCertificates.any(
      (CertificateRecord record) => record.lessonId == lessonId,
    );
    if (!certificateExists) {
      earnedCertificates.add(
        CertificateRecord(
          lessonId: lessonId,
          lessonTitle: lessonTitle ?? lessonId,
          completedAt: DateTime.now(),
        ),
      );
    }

    state = state.copyWith(
      completedLessons: completedLessons,
      skippedLessons: skippedLessons,
      earnedCertificates: earnedCertificates,
    );
    final String activityDate = await _recordActivityDay();
    await FirebaseLearningSync.instance.record('lessonCompleted', <String, dynamic>{
      'entityId': lessonId,
      'lessonTitle': lessonTitle ?? lessonId,
      'activityDate': activityDate,
    });
    await _persist(<String>{
      _completedLessonsKey,
      _skippedLessonsKey,
      _earnedCertificatesKey,
    });

    final String prefix = '$lessonId::';
    final int answered =
        state.reviewedQuestions.where((String k) => k.startsWith(prefix)).length;
    final int right =
        state.correctQuestions.where((String k) => k.startsWith(prefix)).length;
    return ref.read(engagementProvider.notifier).recordLessonComplete(
          lessonId: lessonId,
          correctAnswers: correctAnswers ?? right,
          totalQuestions: totalQuestions ?? answered,
        );
  }

  Future<void> completePractice(String practiceId) =>
      setPracticeCompleted(practiceId, true);

  Future<void> setPracticeCompleted(String practiceId, bool completed) async {
    await _ready;
    final Set<String> practices = <String>{...state.completedPractices};
    final bool firstTime = completed && !practices.contains(practiceId);
    if (completed) {
      practices.add(practiceId);
    } else {
      practices.remove(practiceId);
    }
    state = state.copyWith(completedPractices: practices);
    final String? activityDate = completed ? await _recordActivityDay() : null;
    await FirebaseLearningSync.instance.record(
      completed ? 'practiceCompleted' : 'practiceUncompleted',
      <String, dynamic>{'entityId': practiceId, if (activityDate != null) 'activityDate': activityDate},
    );
    await _persist(<String>{_completedPracticesKey});
    if (firstTime) {
      await ref.read(engagementProvider.notifier).awardXp(5);
    } else if (completed) {
      await ref.read(engagementProvider.notifier).recordActivity();
    }
  }

  Future<void> markShared(String itemId) async {
    await _ready;
    state = state.copyWith(
      sharedItems: <String>{...state.sharedItems, itemId},
    );
    await FirebaseLearningSync.instance.record('itemShared', <String, dynamic>{'entityId': itemId});
    await _persist(<String>{_sharedItemsKey});
  }

  /// Records an answered question. Answering also clears any "skipped" marker
  /// for the question and for its lesson.
  Future<void> recordAnswer({
    required String lessonId,
    required String questionId,
    required bool correct,
  }) async {
    await _ready;
    final String key = '$lessonId::$questionId';
    final bool firstAnswer = !state.reviewedQuestions.contains(key);
    state = state.copyWith(
      reviewedQuestions: <String>{...state.reviewedQuestions, key},
      correctQuestions: correct
          ? <String>{...state.correctQuestions, key}
          : state.correctQuestions,
      skippedQuestions: <String>{...state.skippedQuestions}..remove(key),
      skippedLessons: <String>{...state.skippedLessons}..remove(lessonId),
    );
    final String activityDate = await _recordActivityDay();
    await FirebaseLearningSync.instance.record('questionAnswered', <String, dynamic>{
      'entityId': lessonId, 'questionId': questionId, 'correct': correct,
      'activityDate': activityDate,
    });
    await _persist(<String>{
      _reviewedQuestionsKey,
      _correctQuestionsKey,
      _skippedQuestionsKey,
      _skippedLessonsKey,
    });
    // First answers earn XP; later answers still keep the daily streak alive.
    if (firstAnswer) {
      await ref.read(engagementProvider.notifier).awardXp(1);
    } else {
      await ref.read(engagementProvider.notifier).recordActivity();
    }
  }

  /// Marks a question as skipped. Skipping never counts as progress.
  Future<void> skipQuestion({
    required String lessonId,
    required String questionId,
  }) async {
    await _ready;
    final String key = '$lessonId::$questionId';
    if (state.reviewedQuestions.contains(key)) {
      return;
    }
    state = state.copyWith(
      skippedQuestions: <String>{...state.skippedQuestions, key},
    );
    await FirebaseLearningSync.instance.record('questionSkipped', <String, dynamic>{
      'entityId': lessonId, 'questionId': questionId,
    });
    await _persist(<String>{_skippedQuestionsKey});
  }

  Future<void> skipLesson(String lessonId) async {
    await _ready;
    state = state.copyWith(
      skippedLessons: <String>{...state.skippedLessons, lessonId},
    );
    await FirebaseLearningSync.instance.record('lessonSkipped', <String, dynamic>{'entityId': lessonId});
    await _persist(<String>{_skippedLessonsKey});
  }

  Future<void> setLearnerName(String name) async {
    await _ready;
    final String trimmed = name.trim();
    state = state.copyWith(
      learnerName: trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed,
    );
    await FirebaseLearningSync.instance.record('learnerNameChanged', <String, dynamic>{'name': state.learnerName});
    await _persist(<String>{_learnerNameKey});
  }
}
