import 'dart:convert';

import 'package:farmsynchub/data/remote/operations_hub_remote_store.dart';
import 'package:farmsynchub/providers/operations_hub_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('addInventoryItem persists inventory locally and syncs it to remote storage', () async {
    final FakeOperationsHubRemoteStore remoteStore = FakeOperationsHubRemoteStore(hasActiveUser: true);
    final OperationsHubNotifier notifier = OperationsHubNotifier(remoteStore);

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

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('operations_hub_state');
    expect(raw, isNotNull);
    final Map<String, dynamic> decoded = jsonDecode(raw!) as Map<String, dynamic>;
    expect(decoded['inventory'], isA<List>());
    expect((decoded['inventory'] as List<dynamic>).first['id'], item.id);
    expect(remoteStore.syncCalls, 1);
    expect(remoteStore.syncedPayloads.single['id'], 'operations_hub_state');
    expect(remoteStore.syncedPayloads.single['payload']['inventory'].first['id'], item.id);
  });
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
