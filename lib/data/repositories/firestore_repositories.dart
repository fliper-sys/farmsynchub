import '../local/daos/crops_dao.dart';
import '../local/daos/farms_dao.dart';
import '../local/daos/livestock_dao.dart';
import '../local/database.dart';
import '../../domain/models/crop.dart';
import '../../domain/models/farm.dart';
import '../../domain/models/livestock.dart';
import '../../domain/models/transaction.dart';
import '../remote/firebase_service.dart';
import 'crop_repository.dart';
import 'farm_repository.dart';
import 'finance_repository.dart';
import 'livestock_repository.dart';

class FirestoreFarmRepository implements FarmRepository {
  FirestoreFarmRepository(
    this._remoteStore, {
    FarmsDao? farmsDao,
  }) : _farmsDao = farmsDao ?? FarmsDao(const LocalDatabase());

  final FarmRemoteStore _remoteStore;
  final FarmsDao _farmsDao;

  @override
  Future<void> delete(String id) async {
    await _farmsDao.delete(id);
    if (!_remoteStore.hasActiveUser) {
      return;
    }

    try {
      await _remoteStore.deleteFromFirestore('farms', id);
    } catch (_) {
      // Keep local deletion even if cloud cleanup is temporarily unavailable.
    }
  }

  @override
  Future<List<Farm>> getAll() async {
    final List<Farm> localFarms = await _farmsDao.getAll();
    if (!_remoteStore.hasActiveUser) {
      return _sortFarms(localFarms);
    }

    final List<Farm> syncedLocalFarms = await _syncPendingLocalFarms(localFarms);

    try {
      final List<Map<String, dynamic>> records = await _remoteStore.getFromFirestore('farms');
      final List<Farm> remoteFarms = records.map(Farm.fromJson).toList();
      final List<Farm> mergedFarms = _mergeFarms(
        local: syncedLocalFarms,
        remote: remoteFarms,
      );
      await _farmsDao.replaceAll(mergedFarms);
      return _sortFarms(mergedFarms);
    } catch (_) {
      return _sortFarms(syncedLocalFarms);
    }
  }

  @override
  Future<Farm?> getById(String id) async {
    final List<Farm> farms = await getAll();
    for (final Farm farm in farms) {
      if (farm.id == id) {
        return farm;
      }
    }
    return null;
  }

  @override
  Future<void> insert(Farm farm) async {
    await _saveFarm(farm);
  }

  @override
  Future<void> update(Farm farm) async {
    await _saveFarm(farm);
  }

  Future<void> _saveFarm(Farm farm) async {
    Farm localFarm = farm.copyWith(isSynced: false);
    await _farmsDao.upsert(localFarm);

    if (!_remoteStore.hasActiveUser) {
      return;
    }

    try {
      await _remoteStore.syncToFirestore(
        'farms',
        localFarm.copyWith(isSynced: true).toJson(),
      );
      localFarm = localFarm.copyWith(isSynced: true);
      await _farmsDao.upsert(localFarm);
    } catch (_) {
      await _farmsDao.upsert(localFarm.copyWith(isSynced: false));
    }
  }

  Future<List<Farm>> _syncPendingLocalFarms(List<Farm> farms) async {
    final List<Farm> updated = <Farm>[];
    var hasChanges = false;

    for (final Farm farm in farms) {
      if (!farm.isSynced) {
        try {
          await _remoteStore.syncToFirestore(
            'farms',
            farm.copyWith(isSynced: true).toJson(),
          );
          updated.add(farm.copyWith(isSynced: true));
          hasChanges = true;
          continue;
        } catch (_) {
          updated.add(farm);
          continue;
        }
      }
      updated.add(farm);
    }

    if (hasChanges) {
      await _farmsDao.replaceAll(updated);
    }
    return updated;
  }

  List<Farm> _mergeFarms({
    required List<Farm> local,
    required List<Farm> remote,
  }) {
    final Map<String, Farm> merged = <String, Farm>{
      for (final Farm farm in remote) farm.id: farm.copyWith(isSynced: true),
    };

    for (final Farm farm in local) {
      final Farm? remoteFarm = merged[farm.id];
      if (remoteFarm == null || farm.updatedAt.isAfter(remoteFarm.updatedAt)) {
        merged[farm.id] = farm;
      }
    }

    return merged.values.toList(growable: false);
  }

