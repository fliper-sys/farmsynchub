abstract interface class OperationsHubRemoteStore {
  bool get hasActiveUser;

  Future<void> syncToFirestore(String collection, Map<String, dynamic> data);

  Future<List<Map<String, dynamic>>> getFromFirestore(String collection);
}
