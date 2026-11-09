import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/remote/firebase_service.dart';
import '../domain/models/stock_movement.dart';
import 'auth_provider.dart';

export '../domain/models/stock_movement.dart';

/// Every change to inventory, newest first. Saved on the device first
/// (per account) so it works offline, then merged to the cloud in the
/// background. Rows are never edited - a correction is a new row.
final stockLedgerProvider =
    StateNotifierProvider<StockLedgerNotifier, List<StockMovement>>((ref) {
  // Rebuilt for every account so one person never sees another's records.
  ref.watch(sessionUidProvider);
  return StockLedgerNotifier(ref.watch(firebaseServiceProvider));
});

class StockLedgerNotifier extends StateNotifier<List<StockMovement>> {
  StockLedgerNotifier(this._remote) : super(const <StockMovement>[]) {
    _load();
  }

  final FirebaseService _remote;

  static const String _collection = 'stock_ledger';
  static const int _maxRows = 2000;

  Timer? _syncTimer;
  bool _loaded = false;
  final List<StockMovement> _pendingBeforeLoad = <StockMovement>[];

  String get _localKey {
    // Scoped by account so two people sharing a phone never see each
    // other's stock history.
    final String? uid = _remote.currentUser?.uid;
    return 'stock_ledger.v1.${(uid == null || uid.isEmpty) ? 'guest' : uid}';
  }

  Future<void> _load() async {
    List<StockMovement> rows = <StockMovement>[];
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_localKey);
      if (raw != null && raw.isNotEmpty) {
        final Object? decoded = jsonDecode(raw);
        if (decoded is List<dynamic>) {
          rows = decoded
              .whereType<Map<dynamic, dynamic>>()
              .map((Map<dynamic, dynamic> m) =>
                  StockMovement.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
    } catch (error) {
      debugPrint('StockLedger: could not read local ledger: $error');
    }
    if (!mounted) return;
    _loaded = true;
    final bool hadPending = _pendingBeforeLoad.isNotEmpty;
    state = _merge(<StockMovement>[...rows, ..._pendingBeforeLoad]);
    _pendingBeforeLoad.clear();
    if (hadPending) {
      await _saveLocal();
      _scheduleCloudSync();
    }
    unawaited(_pullRemote());
  }

  /// Newest first, unique by id, capped.
  List<StockMovement> _merge(List<StockMovement> rows) {
    final Map<String, StockMovement> byId = <String, StockMovement>{};
    for (final StockMovement row in <StockMovement>[...state, ...rows]) {
      if (row.id.isEmpty) continue;
      byId[row.id] = row;
    }
    final List<StockMovement> merged = byId.values.toList()
      ..sort((StockMovement a, StockMovement b) =>
          b.createdAt.compareTo(a.createdAt));
    return merged.length > _maxRows ? merged.sublist(0, _maxRows) : merged;
  }

  Future<void> _pullRemote() async {
    if (!_remote.hasActiveUser) return;
    try {
      final List<Map<String, dynamic>> docs =
          await _remote.getFromFirestore(_collection);
      final List<StockMovement> remoteRows = <StockMovement>[];
      for (final Map<String, dynamic> doc in docs) {
        final dynamic payload = doc['payload'];
        if (payload is Map) {
          final dynamic list = payload['movements'];
          if (list is List) {
            for (final dynamic item in list) {
              if (item is Map) {
                remoteRows
                    .add(StockMovement.fromJson(Map<String, dynamic>.from(item)));
              }
            }
          }
        }
      }
      if (remoteRows.isEmpty || !mounted) return;
      state = _merge(remoteRows);
      await _saveLocal();
    } catch (error) {
      debugPrint('StockLedger: cloud pull skipped: $error');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localKey,
        jsonEncode(state.map((StockMovement m) => m.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('StockLedger: could not save locally: $error');
    }
  }

  void _scheduleCloudSync() {
    if (!_remote.hasActiveUser) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 4), () async {
      try {
        await _remote.syncToFirestore(_collection, <String, dynamic>{
          'id': _collection,
          'payload': <String, dynamic>{
            'movements': state.map((StockMovement m) => m.toJson()).toList(),
          },
        });
      } catch (error) {
        debugPrint('StockLedger: cloud sync deferred: $error');
      }
    });
  }

  /// Adds one row. Always written locally; the cloud copy follows.
  Future<void> record(StockMovement movement) async {
    if (!_loaded) {
      _pendingBeforeLoad.add(movement);
      return;
    }
    state = _merge(<StockMovement>[movement]);
    await _saveLocal();
    _scheduleCloudSync();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