  List<Farm> _sortFarms(List<Farm> farms) {
    final List<Farm> sorted = List<Farm>.from(farms);
    sorted.sort((Farm a, Farm b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }
}

class FirestoreCropRepository implements CropRepository {
  FirestoreCropRepository(
    this._firebaseService, {
    CropsDao? cropsDao,
  }) : _cropsDao = cropsDao ?? CropsDao(const LocalDatabase());

  final FirebaseService _firebaseService;
  final CropsDao _cropsDao;

  @override
  Future<void> delete(String id) async {
    await _cropsDao.delete(id);
    if (!_firebaseService.hasActiveUser) {
      return;
    }
    try {
      await _firebaseService.deleteFromFirestore('crops', id);
    } catch (_) {
      // Keep local deletion even if cloud cleanup is temporarily unavailable.
    }
  }

  @override
  Future<List<Crop>> getAll() async {
    final List<Crop> localCrops = await _cropsDao.getAll();
    if (!_firebaseService.hasActiveUser) {
      return _sortCrops(localCrops);
    }

    final List<Crop> syncedLocalCrops = await _syncPendingLocalCrops(localCrops);

    try {
      final List<Map<String, dynamic>> records = await _firebaseService.getFromFirestore('crops');
      final List<Crop> remoteCrops = records
          .map(_tryParseCrop)
          .whereType<Crop>()
          .where((Crop crop) => crop.id.isNotEmpty)
          .toList(growable: false);
      final List<Crop> mergedCrops = _mergeCrops(local: syncedLocalCrops, remote: remoteCrops);
      await _cropsDao.replaceAll(mergedCrops);
      return _sortCrops(mergedCrops);
    } catch (_) {
      return _sortCrops(syncedLocalCrops);
    }
  }

  @override
  Future<Crop?> getById(String id) async {
    final List<Crop> crops = await getAll();
    for (final Crop crop in crops) {
      if (crop.id == id) {
        return crop;
      }
    }
    return null;
  }

  @override
  Future<void> insert(Crop crop) async {
    await _saveCrop(crop);
  }

  @override
  Future<void> update(Crop crop) async {
    await _saveCrop(crop);
  }

  Future<void> _saveCrop(Crop crop) async {
    Crop localCrop = crop.copyWith(isSynced: false);
    await _cropsDao.upsert(localCrop);

    if (!_firebaseService.hasActiveUser) {
      return;
    }

    try {
      await _firebaseService.syncToFirestore('crops', localCrop.copyWith(isSynced: true).toJson());
      localCrop = localCrop.copyWith(isSynced: true);
      await _cropsDao.upsert(localCrop);
    } catch (_) {
      await _cropsDao.upsert(localCrop.copyWith(isSynced: false));
    }
  }

  Future<List<Crop>> _syncPendingLocalCrops(List<Crop> crops) async {
    final List<Crop> updated = <Crop>[];
    var hasChanges = false;

    for (final Crop crop in crops) {
      if (!crop.isSynced) {
        try {
          await _firebaseService.syncToFirestore('crops', crop.copyWith(isSynced: true).toJson());
          updated.add(crop.copyWith(isSynced: true));
          hasChanges = true;
        } catch (_) {
          updated.add(crop);
        }
      } else {
        updated.add(crop);
      }
    }

    if (hasChanges) {
      await _cropsDao.replaceAll(updated);
    }
    return updated;
  }

  List<Crop> _mergeCrops({required List<Crop> local, required List<Crop> remote}) {
    final Map<String, Crop> merged = <String, Crop>{
      for (final Crop crop in remote) crop.id: crop.copyWith(isSynced: true),
    };

    for (final Crop crop in local) {
      final Crop? remoteCrop = merged[crop.id];
      if (remoteCrop == null || crop.updatedAt.isAfter(remoteCrop.updatedAt)) {
        merged[crop.id] = crop;
      }
    }

    return merged.values.toList(growable: false);
  }

  List<Crop> _sortCrops(List<Crop> crops) {
    final List<Crop> sorted = List<Crop>.from(crops);
    sorted.sort((Crop a, Crop b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }
}

class FirestoreLivestockRepository implements LivestockRepository {
  FirestoreLivestockRepository(
    this._firebaseService, {
    LivestockDao? livestockDao,
  }) : _livestockDao = livestockDao ?? LivestockDao(const LocalDatabase());

  final FirebaseService _firebaseService;
  final LivestockDao _livestockDao;

  @override
  Future<void> delete(String id) async {
    await _livestockDao.delete(id);
    if (!_firebaseService.hasActiveUser) {
      return;
    }
    try {
      await _firebaseService.deleteFromFirestore('livestock', id);
    } catch (_) {
      // Keep local deletion even if cloud cleanup is temporarily unavailable.
    }
  }

  @override
  Future<List<Livestock>> getAll() async {
    final List<Livestock> localLivestock = await _livestockDao.getAll();
    if (!_firebaseService.hasActiveUser) {
      return _sortLivestock(localLivestock);
    }

    final List<Livestock> syncedLocalLivestock = await _syncPendingLocalLivestock(localLivestock);

    try {
      final List<Map<String, dynamic>> records = await _firebaseService.getFromFirestore('livestock');
      final List<Livestock> remoteLivestock = records
          .map(_tryParseLivestock)
          .whereType<Livestock>()
          .where((Livestock item) => item.id.isNotEmpty)
          .toList(growable: false);
      final List<Livestock> mergedLivestock = _mergeLivestock(local: syncedLocalLivestock, remote: remoteLivestock);
      await _livestockDao.replaceAll(mergedLivestock);
      return _sortLivestock(mergedLivestock);
    } catch (_) {
      return _sortLivestock(syncedLocalLivestock);
    }
  }

  @override
  Future<Livestock?> getById(String id) async {
    final List<Livestock> livestock = await getAll();
    for (final Livestock item in livestock) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<void> insert(Livestock livestock) async {
    await _saveLivestock(livestock);
  }

  @override
  Future<void> update(Livestock livestock) async {
    await _saveLivestock(livestock);
  }

  Future<void> _saveLivestock(Livestock livestock) async {
    Livestock localLivestock = livestock.copyWith(isSynced: false);
    await _livestockDao.upsert(localLivestock);

    if (!_firebaseService.hasActiveUser) {
      return;
    }

    try {
      await _firebaseService.syncToFirestore('livestock', localLivestock.copyWith(isSynced: true).toJson());
      localLivestock = localLivestock.copyWith(isSynced: true);
      await _livestockDao.upsert(localLivestock);
    } catch (_) {
      await _livestockDao.upsert(localLivestock.copyWith(isSynced: false));
    }
  }

  Future<List<Livestock>> _syncPendingLocalLivestock(List<Livestock> livestock) async {
    final List<Livestock> updated = <Livestock>[];
    var hasChanges = false;

    for (final Livestock item in livestock) {
      if (!item.isSynced) {
        try {
          await _firebaseService.syncToFirestore('livestock', item.copyWith(isSynced: true).toJson());
          updated.add(item.copyWith(isSynced: true));
          hasChanges = true;
        } catch (_) {
          updated.add(item);
        }
      } else {
        updated.add(item);
      }
    }

    if (hasChanges) {
      await _livestockDao.replaceAll(updated);
    }
    return updated;
  }

  List<Livestock> _mergeLivestock({required List<Livestock> local, required List<Livestock> remote}) {
    final Map<String, Livestock> merged = <String, Livestock>{
      for (final Livestock item in remote) item.id: item.copyWith(isSynced: true),
    };

    for (final Livestock item in local) {
      final Livestock? remoteItem = merged[item.id];
      if (remoteItem == null || item.updatedAt.isAfter(remoteItem.updatedAt)) {
        merged[item.id] = item;
      }
    }

    return merged.values.toList(growable: false);
  }

  List<Livestock> _sortLivestock(List<Livestock> livestock) {
    final List<Livestock> sorted = List<Livestock>.from(livestock);
    sorted.sort((Livestock a, Livestock b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }
}

Crop? _tryParseCrop(Map<String, dynamic> record) {
  try {
    return Crop.fromJson(record);
  } catch (_) {
    return null;
  }
}

Livestock? _tryParseLivestock(Map<String, dynamic> record) {
  try {
    return Livestock.fromJson(record);
  } catch (_) {
    return null;
  }
}

Transaction? _tryParseTransaction(Map<String, dynamic> record) {
  try {
    return Transaction.fromJson(record);
  } catch (_) {
    return null;
  }
}

class FirestoreFinanceRepository implements FinanceRepository {
  FirestoreFinanceRepository(this._firebaseService);

  final FirebaseService _firebaseService;

  @override
  Future<void> delete(String id) async {
    if (_firebaseService.currentUser == null) {
      throw Exception('User not authenticated');
    }
    await _firebaseService.deleteFromFirestore('transactions', id);
  }

  @override
  Future<List<Transaction>> getAll() async {
    if (_firebaseService.currentUser == null) {
      return <Transaction>[];
    }
    final List<Map<String, dynamic>> records = await _firebaseService.getFromFirestore('transactions');
    final List<Transaction> items = records
        .map(_tryParseTransaction)
        .whereType<Transaction>()
        .where((Transaction item) => item.id.isNotEmpty)
        .toList()
      ..sort((Transaction a, Transaction b) => b.transactionDate.compareTo(a.transactionDate));
    return items;
  }

  @override
  Future<Transaction?> getById(String id) async {
    if (_firebaseService.currentUser == null) {
      return null;
    }
    final Map<String, dynamic>? record = await _firebaseService.getDocumentFromFirestore('transactions', id);
    return record == null ? null : _tryParseTransaction(record);
  }

  @override
  Future<void> insert(Transaction transaction) async {
    if (_firebaseService.currentUser == null) {
      throw Exception('User not authenticated');
    }
    final Map<String, dynamic> data = transaction.toJson()..['isSynced'] = true;
    await _firebaseService.syncToFirestore('transactions', data);
  }

  @override
  Future<void> update(Transaction transaction) async {
    if (_firebaseService.currentUser == null) {
      throw Exception('User not authenticated');
    }
    final Map<String, dynamic> data = transaction.toJson()..['isSynced'] = true;
    await _firebaseService.syncToFirestore('transactions', data);
  }
}
