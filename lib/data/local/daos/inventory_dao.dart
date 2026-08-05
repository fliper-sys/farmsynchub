import 'dart:convert';

import '../../../domain/models/inventory_item.dart';
import '../database.dart';

/// Persists inventory items locally so they survive app restarts.
class InventoryDao {
  InventoryDao(this._database);

  static const String _storageKey = 'farmsync.inventory_items';

  final LocalDatabase _database;

  Future<List<InventoryItem>> getAll() async {
    final prefs = await _database.instance;
    final List<String> rawItems =
        prefs.getStringList(_storageKey) ?? <String>[];

    return rawItems
        .map((String item) => jsonDecode(item) as Map<String, dynamic>)
        .map(InventoryItem.fromJson)
        .toList();
  }

  Future<InventoryItem?> getById(String id) async {
    final List<InventoryItem> items = await getAll();
    for (final InventoryItem item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<void> upsert(InventoryItem item) async {
    final List<InventoryItem> items = await getAll();
    final int index =
        items.indexWhere((InventoryItem current) => current.id == item.id);
    if (index == -1) {
      items.add(item);
    } else {
      items[index] = item;
    }
    await replaceAll(items);
  }

  Future<void> replaceAll(List<InventoryItem> items) async {
    final prefs = await _database.instance;
    final List<String> encoded = items
        .map((InventoryItem item) => jsonEncode(item.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> delete(String id) async {
    final List<InventoryItem> items = await getAll();
    items.removeWhere((InventoryItem item) => item.id == id);
    await replaceAll(items);
  }
}
