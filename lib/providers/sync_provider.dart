import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/sync_service.dart';
import '../domain/models/crop.dart';
import '../domain/models/farm.dart';
import '../domain/models/health_log.dart';
import '../domain/models/livestock.dart';
import '../domain/models/transaction.dart';
import 'auth_provider.dart';
import 'crop_provider.dart';
import 'farm_provider.dart';
import 'finance_provider.dart';
import 'livestock_provider.dart';

final connectivityProvider = StreamProvider<ConnectivityResult>((Ref ref) {
  return Connectivity().onConnectivityChanged.distinct();
});

class SyncOverview {
  const SyncOverview({
    required this.pendingCount,
    required this.hasConnection,
    required this.lastAttemptAt,
    required this.isSyncing,
  });

  final int pendingCount;
  final bool hasConnection;
  final DateTime? lastAttemptAt;
  final bool isSyncing;

  SyncOverview copyWith({
    int? pendingCount,
    bool? hasConnection,
    DateTime? lastAttemptAt,
    bool? isSyncing,
  }) {
    return SyncOverview(
      pendingCount: pendingCount ?? this.pendingCount,
      hasConnection: hasConnection ?? this.hasConnection,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

final syncServiceProvider = Provider<SyncService>((Ref ref) {
  return SyncService(
    ref.watch(firebaseServiceProvider),
    Connectivity(),
  );
});

final deviceSyncAliasProvider = Provider.autoDispose<SyncService>((Ref ref) {
  // Reuse SyncService for cloud-side device writes; keep provider for compatibility.
  return ref.watch(syncServiceProvider);
});

final syncOverviewProvider =
    StateNotifierProvider<SyncOverviewNotifier, SyncOverview>((Ref ref) {
  final SyncOverviewNotifier notifier = SyncOverviewNotifier(ref);

  ref.listen<AsyncValue<List<Farm>>>(farmsProvider, (_, __) {
    notifier.refreshOverview();
  });
  ref.listen<AsyncValue<List<Crop>>>(cropsProvider, (_, __) {
    notifier.refreshOverview();
  });
  ref.listen<AsyncValue<List<Livestock>>>(livestockProvider, (_, __) {
    notifier.refreshOverview();
  });
  ref.listen<AsyncValue<List<Transaction>>>(transactionsProvider, (_, __) {
    notifier.refreshOverview();
  });
  ref.listen<AsyncValue<User?>>(authStateProvider, (_, __) {
    notifier.refreshOverview();
  });
  ref.listen<AsyncValue<ConnectivityResult>>(connectivityProvider, (_, __) {
    notifier.refreshOverview();
  });

  return notifier;
});

class SyncOverviewNotifier extends StateNotifier<SyncOverview> {
  SyncOverviewNotifier(this._ref)
      : super(const SyncOverview(
          pendingCount: 0,
          hasConnection: true,
          lastAttemptAt: null,
          isSyncing: false,
        )) {
    _recalculate();
  }

  final Ref _ref;

  Future<void> _recalculate() async {
    final List<Farm> farms = _ref.read(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Crop> crops = _ref.read(cropsProvider).valueOrNull ?? <Crop>[];
    final List<Livestock> livestock =
        _ref.read(livestockProvider).valueOrNull ?? <Livestock>[];
    final List<Transaction> transactions =
        _ref.read(transactionsProvider).valueOrNull ?? <Transaction>[];

    final int pendingCount =
        farms.where((Farm item) => !item.isSynced).length +
            crops.where((Crop item) => !item.isSynced).length +
            livestock.where((Livestock item) => !item.isSynced).length +
            transactions.where((Transaction item) => !item.isSynced).length;
    final bool online = await _ref.read(syncServiceProvider).isOnline();
    state = state.copyWith(
      pendingCount: pendingCount,
      hasConnection: online,
    );
  }

  Future<void> runSync() async {
    state = state.copyWith(isSyncing: true, lastAttemptAt: DateTime.now());
    try {
      final SyncService syncService = _ref.read(syncServiceProvider);
      final List<Farm> farms = _ref.read(farmsProvider).valueOrNull ?? <Farm>[];
      final List<Crop> crops = _ref.read(cropsProvider).valueOrNull ?? <Crop>[];
      final List<Livestock> livestock =
          _ref.read(livestockProvider).valueOrNull ?? <Livestock>[];
      final List<Transaction> transactions =
          _ref.read(transactionsProvider).valueOrNull ?? <Transaction>[];

      await syncService.fullSync(
        farms: farms,
        crops: crops,
        livestock: livestock,
        transactions: transactions,
        healthLogs: const <HealthLog>[],
      );

      await Future.wait(<Future<void>>[
        _ref.read(farmsProvider.notifier).refresh(),
        _ref.read(cropsProvider.notifier).refresh(),
        _ref.read(livestockProvider.notifier).refresh(),
        _ref.read(transactionsProvider.notifier).refresh(),
      ]);
    } finally {
      state = state.copyWith(isSyncing: false);
      await _recalculate();
    }
  }

  Future<void> refreshOverview() => _recalculate();
}
