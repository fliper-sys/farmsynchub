import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farmsynchub/data/local/daos/farms_dao.dart';
import 'package:farmsynchub/data/local/database.dart';
import 'package:farmsynchub/data/repositories/farm_repository.dart';
import 'package:farmsynchub/data/repositories/firestore_repositories.dart';
import 'package:farmsynchub/domain/models/farm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('insert persists a farm locally and forwards it to remote storage', () async {
    final FakeRemoteStore remoteStore = FakeRemoteStore();
    final FarmsDao farmsDao = FarmsDao(const LocalDatabase());
    final FirestoreFarmRepository repository = FirestoreFarmRepository(
      remoteStore,
      farmsDao: farmsDao,
    );

    final Farm farm = Farm(
      id: 'farm-001',
      name: 'Green Valley',
      ward: 'Bassa',
      sizeHa: 4.5,
      farmType: FarmType.crop,
      farmerCategory: FarmerCategory.marketOriented,
      soilType: SoilType.loamy,
      waterSource: WaterSource.borehole,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isSynced: false,
    );

    await repository.insert(farm);

    final List<Farm> storedFarms = await farmsDao.getAll();
    expect(storedFarms, hasLength(1));
    expect(storedFarms.single.id, farm.id);
    expect(storedFarms.single.name, farm.name);
    expect(remoteStore.syncCalls, 1);
    expect(remoteStore.syncedPayloads.single['id'], farm.id);
  });
}

class FakeRemoteStore implements FarmRemoteStore {
  FakeRemoteStore({this.hasActiveUser = true});

  @override
  bool hasActiveUser;

  final List<Map<String, dynamic>> syncedPayloads = <Map<String, dynamic>>[];
  int syncCalls = 0;

  @override
  Future<void> deleteFromFirestore(String collection, String id) async {}

  @override
  Future<List<Map<String, dynamic>>> getFromFirestore(
    String collection, {
    String? ownerUidField,
    String? memberArrayField,
  }) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<void> syncToFirestore(String collection, Map<String, dynamic> data) async {
    syncCalls += 1;
    syncedPayloads.add(Map<String, dynamic>.from(data));
  }
}
