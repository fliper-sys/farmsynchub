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
            farmType: FarmType.combined,
            farmerCategory: FarmerCategory.marketOriented,
            soilType: SoilType.loamy,
            waterSource: WaterSource.borehole,
            createdAt: DateTime(2026, 1, 10),
            updatedAt: DateTime(2026, 4, 20),
            isSynced: true,
            ownerUid: 'demo_owner_1',
            ownerEmail: 'aisha@pisangking.com',
            ownerName: 'Aisha Bello',
            cropCapacityHa: 0.8,
            livestockCapacity: 60,
            greenhouseCount: 1,
            greenhouseAreaHa: 0.1,
            workspaceMembers: <FarmWorkspaceMember>[
              FarmWorkspaceMember(
                id: 'member_1',
                name: 'Aisha Bello',
                email: 'aisha@pisangking.com',
                phone: '+2348012345678',
                role: FarmWorkspaceRole.owner,
                allowedFarmIds: <String>['farm_1'],
                financeAccess: FarmFinanceAccess.manage,
                canManageTasks: true,
                canManageSchedule: true,
                canPostUpdates: true,
                canViewActivityLog: true,
                createdAt: DateTime(2026, 2, 1),
                updatedAt: DateTime(2026, 4, 20),
              ),
              FarmWorkspaceMember(
                id: 'member_2',
                name: 'Daniel Bako',
                email: 'daniel@pisangking.com',
                phone: '+2348098765432',
                role: FarmWorkspaceRole.worker,
                allowedFarmIds: <String>['farm_1'],
                financeAccess: FarmFinanceAccess.viewOnly,
                canManageTasks: true,
                canManageSchedule: true,
                canPostUpdates: true,
                canViewActivityLog: true,
                createdAt: DateTime(2026, 3, 14),
                updatedAt: DateTime(2026, 4, 20),
              ),
            ],
            workspaceTasks: <FarmWorkspaceTask>[
              FarmWorkspaceTask(
                id: 'task_1',
                title: 'Check irrigation lines',
                details: 'Inspect the tomato block and report leaks before noon.',
                assigneeName: 'Daniel Bako',
                assigneeRole: FarmWorkspaceRole.worker,
                dueAt: DateTime(2026, 5, 31, 11, 30),
                status: FarmTaskStatus.inProgress,
                reminderEnabled: true,
                reminderLeadMinutes: 60,
                createdBy: 'Aisha Bello',
                updatedBy: 'Aisha Bello',
                createdAt: DateTime(2026, 5, 29),
                updatedAt: DateTime(2026, 5, 30),
              ),
              FarmWorkspaceTask(
                id: 'task_2',
                title: 'Prepare co-owner report',
                details: 'Share the week-end crop and finance summary with owners.',
                assigneeName: 'Aisha Bello',
                assigneeRole: FarmWorkspaceRole.owner,
                dueAt: DateTime(2026, 5, 31, 16, 0),
                status: FarmTaskStatus.open,
                reminderEnabled: true,
                reminderLeadMinutes: 180,
                createdBy: 'Aisha Bello',
                updatedBy: 'Aisha Bello',
                createdAt: DateTime(2026, 5, 30),
                updatedAt: DateTime(2026, 5, 30),
              ),
            ],
            activityLog: <FarmActivityRecord>[
              FarmActivityRecord(
                id: 'activity_1',
                actorName: 'Daniel Bako',
                actorRole: FarmWorkspaceRole.worker,
                action: 'Updated irrigation check',
                detail: 'No leak found on the west line; next inspection scheduled for tomorrow morning.',
                audience: FarmActivityAudience.owners,
                sentToOwners: true,
                createdAt: DateTime(2026, 5, 30, 17, 40),
              ),
              FarmActivityRecord(
                id: 'activity_2',
                actorName: 'Aisha Bello',
                actorRole: FarmWorkspaceRole.owner,
                action: 'Logged finance reminder',
                detail: 'Approve fuel and fertiliser expense before the next delivery.',
                audience: FarmActivityAudience.workspace,
                sentToOwners: true,
                createdAt: DateTime(2026, 5, 30, 9, 15),
              ),
            ],
          ),
          Farm(
            id: 'farm_2',
            name: 'Ranch East Block',
            ward: 'Vwang',
            sizeHa: 0.6,
            farmType: FarmType.livestock,
            farmerCategory: FarmerCategory.semiCommercial,
            soilType: SoilType.sandy,
            waterSource: WaterSource.rainfall,
            createdAt: DateTime(2026, 2, 4),
            updatedAt: DateTime(2026, 4, 18),
            isSynced: false,
            ownerUid: 'demo_owner_2',
            ownerEmail: 'musa@rancheast.com',
            ownerName: 'Musa Jatau',
            livestockCapacity: 120,
            workspaceMembers: <FarmWorkspaceMember>[
              FarmWorkspaceMember(
                id: 'member_3',
                name: 'Musa Jatau',
                email: 'musa@rancheast.com',
                phone: '+2348061122334',
                role: FarmWorkspaceRole.manager,
                allowedFarmIds: <String>['farm_2'],
                financeAccess: FarmFinanceAccess.recordOnly,
                canManageTasks: true,
                canManageSchedule: true,
                canPostUpdates: true,
                canViewActivityLog: true,
                createdAt: DateTime(2026, 3, 1),
                updatedAt: DateTime(2026, 4, 18),
              ),
            ],
            workspaceTasks: <FarmWorkspaceTask>[
              FarmWorkspaceTask(
                id: 'task_3',
                title: 'Review feed stock',
                details: 'Confirm remaining feed covers the next seven days.',
                assigneeName: 'Musa Jatau',
                assigneeRole: FarmWorkspaceRole.manager,
                dueAt: DateTime(2026, 5, 31, 15, 0),
                status: FarmTaskStatus.open,
                reminderEnabled: true,
                reminderLeadMinutes: 30,
                createdBy: 'Musa Jatau',
                updatedBy: 'Musa Jatau',
                createdAt: DateTime(2026, 5, 30),
                updatedAt: DateTime(2026, 5, 30),
              ),
            ],
          ),
          Farm(
            id: 'farm_3',
            name: 'River Bend Plot',
            ward: 'Du',
            sizeHa: 0.4,
            farmType: FarmType.crop,
            farmerCategory: FarmerCategory.subsistence,
            soilType: SoilType.clay,
            waterSource: WaterSource.river,
            createdAt: DateTime(2026, 3, 12),
            updatedAt: DateTime(2026, 4, 22),
            isSynced: true,
            ownerUid: 'demo_owner_3',
            ownerEmail: 'grace@riverbend.com',
            ownerName: 'Grace Pam',
            cropCapacityHa: 0.4,
            workspaceMembers: <FarmWorkspaceMember>[
              FarmWorkspaceMember(
                id: 'member_4',
                name: 'Grace Pam',
                email: 'grace@riverbend.com',
                phone: '+2348076655443',
                role: FarmWorkspaceRole.coOwner,
                allowedFarmIds: <String>['farm_3'],
                financeAccess: FarmFinanceAccess.manage,
                canManageTasks: true,
                canManageSchedule: true,
                canPostUpdates: true,
                canViewActivityLog: true,
                createdAt: DateTime(2026, 4, 1),
                updatedAt: DateTime(2026, 4, 22),
              ),
            ],
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
  Future<List<Farm>> getCachedOnly() async => getAll();

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
            cycleLengthDays: 78,
            notes: 'Irrigation adjusted after last heat wave.',
            createdAt: DateTime(2026, 3, 1),
            updatedAt: DateTime(2026, 4, 24),
            isSynced: true,
            targetYieldKg: 3200,
            protectedEnvironment: true,
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
            cycleLengthDays: 99,
            notes: 'Need to monitor moisture in east block.',
            createdAt: DateTime(2026, 2, 20),
            updatedAt: DateTime(2026, 4, 23),
            isSynced: false,
            targetYieldKg: 4100,
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
            cycleLengthDays: 75,
            notes: 'Market demand looks strong.',
            createdAt: DateTime(2026, 3, 8),
            updatedAt: DateTime(2026, 4, 25),
            isSynced: true,
            targetYieldKg: 1450,
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
  Future<List<Crop>> getCachedOnly() async => getAll();

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
            growthStage: AnimalGrowthStage.breeding,
            averageAgeMonths: 14,
            targetMaturityMonths: 12,
            createdAt: DateTime(2025, 11, 12),
            updatedAt: DateTime(2026, 4, 24),
            isSynced: true,
            mortalityCount: 1,
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
            growthStage: AnimalGrowthStage.mature,
            averageAgeMonths: 7,
            targetMaturityMonths: 6,
            createdAt: DateTime(2026, 1, 15),
            updatedAt: DateTime(2026, 4, 23),
            isSynced: false,
            mortalityCount: 3,
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
            growthStage: AnimalGrowthStage.finishing,
            averageAgeMonths: 10,
            targetMaturityMonths: 9,
            createdAt: DateTime(2026, 2, 2),
            updatedAt: DateTime(2026, 4, 21),
            isSynced: true,
            mortalityCount: 0,
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
  Future<List<Livestock>> getCachedOnly() async => getAll();

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
  Future<List<Transaction>> getCachedOnly() async => getAll();

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
