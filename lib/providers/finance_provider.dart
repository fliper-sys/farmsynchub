import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/farm_email_service.dart';
import '../data/repositories/firestore_repositories.dart';
import '../data/repositories/finance_repository.dart';
import '../data/remote/firebase_service.dart';
import '../domain/models/transaction.dart';
import 'auth_provider.dart';
import 'email_notification_provider.dart';

/// Provider for finance repository.
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FirestoreFinanceRepository(ref.watch(firebaseServiceProvider));
});

/// Provider for list of transactions.
final transactionsProvider = StateNotifierProvider<TransactionsNotifier, AsyncValue<List<Transaction>>>((ref) {
  final repository = ref.watch(financeRepositoryProvider);
  return TransactionsNotifier(
    repository,
    ref.watch(farmEmailServiceProvider),
    ref.watch(firebaseServiceProvider),
  );
});

/// State notifier for managing transactions.
class TransactionsNotifier extends StateNotifier<AsyncValue<List<Transaction>>> {
  TransactionsNotifier(this._repository, this._emailService, this._firebaseService) : super(const AsyncValue.loading()) {
    _loadTransactions();
  }

  final FinanceRepository _repository;
  final FarmEmailService _emailService;
  final FirebaseService _firebaseService;

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

  Future<void> refresh() => _loadTransactions();

  /// Adds a new transaction.
  Future<void> addTransaction(Transaction transaction) async {
    try {
      await _repository.insert(transaction);
      await _sendTransactionEmail(transaction);
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

  Future<void> _sendTransactionEmail(Transaction transaction) async {
    final String email = _firebaseService.currentUser?.email ?? '';
    if (email.isEmpty) {
      return;
    }
    final String displayName = _firebaseService.currentUser?.displayName?.trim() ?? '';
    final String recipientName = displayName.isNotEmpty ? displayName : email.split('@').first;
    final String farmName = transaction.farmId.trim().isNotEmpty ? 'farm ${transaction.farmId}' : 'your farm';
    switch (transaction.recordKind) {
      case TransactionRecordKind.sale:
        await _emailService.sendSaleNotification(
          toEmail: email,
          recipientName: recipientName,
          farmName: farmName,
          productName: transaction.productName,
          quantity: transaction.quantity,
          unit: transaction.unit,
          amount: transaction.amount,
        );
        break;
      case TransactionRecordKind.procurement:
        await _emailService.sendProcurementNotification(
          toEmail: email,
          recipientName: recipientName,
          farmName: farmName,
          productName: transaction.productName,
          quantity: transaction.quantity,
          unit: transaction.unit,
          amount: transaction.amount,
        );
        break;
      case TransactionRecordKind.general:
        if (transaction.type == TransactionType.expense) {
          await _emailService.sendExpenseNotification(
            toEmail: email,
            recipientName: recipientName,
            farmName: farmName,
            title: transaction.productName.isNotEmpty ? transaction.productName : transaction.category.name,
            amount: transaction.amount,
          );
        }
        break;
    }
  }
}
