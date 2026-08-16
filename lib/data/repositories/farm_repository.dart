import '../../domain/models/farm.dart';

/// Remote persistence contract used by farm repositories.
abstract class FarmRemoteStore {
  bool get hasActiveUser;

  Future<void> syncToFirestore(String collection, Map<String, dynamic> data);

  Future<List<Map<String, dynamic>>> getFromFirestore(
    String collection, {
    String? ownerUidField,
    String? memberArrayField,
  });

  Future<void> deleteFromFirestore(String collection, String id);
}

/// Abstract repository for farm operations.
abstract class FarmRepository {
  /// Get all farms.
  Future<List<Farm>> getAll();

  /// Get all farms from the local cache only, without waiting on a network
  /// round-trip. Used so the UI can show what's already on the device
  /// instantly on startup, while [getAll] refreshes from the cloud in the
  /// background.
  Future<List<Farm>> getCachedOnly();

  /// Get farm by ID.
  Future<Farm?> getById(String id);

  /// Insert a new farm.
  Future<void> insert(Farm farm);

  /// Update an existing farm.
  Future<void> update(Farm farm);

  /// Delete a farm.
  Future<void> delete(String id);
}