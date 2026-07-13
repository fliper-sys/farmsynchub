import 'package:farmsynchub/data/local/daos/crops_dao.dart';
import 'package:farmsynchub/data/local/daos/livestock_dao.dart';
import 'package:farmsynchub/data/local/database.dart';
import 'package:farmsynchub/data/repositories/firestore_repositories.dart';
import 'package:farmsynchub/domain/models/crop.dart';
import 'package:farmsynchub/domain/models/livestock.dart';
import 'package:farmsynchub/data/remote/firebase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('crop insert persists locally and forwards it to remote storage', () async {
    await SharedPreferences.getInstance();
    final FakeFirebaseService remoteStore = FakeFirebaseService();
    final CropsDao cropsDao = CropsDao(const LocalDatabase());
    final FirestoreCropRepository repository = FirestoreCropRepository(
      remoteStore,
      cropsDao: cropsDao,
    );

    final Crop crop = Crop(
      id: 'crop-001',
      farmId: 'farm-001',
      name: 'Maize',
      variety: 'Hybrid',
      areaHa: 2.5,
      plantingDate: DateTime(2026, 1, 1),
      expectedHarvestDate: DateTime(2026, 6, 1),
      currentStage: CropStage.germination,
      status: CropStatus.growing,
      totalInputCost: 250,
      cycleLengthDays: 120,
      notes: 'Test crop',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isSynced: false,
    );

    await repository.insert(crop);

    final List<Crop> storedCrops = await cropsDao.getAll();
    expect(storedCrops, hasLength(1));
    expect(storedCrops.single.id, crop.id);
    expect(remoteStore.syncCalls, 1);
    expect(remoteStore.syncedPayloads.single['id'], crop.id);
  });

  test('livestock insert persists locally and forwards it to remote storage', () async {
    await SharedPreferences.getInstance();
    final FakeFirebaseService remoteStore = FakeFirebaseService();
    final LivestockDao livestockDao = LivestockDao(const LocalDatabase());
    final FirestoreLivestockRepository repository = FirestoreLivestockRepository(
      remoteStore,
      livestockDao: livestockDao,
    );

    final Livestock livestock = Livestock(
      id: 'animal-001',
      farmId: 'farm-001',
      species: LivestockSpecies.goat,
      breed: 'Boer',
      count: 10,
      maleCount: 4,
      femaleCount: 6,
      purpose: LivestockPurpose.meat,
      housingLocation: HousingType.shed,
      acquisitionDate: DateTime(2026, 1, 1),
      estimatedValue: 5000,
      vaccinationStatus: 1,
      healthScore: 85,
      growthStage: AnimalGrowthStage.grower,
      averageAgeMonths: 6,
      targetMaturityMonths: 12,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isSynced: false,
    );

    await repository.insert(livestock);

    final List<Livestock> storedLivestock = await livestockDao.getAll();
    expect(storedLivestock, hasLength(1));
    expect(storedLivestock.single.id, livestock.id);
    expect(remoteStore.syncCalls, 1);
    expect(remoteStore.syncedPayloads.single['id'], livestock.id);
  });
}

class FakeFirebaseService extends FirebaseService {
  final List<Map<String, dynamic>> syncedPayloads = <Map<String, dynamic>>[];
  int syncCalls = 0;

  @override
  bool get hasActiveUser => true;

  @override
  Future<void> syncToFirestore(String collection, Map<String, dynamic> data) async {
    syncCalls += 1;
    syncedPayloads.add(Map<String, dynamic>.from(data));
  }

  @override
  Future<List<Map<String, dynamic>>> getFromFirestore(String collection) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>?> getDocumentFromFirestore(String collection, String id) async {
    return null;
  }

  @override
  Future<void> deleteFromFirestore(String collection, String id) async {}
}
