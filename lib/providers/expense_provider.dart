import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/expense_repository.dart';
import '../data/repositories/firestore_procurement_expense_repositories.dart';
import '../domain/models/expense_entry.dart';
import 'auth_provider.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return FirestoreExpenseRepository(ref.watch(firebaseServiceProvider));
});

final expenseEntriesProvider = StateNotifierProvider<ExpenseEntriesNotifier, AsyncValue<List<ExpenseEntry>>>((ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return ExpenseEntriesNotifier(repository);
});

class ExpenseEntriesNotifier extends StateNotifier<AsyncValue<List<ExpenseEntry>>> {
  ExpenseEntriesNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadEntries();
  }

  final ExpenseRepository _repository;

  Future<void> _loadEntries() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    try {
      final entries = await _repository.getAll();
      if (!mounted) return;
      state = AsyncValue.data(entries);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => _loadEntries();

  Future<void> addEntry(ExpenseEntry entry) async {
    try {
      await _repository.insert(entry);
      await _loadEntries();
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateEntry(ExpenseEntry entry) async {
    try {
      await _repository.update(entry);
      await _loadEntries();
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteEntry(String entryId) async {
    try {
      await _repository.delete(entryId);
      await _loadEntries();
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
