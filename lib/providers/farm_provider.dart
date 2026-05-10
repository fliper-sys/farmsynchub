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

  /// Adds a new farm.
  Future<void> addFarm(Farm farm) async {
    try {
      await _repository.insert(farm);
      await _loadFarms();
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
      await _loadFarms();
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
      await _loadFarms();
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
}
