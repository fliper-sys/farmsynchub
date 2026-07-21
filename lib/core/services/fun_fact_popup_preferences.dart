import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the fun-fact popup has already been shown today, per user.
abstract final class FunFactPopupPreferences {
  static const String _keyPrefix = 'fun_fact_shown_';

  static Future<bool> shouldShowToday(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? lastShown = prefs.getString('$_keyPrefix$userId');
    return lastShown != _todayKey();
  }

  static Future<void> markShownToday(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$userId', _todayKey());
  }

  static String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
