import '../../domain/models/livestock.dart';

/// Abstract repository for livestock operations.
abstract class LivestockRepository {
  /// Get all livestock.
  Future<List<Livestock>> getAll();

  /// Get all livestock from the local cache only, without waiting on a
  /// network round-trip. Used so the UI can show what's already on the
  /// device instantly on startup, while [getAll] refreshes from the cloud
  /// in the background.
  Future<List<Livestock>> getCachedOnly();

  /// Get livestock by ID.
  Future<Livestock?> getById(String id);

  /// Insert new livestock.
  Future<void> insert(Livestock livestock);

  /// Update existing livestock.
  Future<void> update(Livestock livestock);

  /// Delete livestock.
  Future<void> delete(String id);
}