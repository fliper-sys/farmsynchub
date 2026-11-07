import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps one account's on-device records from leaking into another account.
///
/// Farms, crops, livestock and the other offline caches are stored under keys
/// shared by every account that signs in on the device. Without this, signing
/// out and into a different account would briefly (or permanently) show the
/// previous person's data. The cache is therefore stamped with the owning
/// account's uid, wiped on sign-out, and wiped again on sign-in if the stamp
/// belongs to someone else (for example after the session expired).
abstract final class SessionCache {
  static const String _ownerKey = 'farmsync.cache_owner_uid';

  /// Device-wide records that belong to the signed-in account. Settings such
  /// as language, theme and onboarding are deliberately NOT listed: they
  /// describe the device, not the account.
  ///
  /// Records already stored per account (notifications, stock ledger,
  /// engagement) are keyed by uid and need no purge.
  static const List<String> accountKeys = <String>[
    'farmsync.farms',
    'farmsync.crops',
    'farmsync.livestock',
    'farmsync.health_logs',
    'farmsync.inventory_items',
    'farmsync.procurement_orders',
    'farmsync.transactions',
    'farmsync.expense_entries',
    'active_farm_id',
    'operations_hub_state',
    'finance_ai_recap_history',
    'news_followed_authors',
  ];

  /// Removes every account-owned cache entry and the owner stamp.
  static Future<void> clear() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      for (final String key in accountKeys) {
        await prefs.remove(key);
      }
      await prefs.remove(_ownerKey);
    } catch (error) {
      debugPrint('SessionCache: could not clear cache: $error');
    }
  }

  /// Declares that [uid] is now using the device. Wipes the cache first when
  /// it was last filled by a different account. Does nothing when signed out
  /// (sign-out already clears the cache).
  static Future<void> claim(String? uid) async {
    if (uid == null || uid.isEmpty) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? owner = prefs.getString(_ownerKey);
      if (owner != null && owner != uid) {
        await clear();
      }
      await prefs.setString(_ownerKey, uid);
    } catch (error) {
      debugPrint('SessionCache: could not claim cache: $error');
    }
  }
}
