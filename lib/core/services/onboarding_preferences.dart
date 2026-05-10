import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has already completed onboarding.
abstract final class OnboardingPreferences {
  static const String _completedKey = 'onboarding_completed';

  static Future<bool> isCompleted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }
}
