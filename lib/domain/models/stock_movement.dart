import 'inventory_item.dart';

/// Why a quantity of stock changed. Positive types add stock, negative types
/// take it away; [adjustment] can go either way (stock-take correction).
enum StockMovementType {
  opening,
  purchase,
  harvest,
  production,
  transferIn,
  sale,
  usage,
  loss,
  adjustment,
}

extension StockMovementTypeX on StockMovementType {
  String get label {
    switch (this) {
      case StockMovementType.opening:
        return 'Opening stock';
      case StockMovementType.purchase:
        return 'Purchase';
      case StockMovementType.harvest:
        return 'Harvest';
      case StockMovementType.production:
        return 'Production';
      case StockMovementType.transferIn:
        return 'Moved to sale stock';
      case StockMovementType.sale:
        return 'Sale';
      case StockMovementType.usage:
        return 'Used';
      case StockMovementType.loss:
        return 'Loss / waste';
      case StockMovementType.adjustment:
        return 'Stock-take';
    }
  }

  /// True for movements that take stock out because it was consumed, not sold.
  bool get isConsumption =>
      this == StockMovementType.usage || this == StockMovementType.loss;
}

/// One immutable line in the stock ledger.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.itemId,
    required this.farmId,
    required this.itemName,
    required this.unit,
    required this.type,
    required this.quantity,
    required this.balanceAfter,
    required this.createdAt,
    this.unitValue = 0,
    this.note = '',
    this.linkedEntityId = '',
    this.linkedEntityLabel = '',
  });

  final String id;
  final String itemId;
  final String farmId;
  final String itemName;
  final String unit;
  final StockMovementType type;

  /// Signed change: positive adds stock, negative removes it.
  final double quantity;
  final double balanceAfter;
  final DateTime createdAt;

  /// Cost per unit for inflows, selling price per unit for sales.
  final double unitValue;
  final String note;

  /// Crop, animal group, transaction or order this movement belongs to.
  final String linkedEntityId;
  final String linkedEntityLabel;

  bool get isInflow => quantity > 0;
  double get value => quantity.abs() * unitValue;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'itemId': itemId,
        'farmId': farmId,
        'itemName': itemName,
        'unit': unit,
        'type': type.name,
        'quantity': quantity,
        'balanceAfter': balanceAfter,
        'createdAt': createdAt.toIso8601String(),
        'unitValue': unitValue,
        'note': note,
        'linkedEntityId': linkedEntityId,
        'linkedEntityLabel': linkedEntityLabel,
      };

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id'] as String? ?? '',
        itemId: json['itemId'] as String? ?? '',
        farmId: json['farmId'] as String? ?? '',
        itemName: json['itemName'] as String? ?? '',
        unit: json['unit'] as String? ?? 'unit',
        type: StockMovementType.values.firstWhere(
          (StockMovementType t) => t.name == json['type'],
          orElse: () => StockMovementType.adjustment,
        ),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        unitValue: (json['unitValue'] as num?)?.toDouble() ?? 0,
        note: json['note'] as String? ?? '',
        linkedEntityId: json['linkedEntityId'] as String? ?? '',
        linkedEntityLabel: json['linkedEntityLabel'] as String? ?? '',
      );
}

/// How the app groups stock for the farmer. Derived from the existing
/// category / unit text, so no stored data has to change.
enum InventoryGroup { inputs, produce, animals }

extension InventoryItemGroupX on InventoryItem {
  InventoryGroup get group {
    if (unit.trim().toLowerCase() == 'head') return InventoryGroup.animals;
    final String c = category.toLowerCase();
    final String n = name.toLowerCase();
    const List<String> produceWords = <String>[
      'produce',
      'harvest',
      'crop',
      'egg',
      'milk',
      'meat',
      'fish',
    ];
    for (final String w in produceWords) {
      if (c.contains(w) || n == w || n.contains('egg')) {
        return InventoryGroup.produce;
      }
    }
    return InventoryGroup.inputs;
  }

  /// Money tied up in this stock at cost (falls back to selling price when
  /// no cost was entered).
  double get costValue =>
      availableQuantity * (costPrice > 0 ? costPrice : unitPrice);

  double get retailValue => availableQuantity * unitPrice;

  /// Profit margin on the selling price, 0..1 (can be negative).
  double get margin => unitPrice <= 0 || costPrice <= 0
      ? 0
      : (unitPrice - costPrice) / unitPrice;
}

/// Read-only maths over a list of ledger rows.
class StockAnalytics {
  const StockAnalytics._();

  static List<StockMovement> forItem(List<StockMovement> all, String itemId) {
    final List<StockMovement> rows = all
        .where((StockMovement m) => m.itemId == itemId)
        .toList(growable: false);
    rows.sort((StockMovement a, StockMovement b) =>
        b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  /// Quantity consumed (used or lost) in the last [days] days.
  static double consumedIn(
    List<StockMovement> all,
    String itemId, {
    int days = 30,
    DateTime? now,
  }) {
    final DateTime from =
        (now ?? DateTime.now()).subtract(Duration(days: days));
    double total = 0;
    for (final StockMovement m in all) {
      if (m.itemId == itemId &&
          m.type.isConsumption &&
          m.createdAt.isAfter(from)) {
        total += m.quantity.abs();
      }
    }
    return total;
  }

  /// Quantity sold in the last [days] days.
  static double soldIn(
    List<StockMovement> all,
    String itemId, {
    int days = 30,
    DateTime? now,
  }) {
    final DateTime from =
        (now ?? DateTime.now()).subtract(Duration(days: days));
    double total = 0;
    for (final StockMovement m in all) {
      if (m.itemId == itemId &&
          m.type == StockMovementType.sale &&
          m.createdAt.isAfter(from)) {
        total += m.quantity.abs();
      }
    }
    return total;
  }

  /// Days the current stock will last at the last-30-day outflow rate, or
  /// null when there is not enough history to say.
  static int? daysOfCover(
    List<StockMovement> all,
    InventoryItem item, {
    DateTime? now,
  }) {
    final double out = consumedIn(all, item.id, now: now) +
        soldIn(all, item.id, now: now);
    if (out <= 0) return null;
    final double perDay = out / 30;
    return (item.availableQuantity / perDay).floor();
  }

  /// Highest balance the item has had, used to draw the "how full" bar.
  static double peak(List<StockMovement> all, InventoryItem item) {
    double best = item.availableQuantity;
    for (final StockMovement m in all) {
      if (m.itemId == item.id && m.balanceAfter > best) best = m.balanceAfter;
    }
    return best;
  }

  static DateTime? lastInflow(List<StockMovement> all, String itemId) {
    DateTime? last;
    for (final StockMovement m in all) {
      if (m.itemId == itemId && m.isInflow) {
        if (last == null || m.createdAt.isAfter(last)) last = m.createdAt;
      }
    }
    return last;
  }
}
