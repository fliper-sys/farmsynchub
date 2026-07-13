import 'dart:convert';

import '../../../domain/models/livestock.dart';
import '../database.dart';

/// Persists livestock records locally so they survive app restarts.
class LivestockDao {
  LivestockDao(this._database);

  static const String _storageKey = 'farmsync.livestock';

  final LocalDatabase _database;

  Future<List<Livestock>> getAll() async {
    final prefs = await _database.instance;
    final List<String> rawItems = prefs.getStringList(_storageKey) ?? <String>[];

    return rawItems
        .map((String item) => jsonDecode(item) as Map<String, dynamic>)
        .map(Livestock.fromJson)
        .toList();
  }

  Future<Livestock?> getById(String id) async {
    final List<Livestock> livestock = await getAll();
    for (final Livestock item in livestock) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<void> upsert(Livestock animal) async {
    final List<Livestock> livestock = await getAll();
    final int index = livestock.indexWhere((Livestock item) => item.id == animal.id);
    if (index == -1) {
      livestock.add(animal);
    } else {
      livestock[index] = animal;
    }
    await replaceAll(livestock);
  }

  Future<void> replaceAll(List<Livestock> livestock) async {
    final prefs = await _database.instance;
    final List<String> encoded = livestock.map((Livestock item) => jsonEncode(item.toJson())).toList(growable: false);
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> delete(String id) async {
    final List<Livestock> livestock = await getAll();
    livestock.removeWhere((Livestock item) => item.id == id);
    await replaceAll(livestock);
  }
}
