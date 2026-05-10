import '../../domain/models/transaction.dart';

/// Abstract repository for finance operations.
abstract class FinanceRepository {
  /// Get all transactions.
  Future<List<Transaction>> getAll();

  /// Get transaction by ID.
  Future<Transaction?> getById(String id);

  /// Insert a new transaction.
  Future<void> insert(Transaction transaction);

  /// Update an existing transaction.
  Future<void> update(Transaction transaction);

  /// Delete a transaction.
  Future<void> delete(String id);
}