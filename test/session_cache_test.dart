import 'package:farmsynchub/core/services/session_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'farmsync.farms': <String>['{"id":"a"}'],
      'farmsync.crops': <String>['{"id":"c"}'],
      'active_farm_id': 'a',
      'theme_mode': 'dark',
      'ai_language': 'ha',
    });
  });

  test('first claim keeps existing records and stamps the owner', () async {
    await SessionCache.claim('user-1');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('farmsync.farms'), isNotEmpty);
    expect(prefs.getString('farmsync.cache_owner_uid'), 'user-1');
  });

  test('claiming as the same account keeps the cache', () async {
    await SessionCache.claim('user-1');
    await SessionCache.claim('user-1');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('farmsync.crops'), isNotEmpty);
  });

  test('a different account never sees the previous account cache', () async {
    await SessionCache.claim('user-1');
    await SessionCache.claim('user-2');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('farmsync.farms'), isNull);
    expect(prefs.getStringList('farmsync.crops'), isNull);
    expect(prefs.getString('active_farm_id'), isNull);
    expect(prefs.getString('farmsync.cache_owner_uid'), 'user-2');
  });

  test('clear removes account records but keeps device settings', () async {
    await SessionCache.claim('user-1');
    await SessionCache.clear();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('farmsync.farms'), isNull);
    expect(prefs.getString('farmsync.cache_owner_uid'), isNull);
    expect(prefs.getString('theme_mode'), 'dark');
    expect(prefs.getString('ai_language'), 'ha');
  });

  test('claiming while signed out changes nothing', () async {
    await SessionCache.claim(null);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('farmsync.farms'), isNotEmpty);
  });
}
