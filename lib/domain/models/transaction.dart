/// Transaction type enumeration.
enum TransactionType {
  income,
  expense,
}

/// Transaction category enumeration.
enum TransactionCategory {
  cropSale,
  livestockSale,
  feed,
  fertiliser,
  labour,
  veterinary,
  other,
}

/// Transaction model representing financial transactions.
class Transaction {
  const Transaction({
    required this.id,
    required this.farmId,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    required this.transactionDate,
    required this.linkedEntityId,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
  });

  final String id;
  final String farmId;
  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final String description;
  final DateTime transactionDate;
  final String linkedEntityId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmId': farmId,
        'type': type.name,
        'category': category.name,
        'amount': amount,
        'description': description,
        'transactionDate': transactionDate.toIso8601String(),
        'linkedEntityId': linkedEntityId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        farmId: json['farmId'] as String,
        type: TransactionType.values.firstWhere(
          (e) => e.name == json['type'],
        ),
        category: TransactionCategory.values.firstWhere(
          (e) => e.name == json['category'],
        ),
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String,
        transactionDate: DateTime.parse(json['transactionDate'] as String),
        linkedEntityId: json['linkedEntityId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isSynced: json['isSynced'] as bool,
      );
}