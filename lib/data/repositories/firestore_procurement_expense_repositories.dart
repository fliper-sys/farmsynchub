import '../local/daos/expense_dao.dart';
import '../local/daos/procurement_dao.dart';
import '../local/database.dart';
import '../remote/firebase_service.dart';
import '../../domain/models/expense_entry.dart';
import '../../domain/models/procurement_order.dart';
import 'expense_repository.dart';
import 'procurement_repository.dart';

class FirestoreProcurementRepository implements ProcurementRepository {
  FirestoreProcurementRepository(this._firebaseService, {ProcurementDao? procurementDao})
      : _procurementDao = procurementDao ?? ProcurementDao(const LocalDatabase());

  final FirebaseService _firebaseService;
  final ProcurementDao _procurementDao;

  @override
  Future<void> delete(String id) async {
    await _procurementDao.delete(id);
    if (_firebaseService.currentUser == null) {
      return;
    }
    try {
      await _firebaseService.deleteFromFirestore('procurement_orders', id);
    } catch (_) {
      // Keep local delete and allow cloud cleanup later.
    }
  }

  @override
  Future<List<ProcurementOrder>> getAll() async {
    final List<ProcurementOrder> localOrders = await _procurementDao.getAll();
    if (_firebaseService.currentUser == null) {
      return _sortOrders(localOrders);
    }

    final List<ProcurementOrder> syncedLocalOrders = await _syncPendingLocalOrders(localOrders);
    try {
      final List<Map<String, dynamic>> records = await _firebaseService.getFromFirestore('procurement_orders', scopeByFarmIds: true);
      final List<ProcurementOrder> remoteOrders = records
          .map((Map<String, dynamic> record) {
            try {
              return ProcurementOrder.fromJson(record);
            } catch (_) {
              return null;
            }
          })
          .whereType<ProcurementOrder>()
          .where((ProcurementOrder item) => item.id.isNotEmpty)
          .toList();
      final List<ProcurementOrder> merged = _mergeOrders(local: syncedLocalOrders, remote: remoteOrders);
      await _procurementDao.replaceAll(merged);
      return _sortOrders(merged);
    } catch (_) {
      return _sortOrders(syncedLocalOrders);
    }
  }

  @override
  Future<ProcurementOrder?> getById(String id) async {
    final List<ProcurementOrder> orders = await getAll();
    for (final ProcurementOrder order in orders) {
      if (order.id == id) {
        return order;
      }
    }
    return null;
  }

  @override
  Future<void> insert(ProcurementOrder order) async {
    await _saveOrder(order);
  }

  @override
  Future<void> update(ProcurementOrder order) async {
    await _saveOrder(order);
  }

  Future<void> _saveOrder(ProcurementOrder order) async {
    ProcurementOrder localOrder = order.copyWith(isSynced: false);
    await _procurementDao.upsert(localOrder);
    if (_firebaseService.currentUser == null) {
      return;
    }

    try {
      await _firebaseService.syncToFirestore(
        'procurement_orders',
        localOrder.copyWith(isSynced: true).toJson(),
      );
      localOrder = localOrder.copyWith(isSynced: true);
      await _procurementDao.upsert(localOrder);
    } catch (_) {
      await _procurementDao.upsert(localOrder.copyWith(isSynced: false));
    }
  }

  Future<List<ProcurementOrder>> _syncPendingLocalOrders(List<ProcurementOrder> orders) async {
    final List<ProcurementOrder> updated = <ProcurementOrder>[];
    var hasChanges = false;

    for (final ProcurementOrder order in orders) {
      if (!order.isSynced) {
        try {
          await _firebaseService.syncToFirestore('procurement_orders', order.copyWith(isSynced: true).toJson());
          updated.add(order.copyWith(isSynced: true));
          hasChanges = true;
          continue;
        } catch (_) {
          updated.add(order);
          continue;
        }
      }
      updated.add(order);
    }

    if (hasChanges) {
      await _procurementDao.replaceAll(updated);
    }
    return updated;
  }

  List<ProcurementOrder> _mergeOrders({
    required List<ProcurementOrder> local,
    required List<ProcurementOrder> remote,
  }) {
    final Map<String, ProcurementOrder> merged = <String, ProcurementOrder>{
      for (final ProcurementOrder order in remote) order.id: order.copyWith(isSynced: true),
    };

    for (final ProcurementOrder order in local) {
      final ProcurementOrder? remoteOrder = merged[order.id];
      if (remoteOrder == null || order.updatedAt.isAfter(remoteOrder.updatedAt)) {
        merged[order.id] = order;
      }
    }

    return merged.values.toList(growable: false);
  }

