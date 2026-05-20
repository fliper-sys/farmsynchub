import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningState {
  const LearningState({
    this.completedLessons = const <String>{},
    this.completedPractices = const <String>{},
    this.sharedItems = const <String>{},
  });

  final Set<String> completedLessons;
  final Set<String> completedPractices;
  final Set<String> sharedItems;

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
    return count;
  }

  LearningState copyWith({
    Set<String>? completedLessons,
    Set<String>? completedPractices,
    Set<String>? sharedItems,
  }) {
    return LearningState(
      completedLessons: completedLessons ?? this.completedLessons,
      completedPractices: completedPractices ?? this.completedPractices,
      sharedItems: sharedItems ?? this.sharedItems,
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

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = LearningState(
      completedLessons:
          (prefs.getStringList(_completedLessonsKey) ?? <String>[]).toSet(),
      completedPractices:
          (prefs.getStringList(_completedPracticesKey) ?? <String>[]).toSet(),
      sharedItems: (prefs.getStringList(_sharedItemsKey) ?? <String>[]).toSet(),
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
}
