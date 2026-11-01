import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable, account-scoped outbox for offline learning activity.
/// Firestore event documents are immutable and use client-generated IDs so
/// retries cannot award duplicate progress or certificates.
class FirebaseLearningSync with WidgetsBindingObserver {
  FirebaseLearningSync._();
  static final FirebaseLearningSync instance = FirebaseLearningSync._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  // connectivity_plus ^5 emits one result per change (v6 emits a List).
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  StreamSubscription<User?>? _authSub;
  bool _syncRequested = false;
  Future<void> Function(List<Map<String, dynamic>> events)? _onRemoteEvents;
  bool _started = false;
  bool _syncing = false;
  String? _lastError;

  String? get lastError => _lastError;
  bool get isSyncing => _syncing;

  Future<void> start({
    required Future<void> Function(List<Map<String, dynamic>> events)
        onRemoteEvents,
  }) async {
    _onRemoteEvents = onRemoteEvents;
    if (_started) {
      await syncNow();
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        unawaited(syncNow());
      }
    }, onError: (Object e) => _lastError = e.toString());
    _authSub = _auth.userChanges().listen((_) => unawaited(syncNow()));
    await syncNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow());
  }

  String _queueKey(String uid) => 'farmsync.sync.outbox.$uid';

  String _newEventId() {
    final int micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    final String random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '${micros}_$random';
  }

  /// Call only after the corresponding local progress write has succeeded.
  Future<void> record(String type, Map<String, dynamic> fields) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      debugPrint('FarmSync: progress saved locally; sign-in required before cloud sync.');
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = _queueKey(user.uid);
    final List<Map<String, dynamic>> queue = _readQueue(prefs, key);
    final DateTime now = DateTime.now().toUtc();
    queue.add(<String, dynamic>{
      'eventId': _newEventId(),
      'uid': user.uid,
      'type': type,
      'occurredAt': now.toIso8601String(),
      ...fields,
    });
    await prefs.setStringList(
      key,
      queue.map((event) => jsonEncode(event)).toList(growable: false),
    );
    unawaited(syncNow());
  }

  List<Map<String, dynamic>> _readQueue(SharedPreferences prefs, String key) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final String raw in prefs.getStringList(key) ?? const <String>[]) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map) result.add(Map<String, dynamic>.from(decoded));
      } catch (e) {
        debugPrint('FarmSync: ignoring malformed outbox record: $e');
      }
    }
    return result;
  }

  Future<void> syncNow() async {
    if (_syncing) { _syncRequested = true; return; }
    final User? user = _auth.currentUser;
    if (user == null) return;
    _syncing = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = _queueKey(user.uid);
      final List<Map<String, dynamic>> queue = _readQueue(prefs, key);
      final CollectionReference<Map<String, dynamic>> eventsRef = _db
          .collection('users').doc(user.uid).collection('learningEvents');

      // Sequential, idempotent writes: an interrupted batch is safe to retry.
      final List<Map<String, dynamic>> remaining = <Map<String, dynamic>>[];
      for (final Map<String, dynamic> event in queue) {
        if (event['uid'] != user.uid) continue;
        try {
          final String eventId = event['eventId'] as String;
          await eventsRef.doc(eventId).set(event, SetOptions(merge: false));
        } catch (e) {
          remaining.add(event);
          _lastError = e.toString();
        }
      }
      await prefs.setStringList(
        key,
        remaining.map((event) => jsonEncode(event)).toList(growable: false),
      );

      // Fetch remote event history so a second device can rebuild the same
      // progress. Event IDs are stable; provider merging is set-based.
      final QuerySnapshot<Map<String, dynamic>> snapshot = await eventsRef.get();
      final List<Map<String, dynamic>> remote = snapshot.docs
          .map((doc) => doc.data())
          .toList(growable: false);
      await _onRemoteEvents?.call(remote);
      _lastError = remaining.isEmpty ? null : _lastError;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('FarmSync sync failed; queued activity will be retried: $e');
    } finally {
      _syncing = false;
      if (_syncRequested) {
        _syncRequested = false;
        unawaited(syncNow());
      }
    }
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _authSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}
