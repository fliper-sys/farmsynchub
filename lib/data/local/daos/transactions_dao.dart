import 'dart:convert';

import '../../../domain/models/transaction.dart';
import '../database.dart';

/// Persists transaction records locally so they survive app restarts.
class TransactionsDao {
  TransactionsDao(this._database);

  static const String _storageKey = 'farmsync.transactions';

  final LocalDatabase _database;

  Future<List<Transaction>> getAll() async {
    final prefs = await _database.instance;
    final List<String> rawItems = prefs.getStringList(_storageKey) ?? <String>[];

    return rawItems
        .map((String item) => jsonDecode(item) as Map<String, dynamic>)
        .map(Transaction.fromJson)
        .toList();
  }

  Future<Transaction?> getById(String id) async {
    final List<Transaction> transactions = await getAll();
    for (final Transaction txn in transactions) {
      if (txn.id == id) {
        return txn;
      }
    }
    return null;
  }

  Future<void> upsert(Transaction transaction) async {
    final List<Transaction> transactions = await getAll();
    final int index = transactions.indexWhere((Transaction item) => item.id == transaction.id);
    if (index == -1) {
      transactions.add(transaction);
    } else {
      transactions[index] = transaction;
    }
    await replaceAll(transactions);
  }

  Future<void> replaceAll(List<Transaction> transactions) async {
    final prefs = await _database.instance;
    final List<String> encoded = transactions.map((Transaction item) => jsonEncode(item.toJson())).toList(growable: false);
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> delete(String id) async {
    final List<Transaction> transactions = await getAll();
    transactions.removeWhere((Transaction item) => item.id == id);
    await replaceAll(transactions);
  }
}
