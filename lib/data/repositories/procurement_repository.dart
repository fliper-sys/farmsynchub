import '../../domain/models/procurement_order.dart';

abstract class ProcurementRepository {
  Future<List<ProcurementOrder>> getAll();
  Future<ProcurementOrder?> getById(String id);
  Future<void> insert(ProcurementOrder order);
  Future<void> update(ProcurementOrder order);
  Future<void> delete(String id);
}
