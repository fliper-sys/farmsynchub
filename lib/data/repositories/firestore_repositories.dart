import '../local/daos/farms_dao.dart';
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
    this._firebaseService, {
    FarmsDao? farmsDao,
  }) : _farmsDao = farmsDao ?? FarmsDao(const LocalDatabase());

  final FirebaseService _firebaseService;
  final FarmsDao _farmsDao;

  @override
  Future<void> delete(String id) async {
    await _farmsDao.delete(id);
    if (_firebaseService.currentUser == null) {
      return;
    }

    try {
      await _firebaseService.deleteFromFirestore('farms', id);
    } catch (_) {
      // Keep local deletion even if cloud cleanup is temporarily unavailable.
    }
  }

  @override
  Future<List<Farm>> getAll() async {
    final List<Farm> localFarms = await _farmsDao.getAll();
    if (_firebaseService.currentUser == null) {
      return _sortFarms(localFarms);
    }

    final List<Farm> syncedLocalFarms = await _syncPendingLocalFarms(localFarms);

    try {
      final List<Map<String, dynamic>> records = await _firebaseService.getFromFirestore('farms');
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

    if (_firebaseService.currentUser == null) {
      return;
    }

    try {
      await _firebaseService.syncToFirestore(
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
          await _firebaseService.syncToFirestore(
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
  FirestoreCropRepository(this._firebaseService);

  final FirebaseService _firebaseService;

  @override
  Future<void> delete(String id) async {
    if (_firebaseService.currentUser == null) {
      throw Exception('User not authenticated');
    }
    await _firebaseService.deleteFromFirestore('crops', id);
  }

  @override
  Future<List<Crop>> getAll() async {
    if (_firebaseService.currentUser == null) {
      return <Crop>[];
    }
    final List<Map<String, dynamic>> records = await _firebaseService.getFromFirestore('crops');
    final List<Crop> crops = records
        .map(_tryParseCrop)
        .whereType<Crop>()
        .where((Crop crop) => crop.id.isNotEmpty)
        .toList()
      ..sort((Crop a, Crop b) => b.updatedAt.compareTo(a.updatedAt));
    return crops;
  }

  @override
  Future<Crop?> getById(String id) async {
    if (_firebaseService.currentUser == null) {
      return null;
    }
    final Map<String, dynamic>? record = await _firebaseService.getDocumentFromFirestore('crops', id);
    return record == null ? null : _tryParseCrop(record);
  }

  @override
  Future<void> insert(Crop crop) async {
    if (_firebaseService.currentUser == null) {
      throw Exception('User not authenticated');
    }
    final Map<String, dynamic> data = crop.toJson()..['isSynced'] = true;
    await _firebaseService.syncToFirestore('crops', data);
  }

  @override
  Future<void> update(Crop crop) async {
    if (_firebaseService.currentUser == null) {
      throw Exception('User not authenticated');
    }
    final Map<String, dynamic> data = crop.toJson()..['isSynced'] = true;
    await _firebaseService.syncToFirestore('crops', data);
  }
}

class FirestoreLivestockRepository implements LivestockRepository {
  FirestoreLivestockRepository(this._firebaseService);

  final FirebaseService _firebaseService;

  @override
  Future<void> delete(String id) async {
    if (_firebaseService.currentUser == null) {
      throw Exception('User not authenticated');
    }
    await _firebaseService.deleteFromFirestore('livestock', id);
  }

  @override
  Future<List<Livestock>> getAll() async {
    if (_firebaseService.currentUser == null) {
      return <Livestock>[];
    }
    final List<Map<String, dynamic>> records = await _firebaseService.getFromFirestore('livestock');
    final List<Livestock> items = records
        .map(_tryParseLivestock)
        .whereType<Livestock>()
        .where((Livestock item) => item.id.isNotEmpty)
        .toList()
      ..sort((Livestock a, Livestock b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  @override
  Future<Livestock?> getById(String id) async {
    if (_firebaseService.currentUser == null) {
      return null;
    }
    final Map<String, dynamic>? record = await _firebaseService.getDocumentFromFirestore('livestock', id);
    return record == null ? null : _tryParseLivestock(record);
  }

  @override
  Future<void> insert(Livestock livestock) async {
    if (_firebaseService.currentUser == null) {
      throw Exception('User not authenticated');
    }
    final Map<String, dynamic> data = livestock.toJson()..['isSynced'] = true;
    await _firebaseService.syncToFirestore('livestock', data);
  }

  @override
  Future<void> update(Livestock livestock) async {
    if (_firebaseService.currentUser == null) {
      throw Exception('User not authenticated');
    }
    final Map<String, dynamic> data = livestock.toJson()..['isSynced'] = true;
    await _firebaseService.syncToFirestore('livestock', data);
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
