import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/farm_email_service.dart';
import '../data/repositories/firestore_repositories.dart';
import '../data/repositories/finance_repository.dart';
import '../data/remote/firebase_service.dart';
import '../domain/models/notification.dart';
import '../domain/models/transaction.dart';
import 'auth_provider.dart';
import 'email_notification_provider.dart';
import 'notification_provider.dart';

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
    ref.watch(notificationsProvider.notifier),
  );
});

/// State notifier for managing transactions.
class TransactionsNotifier extends StateNotifier<AsyncValue<List<Transaction>>> {
  TransactionsNotifier(this._repository, this._emailService, this._firebaseService, this._notifications) : super(const AsyncValue.loading()) {
    _loadTransactions();
  }

  final FinanceRepository _repository;
  final FarmEmailService _emailService;
  final FirebaseService _firebaseService;
  final NotificationsNotifier _notifications;

  /// Loads all transactions from the repository. Shows whatever is already
  /// cached on the device immediately (so the app never sits on a loading
  /// spinner just because the network round-trip is slow or offline), then
  /// refreshes from the cloud in the background.
  Future<void> _loadTransactions() async {
    if (!mounted) {
      return;
    }
    try {
      final List<Transaction> cached = await _repository.getCachedOnly();
      if (!mounted) {
        return;
      }
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      } else if (!state.hasValue) {
        state = const AsyncValue.loading();
      }
    } catch (_) {
      // Cache read failures aren't fatal - fall through to the full load.
    }

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
      if (!state.hasValue) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> refresh() => _loadTransactions();

  /// Adds a new transaction.
  Future<void> addTransaction(Transaction transaction) async {
    try {
      await _repository.insert(transaction);
      await _sendTransactionEmail(transaction);
      await _publishTransactionNotification(transaction);
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

  Future<void> _publishTransactionNotification(Transaction transaction) async {
    final String product = transaction.productName.trim().isNotEmpty ? transaction.productName.trim() : transaction.description;
    switch (transaction.recordKind) {
      case TransactionRecordKind.sale:
        await _notifications.publishNotification(
          title: 'Sale recorded',
          message: '$product sale was saved for ${transaction.amount.toStringAsFixed(2)}.',
          type: NotificationType.success,
          actionUrl: '/finance',
          audience: 'single',
          targetUserId: _firebaseService.currentUser?.uid,
          metadata: <String, dynamic>{
            'source': 'finance',
            'recordKind': transaction.recordKind.name,
            'transactionId': transaction.id,
            'farmId': transaction.farmId,
          },
        );
        break;
      case TransactionRecordKind.procurement:
        await _notifications.publishNotification(
          title: 'Procurement recorded',
          message: '$product procurement was saved for ${transaction.amount.toStringAsFixed(2)}.',
          type: NotificationType.info,
          actionUrl: '/finance',
          audience: 'single',
          targetUserId: _firebaseService.currentUser?.uid,
          metadata: <String, dynamic>{
            'source': 'finance',
            'recordKind': transaction.recordKind.name,
            'transactionId': transaction.id,
            'farmId': transaction.farmId,
          },
        );
        break;
      case TransactionRecordKind.general:
        if (transaction.type == TransactionType.expense) {
          await _notifications.publishNotification(
            title: 'Expense uploaded',
            message: '$product expense was saved for ${transaction.amount.toStringAsFixed(2)}.',
            type: NotificationType.warning,
            actionUrl: '/finance',
            audience: 'single',
            targetUserId: _firebaseService.currentUser?.uid,
            metadata: <String, dynamic>{
              'source': 'finance',
              'recordKind': transaction.recordKind.name,
              'transactionId': transaction.id,
              'farmId': transaction.farmId,
            },
          );
        }
        break;
    }
  }
}
