import '../../domain/models/crop.dart';
import '../../domain/models/farm.dart';
import '../../domain/models/livestock.dart';
import '../../domain/models/transaction.dart';
import 'crop_repository.dart';
import 'farm_repository.dart';
import 'finance_repository.dart';
import 'livestock_repository.dart';

class DemoFarmRepository implements FarmRepository {
  DemoFarmRepository()
      : _items = <Farm>[
          Farm(
            id: 'farm_1',
            name: 'Pisang King Farms',
            ward: 'Jos South',
            sizeHa: 1.2,
            farmerCategory: FarmerCategory.marketOriented,
            soilType: SoilType.loamy,
            waterSource: WaterSource.borehole,
            createdAt: DateTime(2026, 1, 10),
            updatedAt: DateTime(2026, 4, 20),
            isSynced: true,
          ),
          Farm(
            id: 'farm_2',
            name: 'Ranch East Block',
            ward: 'Vwang',
            sizeHa: 0.6,
            farmerCategory: FarmerCategory.semiCommercial,
            soilType: SoilType.sandy,
            waterSource: WaterSource.rainfall,
            createdAt: DateTime(2026, 2, 4),
            updatedAt: DateTime(2026, 4, 18),
            isSynced: false,
          ),
          Farm(
            id: 'farm_3',
            name: 'River Bend Plot',
            ward: 'Du',
            sizeHa: 0.4,
            farmerCategory: FarmerCategory.subsistence,
            soilType: SoilType.clay,
            waterSource: WaterSource.river,
            createdAt: DateTime(2026, 3, 12),
            updatedAt: DateTime(2026, 4, 22),
            isSynced: true,
          ),
        ];

  final List<Farm> _items;

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((Farm farm) => farm.id == id);
  }

  @override
  Future<List<Farm>> getAll() async => List<Farm>.unmodifiable(_items);

  @override
  Future<Farm?> getById(String id) async {
    for (final Farm farm in _items) {
      if (farm.id == id) {
        return farm;
      }
    }
    return null;
  }

  @override
  Future<void> insert(Farm farm) async {
    _items.add(farm);
  }

  @override
  Future<void> update(Farm farm) async {
    final int index = _items.indexWhere((Farm item) => item.id == farm.id);
    if (index >= 0) {
      _items[index] = farm;
    }
  }
}

class DemoCropRepository implements CropRepository {
  DemoCropRepository()
      : _items = <Crop>[
          Crop(
            id: 'crop_1',
            farmId: 'farm_1',
            name: 'Tomato',
            variety: 'Roma',
            areaHa: 0.3,
            plantingDate: DateTime(2026, 3, 1),
            expectedHarvestDate: DateTime(2026, 5, 18),
            currentStage: CropStage.vegetative,
            status: CropStatus.growing,
            totalInputCost: 78000,
            notes: 'Irrigation adjusted after last heat wave.',
            createdAt: DateTime(2026, 3, 1),
            updatedAt: DateTime(2026, 4, 24),
            isSynced: true,
          ),
          Crop(
            id: 'crop_2',
            farmId: 'farm_2',
            name: 'Maize',
            variety: 'SAMMAZ',
            areaHa: 0.5,
            plantingDate: DateTime(2026, 2, 20),
            expectedHarvestDate: DateTime(2026, 5, 30),
            currentStage: CropStage.flowering,
            status: CropStatus.growing,
            totalInputCost: 52000,
            notes: 'Need to monitor moisture in east block.',
            createdAt: DateTime(2026, 2, 20),
            updatedAt: DateTime(2026, 4, 23),
            isSynced: false,
          ),
          Crop(
            id: 'crop_3',
            farmId: 'farm_3',
            name: 'Pepper',
            variety: 'Tatase',
            areaHa: 0.2,
            plantingDate: DateTime(2026, 3, 8),
            expectedHarvestDate: DateTime(2026, 5, 22),
            currentStage: CropStage.fruiting,
            status: CropStatus.ready,
            totalInputCost: 31000,
            notes: 'Market demand looks strong.',
            createdAt: DateTime(2026, 3, 8),
            updatedAt: DateTime(2026, 4, 25),
            isSynced: true,
          ),
        ];

  final List<Crop> _items;

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((Crop crop) => crop.id == id);
  }

  @override
  Future<List<Crop>> getAll() async => List<Crop>.unmodifiable(_items);

  @override
  Future<Crop?> getById(String id) async {
    for (final Crop crop in _items) {
      if (crop.id == id) {
        return crop;
      }
    }
    return null;
  }

  @override
  Future<void> insert(Crop crop) async {
    _items.add(crop);
  }

  @override
  Future<void> update(Crop crop) async {
    final int index = _items.indexWhere((Crop item) => item.id == crop.id);
    if (index >= 0) {
      _items[index] = crop;
    }
  }
}

