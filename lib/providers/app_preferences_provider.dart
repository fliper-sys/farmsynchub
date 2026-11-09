import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/pidgin_phrases.dart';

enum AppLanguage {
  english,
  hausa,
  french,
  pidgin,
}

extension AppLanguageBuildContext on BuildContext {
  /// Reads the current app language from the nearest ProviderScope without
  /// subscribing. Use inside StatelessWidgets whose parent already watches
  /// [appLanguageProvider] (so they rebuild when the language changes).
  AppLanguage get appLanguage =>
      ProviderScope.containerOf(this).read(appLanguageProvider);
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
      case AppLanguage.pidgin:
        return 'Pidgin';
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
      case AppLanguage.pidgin:
        // No Material localizations exist for Pidgin (pcm); English-Nigeria
        // keeps widget text (dialogs, pickers) readable.
        return const Locale('en', 'NG');
    }
  }

  String tr({
    required String en,
    String? ha,
    String? fr,
    String? pcm,
  }) {
    switch (this) {
      case AppLanguage.english:
        return en;
      case AppLanguage.hausa:
        return ha ?? en;
      case AppLanguage.french:
        return fr ?? en;
      case AppLanguage.pidgin:
        return pcm ?? kPidginPhrases[en] ?? en;
    }
  }
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier();
});

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
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

class AppSettings {
  const AppSettings({
    required this.notificationsEnabled,
    required this.reminderNotificationsEnabled,
    required this.autoSyncEnabled,
    required this.biometricLockEnabled,
  });

  final bool notificationsEnabled;
  final bool reminderNotificationsEnabled;
  final bool autoSyncEnabled;
  final bool biometricLockEnabled;

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? reminderNotificationsEnabled,
    bool? autoSyncEnabled,
    bool? biometricLockEnabled,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderNotificationsEnabled:
          reminderNotificationsEnabled ?? this.reminderNotificationsEnabled,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier()
      : super(const AppSettings(
          notificationsEnabled: true,
          reminderNotificationsEnabled: true,
          autoSyncEnabled: true,
          biometricLockEnabled: false,
        )) {
    _load();
  }

  static const String _notificationsKey = 'settings_notifications_enabled';
  static const String _remindersKey = 'settings_reminders_enabled';
  static const String _autoSyncKey = 'settings_auto_sync_enabled';
  static const String _biometricLockKey = 'settings_biometric_lock_enabled';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      notificationsEnabled: prefs.getBool(_notificationsKey) ?? true,
      reminderNotificationsEnabled: prefs.getBool(_remindersKey) ?? true,
      autoSyncEnabled: prefs.getBool(_autoSyncKey) ?? true,
      biometricLockEnabled: prefs.getBool(_biometricLockKey) ?? false,
    );
  }

  Future<void> _save(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, settings.notificationsEnabled);
    await prefs.setBool(_remindersKey, settings.reminderNotificationsEnabled);
    await prefs.setBool(_autoSyncKey, settings.autoSyncEnabled);
    await prefs.setBool(_biometricLockKey, settings.biometricLockEnabled);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    await _save(state);
  }

  Future<void> setReminderNotificationsEnabled(bool value) async {
    state = state.copyWith(reminderNotificationsEnabled: value);
    await _save(state);
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    state = state.copyWith(autoSyncEnabled: value);
    await _save(state);
  }

  Future<void> setBiometricLockEnabled(bool value) async {
    state = state.copyWith(biometricLockEnabled: value);
    await _save(state);
  }
}
