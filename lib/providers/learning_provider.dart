import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningState {
  const LearningState({
    this.completedLessons = const <String>{},
    this.completedPractices = const <String>{},
    this.sharedItems = const <String>{},
    this.reviewedQuestions = const <String>{},
    this.skippedLessons = const <String>{},
  });

  final Set<String> completedLessons;
  final Set<String> completedPractices;
  final Set<String> sharedItems;
  final Set<String> reviewedQuestions;
  final Set<String> skippedLessons;

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
    return count;
  }

  LearningState copyWith({
    Set<String>? completedLessons,
    Set<String>? completedPractices,
    Set<String>? sharedItems,
    Set<String>? reviewedQuestions,
    Set<String>? skippedLessons,
  }) {
    return LearningState(
      completedLessons: completedLessons ?? this.completedLessons,
      completedPractices: completedPractices ?? this.completedPractices,
      sharedItems: sharedItems ?? this.sharedItems,
      reviewedQuestions: reviewedQuestions ?? this.reviewedQuestions,
      skippedLessons: skippedLessons ?? this.skippedLessons,
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

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = LearningState(
      completedLessons:
          (prefs.getStringList(_completedLessonsKey) ?? <String>[]).toSet(),
      completedPractices:
          (prefs.getStringList(_completedPracticesKey) ?? <String>[]).toSet(),
      sharedItems: (prefs.getStringList(_sharedItemsKey) ?? <String>[]).toSet(),
      reviewedQuestions: (prefs.getStringList(_reviewedQuestionsKey) ?? <String>[]).toSet(),
      skippedLessons: (prefs.getStringList(_skippedLessonsKey) ?? <String>[]).toSet(),
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
  }

  Future<void> completeLesson(String lessonId) async {
    state = state.copyWith(
      completedLessons: <String>{...state.completedLessons, lessonId},
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
