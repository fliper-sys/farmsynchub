import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/crop_repository.dart';
import '../data/repositories/firestore_repositories.dart';
import '../domain/models/crop.dart';
import 'auth_provider.dart';

/// Provider for crop repository.
final cropRepositoryProvider = Provider<CropRepository>((ref) {
  return FirestoreCropRepository(ref.watch(firebaseServiceProvider));
});

/// Provider for list of crops.
final cropsProvider = StateNotifierProvider<CropsNotifier, AsyncValue<List<Crop>>>((ref) {
  final repository = ref.watch(cropRepositoryProvider);
  return CropsNotifier(repository);
});

/// State notifier for managing crops.
class CropsNotifier extends StateNotifier<AsyncValue<List<Crop>>> {
  CropsNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadCrops();
  }

  final CropRepository _repository;

  /// Loads all crops from the repository.
  Future<void> _loadCrops() async {
    if (!mounted) {
      return;
    }
    state = const AsyncValue.loading();
    try {
      final crops = await _repository.getAll();
      if (!mounted) {
        return;
      }
      state = AsyncValue.data(crops);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => _loadCrops();

  /// Adds a new crop.
  Future<void> addCrop(Crop crop) async {
    try {
      await _repository.insert(crop);
      await _loadCrops();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Updates an existing crop.
  Future<void> updateCrop(Crop crop) async {
    try {
      await _repository.update(crop);
      await _loadCrops();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Deletes a crop.
  Future<void> deleteCrop(String cropId) async {
    try {
      await _repository.delete(cropId);
      await _loadCrops();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Gets a crop by ID.
  Future<Crop?> getCropById(String cropId) async {
    try {
      return await _repository.getById(cropId);
    } catch (error, stackTrace) {
      if (!mounted) {
        return null;
      }
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}
