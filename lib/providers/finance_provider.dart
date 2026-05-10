import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/firestore_repositories.dart';
import '../data/repositories/finance_repository.dart';
import '../domain/models/transaction.dart';
import 'auth_provider.dart';

/// Provider for finance repository.
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FirestoreFinanceRepository(ref.watch(firebaseServiceProvider));
});

/// Provider for list of transactions.
final transactionsProvider = StateNotifierProvider<TransactionsNotifier, AsyncValue<List<Transaction>>>((ref) {
  final repository = ref.watch(financeRepositoryProvider);
  return TransactionsNotifier(repository);
});

/// State notifier for managing transactions.
class TransactionsNotifier extends StateNotifier<AsyncValue<List<Transaction>>> {
  TransactionsNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadTransactions();
  }

  final FinanceRepository _repository;

  /// Loads all transactions from the repository.
  Future<void> _loadTransactions() async {
    if (!mounted) {
      return;
    }
    state = const AsyncValue.loading();
    try {
      final transactions = await _repository.getAll();
      if (!mounted) {
        return;
      }
      state = AsyncValue.data(transactions);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Adds a new transaction.
  Future<void> addTransaction(Transaction transaction) async {
    try {
      await _repository.insert(transaction);
      await _loadTransactions();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Updates an existing transaction.
  Future<void> updateTransaction(Transaction transaction) async {
    try {
      await _repository.update(transaction);
      await _loadTransactions();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Deletes a transaction.
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _repository.delete(transactionId);
      await _loadTransactions();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Gets a transaction by ID.
  Future<Transaction?> getTransactionById(String transactionId) async {
    try {
      return await _repository.getById(transactionId);
    } catch (error, stackTrace) {
      if (!mounted) {
        return null;
      }
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}
