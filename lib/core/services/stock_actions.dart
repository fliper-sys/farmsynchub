import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../providers/operations_hub_provider.dart';

/// Result of trying to sell stock quickly.
class QuickSaleResult {
  const QuickSaleResult.ok(this.receiptNumber) : error = null;
  const QuickSaleResult.failed(this.error) : receiptNumber = null;

  final String? receiptNumber;
  final String? error;

  bool get isOk => error == null;
}

/// Stock-aware actions shared by several screens, so selling always writes
/// the income record AND takes the goods out of stock together.
class StockActions {
  const StockActions._();

  /// Sells [quantity] of [item] at [unitPrice]. Refuses to sell more than is
  /// in stock.
  static Future<QuickSaleResult> quickSale(
    WidgetRef ref, {
    required InventoryItem item,
    required double quantity,
    required double unitPrice,
    String buyerName = '',
    String buyerId = '',
    String note = '',
  }) async {
    if (quantity <= 0) {
      return const QuickSaleResult.failed('Enter a quantity above zero.');
    }
    if (unitPrice < 0) {
      return const QuickSaleResult.failed('Price cannot be negative.');
    }
    // Always read the latest stock, not the copy the screen was built with.
    InventoryItem? live;
    for (final InventoryItem i in ref.read(operationsHubProvider).inventory) {
      if (i.id == item.id) live = i;
    }
    if (live == null) {
      return const QuickSaleResult.failed('That item no longer exists.');
    }
    if (quantity > live.availableQuantity) {
      return QuickSaleResult.failed(
          'Only ${live.availableQuantity.toStringAsFixed(live.availableQuantity % 1 == 0 ? 0 : 1)} ${live.unit} of ${live.name} left.');
    }

    final DateTime now = DateTime.now();
    final String receipt = 'FS-SALE-${now.millisecondsSinceEpoch}';
    final String lower = '${live.category} ${live.name}'.toLowerCase();
    final bool livestock = live.unit.toLowerCase() == 'head' ||
        lower.contains('live') ||
        lower.contains('goat') ||
        lower.contains('sheep') ||
        lower.contains('cow') ||
        lower.contains('egg');

    await ref.read(transactionsProvider.notifier).addTransaction(
          Transaction(
            id: const Uuid().v4(),
            farmId: live.farmId,
            type: TransactionType.income,
            category: livestock
                ? TransactionCategory.livestockSale
                : TransactionCategory.cropSale,
            amount: quantity * unitPrice,
            description: '${live.name} sale',
            transactionDate: now,
            linkedEntityId: buyerId,
            createdAt: now,
            updatedAt: now,
            isSynced: true,
            recordKind: TransactionRecordKind.sale,
            partyType: TransactionPartyType.customer,
            productName: live.name,
            quantity: quantity,
            unit: live.unit,
            unitPrice: unitPrice,
            counterpartyName: buyerName.isEmpty ? 'Walk-in customer' : buyerName,
            receiptNumber: receipt,
            notes: note.isEmpty ? 'Quick sale from Ready to sell.' : note,
          ),
        );
    await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
          farmId: live.farmId,
          productName: live.name,
          unit: live.unit,
          deltaQuantity: -quantity,
          unitPrice: unitPrice,
          costPrice: live.costPrice,
          type: StockMovementType.sale,
          note: 'Quick sale $receipt',
          linkedEntityId: receipt,
        );
    return QuickSaleResult.ok(receipt);
  }
}
