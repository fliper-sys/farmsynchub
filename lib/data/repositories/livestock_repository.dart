import '../../domain/models/livestock.dart';

/// Abstract repository for livestock operations.
abstract class LivestockRepository {
  /// Get all livestock.
  Future<List<Livestock>> getAll();

  /// Get livestock by ID.
  Future<Livestock?> getById(String id);

  /// Insert new livestock.
  Future<void> insert(Livestock livestock);

  /// Update existing livestock.
  Future<void> update(Livestock livestock);

  /// Delete livestock.
  Future<void> delete(String id);
}