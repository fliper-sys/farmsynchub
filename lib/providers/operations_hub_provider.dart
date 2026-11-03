import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/remote/operations_hub_remote_store.dart';
import '../data/repositories/firestore_inventory_repository.dart';
import '../data/repositories/inventory_repository.dart';
import '../domain/models/inventory_item.dart';
import 'auth_provider.dart';
import 'stock_ledger_provider.dart';

export '../domain/models/inventory_item.dart';
export '../domain/models/stock_movement.dart';

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
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
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
        'inventory':
            inventory.map((InventoryItem item) => item.toJson()).toList(),
        'partners': partners
            .map((BusinessPartner partner) => partner.toJson())
            .toList(),
      };

  factory OperationsHubState.fromJson(Map<String, dynamic> json) {
    return OperationsHubState(
      inventory: ((json['inventory'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map>()
          .map((Map item) =>
              InventoryItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      partners: ((json['partners'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map>()
          .map((Map item) =>
              BusinessPartner.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return FirestoreInventoryRepository(ref.watch(firebaseServiceProvider));
});

final operationsHubProvider =
    StateNotifierProvider<OperationsHubNotifier, OperationsHubState>((ref) {
  return OperationsHubNotifier(
    ref.watch(firebaseServiceProvider),
    ref.watch(inventoryRepositoryProvider),
    ref.watch(stockLedgerProvider.notifier),
  );
});

class OperationsHubNotifier extends StateNotifier<OperationsHubState> {
  OperationsHubNotifier(
      this._remoteStore, this._inventoryRepository, [this._ledger])
      : super(const OperationsHubState()) {
    _load();
  }

  final StockLedgerNotifier? _ledger;

  final OperationsHubRemoteStore _remoteStore;
  final InventoryRepository _inventoryRepository;

  /// Legacy combined-blob storage key. Partners still live here; inventory
  /// used to as well, and is migrated out on first load after upgrade (see
  /// [_load]) into its own per-item synced collection via
  /// [InventoryRepository].
  static const String _storageKey = 'operations_hub_state';

  Future<void> _load() async {
    OperationsHubState legacy = const OperationsHubState();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      legacy =
          OperationsHubState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }

    if (_remoteStore.hasActiveUser) {
      try {
        final List<Map<String, dynamic>> remoteDocs =
            await _remoteStore.getFromFirestore(_storageKey);
        for (final Map<String, dynamic> doc in remoteDocs) {
          final dynamic payload = doc['payload'];
          if (payload is Map<String, dynamic>) {
            legacy = OperationsHubState.fromJson(payload);
            break;
          }
          if (payload is Map) {
            legacy =
                OperationsHubState.fromJson(Map<String, dynamic>.from(payload));
            break;
          }
        }
      } catch (_) {
        // Fall back to the locally cached legacy blob if remote loading is unavailable.
      }
    }

    List<InventoryItem> inventory = await _inventoryRepository.getAll();
    if (inventory.isEmpty && legacy.inventory.isNotEmpty) {
      // One-time migration from the old combined blob into the new
      // per-item synced collection.
      for (final InventoryItem item in legacy.inventory) {
        await _inventoryRepository.insert(item);
      }
      inventory = legacy.inventory;
    }

    if (!mounted) {
      return;
    }
    state = OperationsHubState(inventory: inventory, partners: legacy.partners);
  }

  /// Partners remain on the legacy combined-blob sync — only inventory was
  /// asked to become properly per-item synced.
  Future<void> _savePartners() async {
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
    await _savePartners();
  }

  Future<void> updatePartner(BusinessPartner partner) async {
    final List<BusinessPartner> next = state.partners
        .map((BusinessPartner current) =>
            current.id == partner.id ? partner : current)
        .toList(growable: false);
    state = state.copyWith(partners: next);
    await _savePartners();
  }

  Future<void> deletePartner(String partnerId) async {
    final List<BusinessPartner> next = state.partners
        .where((BusinessPartner partner) => partner.id != partnerId)
        .toList(growable: false);
    state = state.copyWith(partners: next);
    await _savePartners();
  }

  Future<void> addInventoryItem(InventoryItem item) async {
    final List<InventoryItem> next = <InventoryItem>[...state.inventory];
    final int index =
        next.indexWhere((InventoryItem current) => current.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.insert(0, item);
    }
    state = state.copyWith(inventory: next);
    await _inventoryRepository.insert(item);
    if (index < 0 && item.availableQuantity > 0) {
      await _log(
        item,
        StockMovementType.opening,
        item.availableQuantity,
        note: 'Stock added',
        unitValue: item.costPrice > 0 ? item.costPrice : item.unitPrice,
      );
    }
  }

  Future<void> _log(
    InventoryItem item,
    StockMovementType type,
    double signedQuantity, {
    String note = '',
    String linkedEntityId = '',
    String linkedEntityLabel = '',
    double? unitValue,
    double? balanceAfter,
  }) {
    final StockLedgerNotifier? ledger = _ledger;
    if (ledger == null) return Future<void>.value();
    return ledger.record(
      StockMovement(
        id: const Uuid().v4(),
        itemId: item.id,
        farmId: item.farmId,
        itemName: item.name,
        unit: item.unit,
        type: type,
        quantity: signedQuantity,
        balanceAfter: balanceAfter ?? item.availableQuantity,
        createdAt: DateTime.now(),
        unitValue: unitValue ?? item.costPrice,
        note: note,
        linkedEntityId: linkedEntityId,
        linkedEntityLabel: linkedEntityLabel,
      ),
    );
  }

  InventoryItem? _byId(String id) {
    for (final InventoryItem item in state.inventory) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Takes [quantity] out of stock because it was used (fed, sprayed,
  /// planted ...). Refuses when there is not enough left, so stock can never
  /// go negative. Returns false when nothing was recorded.
  Future<bool> recordUsage({
    required String itemId,
    required double quantity,
    String note = '',
    String linkedEntityId = '',
    String linkedEntityLabel = '',
    StockMovementType type = StockMovementType.usage,
  }) async {
    final InventoryItem? item = _byId(itemId);
    if (item == null || quantity <= 0 || quantity > item.availableQuantity) {
      return false;
    }
    final InventoryItem next = item.copyWith(
      availableQuantity: item.availableQuantity - quantity,
      updatedAt: DateTime.now(),
    );
    await updateInventoryItem(next);
    await _log(
      next,
      type,
      -quantity,
      note: note,
      linkedEntityId: linkedEntityId,
      linkedEntityLabel: linkedEntityLabel,
    );
    return true;
  }

  /// Adds bought stock and keeps a weighted-average cost, so margins stay
  /// honest when prices change between purchases.
  Future<bool> restock({
    required String itemId,
    required double quantity,
    double? unitCost,
    String note = '',
    String linkedEntityId = '',
    String linkedEntityLabel = '',
  }) async {
    final InventoryItem? item = _byId(itemId);
    if (item == null || quantity <= 0) return false;
    final double paid = (unitCost != null && unitCost > 0)
        ? unitCost
        : (item.costPrice > 0 ? item.costPrice : item.unitPrice);
    final double total = item.availableQuantity + quantity;
    final double oldCost = item.costPrice > 0 ? item.costPrice : paid;
    final double avgCost =
        total <= 0 ? paid : ((item.availableQuantity * oldCost) + (quantity * paid)) / total;
    final InventoryItem next = item.copyWith(
      availableQuantity: total,
      costPrice: avgCost,
      updatedAt: DateTime.now(),
    );
    await updateInventoryItem(next);
    await _log(
      next,
      StockMovementType.purchase,
      quantity,
      note: note,
      unitValue: paid,
      linkedEntityId: linkedEntityId,
      linkedEntityLabel: linkedEntityLabel,
    );
    return true;
  }

  /// Stock-take: sets the real counted quantity and logs the difference.
  Future<bool> setCount({
    required String itemId,
    required double counted,
    String note = '',
  }) async {
    final InventoryItem? item = _byId(itemId);
    if (item == null || counted < 0) return false;
    final double delta = counted - item.availableQuantity;
    if (delta == 0) return true;
    final InventoryItem next = item.copyWith(
      availableQuantity: counted,
      updatedAt: DateTime.now(),
    );
    await updateInventoryItem(next);
    await _log(
      next,
      StockMovementType.adjustment,
      delta,
      note: note.isEmpty ? 'Counted ${counted.toStringAsFixed(1)} ${item.unit}' : note,
    );
    return true;
  }

  /// Takes feed (or any item whose category/name contains [keyword]) for one
  /// farm out of stock, oldest-expiry first. Returns how much was actually
  /// deducted, which can be less than [quantity] when stock runs short.
  Future<double> consumeByKeyword({
    required String farmId,
    required String keyword,
    required double quantity,
    String note = '',
    String linkedEntityId = '',
    String linkedEntityLabel = '',
  }) async {
    if (quantity <= 0) return 0;
    final String key = keyword.toLowerCase();
    final List<InventoryItem> pool = state.inventory
        .where((InventoryItem i) =>
            i.farmId == farmId &&
            i.availableQuantity > 0 &&
            (i.category.toLowerCase().contains(key) ||
                i.name.toLowerCase().contains(key)))
        .toList()
      ..sort((InventoryItem a, InventoryItem b) {
        final DateTime ax = a.expiryDate ?? DateTime(9999);
        final DateTime bx = b.expiryDate ?? DateTime(9999);
        return ax.compareTo(bx);
      });
    double remaining = quantity;
    double taken = 0;
    for (final InventoryItem item in pool) {
      if (remaining <= 0) break;
      final double take =
          item.availableQuantity < remaining ? item.availableQuantity : remaining;
      final bool ok = await recordUsage(
        itemId: item.id,
        quantity: take,
        note: note,
        linkedEntityId: linkedEntityId,
        linkedEntityLabel: linkedEntityLabel,
      );
      if (ok) {
        remaining -= take;
        taken += take;
      }
    }
    return taken;
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final List<InventoryItem> next = state.inventory
        .map((InventoryItem current) => current.id == item.id ? item : current)
        .toList(growable: false);
    state = state.copyWith(inventory: next);
    await _inventoryRepository.update(item);
  }

  Future<void> deleteInventoryItem(String itemId) async {
    final List<InventoryItem> next = state.inventory
        .where((InventoryItem item) => item.id != itemId)
        .toList(growable: false);
    state = state.copyWith(inventory: next);
    await _inventoryRepository.delete(itemId);
  }

  /// Legacy entry point used by harvest, egg collection, procurement and the
  /// sales screens. Applies [deltaQuantity] (never below zero), writes a
  /// ledger row, and returns the change that was actually applied.
  Future<double> adjustInventoryQuantity({
    required String farmId,
    required String productName,
    required String unit,
    required double deltaQuantity,
    required double unitPrice,
    double? costPrice,
    StockMovementType? type,
    String note = '',
    String linkedEntityId = '',
    String linkedEntityLabel = '',
  }) async {
    final String normalizedName = productName.trim().toLowerCase();
    final int index = state.inventory.indexWhere(
      (InventoryItem item) =>
          item.farmId == farmId &&
          item.name.trim().toLowerCase() == normalizedName &&
          item.unit.trim().toLowerCase() == unit.trim().toLowerCase(),
    );
    final DateTime now = DateTime.now();
    final StockMovementType kind = type ??
        (deltaQuantity >= 0
            ? StockMovementType.purchase
            : StockMovementType.sale);
    if (index == -1) {
      if (deltaQuantity <= 0) {
        return 0;
      }
      final InventoryItem created = InventoryItem(
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
      );
      // addInventoryItem would log an "opening" row; log the real reason.
      final List<InventoryItem> next = <InventoryItem>[created, ...state.inventory];
      state = state.copyWith(inventory: next);
      await _inventoryRepository.insert(created);
      await _log(
        created,
        kind,
        deltaQuantity,
        note: note,
        linkedEntityId: linkedEntityId,
        linkedEntityLabel: linkedEntityLabel,
        unitValue: created.costPrice,
      );
      return deltaQuantity;
    }

    final InventoryItem current = state.inventory[index];
    final double nextQuantity =
        (current.availableQuantity + deltaQuantity).clamp(0, 999999).toDouble();
    final double applied = nextQuantity - current.availableQuantity;
    final InventoryItem updated = current.copyWith(
      availableQuantity: nextQuantity,
      unitPrice: unitPrice == 0 ? current.unitPrice : unitPrice,
      costPrice: costPrice ?? current.costPrice,
      updatedAt: now,
    );
    await updateInventoryItem(updated);
    if (applied != 0) {
      await _log(
        updated,
        kind,
        applied,
        note: note,
        linkedEntityId: linkedEntityId,
        linkedEntityLabel: linkedEntityLabel,
        unitValue: kind == StockMovementType.sale ? unitPrice : updated.costPrice,
      );
    }
    return applied;
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
    if (lower.contains('veg') ||
        lower.contains('leaf') ||
        lower.contains('lettuce')) {
      return '🥬';
    }
    if (lower.contains('tomato') || lower.contains('pepper')) {
      return '🍅';
    }
    return '🌾';
  }
}
