import 'dart:convert';

import '../../../domain/models/health_log.dart';
import '../database.dart';

/// Persists health log records locally so they survive app restarts.
class HealthLogsDao {
  HealthLogsDao(this._database);

  static const String _storageKey = 'farmsync.health_logs';

  final LocalDatabase _database;

  Future<List<HealthLog>> getAll() async {
    final prefs = await _database.instance;
    final List<String> rawItems = prefs.getStringList(_storageKey) ?? <String>[];

    return rawItems
        .map((String item) => jsonDecode(item) as Map<String, dynamic>)
        .map(HealthLog.fromJson)
        .toList();
  }

  Future<HealthLog?> getById(String id) async {
    final List<HealthLog> logs = await getAll();
    for (final HealthLog log in logs) {
      if (log.id == id) {
        return log;
      }
    }
    return null;
  }

  Future<void> upsert(HealthLog log) async {
    final List<HealthLog> logs = await getAll();
    final int index = logs.indexWhere((HealthLog item) => item.id == log.id);
    if (index == -1) {
      logs.add(log);
    } else {
      logs[index] = log;
    }
    await replaceAll(logs);
  }

  Future<void> replaceAll(List<HealthLog> logs) async {
    final prefs = await _database.instance;
    final List<String> encoded = logs.map((HealthLog item) => jsonEncode(item.toJson())).toList(growable: false);
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> delete(String id) async {
    final List<HealthLog> logs = await getAll();
    logs.removeWhere((HealthLog item) => item.id == id);
    await replaceAll(logs);
  }
}
