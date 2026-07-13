import 'dart:convert';

import '../../../domain/models/procurement_order.dart';
import '../database.dart';

/// Persists procurement orders locally so they survive app restarts.
class ProcurementDao {
  ProcurementDao(this._database);

  static const String _storageKey = 'farmsync.procurement_orders';

  final LocalDatabase _database;

  Future<List<ProcurementOrder>> getAll() async {
    final prefs = await _database.instance;
    final List<String> rawItems = prefs.getStringList(_storageKey) ?? <String>[];

    return rawItems
        .map((String item) => jsonDecode(item) as Map<String, dynamic>)
        .map(ProcurementOrder.fromJson)
        .toList();
  }

  Future<ProcurementOrder?> getById(String id) async {
    final List<ProcurementOrder> orders = await getAll();
    for (final ProcurementOrder order in orders) {
      if (order.id == id) {
        return order;
      }
    }
    return null;
  }

  Future<void> upsert(ProcurementOrder order) async {
    final List<ProcurementOrder> orders = await getAll();
    final int index = orders.indexWhere((ProcurementOrder item) => item.id == order.id);
    if (index == -1) {
      orders.add(order);
    } else {
      orders[index] = order;
    }
    await replaceAll(orders);
  }

  Future<void> replaceAll(List<ProcurementOrder> orders) async {
    final prefs = await _database.instance;
    final List<String> encoded = orders.map((ProcurementOrder order) => jsonEncode(order.toJson())).toList(growable: false);
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> delete(String id) async {
    final List<ProcurementOrder> orders = await getAll();
    orders.removeWhere((ProcurementOrder order) => order.id == id);
    await replaceAll(orders);
  }
}
