import 'dart:convert';

import '../../../domain/models/crop.dart';
import '../database.dart';

/// Persists crop records locally so they survive app restarts.
class CropsDao {
  CropsDao(this._database);

  static const String _storageKey = 'farmsync.crops';

  final LocalDatabase _database;

  Future<List<Crop>> getAll() async {
    final prefs = await _database.instance;
    final List<String> rawItems = prefs.getStringList(_storageKey) ?? <String>[];

    return rawItems
        .map((String item) => jsonDecode(item) as Map<String, dynamic>)
        .map(Crop.fromJson)
        .toList();
  }

  Future<Crop?> getById(String id) async {
    final List<Crop> crops = await getAll();
    for (final Crop crop in crops) {
      if (crop.id == id) {
        return crop;
      }
    }
    return null;
  }

  Future<void> upsert(Crop crop) async {
    final List<Crop> crops = await getAll();
    final int index = crops.indexWhere((Crop item) => item.id == crop.id);
    if (index == -1) {
      crops.add(crop);
    } else {
      crops[index] = crop;
    }
    await replaceAll(crops);
  }

  Future<void> replaceAll(List<Crop> crops) async {
    final prefs = await _database.instance;
    final List<String> encoded = crops.map((Crop crop) => jsonEncode(crop.toJson())).toList(growable: false);
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> delete(String id) async {
    final List<Crop> crops = await getAll();
    crops.removeWhere((Crop crop) => crop.id == id);
    await replaceAll(crops);
  }
}
