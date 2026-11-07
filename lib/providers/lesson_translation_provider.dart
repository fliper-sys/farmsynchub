import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/gemini_service.dart';
import 'app_preferences_provider.dart';

/// Per-lesson, per-language cache of AI translations.
///
/// Lessons are English-only source content (about 270 lessons). The sentences
/// that repeat across lessons are translated by hand in
/// lib/core/i18n/lesson_boilerplate.dart; everything else is translated on
/// demand the first time a learner opens a lesson in Hausa or Pidgin, then
/// stored on the device so it works offline afterwards.
class LessonTranslationState {
  const LessonTranslationState({
    this.translations = const <String, Map<String, String>>{},
    this.loading = const <String>{},
    this.failed = const <String>{},
  });

  /// key `<language>|<lessonId>` -> english sentence -> translated sentence.
  final Map<String, Map<String, String>> translations;
  final Set<String> loading;
  final Set<String> failed;

  static String keyFor(AppLanguage language, String lessonId) =>
      '${language.name}|$lessonId';

  Map<String, String> forLesson(AppLanguage language, String lessonId) =>
      translations[keyFor(language, lessonId)] ?? const <String, String>{};

  bool isLoading(AppLanguage language, String lessonId) =>
      loading.contains(keyFor(language, lessonId));

  bool hasFailed(AppLanguage language, String lessonId) =>
      failed.contains(keyFor(language, lessonId));
}

class LessonTranslationNotifier extends StateNotifier<LessonTranslationState> {
  LessonTranslationNotifier() : super(const LessonTranslationState());

  static const String _prefix = 'lesson_tr_v1_';
  static const int _batchSentences = 30;
  static const int _batchChars = 5000;

  static String? languageName(AppLanguage language) {
    switch (language) {
      case AppLanguage.hausa:
        return 'Hausa';
      case AppLanguage.pidgin:
        return 'Nigerian Pidgin (Naija Pidgin)';
      case AppLanguage.english:
      case AppLanguage.french:
        return null;
    }
  }

  /// Loads the cached translation for a lesson from disk (cheap, no network)
  /// so list screens can show already-translated titles.
  Future<void> loadCached(AppLanguage language, String lessonId) async {
    final String key = LessonTranslationState.keyFor(language, lessonId);
    if (state.translations.containsKey(key)) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('$_prefix$key');
      if (raw == null) return;
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      _put(key, decoded.map((String k, dynamic v) => MapEntry(k, '$v')));
    } catch (_) {
      // Corrupt cache entry: ignore and re-translate when needed.
    }
  }

  /// Loads cached translations for many lessons with a single state update.
  Future<void> loadCachedMany(
      AppLanguage language, Iterable<String> lessonIds) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, Map<String, String>> next =
          Map<String, Map<String, String>>.from(state.translations);
      bool changed = false;
      for (final String id in lessonIds) {
        final String key = LessonTranslationState.keyFor(language, id);
        if (next.containsKey(key)) continue;
        final String? raw = prefs.getString('$_prefix$key');
        if (raw == null) continue;
        try {
          final Map<String, dynamic> decoded =
              jsonDecode(raw) as Map<String, dynamic>;
          next[key] = decoded.map((String k, dynamic v) => MapEntry(k, '$v'));
          changed = true;
        } catch (_) {}
      }
      if (changed && mounted) {
        state = LessonTranslationState(
          translations: next,
          loading: state.loading,
          failed: state.failed,
        );
      }
    } catch (_) {}
  }

  /// Translates [sentences] (the lesson text not covered by the built-in
  /// table) and caches the result. Safe to call repeatedly.
  Future<void> ensure({
    required AppLanguage language,
    required String lessonId,
    required List<String> sentences,
  }) async {
    final String? name = languageName(language);
    if (name == null || sentences.isEmpty) return;
    final String key = LessonTranslationState.keyFor(language, lessonId);

    await loadCached(language, lessonId);
    final Map<String, String> have = state.translations[key] ?? const {};
    final List<String> missing =
        sentences.where((String s) => !have.containsKey(s)).toList();
    if (missing.isEmpty || state.loading.contains(key)) return;

    state = LessonTranslationState(
      translations: state.translations,
      loading: <String>{...state.loading, key},
      failed: <String>{...state.failed}..remove(key),
    );

    final Map<String, String> merged = Map<String, String>.from(have);
    bool anyFailed = false;
    int i = 0;
    while (i < missing.length) {
      final List<String> batch = <String>[];
      int chars = 0;
      while (i < missing.length &&
          batch.length < _batchSentences &&
          (batch.isEmpty || chars + missing[i].length <= _batchChars)) {
        batch.add(missing[i]);
        chars += missing[i].length;
        i++;
      }
      final List<String>? out =
          await GeminiService.instance.translateTexts(batch, name);
      if (out == null) {
        anyFailed = true;
        break;
      }
      for (int j = 0; j < batch.length; j++) {
        merged[batch[j]] = out[j];
      }
    }

    if (merged.length > have.length) {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_prefix$key', jsonEncode(merged));
      } catch (error) {
        debugPrint('[LessonTranslation] cache write failed: $error');
      }
    }
    if (!mounted) return;
    state = LessonTranslationState(
      translations: <String, Map<String, String>>{
        ...state.translations,
        key: merged,
      },
      loading: <String>{...state.loading}..remove(key),
      failed: anyFailed ? <String>{...state.failed, key} : state.failed,
    );
  }

  void _put(String key, Map<String, String> value) {
    if (!mounted) return;
    state = LessonTranslationState(
      translations: <String, Map<String, String>>{
        ...state.translations,
        key: value,
      },
      loading: state.loading,
      failed: state.failed,
    );
  }
}

final StateNotifierProvider<LessonTranslationNotifier, LessonTranslationState>
    lessonTranslationProvider = StateNotifierProvider<LessonTranslationNotifier,
        LessonTranslationState>(
  (Ref ref) => LessonTranslationNotifier(),
);
