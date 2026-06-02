/// Transaction type enumeration.
enum TransactionType {
  income,
  expense,
}

enum TransactionRecordKind {
  general,
  sale,
  procurement,
}

enum TransactionPartyType {
  customer,
  provider,
  internal,
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
    this.recordKind = TransactionRecordKind.general,
    this.partyType = TransactionPartyType.internal,
    this.productName = '',
    this.quantity = 0,
    this.unit = 'unit',
    this.unitPrice = 0,
    this.counterpartyName = '',
    this.counterpartyEmail = '',
    this.counterpartyPhone = '',
    this.receiptNumber = '',
    this.notes = '',
    this.attachmentNames = const <String>[],
    this.attachmentBase64 = const <String>[],
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
  final TransactionRecordKind recordKind;
  final TransactionPartyType partyType;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final String counterpartyName;
  final String counterpartyEmail;
  final String counterpartyPhone;
  final String receiptNumber;
  final String notes;
  final List<String> attachmentNames;
  final List<String> attachmentBase64;

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
        'recordKind': recordKind.name,
        'partyType': partyType.name,
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'counterpartyName': counterpartyName,
        'counterpartyEmail': counterpartyEmail,
        'counterpartyPhone': counterpartyPhone,
        'receiptNumber': receiptNumber,
        'notes': notes,
        'attachmentNames': attachmentNames,
        'attachmentBase64': attachmentBase64,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String? ?? '',
        farmId: json['farmId'] as String? ?? '',
        type: TransactionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => TransactionType.expense,
        ),
        category: TransactionCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => TransactionCategory.other,
        ),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String? ?? '',
        transactionDate: DateTime.tryParse(json['transactionDate'] as String? ?? '') ?? DateTime.now(),
        linkedEntityId: json['linkedEntityId'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        isSynced: json['isSynced'] as bool? ?? false,
        recordKind: TransactionRecordKind.values.firstWhere(
          (TransactionRecordKind value) => value.name == json['recordKind'],
          orElse: () => TransactionRecordKind.general,
        ),
        partyType: TransactionPartyType.values.firstWhere(
          (TransactionPartyType value) => value.name == json['partyType'],
          orElse: () => TransactionPartyType.internal,
        ),
        productName: json['productName'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? 'unit',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        counterpartyName: json['counterpartyName'] as String? ?? '',
        counterpartyEmail: json['counterpartyEmail'] as String? ?? '',
        counterpartyPhone: json['counterpartyPhone'] as String? ?? '',
        receiptNumber: json['receiptNumber'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        attachmentNames: ((json['attachmentNames'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<String>()
            .toList(growable: false),
        attachmentBase64: ((json['attachmentBase64'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<String>()
            .toList(growable: false),
      );
}
