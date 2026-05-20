enum FarmTodoPriority {
  low,
  normal,
  high,
  urgent,
}

enum FarmInputCategory {
  seed,
  fertiliser,
  feed,
  veterinary,
  labour,
  equipment,
  other,
}

class FarmTodoItem {
  const FarmTodoItem({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.priority = FarmTodoPriority.normal,
    this.dailyReminder = false,
    this.pushNotificationEnabled = true,
    this.isCompleted = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final String notes;
  final DateTime dueDate;
  final FarmTodoPriority priority;
  final bool dailyReminder;
  final bool pushNotificationEnabled;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'notes': notes,
        'dueDate': dueDate.toIso8601String(),
        'priority': priority.name,
        'dailyReminder': dailyReminder,
        'pushNotificationEnabled': pushNotificationEnabled,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FarmTodoItem.fromJson(Map<String, dynamic> json) => FarmTodoItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Farm task',
        notes: json['notes'] as String? ?? '',
        dueDate: DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
        priority: FarmTodoPriority.values.firstWhere(
          (FarmTodoPriority value) => value.name == json['priority'],
          orElse: () => FarmTodoPriority.normal,
        ),
        dailyReminder: json['dailyReminder'] as bool? ?? false,
        pushNotificationEnabled: json['pushNotificationEnabled'] as bool? ?? true,
        isCompleted: json['isCompleted'] as bool? ?? false,
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  FarmTodoItem copyWith({
    String? title,
    String? notes,
    DateTime? dueDate,
    FarmTodoPriority? priority,
    bool? dailyReminder,
    bool? pushNotificationEnabled,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
  }) =>
      FarmTodoItem(
        id: id,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        dueDate: dueDate ?? this.dueDate,
        priority: priority ?? this.priority,
        dailyReminder: dailyReminder ?? this.dailyReminder,
        pushNotificationEnabled: pushNotificationEnabled ?? this.pushNotificationEnabled,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class FarmInputRecord {
  const FarmInputRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.recordedAt,
    required this.createdAt,
    required this.updatedAt,
    this.supplier = '',
    this.notes = '',
    this.financeSynced = false,
    this.financeTransactionId = '',
  });

  final String id;
  final String name;
  final FarmInputCategory category;
  final double quantity;
  final String unit;
  final double unitCost;
  final String supplier;
  final String notes;
  final DateTime recordedAt;
  final bool financeSynced;
  final String financeTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get totalCost => quantity * unitCost;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category.name,
        'quantity': quantity,
        'unit': unit,
        'unitCost': unitCost,
        'supplier': supplier,
        'notes': notes,
        'recordedAt': recordedAt.toIso8601String(),
        'financeSynced': financeSynced,
        'financeTransactionId': financeTransactionId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FarmInputRecord.fromJson(Map<String, dynamic> json) => FarmInputRecord(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Farm input',
        category: FarmInputCategory.values.firstWhere(
          (FarmInputCategory value) => value.name == json['category'],
          orElse: () => FarmInputCategory.other,
        ),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? 'unit',
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0,
        supplier: json['supplier'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? '') ?? DateTime.now(),
        financeSynced: json['financeSynced'] as bool? ?? false,
        financeTransactionId: json['financeTransactionId'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
