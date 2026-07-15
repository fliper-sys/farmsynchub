import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/remote/operations_hub_remote_store.dart';
import 'auth_provider.dart';

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
    this.costPrice = 0,
    this.emoji = '🌾',
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
  final double costPrice;
  final String emoji;

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
    double? costPrice,
    String? emoji,
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
      costPrice: costPrice ?? this.costPrice,
      emoji: emoji ?? this.emoji,
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
        'costPrice': costPrice,
        'emoji': emoji,
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
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      emoji: json['emoji'] as String? ?? '🌾',
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
  return OperationsHubNotifier(ref.watch(firebaseServiceProvider));
});

class OperationsHubNotifier extends StateNotifier<OperationsHubState> {
  OperationsHubNotifier(this._remoteStore) : super(const OperationsHubState()) {
    _load();
  }

  final OperationsHubRemoteStore _remoteStore;
  static const String _storageKey = 'operations_hub_state';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      state = OperationsHubState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }

    if (!_remoteStore.hasActiveUser) {
      return;
    }

    try {
      final List<Map<String, dynamic>> remoteDocs = await _remoteStore.getFromFirestore(_storageKey);
      for (final Map<String, dynamic> doc in remoteDocs) {
        final dynamic payload = doc['payload'];
        if (payload is Map<String, dynamic>) {
          state = OperationsHubState.fromJson(payload);
          break;
        }
        if (payload is Map) {
          state = OperationsHubState.fromJson(Map<String, dynamic>.from(payload));
          break;
        }
      }
    } catch (_) {
      // Fall back to the locally cached state if remote loading is unavailable.
    }
  }

  Future<void> _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> payload = state.toJson();
    await prefs.setString(_storageKey, jsonEncode(payload));
    if (_remoteStore.hasActiveUser) {
      try {
        await _remoteStore.syncToFirestore(_storageKey, <String, dynamic>{
          'id': _storageKey,
          'payload': payload,
        });
      } catch (_) {
        // Persist locally even if remote sync is unavailable.
      }
    }
  }

  Future<void> addPartner(BusinessPartner partner) async {
    state = state.copyWith(
      partners: <BusinessPartner>[partner, ...state.partners],
    );
    await _save();
  }

  Future<void> addInventoryItem(InventoryItem item) async {
    final List<InventoryItem> next = <InventoryItem>[...state.inventory];
    final int index = next.indexWhere((InventoryItem current) => current.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.insert(0, item);
    }
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

  Future<void> deleteInventoryItem(String itemId) async {
    final List<InventoryItem> next = state.inventory
        .where((InventoryItem item) => item.id != itemId)
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
    double? costPrice,
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
          costPrice: costPrice ?? unitPrice,
          emoji: _emojiForProductName(productName),
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
        costPrice: costPrice ?? current.costPrice,
        updatedAt: now,
      ),
    );
  }

  String _emojiForProductName(String name) {
    final String lower = name.trim().toLowerCase();
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('goat')) return '🐐';
    if (lower.contains('sheep')) return '🐑';
    if (lower.contains('fish')) return '🐟';
    if (lower.contains('feed')) return '🌽';
    if (lower.contains('fertil')) return '🧪';
    if (lower.contains('veg') || lower.contains('leaf') || lower.contains('lettuce')) return '🥬';
    if (lower.contains('tomato') || lower.contains('pepper') || lower.contains('pepper')) return '🍅';
    return '🌾';
  }
}
