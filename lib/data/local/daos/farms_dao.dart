import 'dart:convert';

import '../../../domain/models/farm.dart';
import '../database.dart';

/// Persists farm records locally so they survive app restarts.
class FarmsDao {
  FarmsDao(this._database);

  static const String _storageKey = 'farmsync.farms';

  final LocalDatabase _database;

  Future<List<Farm>> getAll() async {
    final prefs = await _database.instance;
    final List<String> rawItems = prefs.getStringList(_storageKey) ?? <String>[];

    return rawItems
        .map((String item) => jsonDecode(item) as Map<String, dynamic>)
        .map(Farm.fromJson)
        .toList();
  }

  Future<Farm?> getById(String id) async {
    final List<Farm> farms = await getAll();
    for (final Farm farm in farms) {
      if (farm.id == id) {
        return farm;
      }
    }
    return null;
  }

  Future<void> upsert(Farm farm) async {
    final List<Farm> farms = await getAll();
    final int index = farms.indexWhere((Farm item) => item.id == farm.id);
    if (index == -1) {
      farms.add(farm);
    } else {
      farms[index] = farm;
    }
    await replaceAll(farms);
  }

  Future<void> replaceAll(List<Farm> farms) async {
    final prefs = await _database.instance;
    final List<String> encoded = farms
        .map((Farm farm) => jsonEncode(farm.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> delete(String id) async {
    final List<Farm> farms = await getAll();
    farms.removeWhere((Farm farm) => farm.id == id);
    await replaceAll(farms);
  }
}
