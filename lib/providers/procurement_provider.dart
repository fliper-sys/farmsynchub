import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/procurement_repository.dart';
import '../data/repositories/firestore_procurement_expense_repositories.dart';
import '../domain/models/procurement_order.dart';
import 'auth_provider.dart';

final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) {
  return FirestoreProcurementRepository(ref.watch(firebaseServiceProvider));
});

final procurementOrdersProvider = StateNotifierProvider<ProcurementOrdersNotifier, AsyncValue<List<ProcurementOrder>>>((ref) {
  final repository = ref.watch(procurementRepositoryProvider);
  return ProcurementOrdersNotifier(repository);
});

class ProcurementOrdersNotifier extends StateNotifier<AsyncValue<List<ProcurementOrder>>> {
  ProcurementOrdersNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadOrders();
  }

  final ProcurementRepository _repository;

  Future<void> _loadOrders() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    try {
      final orders = await _repository.getAll();
      if (!mounted) return;
      state = AsyncValue.data(orders);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => _loadOrders();

  Future<void> addOrder(ProcurementOrder order) async {
    try {
      await _repository.insert(order);
      await _loadOrders();
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateOrder(ProcurementOrder order) async {
    try {
      await _repository.update(order);
      await _loadOrders();
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _repository.delete(orderId);
      await _loadOrders();
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