class DemoLivestockRepository implements LivestockRepository {
  DemoLivestockRepository()
      : _items = <Livestock>[
          Livestock(
            id: 'live_1',
            farmId: 'farm_1',
            species: LivestockSpecies.goat,
            breed: 'West African Dwarf',
            count: 46,
            maleCount: 12,
            femaleCount: 34,
            purpose: LivestockPurpose.breeding,
            housingLocation: HousingType.shed,
            acquisitionDate: DateTime(2025, 11, 12),
            estimatedValue: 920000,
            vaccinationStatus: 92,
            healthScore: 88,
            createdAt: DateTime(2025, 11, 12),
            updatedAt: DateTime(2026, 4, 24),
            isSynced: true,
          ),
          Livestock(
            id: 'live_2',
            farmId: 'farm_2',
            species: LivestockSpecies.chicken,
            breed: 'Layer',
            count: 62,
            maleCount: 4,
            femaleCount: 58,
            purpose: LivestockPurpose.eggs,
            housingLocation: HousingType.coop,
            acquisitionDate: DateTime(2026, 1, 15),
            estimatedValue: 540000,
            vaccinationStatus: 85,
            healthScore: 91,
            createdAt: DateTime(2026, 1, 15),
            updatedAt: DateTime(2026, 4, 23),
            isSynced: false,
          ),
          Livestock(
            id: 'live_3',
            farmId: 'farm_3',
            species: LivestockSpecies.sheep,
            breed: 'Yankasa',
            count: 20,
            maleCount: 6,
            femaleCount: 14,
            purpose: LivestockPurpose.meat,
            housingLocation: HousingType.barn,
            acquisitionDate: DateTime(2026, 2, 2),
            estimatedValue: 610000,
            vaccinationStatus: 78,
            healthScore: 80,
            createdAt: DateTime(2026, 2, 2),
            updatedAt: DateTime(2026, 4, 21),
            isSynced: true,
          ),
        ];

  final List<Livestock> _items;

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((Livestock livestock) => livestock.id == id);
  }

  @override
  Future<List<Livestock>> getAll() async => List<Livestock>.unmodifiable(_items);

  @override
  Future<Livestock?> getById(String id) async {
    for (final Livestock item in _items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<void> insert(Livestock livestock) async {
    _items.add(livestock);
  }

  @override
  Future<void> update(Livestock livestock) async {
    final int index = _items.indexWhere((Livestock item) => item.id == livestock.id);
    if (index >= 0) {
      _items[index] = livestock;
    }
  }
}

class DemoFinanceRepository implements FinanceRepository {
  DemoFinanceRepository()
      : _items = <Transaction>[
          Transaction(
            id: 'txn_1',
            farmId: 'farm_1',
            type: TransactionType.income,
            category: TransactionCategory.cropSale,
            amount: 250000,
            description: 'Tomato sales from main market collection',
            transactionDate: DateTime(2026, 4, 20),
            linkedEntityId: 'crop_1',
            createdAt: DateTime(2026, 4, 20),
            updatedAt: DateTime(2026, 4, 20),
            isSynced: true,
          ),
          Transaction(
            id: 'txn_2',
            farmId: 'farm_1',
            type: TransactionType.expense,
            category: TransactionCategory.feed,
            amount: 75000,
            description: 'Livestock feed restock',
            transactionDate: DateTime(2026, 4, 19),
            linkedEntityId: 'live_1',
            createdAt: DateTime(2026, 4, 19),
            updatedAt: DateTime(2026, 4, 19),
            isSynced: false,
          ),
          Transaction(
            id: 'txn_3',
            farmId: 'farm_2',
            type: TransactionType.expense,
            category: TransactionCategory.labour,
            amount: 42000,
            description: 'Weekly field support',
            transactionDate: DateTime(2026, 4, 18),
            linkedEntityId: 'farm_2',
            createdAt: DateTime(2026, 4, 18),
            updatedAt: DateTime(2026, 4, 18),
            isSynced: true,
          ),
          Transaction(
            id: 'txn_4',
            farmId: 'farm_3',
            type: TransactionType.income,
            category: TransactionCategory.livestockSale,
            amount: 180000,
            description: 'Ram sold for festive market',
            transactionDate: DateTime(2026, 4, 16),
            linkedEntityId: 'live_3',
            createdAt: DateTime(2026, 4, 16),
            updatedAt: DateTime(2026, 4, 16),
            isSynced: true,
          ),
        ];

  final List<Transaction> _items;

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((Transaction transaction) => transaction.id == id);
  }

  @override
  Future<List<Transaction>> getAll() async => List<Transaction>.unmodifiable(_items);

  @override
  Future<Transaction?> getById(String id) async {
    for (final Transaction transaction in _items) {
      if (transaction.id == id) {
        return transaction;
      }
    }
    return null;
  }

  @override
  Future<void> insert(Transaction transaction) async {
    _items.add(transaction);
  }

  @override
  Future<void> update(Transaction transaction) async {
    final int index = _items.indexWhere((Transaction item) => item.id == transaction.id);
    if (index >= 0) {
      _items[index] = transaction;
    }
  }
}
