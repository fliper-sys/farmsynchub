import 'package:farmsynchub/data/remote/operations_hub_remote_store.dart';
import 'package:farmsynchub/data/repositories/inventory_repository.dart';
import 'package:farmsynchub/providers/operations_hub_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('addInventoryItem updates state and forwards it to the inventory repository', () async {
    final FakeOperationsHubRemoteStore remoteStore = FakeOperationsHubRemoteStore(hasActiveUser: true);
    final FakeInventoryRepository inventoryRepository = FakeInventoryRepository();
    final OperationsHubNotifier notifier = OperationsHubNotifier(remoteStore, inventoryRepository);

    final InventoryItem item = InventoryItem(
      id: 'item-1',
      farmId: 'farm-1',
      name: 'Tomatoes',
      category: 'Vegetables',
      unit: 'kg',
      availableQuantity: 10,
      unitPrice: 3.5,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      costPrice: 2.5,
      emoji: '🍅',
    );

    await notifier.addInventoryItem(item);

    expect(notifier.state.inventory, hasLength(1));
    expect(notifier.state.inventory.single.id, item.id);
    expect(inventoryRepository.insertedItems, hasLength(1));
    expect(inventoryRepository.insertedItems.single.id, item.id);
  });
}

class FakeInventoryRepository implements InventoryRepository {
  final List<InventoryItem> insertedItems = <InventoryItem>[];

  @override
  Future<List<InventoryItem>> getAll() async => <InventoryItem>[];

  @override
  Future<InventoryItem?> getById(String id) async => null;

  @override
  Future<void> insert(InventoryItem item) async {
    insertedItems.add(item);
  }

  @override
  Future<void> update(InventoryItem item) async {
    insertedItems.add(item);
  }

  @override
  Future<void> delete(String id) async {}
}

class FakeOperationsHubRemoteStore implements OperationsHubRemoteStore {
  FakeOperationsHubRemoteStore({this.hasActiveUser = true});

  @override
  bool hasActiveUser;

  final List<Map<String, dynamic>> syncedPayloads = <Map<String, dynamic>>[];
  int syncCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> getFromFirestore(String collection) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<void> syncToFirestore(String collection, Map<String, dynamic> data) async {
    syncCalls += 1;
    syncedPayloads.add(Map<String, dynamic>.from(data));
  }
}
