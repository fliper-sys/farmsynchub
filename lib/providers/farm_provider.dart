import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/farm_repository.dart';
import '../data/repositories/firestore_repositories.dart';
import '../domain/models/farm.dart';
import 'auth_provider.dart';

/// Provider for farm repository.
final farmRepositoryProvider = Provider<FarmRepository>((ref) {
  return FirestoreFarmRepository(ref.watch(firebaseServiceProvider));
});

/// Provider for list of farms.
final farmsProvider = StateNotifierProvider<FarmsNotifier, AsyncValue<List<Farm>>>((ref) {
  final repository = ref.watch(farmRepositoryProvider);
  return FarmsNotifier(repository);
});

/// Persisted active farm selection used by the dashboard and workspace cards.
final activeFarmProvider = StateNotifierProvider<ActiveFarmNotifier, String?>((ref) {
  return ActiveFarmNotifier();
});

/// State notifier for managing farms.
class FarmsNotifier extends StateNotifier<AsyncValue<List<Farm>>> {
  FarmsNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadFarms();
  }

  final FarmRepository _repository;

  /// Loads all farms from the repository.
  Future<void> _loadFarms() async {
    if (!mounted) {
      return;
    }
    state = const AsyncValue.loading();
    try {
      final farms = await _repository.getAll();
      if (!mounted) {
        return;
      }
      state = AsyncValue.data(farms);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => _loadFarms();

  /// Adds a new farm.
  Future<void> addFarm(Farm farm) async {
    try {
      await _repository.insert(farm);
      _upsertFarmInState(farm);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Updates an existing farm.
  Future<void> updateFarm(Farm farm) async {
    try {
      await _repository.update(farm);
      _upsertFarmInState(farm);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Deletes a farm.
  Future<void> deleteFarm(String farmId) async {
    try {
      await _repository.delete(farmId);
      _removeFarmFromState(farmId);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Gets a farm by ID.
  Future<Farm?> getFarmById(String farmId) async {
    try {
      return await _repository.getById(farmId);
    } catch (error, stackTrace) {
      if (!mounted) {
        return null;
      }
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  void _upsertFarmInState(Farm farm) {
    final List<Farm> currentFarms = List<Farm>.from(state.valueOrNull ?? const <Farm>[]);
    final int index = currentFarms.indexWhere((Farm item) => item.id == farm.id);
    if (index == -1) {
      currentFarms.add(farm);
    } else {
      currentFarms[index] = farm;
    }
    currentFarms.sort((Farm a, Farm b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncValue.data(currentFarms);
  }

  void _removeFarmFromState(String farmId) {
    final List<Farm> currentFarms = List<Farm>.from(state.valueOrNull ?? const <Farm>[]);
    currentFarms.removeWhere((Farm item) => item.id == farmId);
    state = AsyncValue.data(currentFarms);
  }
}

class ActiveFarmNotifier extends StateNotifier<String?> {
  ActiveFarmNotifier() : super(null) {
    _load();
  }

  static const String _activeFarmKey = 'active_farm_id';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? savedFarmId = prefs.getString(_activeFarmKey);
    if (!mounted) {
      return;
    }
    state = savedFarmId != null && savedFarmId.trim().isNotEmpty ? savedFarmId : null;
  }

  Future<void> setActiveFarm(String farmId) async {
    final String normalized = farmId.trim();
    if (normalized.isEmpty || normalized == state) {
      return;
    }
    state = normalized;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeFarmKey, normalized);
  }

  Future<void> clearActiveFarm() async {
    state = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeFarmKey);
  }
}
