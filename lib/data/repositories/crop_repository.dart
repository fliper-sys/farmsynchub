import '../../domain/models/crop.dart';

/// Abstract repository for crop operations.
abstract class CropRepository {
  /// Get all crops.
  Future<List<Crop>> getAll();

  /// Get crop by ID.
  Future<Crop?> getById(String id);

  /// Insert a new crop.
  Future<void> insert(Crop crop);

  /// Update an existing crop.
  Future<void> update(Crop crop);

  /// Delete a crop.
  Future<void> delete(String id);
}