  List<ProcurementOrder> _sortOrders(List<ProcurementOrder> orders) {
    final List<ProcurementOrder> sorted = List<ProcurementOrder>.from(orders);
    sorted.sort((ProcurementOrder a, ProcurementOrder b) => b.orderDate.compareTo(a.orderDate));
    return sorted;
  }
}

class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository(this._firebaseService, {ExpenseDao? expenseDao})
      : _expenseDao = expenseDao ?? ExpenseDao(const LocalDatabase());

  final FirebaseService _firebaseService;
  final ExpenseDao _expenseDao;

  @override
  Future<void> delete(String id) async {
    await _expenseDao.delete(id);
    if (_firebaseService.currentUser == null) {
      return;
    }
    try {
      await _firebaseService.deleteFromFirestore('expense_entries', id);
    } catch (_) {
      // Keep local delete and allow cloud cleanup later.
    }
  }

  @override
  Future<List<ExpenseEntry>> getAll() async {
    final List<ExpenseEntry> localEntries = await _expenseDao.getAll();
    if (_firebaseService.currentUser == null) {
      return _sortEntries(localEntries);
    }

    final List<ExpenseEntry> syncedLocalEntries = await _syncPendingLocalEntries(localEntries);
    try {
      final List<Map<String, dynamic>> records = await _firebaseService.getFromFirestore('expense_entries', scopeByFarmIds: true);
      final List<ExpenseEntry> remoteEntries = records
          .map((Map<String, dynamic> record) {
            try {
              return ExpenseEntry.fromJson(record);
            } catch (_) {
              return null;
            }
          })
          .whereType<ExpenseEntry>()
          .where((ExpenseEntry item) => item.id.isNotEmpty)
          .toList();
      final List<ExpenseEntry> merged = _mergeEntries(local: syncedLocalEntries, remote: remoteEntries);
      await _expenseDao.replaceAll(merged);
      return _sortEntries(merged);
    } catch (_) {
      return _sortEntries(syncedLocalEntries);
    }
  }

  @override
  Future<ExpenseEntry?> getById(String id) async {
    final List<ExpenseEntry> entries = await getAll();
    for (final ExpenseEntry entry in entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<void> insert(ExpenseEntry entry) async {
    await _saveEntry(entry);
  }

  @override
  Future<void> update(ExpenseEntry entry) async {
    await _saveEntry(entry);
  }

  Future<void> _saveEntry(ExpenseEntry entry) async {
    ExpenseEntry localEntry = entry.copyWith(isSynced: false);
    await _expenseDao.upsert(localEntry);
    if (_firebaseService.currentUser == null) {
      return;
    }

    try {
      await _firebaseService.syncToFirestore(
        'expense_entries',
        localEntry.copyWith(isSynced: true).toJson(),
      );
      localEntry = localEntry.copyWith(isSynced: true);
      await _expenseDao.upsert(localEntry);
    } catch (_) {
      await _expenseDao.upsert(localEntry.copyWith(isSynced: false));
    }
  }

  Future<List<ExpenseEntry>> _syncPendingLocalEntries(List<ExpenseEntry> entries) async {
    final List<ExpenseEntry> updated = <ExpenseEntry>[];
    var hasChanges = false;

    for (final ExpenseEntry entry in entries) {
      if (!entry.isSynced) {
        try {
          await _firebaseService.syncToFirestore('expense_entries', entry.copyWith(isSynced: true).toJson());
          updated.add(entry.copyWith(isSynced: true));
          hasChanges = true;
          continue;
        } catch (_) {
          updated.add(entry);
          continue;
        }
      }
      updated.add(entry);
    }

    if (hasChanges) {
      await _expenseDao.replaceAll(updated);
    }
    return updated;
  }

  List<ExpenseEntry> _mergeEntries({
    required List<ExpenseEntry> local,
    required List<ExpenseEntry> remote,
  }) {
    final Map<String, ExpenseEntry> merged = <String, ExpenseEntry>{
      for (final ExpenseEntry entry in remote) entry.id: entry.copyWith(isSynced: true),
    };

    for (final ExpenseEntry entry in local) {
      final ExpenseEntry? remoteEntry = merged[entry.id];
      if (remoteEntry == null || entry.updatedAt.isAfter(remoteEntry.updatedAt)) {
        merged[entry.id] = entry;
      }
    }

    return merged.values.toList(growable: false);
  }

  List<ExpenseEntry> _sortEntries(List<ExpenseEntry> entries) {
    final List<ExpenseEntry> sorted = List<ExpenseEntry>.from(entries);
    sorted.sort((ExpenseEntry a, ExpenseEntry b) => b.transactionDate.compareTo(a.transactionDate));
    return sorted;
  }
}
