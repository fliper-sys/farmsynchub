import '../../domain/models/crop.dart';

/// Abstract repository for crop operations.
abstract class CropRepository {
  /// Get all crops.
  Future<List<Crop>> getAll();

  /// Get all crops from the local cache only, without waiting on a network
  /// round-trip. Used so the UI can show what's already on the device
  /// instantly on startup, while [getAll] refreshes from the cloud in the
  /// background.
  Future<List<Crop>> getCachedOnly();

  /// Get crop by ID.
  Future<Crop?> getById(String id);

  /// Insert a new crop.
  Future<void> insert(Crop crop);

  /// Update an existing crop.
  Future<void> update(Crop crop);

  /// Delete a crop.
  Future<void> delete(String id);
}