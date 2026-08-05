import '../../providers/operations_hub_provider.dart';

abstract class InventoryRepository {
  Future<List<InventoryItem>> getAll();
  Future<InventoryItem?> getById(String id);
  Future<void> insert(InventoryItem item);
  Future<void> update(InventoryItem item);
  Future<void> delete(String id);
}
