import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/farm_task_calendar_service.dart';
import '../../../core/services/harvest_readiness_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/livestock.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../crops/crop_detail_screen.dart';
import '../livestock/livestock_detail_screen.dart';
import 'widgets/activity_feed.dart';
import 'widgets/weather_pill.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
        .animate(_fade);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLanguage language = ref.watch(appLanguageProvider);
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Crop> crops = ref.watch(cropsProvider).valueOrNull ?? <Crop>[];
    final List<Livestock> livestock =
        ref.watch(livestockProvider).valueOrNull ?? <Livestock>[];
    final List<Transaction> transactions =
        ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final notifications = ref.watch(notificationsProvider);
    final currentUser = ref.watch(firebaseServiceProvider).currentUser;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final SyncOverview sync = ref.watch(syncOverviewProvider);
    final String? activeFarmId = ref.watch(activeFarmProvider);

    Farm? activeFarm;
    for (final Farm farm in farms) {
      if (farm.id == activeFarmId) {
        activeFarm = farm;
        break;
      }
    }
    activeFarm ??= farms.isNotEmpty ? farms.first : null;

    final int animals =
        livestock.fold<int>(0, (int sum, Livestock item) => sum + item.count);
    final double balanceValue = transactions.fold<double>(
      0,
      (double sum, Transaction item) => item.type == TransactionType.income
          ? sum + item.amount
          : sum - item.amount,
    );
    final int unread = notifications.where((item) => !item.isRead).length;
    final String userName = currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!.trim()
        : profile?.fullName.trim().isNotEmpty == true
            ? profile!.fullName.trim()
            : 'Love Bari';
    final String activeFocus =
        activeFarm?.name ?? (crops.isNotEmpty ? crops.first.name : 'Jane');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        title: Text(language.tr(en: 'Home', ha: 'Gida', fr: 'Accueil')),
        actions: <Widget>[
          _HeaderIcon(
              icon: Icons.school_outlined, onTap: () => context.go('/learn')),
          _HeaderIcon(
            icon: Icons.notifications_none_rounded,
            badge: unread,
            onTap: () => context.go('/notifications'),
          ),
          _HeaderIcon(
              icon: Icons.auto_awesome_rounded,
              onTap: () => context.go('/ai-advisor')),
          const SizedBox(width: 10),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainer,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () async {
              _intro.forward(from: 0);
              await Future.wait(<Future<void>>[
                ref.read(farmsProvider.notifier).refresh(),
                ref.read(cropsProvider.notifier).refresh(),
                ref.read(livestockProvider.notifier).refresh(),
                ref.read(transactionsProvider.notifier).refresh(),
                ref.read(syncOverviewProvider.notifier).refreshOverview(),
              ]);
            },
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 112),
                  children: <Widget>[
                    _SyncRow(
                      pendingCount: sync.pendingCount,
                      hasConnection: sync.hasConnection,
                      onSyncTap: sync.hasConnection && !sync.isSyncing
                          ? () =>
                              ref.read(syncOverviewProvider.notifier).runSync()
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _TodayTasksCard(
                      farm: activeFarm,
                      tasks: activeFarm?.workspaceTasks ??
                          const <FarmWorkspaceTask>[],
                      onViewAll: () => context.go('/farm-tasks'),
                    ),
                    const SizedBox(height: 18),
                    _HarvestReadinessCard(
                      items: HarvestReadinessService.all(
                          crops: crops, livestock: livestock),
                    ),
                    const SizedBox(height: 18),
                    _HeroSummaryCard(
                      greeting: _greeting(),
                      userName: userName,
                      activeFocus: activeFocus,
                      pendingSync: sync.pendingCount,
                      onMeasurements: () => context.go('/farms'),
                    ),
                    const SizedBox(height: 18),
                    const WeatherPill(),
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.agriculture_rounded,
                            value: '${farms.length}',
                            title: 'Managed farms',
                            subtitle: 'All locations',
                            onTap: () => context.go('/farms'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.pets_rounded,
                            value: '$animals',
                            title: 'Animals',
                            subtitle: 'All species',
                            onTap: () => context.go('/livestock'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.account_balance_wallet_rounded,
                            value: CurrencyUtils.formatCompactCurrency(
                                balanceValue),
                            title: 'Wallet balance',
                            subtitle: 'Open balance',
                            onTap: () => context.go('/finance'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    _SectionTitle(
                        title: language.tr(
                            en: 'Management center',
                            ha: 'Cibiyar gudanarwa',
                            fr: 'Centre de gestion')),
                    const SizedBox(height: 14),
                    _ManagementGrid(
                      actions: <_ManagementAction>[
                        _ManagementAction(Icons.eco_rounded, 'Crops',
                            '${crops.length} crop records', '/crops'),
                        _ManagementAction(Icons.pets_rounded, 'Livestock',
                            '${livestock.length} groups', '/livestock'),
                        _ManagementAction(Icons.inventory_2_rounded,
                            'Inventory', 'Stock & supplies', '/finance'),
                        _ManagementAction(Icons.account_balance_wallet_rounded,
                            'Finance', 'Sales & expenses', '/finance'),
                        _ManagementAction(Icons.agriculture_rounded, 'Farms',
                            '${farms.length} locations', '/farms'),
                        _ManagementAction(Icons.cloud_queue_rounded, 'Weather',
                            'Live readings', '/farms'),
                      ],
                    ),
                    const SizedBox(height: 26),
                    if (profile?.isComplete != true) ...<Widget>[
                      _SetupCard(onTap: () => context.go('/account-setup')),
                      const SizedBox(height: 22),
                    ],
                    _SectionTitle(
                        title: language.tr(
                            en: 'Recent activity',
                            ha: 'Ayyukan baya-bayan nan',
                            fr: 'Activite recente')),
                    const SizedBox(height: 14),
                    const ActivityFeed(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _TodayTasksCard extends StatelessWidget {
  const _TodayTasksCard(
      {required this.farm, required this.tasks, this.onViewAll});

  final Farm? farm;
  final List<FarmWorkspaceTask> tasks;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final List<FarmWorkspaceTask> upcoming =
        FarmTaskCalendarService.todayAndUpcomingTasks(
      tasks,
      referenceDate: now,
      maxDays: 7,
      maxItems: 4,
    );
    if (upcoming.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.event_available_rounded,
                  color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  farm != null
                      ? 'Today\'s farm tasks • ${farm!.name}'
                      : 'Today\'s farm tasks',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...upcoming.map((FarmWorkspaceTask task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            theme.colorScheme.outlineVariant.withOpacity(0.6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.circle,
                          size: 9, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              task.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700, height: 1.3),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_friendlyDate(task.dueAt)} • ${task.assigneeName.isNotEmpty ? task.assigneeName : 'No assignee'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          if (onViewAll != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onViewAll,
                child: const Text('View all tasks'),
              ),
            ),
        ],
      ),
    );
  }

  String _friendlyDate(DateTime value) {
    final DateTime now = DateTime.now();
    final DateTime day = DateTime(value.year, value.month, value.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return 'In $diff days';
    return '${value.day}/${value.month}/${value.year}';
  }
}

class _HarvestReadinessCard extends StatelessWidget {
  const _HarvestReadinessCard({required this.items});

  final List<HarvestReadinessItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFE3B3), Color(0xFFFFC98B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.agriculture_rounded, color: Color(0xFF7A4A00)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ready for the market',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A4A00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.take(3).map(
                (HarvestReadinessItem item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openItem(context, item),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            item.kind == HarvestReadinessKind.crop
                                ? Icons.eco_rounded
                                : Icons.pets_rounded,
                            size: 20,
                            color: const Color(0xFF7A4A00),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.detail,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF7A4A00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF7A4A00)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _openItem(BuildContext context, HarvestReadinessItem item) {
    if (item.kind == HarvestReadinessKind.crop) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CropDetailScreen(cropId: item.id),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LivestockDetailScreen(livestockId: item.id),
        ),
      );
    }
  }
}

class _SyncRow extends StatelessWidget {
  const _SyncRow({
    required this.pendingCount,
    required this.hasConnection,
    required this.onSyncTap,
  });

  final int pendingCount;
  final bool hasConnection;
  final VoidCallback? onSyncTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String label = !hasConnection
        ? 'Offline'
        : pendingCount == 0
            ? 'Synchronise'
            : '$pendingCount pending';
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onSyncTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: hasConnection
                      ? AppColors.premiumGreen
                      : theme.colorScheme.onSurfaceVariant,
                  shape: BoxShape.circle,
                  boxShadow: hasConnection
                      ? <BoxShadow>[
                          BoxShadow(
                              color: AppColors.premiumGreen.withOpacity(0.55),
                              blurRadius: 12),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: AppColors.premiumGreen)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.premiumGreen, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSummaryCard extends StatefulWidget {
  const _HeroSummaryCard({
    required this.greeting,
    required this.userName,
    required this.activeFocus,
    required this.pendingSync,
    required this.onMeasurements,
  });

  final String greeting;
  final String userName;
  final String activeFocus;
  final int pendingSync;
  final VoidCallback onMeasurements;

  @override
  State<_HeroSummaryCard> createState() => _HeroSummaryCardState();
}

class _HeroSummaryCardState extends State<_HeroSummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _leaf;

  @override
  void initState() {
    super.initState();
    _leaf =
        AnimationController(vsync: this, duration: const Duration(seconds: 7))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _leaf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _PremiumPanel(
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _leaf,
              builder: (_, __) =>
                  CustomPaint(painter: _LeafPatternPainter(_leaf.value)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.greeting,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: AppColors.premiumGreen)),
                        const SizedBox(height: 8),
                        Text(
                          widget.userName,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 36,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            text: 'Active focus: ',
                            children: <InlineSpan>[
                              TextSpan(
                                text: widget.activeFocus,
                                style: const TextStyle(
                                    color: AppColors.premiumGreen,
                                    fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  _ThemeToggleButton(),
                ],
              ),
              const SizedBox(height: 26),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stack = constraints.maxWidth < 520;
                  final List<Widget> chips = <Widget>[
                    Expanded(
                      child: _HeroChip(
                        icon: Icons.check_circle_rounded,
                        title: widget.pendingSync == 0
                            ? 'Everything synced'
                            : '${widget.pendingSync} updates pending',
                        subtitle: widget.pendingSync == 0
                            ? 'All data is up to date'
                            : 'Tap sync when online',
                      ),
                    ),
                    SizedBox(width: stack ? 0 : 14, height: stack ? 12 : 0),
                    Expanded(
                      child: _HeroChip(
                        icon: Icons.monitor_heart_rounded,
                        title: 'Live measurements',
                        subtitle: 'Real-time farm data',
                        onTap: widget.onMeasurements,
                      ),
                    ),
                  ];
                  return stack
                      ? Column(
                          children: chips
                              .map((Widget item) =>
                                  item is Expanded ? item.child : item)
                              .toList())
                      : Row(children: chips);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withOpacity(theme.brightness == Brightness.dark ? 0.82 : 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: AppColors.premiumGreen, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatefulWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: _PremiumPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _GlowIcon(icon: widget.icon, size: 40),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 20),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(widget.value,
                    maxLines: 1,
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.premiumGreen,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              Text(widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementGrid extends StatelessWidget {
  const _ManagementGrid({required this.actions});

  final List<_ManagementAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth > 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columns == 3 ? 2.45 : 2.15,
          ),
          itemBuilder: (BuildContext context, int index) {
            return _ManagementTile(action: actions[index]);
          },
        );
      },
    );
  }
}

class _ManagementAction {
  const _ManagementAction(this.icon, this.title, this.subtitle, this.route);

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

class _ManagementTile extends StatelessWidget {
  const _ManagementTile({required this.action});

  final _ManagementAction action;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(action.route),
      child: _PremiumPanel(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            _GlowIcon(icon: action.icon, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(action.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _PremiumPanel(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const _GlowIcon(icon: Icons.person_add_alt_1_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Finish your account setup to personalize your dashboard.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const <Color>[AppColors.darkCard, AppColors.darkElevatedCard]
              : <Color>[
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.surfaceContainer
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(isDark ? 0.42 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.premiumGreen.withOpacity(isDark ? 0.035 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GlowIcon extends StatelessWidget {
  const _GlowIcon({required this.icon, this.size = 58});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0D6B45),
            Color(0xFF123D33),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.31),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: AppColors.premiumGreen.withOpacity(0.26), blurRadius: 22),
        ],
      ),
      child: Icon(icon,
          color: Theme.of(context).colorScheme.onPrimary, size: size * 0.48),
    );
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ThemeMode mode = ref.watch(themeProvider);
    final bool isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && theme.brightness == Brightness.dark);
    final IconData icon =
        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
    final String label =
        isDark ? 'Switch to light mode' : 'Switch to dark mode';

    return InkWell(
      onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: AppColors.premiumGreen.withOpacity(0.10),
                blurRadius: 22),
          ],
        ),
        child: Tooltip(
          message: label,
          child: Icon(icon, color: theme.colorScheme.onSurface, size: 34),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.premiumGreen,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
        ),
        if (badge > 0)
          Positioned(
            right: 6,
            top: 5,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                  color: AppColors.premiumGreen, shape: BoxShape.circle),
              child: Text(
                badge > 9 ? '9+' : '$badge',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}

class _LeafPatternPainter extends CustomPainter {
  const _LeafPatternPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.premiumGreen.withOpacity(0.22),
          AppColors.premiumGreen.withOpacity(0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.82, size.height * 0.10),
          radius: size.width * 0.55));
    canvas.drawRect(Offset.zero & size, glow);

    final Paint leafPaint = Paint()
      ..color = AppColors.premiumGreen.withOpacity(0.075)
      ..style = PaintingStyle.fill;
    final Offset stem = Offset(size.width * 0.74,
        size.height * (0.70 + math.sin(progress * math.pi) * 0.02));
    for (int i = 0; i < 5; i++) {
      final double angle = -1.25 + i * 0.36;
      final double length = size.width * (0.11 + i * 0.015);
      final Offset end = Offset(stem.dx + math.cos(angle) * length,
          stem.dy + math.sin(angle) * length);
      final Path leaf = Path()
        ..moveTo(stem.dx, stem.dy)
        ..quadraticBezierTo((stem.dx + end.dx) / 2, end.dy - 34, end.dx, end.dy)
        ..quadraticBezierTo(
            (stem.dx + end.dx) / 2, end.dy + 28, stem.dx, stem.dy);
      canvas.drawPath(leaf, leafPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LeafPatternPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
