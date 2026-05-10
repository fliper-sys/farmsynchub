import 'package:shared_preferences/shared_preferences.dart';

/// Minimal local storage entry point for persisted app records.
class LocalDatabase {
  const LocalDatabase();

  Future<SharedPreferences> get instance => SharedPreferences.getInstance();
}
