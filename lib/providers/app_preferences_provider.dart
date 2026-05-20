import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english,
  hausa,
  french,
}

extension AppLanguageX on AppLanguage {
  String get label {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.hausa:
        return 'Hausa';
      case AppLanguage.french:
        return 'French';
    }
  }

  Locale get locale {
    switch (this) {
      case AppLanguage.english:
        return const Locale('en');
      case AppLanguage.hausa:
        return const Locale('ha');
      case AppLanguage.french:
        return const Locale('fr');
    }
  }

  String tr({
    required String en,
    String? ha,
    String? fr,
  }) {
    switch (this) {
      case AppLanguage.english:
        return en;
      case AppLanguage.hausa:
        return ha ?? en;
      case AppLanguage.french:
        return fr ?? en;
    }
  }
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier();
});

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.english) {
    _load();
  }

  static const String _key = 'app_language';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_key) ?? AppLanguage.english.name;
    state = AppLanguage.values.firstWhere(
      (AppLanguage value) => value.name == raw,
      orElse: () => AppLanguage.english,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.name);
  }
}
