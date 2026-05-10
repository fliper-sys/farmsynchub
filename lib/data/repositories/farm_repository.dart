import '../../domain/models/farm.dart';

/// Abstract repository for farm operations.
abstract class FarmRepository {
  /// Get all farms.
  Future<List<Farm>> getAll();

  /// Get farm by ID.
  Future<Farm?> getById(String id);

  /// Insert a new farm.
  Future<void> insert(Farm farm);

  /// Update an existing farm.
  Future<void> update(Farm farm);

  /// Delete a farm.
  Future<void> delete(String id);
}