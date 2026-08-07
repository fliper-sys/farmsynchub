import '../../domain/models/transaction.dart';

/// Abstract repository for finance operations.
abstract class FinanceRepository {
  /// Get all transactions.
  Future<List<Transaction>> getAll();

  /// Get all transactions from the local cache only, without waiting on a
  /// network round-trip. Used so the UI can show what's already on the
  /// device instantly on startup, while [getAll] refreshes from the cloud
  /// in the background.
  Future<List<Transaction>> getCachedOnly();

  /// Get transaction by ID.
  Future<Transaction?> getById(String id);

  /// Insert a new transaction.
  Future<void> insert(Transaction transaction);

  /// Update an existing transaction.
  Future<void> update(Transaction transaction);

  /// Delete a transaction.
  Future<void> delete(String id);
}