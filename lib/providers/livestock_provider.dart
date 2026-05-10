import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/firestore_repositories.dart';
import '../data/repositories/livestock_repository.dart';
import '../domain/models/livestock.dart';
import 'auth_provider.dart';

/// Provider for livestock repository.
final livestockRepositoryProvider = Provider<LivestockRepository>((ref) {
  return FirestoreLivestockRepository(ref.watch(firebaseServiceProvider));
});

/// Provider for list of livestock.
final livestockProvider = StateNotifierProvider<LivestockNotifier, AsyncValue<List<Livestock>>>((ref) {
  final repository = ref.watch(livestockRepositoryProvider);
  return LivestockNotifier(repository);
});

/// State notifier for managing livestock.
class LivestockNotifier extends StateNotifier<AsyncValue<List<Livestock>>> {
  LivestockNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadLivestock();
  }

  final LivestockRepository _repository;

  /// Loads all livestock from the repository.
  Future<void> _loadLivestock() async {
    if (!mounted) {
      return;
    }
    state = const AsyncValue.loading();
    try {
      final livestock = await _repository.getAll();
      if (!mounted) {
        return;
      }
      state = AsyncValue.data(livestock);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Adds new livestock.
  Future<void> addLivestock(Livestock livestock) async {
    try {
      await _repository.insert(livestock);
      await _loadLivestock();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Updates existing livestock.
  Future<void> updateLivestock(Livestock livestock) async {
    try {
      await _repository.update(livestock);
      await _loadLivestock();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Deletes livestock.
  Future<void> deleteLivestock(String livestockId) async {
    try {
      await _repository.delete(livestockId);
      await _loadLivestock();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Gets livestock by ID.
  Future<Livestock?> getLivestockById(String livestockId) async {
    try {
      return await _repository.getById(livestockId);
    } catch (error, stackTrace) {
      if (!mounted) {
        return null;
      }
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}
