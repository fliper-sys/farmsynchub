import '../../domain/models/inventory_item.dart';
import '../local/daos/inventory_dao.dart';
import '../local/database.dart';
import '../remote/firebase_service.dart';
import 'inventory_repository.dart';

class FirestoreInventoryRepository implements InventoryRepository {
  FirestoreInventoryRepository(this._firebaseService,
      {InventoryDao? inventoryDao})
      : _inventoryDao = inventoryDao ?? InventoryDao(const LocalDatabase());

  final FirebaseService _firebaseService;
  final InventoryDao _inventoryDao;

  @override
  Future<void> delete(String id) async {
    await _inventoryDao.delete(id);
    if (_firebaseService.currentUser == null) {
      return;
    }
    try {
      await _firebaseService.deleteFromFirestore('inventory_items', id);
    } catch (_) {
      // Keep local delete and allow cloud cleanup later.
    }
  }

  @override
  Future<List<InventoryItem>> getAll() async {
    final List<InventoryItem> localItems = await _inventoryDao.getAll();
    if (_firebaseService.currentUser == null) {
      return _sortItems(localItems);
    }

    final List<InventoryItem> syncedLocalItems =
        await _syncPendingLocalItems(localItems);
    try {
      final List<Map<String, dynamic>> records =
          await _firebaseService.getFromFirestore('inventory_items', scopeByFarmIds: true);
      final List<InventoryItem> remoteItems = records
          .map((Map<String, dynamic> record) {
            try {
              return InventoryItem.fromJson(record);
            } catch (_) {
              return null;
            }
          })
          .whereType<InventoryItem>()
          .where((InventoryItem item) => item.id.isNotEmpty)
          .toList();
      final List<InventoryItem> merged =
          _mergeItems(local: syncedLocalItems, remote: remoteItems);
      await _inventoryDao.replaceAll(merged);
      return _sortItems(merged);
    } catch (_) {
      return _sortItems(syncedLocalItems);
    }
  }

  @override
  Future<InventoryItem?> getById(String id) async {
    final List<InventoryItem> items = await getAll();
    for (final InventoryItem item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<void> insert(InventoryItem item) async {
    await _saveItem(item);
  }

  @override
  Future<void> update(InventoryItem item) async {
    await _saveItem(item);
  }

  Future<void> _saveItem(InventoryItem item) async {
    await _inventoryDao.upsert(item);
    if (_firebaseService.currentUser == null) {
      return;
    }
    try {
      await _firebaseService.syncToFirestore('inventory_items', item.toJson());
    } catch (_) {
      // Local copy already saved; cloud sync will retry on next getAll().
    }
  }

  Future<List<InventoryItem>> _syncPendingLocalItems(
      List<InventoryItem> items) async {
    // Unlike ProcurementOrder/ExpenseEntry, InventoryItem has no isSynced
    // flag — every local item is opportunistically re-pushed on load. This
    // is a cheap no-op when Firestore already has the same data (a plain
    // overwrite), and guarantees items created while offline reach the
    // cloud once connectivity returns.
    for (final InventoryItem item in items) {
      try {
        await _firebaseService.syncToFirestore(
            'inventory_items', item.toJson());
      } catch (_) {
        // Ignore; will retry on the next load.
      }
    }
    return items;
  }

  List<InventoryItem> _mergeItems({
    required List<InventoryItem> local,
    required List<InventoryItem> remote,
  }) {
    final Map<String, InventoryItem> merged = <String, InventoryItem>{
      for (final InventoryItem item in remote) item.id: item,
    };

    for (final InventoryItem item in local) {
      final InventoryItem? remoteItem = merged[item.id];
      if (remoteItem == null || item.updatedAt.isAfter(remoteItem.updatedAt)) {
        merged[item.id] = item;
      }
    }

    return merged.values.toList(growable: false);
  }

  List<InventoryItem> _sortItems(List<InventoryItem> items) {
    final List<InventoryItem> sorted = List<InventoryItem>.from(items);
    sorted.sort((InventoryItem a, InventoryItem b) =>
        b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }
}
