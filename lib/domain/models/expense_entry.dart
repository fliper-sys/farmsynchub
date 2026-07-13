enum ExpenseCategory {
  feed,
  labour,
  veterinary,
  utilities,
  maintenance,
  equipment,
  other,
}

class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.farmId,
    required this.category,
    required this.amount,
    required this.description,
    required this.transactionDate,
    required this.vendorName,
    required this.receiptNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
    this.notes = '',
  });

  final String id;
  final String farmId;
  final ExpenseCategory category;
  final double amount;
  final String description;
  final DateTime transactionDate;
  final String vendorName;
  final String receiptNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmId': farmId,
        'category': category.name,
        'amount': amount,
        'description': description,
        'transactionDate': transactionDate.toIso8601String(),
        'vendorName': vendorName,
        'receiptNumber': receiptNumber,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
        'notes': notes,
      };

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) => ExpenseEntry(
        id: json['id'] as String? ?? '',
        farmId: json['farmId'] as String? ?? '',
        category: ExpenseCategory.values.firstWhere(
          (ExpenseCategory value) => value.name == json['category'],
          orElse: () => ExpenseCategory.other,
        ),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String? ?? '',
        transactionDate: DateTime.tryParse(json['transactionDate'] as String? ?? '') ?? DateTime.now(),
        vendorName: json['vendorName'] as String? ?? '',
        receiptNumber: json['receiptNumber'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        isSynced: json['isSynced'] as bool? ?? false,
        notes: json['notes'] as String? ?? '',
      );

  ExpenseEntry copyWith({
    String? id,
    String? farmId,
    ExpenseCategory? category,
    double? amount,
    String? description,
    DateTime? transactionDate,
    String? vendorName,
    String? receiptNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? notes,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      vendorName: vendorName ?? this.vendorName,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      notes: notes ?? this.notes,
    );
  }
}
