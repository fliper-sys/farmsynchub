import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class LearningState {
  const LearningState({
    this.completedLessons = const <String>{},
    this.completedPractices = const <String>{},
    this.sharedItems = const <String>{},
    this.reviewedQuestions = const <String>{},
    this.skippedLessons = const <String>{},
    this.earnedCertificates = const <CertificateRecord>[],
  });

  final Set<String> completedLessons;
  final Set<String> completedPractices;
  final Set<String> sharedItems;
  final Set<String> reviewedQuestions;
  final Set<String> skippedLessons;
  final List<CertificateRecord> earnedCertificates;

  int get awardCount {
    var count = 0;
    if (completedLessons.isNotEmpty) {
      count++;
    }
    if (completedLessons.length >= 3) {
      count++;
    }
    if (completedPractices.length >= 2) {
      count++;
    }
    if (sharedItems.isNotEmpty) {
      count++;
    }
    if (reviewedQuestions.isNotEmpty) {
      count++;
    }
    if (earnedCertificates.isNotEmpty) {
      count++;
    }
    return count;
  }

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
    Set<String>? skippedLessons,
    List<CertificateRecord>? earnedCertificates,
  }) {
    return LearningState(
      completedLessons: completedLessons ?? this.completedLessons,
      completedPractices: completedPractices ?? this.completedPractices,
      sharedItems: sharedItems ?? this.sharedItems,
      reviewedQuestions: reviewedQuestions ?? this.reviewedQuestions,
      skippedLessons: skippedLessons ?? this.skippedLessons,
      earnedCertificates: earnedCertificates ?? this.earnedCertificates,
    );
  }
}

final learningProvider =
    StateNotifierProvider<LearningNotifier, LearningState>((Ref ref) {
  return LearningNotifier();
});

class LearningNotifier extends StateNotifier<LearningState> {
  LearningNotifier() : super(const LearningState()) {
    _load();
  }

  static const String _completedLessonsKey = 'learning.completed_lessons';
  static const String _completedPracticesKey = 'learning.completed_practices';
  static const String _sharedItemsKey = 'learning.shared_items';
  static const String _reviewedQuestionsKey = 'learning.reviewed_questions';
  static const String _skippedLessonsKey = 'learning.skipped_lessons';
  static const String _earnedCertificatesKey = 'learning.earned_certificates';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<CertificateRecord> loadedCertificates = (prefs.getStringList(_earnedCertificatesKey) ?? <String>[])
        .map((String raw) {
          final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
          return CertificateRecord.fromJson(decoded);
        })
        .toList();

    state = LearningState(
      completedLessons:
          (prefs.getStringList(_completedLessonsKey) ?? <String>[]).toSet(),
      completedPractices:
          (prefs.getStringList(_completedPracticesKey) ?? <String>[]).toSet(),
      sharedItems: (prefs.getStringList(_sharedItemsKey) ?? <String>[]).toSet(),
      reviewedQuestions: (prefs.getStringList(_reviewedQuestionsKey) ?? <String>[]).toSet(),
      skippedLessons: (prefs.getStringList(_skippedLessonsKey) ?? <String>[]).toSet(),
      earnedCertificates: loadedCertificates,
    );
  }

  Future<void> _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_completedLessonsKey, state.completedLessons.toList());
    await prefs.setStringList(
      _completedPracticesKey,
      state.completedPractices.toList(),
    );
    await prefs.setStringList(_sharedItemsKey, state.sharedItems.toList());
    await prefs.setStringList(_reviewedQuestionsKey, state.reviewedQuestions.toList());
    await prefs.setStringList(_skippedLessonsKey, state.skippedLessons.toList());
    await prefs.setStringList(
      _earnedCertificatesKey,
      state.earnedCertificates.map((CertificateRecord record) => jsonEncode(record.toJson())).toList(),
    );
  }

  Future<void> completeLesson(String lessonId, {String? lessonTitle}) async {
    final Set<String> completedLessons = <String>{...state.completedLessons, lessonId};
    final List<CertificateRecord> earnedCertificates = <CertificateRecord>[...state.earnedCertificates];

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
      earnedCertificates: earnedCertificates,
    );
    await _save();
  }

  Future<void> completePractice(String practiceId) async {
    state = state.copyWith(
      completedPractices: <String>{...state.completedPractices, practiceId},
    );
    await _save();
  }

  Future<void> markShared(String itemId) async {
    state = state.copyWith(
      sharedItems: <String>{...state.sharedItems, itemId},
    );
    await _save();
  }

  Future<void> markQuestionReviewed({
    required String lessonId,
    required String questionId,
  }) async {
    final String key = '$lessonId::$questionId';
    state = state.copyWith(
      reviewedQuestions: <String>{...state.reviewedQuestions, key},
      skippedLessons: state.skippedLessons,
    );
    await _save();
  }

  Future<void> skipLesson(String lessonId) async {
    state = state.copyWith(
      skippedLessons: <String>{...state.skippedLessons, lessonId},
    );
    await _save();
  }
}
