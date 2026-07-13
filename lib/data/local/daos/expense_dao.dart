import 'dart:convert';

import '../../../domain/models/expense_entry.dart';
import '../database.dart';

/// Persists expense records locally so they survive app restarts.
class ExpenseDao {
  ExpenseDao(this._database);

  static const String _storageKey = 'farmsync.expense_entries';

  final LocalDatabase _database;

  Future<List<ExpenseEntry>> getAll() async {
    final prefs = await _database.instance;
    final List<String> rawItems = prefs.getStringList(_storageKey) ?? <String>[];

    return rawItems
        .map((String item) => jsonDecode(item) as Map<String, dynamic>)
        .map(ExpenseEntry.fromJson)
        .toList();
  }

  Future<ExpenseEntry?> getById(String id) async {
    final List<ExpenseEntry> entries = await getAll();
    for (final ExpenseEntry entry in entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  Future<void> upsert(ExpenseEntry entry) async {
    final List<ExpenseEntry> entries = await getAll();
    final int index = entries.indexWhere((ExpenseEntry item) => item.id == entry.id);
    if (index == -1) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    await replaceAll(entries);
  }

  Future<void> replaceAll(List<ExpenseEntry> entries) async {
    final prefs = await _database.instance;
    final List<String> encoded = entries.map((ExpenseEntry entry) => jsonEncode(entry.toJson())).toList(growable: false);
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> delete(String id) async {
    final List<ExpenseEntry> entries = await getAll();
    entries.removeWhere((ExpenseEntry entry) => entry.id == id);
    await replaceAll(entries);
  }
}
