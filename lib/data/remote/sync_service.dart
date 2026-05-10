import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/models/crop.dart';
import '../../domain/models/farm.dart';
import '../../domain/models/health_log.dart';
import '../../domain/models/livestock.dart';
import '../../domain/models/transaction.dart';
import 'firebase_service.dart';

/// Service for syncing local data with cloud when online.
class SyncService {
  SyncService(this._firebaseService, this._connectivity);

  final FirebaseService _firebaseService;
  final Connectivity _connectivity;

  /// Check if device is online.
  Future<bool> isOnline() async {
    final ConnectivityResult result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Sync farms to cloud.
  Future<void> syncFarms(List<Farm> farms) async {
    if (!await isOnline()) return;

    for (final Farm farm in farms.where((Farm item) => !item.isSynced)) {
      try {
        await _firebaseService.syncToFirestore('farms', farm.toJson());
      } catch (e) {
        print('Failed to sync farm: ${farm.id}');
      }
    }
  }

  /// Sync crops to cloud.
  Future<void> syncCrops(List<Crop> crops) async {
    if (!await isOnline()) return;

    for (final Crop crop in crops.where((Crop item) => !item.isSynced)) {
      try {
        await _firebaseService.syncToFirestore('crops', crop.toJson());
      } catch (e) {
        print('Failed to sync crop: ${crop.id}');
      }
    }
  }

  /// Sync livestock to cloud.
  Future<void> syncLivestock(List<Livestock> livestock) async {
    if (!await isOnline()) return;

    for (final Livestock animal in livestock.where((Livestock item) => !item.isSynced)) {
      try {
        await _firebaseService.syncToFirestore('livestock', animal.toJson());
      } catch (e) {
        print('Failed to sync livestock: ${animal.id}');
      }
    }
  }

  /// Sync transactions to cloud.
  Future<void> syncTransactions(List<Transaction> transactions) async {
    if (!await isOnline()) return;

    for (final Transaction transaction in transactions.where((Transaction item) => !item.isSynced)) {
      try {
        await _firebaseService.syncToFirestore('transactions', transaction.toJson());
      } catch (e) {
        print('Failed to sync transaction: ${transaction.id}');
      }
    }
  }

  /// Sync health logs to cloud.
  Future<void> syncHealthLogs(List<HealthLog> healthLogs) async {
    if (!await isOnline()) return;

    for (final HealthLog log in healthLogs.where((HealthLog item) => !item.isSynced)) {
      try {
        await _firebaseService.syncToFirestore('health_logs', log.toJson());
      } catch (e) {
        print('Failed to sync health log: ${log.id}');
      }
    }
  }

  /// Pull data from cloud and merge records by newest update timestamp.
  Future<SyncPullSnapshot?> pullFromCloud() async {
    if (!await isOnline()) return null;

    try {
      final SyncPullSnapshot snapshot = SyncPullSnapshot(
        farms: _mergeRecords(await _firebaseService.getFromFirestore('farms')),
        crops: _mergeRecords(await _firebaseService.getFromFirestore('crops')),
        livestock: _mergeRecords(await _firebaseService.getFromFirestore('livestock')),
        transactions: _mergeRecords(await _firebaseService.getFromFirestore('transactions')),
        healthLogs: _mergeRecords(await _firebaseService.getFromFirestore('health_logs')),
      );

      print(
        'Pulled ${snapshot.farms.length} farms, '
        '${snapshot.crops.length} crops, '
        '${snapshot.livestock.length} livestock, '
        '${snapshot.transactions.length} transactions, '
        '${snapshot.healthLogs.length} health logs from cloud.',
      );

      return snapshot;
    } catch (e) {
      print('Failed to pull from cloud: $e');
      return null;
    }
  }

  /// Perform full sync (push local changes, pull remote changes).
  Future<SyncPullSnapshot?> fullSync({
    required List<Farm> farms,
    required List<Crop> crops,
    required List<Livestock> livestock,
    required List<Transaction> transactions,
    required List<HealthLog> healthLogs,
  }) async {
    if (!await isOnline()) return null;

    await Future.wait(<Future<void>>[
      syncFarms(farms),
      syncCrops(crops),
      syncLivestock(livestock),
      syncTransactions(transactions),
      syncHealthLogs(healthLogs),
    ]);

    return pullFromCloud();
  }

  List<Map<String, dynamic>> _mergeRecords(List<Map<String, dynamic>> cloudRecords) {
    final Map<String, Map<String, dynamic>> mergedById = <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> record in cloudRecords) {
      final Object? id = record['id'];
      if (id is! String || id.isEmpty) {
        continue;
      }

      final Map<String, dynamic>? current = mergedById[id];
      if (current == null) {
        mergedById[id] = record;
        continue;
      }

      if (_parseDate(record['updatedAt']).isAfter(_parseDate(current['updatedAt']))) {
        mergedById[id] = record;
      }
    }

    return mergedById.values.toList(growable: false);
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is Map<String, dynamic>) {
      final Object? seconds = value['_seconds'] ?? value['seconds'];
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class SyncPullSnapshot {
  const SyncPullSnapshot({
    required this.farms,
    required this.crops,
    required this.livestock,
    required this.transactions,
    required this.healthLogs,
  });

  final List<Map<String, dynamic>> farms;
  final List<Map<String, dynamic>> crops;
  final List<Map<String, dynamic>> livestock;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> healthLogs;
}
