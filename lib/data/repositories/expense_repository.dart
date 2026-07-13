import '../../domain/models/expense_entry.dart';

abstract class ExpenseRepository {
  Future<List<ExpenseEntry>> getAll();
  Future<ExpenseEntry?> getById(String id);
  Future<void> insert(ExpenseEntry entry);
  Future<void> update(ExpenseEntry entry);
  Future<void> delete(String id);
}
