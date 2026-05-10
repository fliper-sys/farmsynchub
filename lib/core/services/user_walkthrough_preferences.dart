import 'package:shared_preferences/shared_preferences.dart';

abstract final class UserWalkthroughPreferences {
  static const String _keyPrefix = 'walkthrough_completed_';

  static Future<bool> isCompleted(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyPrefix$userId') ?? false;
  }

  static Future<void> markCompleted(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$userId', true);
  }
}
