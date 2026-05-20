import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BusinessPartnerType {
  customer,
  provider,
}

class BusinessPartner {
  const BusinessPartner({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final BusinessPartnerType type;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BusinessPartner.fromJson(Map<String, dynamic> json) {
    return BusinessPartner(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      type: BusinessPartnerType.values.firstWhere(
        (BusinessPartnerType value) => value.name == json['type'],
        orElse: () => BusinessPartnerType.customer,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.farmId,
    required this.name,
    required this.category,
    required this.unit,
    required this.availableQuantity,
    required this.unitPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String farmId;
  final String name;
  final String category;
  final String unit;
  final double availableQuantity;
  final double unitPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryItem copyWith({
    String? id,
    String? farmId,
    String? name,
    String? category,
    String? unit,
    double? availableQuantity,
    double? unitPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      unitPrice: unitPrice ?? this.unitPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'farmId': farmId,
        'name': name,
        'category': category,
        'unit': unit,
        'availableQuantity': availableQuantity,
        'unitPrice': unitPrice,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      farmId: json['farmId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String? ?? 'unit',
      availableQuantity: (json['availableQuantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class OperationsHubState {
  const OperationsHubState({
    this.inventory = const <InventoryItem>[],
    this.partners = const <BusinessPartner>[],
  });

  final List<InventoryItem> inventory;
  final List<BusinessPartner> partners;

  OperationsHubState copyWith({
    List<InventoryItem>? inventory,
    List<BusinessPartner>? partners,
  }) {
    return OperationsHubState(
      inventory: inventory ?? this.inventory,
      partners: partners ?? this.partners,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'inventory': inventory.map((InventoryItem item) => item.toJson()).toList(),
        'partners': partners.map((BusinessPartner partner) => partner.toJson()).toList(),
      };

  factory OperationsHubState.fromJson(Map<String, dynamic> json) {
    return OperationsHubState(
      inventory: ((json['inventory'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map>()
          .map((Map item) => InventoryItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      partners: ((json['partners'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map>()
          .map((Map item) => BusinessPartner.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }
}

final operationsHubProvider =
    StateNotifierProvider<OperationsHubNotifier, OperationsHubState>((ref) {
  return OperationsHubNotifier();
});

class OperationsHubNotifier extends StateNotifier<OperationsHubState> {
  OperationsHubNotifier() : super(const OperationsHubState()) {
    _load();
  }

  static const String _storageKey = 'operations_hub_state';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    state = OperationsHubState.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  Future<void> addPartner(BusinessPartner partner) async {
    state = state.copyWith(
      partners: <BusinessPartner>[partner, ...state.partners],
    );
    await _save();
  }

  Future<void> addInventoryItem(InventoryItem item) async {
    final List<InventoryItem> next = <InventoryItem>[item, ...state.inventory];
    state = state.copyWith(inventory: next);
    await _save();
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final List<InventoryItem> next = state.inventory
        .map((InventoryItem current) => current.id == item.id ? item : current)
        .toList(growable: false);
    state = state.copyWith(inventory: next);
    await _save();
  }

  Future<void> adjustInventoryQuantity({
    required String farmId,
    required String productName,
    required String unit,
    required double deltaQuantity,
    required double unitPrice,
  }) async {
    final String normalizedName = productName.trim().toLowerCase();
    final int index = state.inventory.indexWhere(
      (InventoryItem item) =>
          item.farmId == farmId &&
          item.name.trim().toLowerCase() == normalizedName &&
          item.unit.trim().toLowerCase() == unit.trim().toLowerCase(),
    );
    final DateTime now = DateTime.now();
    if (index == -1) {
      if (deltaQuantity <= 0) {
        return;
      }
      await addInventoryItem(
        InventoryItem(
          id: '${farmId}_${normalizedName}_$unit',
          farmId: farmId,
          name: productName.trim(),
          category: 'Farm produce',
          unit: unit.trim(),
          availableQuantity: deltaQuantity,
          unitPrice: unitPrice,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }

    final InventoryItem current = state.inventory[index];
    final double nextQuantity = (current.availableQuantity + deltaQuantity).clamp(0, 999999).toDouble();
    await updateInventoryItem(
      current.copyWith(
        availableQuantity: nextQuantity,
        unitPrice: unitPrice == 0 ? current.unitPrice : unitPrice,
        updatedAt: now,
      ),
    );
  }
}
