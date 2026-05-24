import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../common/widgets/farm_scene_artwork.dart';
import 'widgets/activity_feed.dart';
import 'widgets/quick_actions_grid.dart';
import 'widgets/weather_pill.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Farm>> farmsAsync = ref.watch(farmsProvider);
    final AsyncValue<List<Crop>> cropsAsync = ref.watch(cropsProvider);
    final AsyncValue<List<Livestock>> livestockAsync = ref.watch(livestockProvider);
    final AsyncValue<List<Transaction>> transactionsAsync = ref.watch(transactionsProvider);
    final notifications = ref.watch(notificationsProvider);
    final currentUser = ref.watch(firebaseServiceProvider).currentUser;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final AppLanguage language = ref.watch(appLanguageProvider);
    final ThemeMode themeMode = ref.watch(themeProvider);
    final SyncOverview syncOverview = ref.watch(syncOverviewProvider);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color primaryTextColor = isDark ? Colors.white : AppColors.primary;

    final List<Farm> farms = farmsAsync.maybeWhen(
      data: (List<Farm> items) => items,
      orElse: () => <Farm>[],
    );
    final String farmsCount = farms.length.toString();
    final String cropsCount =
        cropsAsync.maybeWhen(data: (List<Crop> items) => items.length.toString(), orElse: () => '0');
    final int animalTotal = livestockAsync.maybeWhen(
      data: (List<Livestock> items) => items.fold<int>(0, (int sum, Livestock item) => sum + item.count),
      orElse: () => 0,
    );
    final String livestockCount = livestockAsync.maybeWhen(
      data: (List<Livestock> items) => items.length.toString(),
      orElse: () => '0',
    );
    final List<Transaction> transactions = transactionsAsync.maybeWhen(
      data: (List<Transaction> items) => items,
      orElse: () => <Transaction>[],
    );
    final String balance = CurrencyUtils.formatCompactCurrency(_calculateBalance(transactions));
    final int pendingSync = syncOverview.pendingCount;
    final String activeFarmName = farms.isEmpty
        ? language.tr(en: 'No farms yet', ha: 'Babu gona tukuna', fr: 'Aucune ferme pour le moment')
        : farms.first.name;
    final int unreadNotifications = notifications.where((notification) => !notification.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(language.tr(en: 'Home', ha: 'Gida', fr: 'Accueil')),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.school_outlined),
            onPressed: () => context.go('/learn'),
          ),
          Stack(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => context.go('/notifications'),
              ),
              if (unreadNotifications > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.amberAccent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => context.go('/ai-advisor'),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? <Color>[
                    const Color(0xFF0B1610),
                    const Color(0xFF132319),
                    theme.colorScheme.surface,
                  ]
                : const <Color>[
                    Color(0xFFFFFBF2),
                    Color(0xFFF3F8EF),
                    Color(0xFFE7F7DE),
                  ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: RefreshIndicator(
                onRefresh: () async {
                  _controller.forward(from: 0);
                  await Future.wait(<Future<void>>[
                    ref.read(farmsProvider.notifier).refresh(),
                    ref.read(cropsProvider.notifier).refresh(),
                    ref.read(livestockProvider.notifier).refresh(),
                    ref.read(transactionsProvider.notifier).refresh(),
                    ref.read(syncOverviewProvider.notifier).refreshOverview(),
                  ]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _AnimatedHeroCard(
                        greeting: _getGreeting(),
                        userName: currentUser?.displayName?.trim().isNotEmpty == true
                            ? currentUser!.displayName!
                            : 'Farmer',
                        activeFarmName: activeFarmName,
                        pendingSync: pendingSync,
                        themeMode: themeMode,
                        onThemeToggle: () => ref.read(themeProvider.notifier).toggleTheme(),
                        language: language,
                      ),
                      const SizedBox(height: 18),
                      const WeatherPill(),
                      const SizedBox(height: 22),
                      if (profile?.isComplete != true) ...<Widget>[
                        _SetupCallout(
                          userName: currentUser?.displayName?.trim().isNotEmpty == true
                              ? currentUser!.displayName!
                              : 'Farmer',
                        ),
                        const SizedBox(height: 22),
                      ],
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _AnimatedStatCard(
                              label: 'Managed farms',
                              value: farmsCount,
                              icon: Icons.agriculture_rounded,
                              tint: const Color(0xFFE8F4D8),
                              delay: 0,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AnimatedStatCard(
                              label: language.tr(en: 'Animal count', ha: 'Yawan dabbobi', fr: 'Nombre d animaux'),
                              value: '$animalTotal',
                              icon: Icons.pets_rounded,
                              tint: const Color(0xFFDFF1E5),
                              delay: 60,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AnimatedStatCard(
                              label: 'Open balance',
                              value: balance,
                              icon: Icons.account_balance_wallet_rounded,
                              tint: const Color(0xFFFFEECC),
                              delay: 120,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        language.tr(en: 'Farm launchpad', ha: 'Wurin fara aiki', fr: 'Centre de gestion'),
                        style: theme.textTheme.titleLarge?.copyWith(color: primaryTextColor),
                      ),
                      const SizedBox(height: 14),
                      const QuickActionsGrid(),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            const FarmSceneArtwork(
                              height: 230,
                              variant: FarmArtworkVariant.crops,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(32),
                                topRight: Radius.circular(32),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      activeFarmName,
                                      key: ValueKey<String>(activeFarmName),
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontSize: 30,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    farms.isEmpty
                                        ? 'Create your first farm, then start linking crops, livestock, finance, and AI support to one workspace.'
                                        : 'Your current operations snapshot updates live from farm, crop, livestock, and finance providers.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.6,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: _MiniStatCard(
                                          label: 'Farms',
                                          value: farmsCount,
                                          tint: const Color(0xFFE8F4D8),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MiniStatCard(
                                          label: 'Livestock',
                                          value: '$animalTotal',
                                          tint: const Color(0xFFDFF1FF),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MiniStatCard(
                                          label: 'Sync',
                                          value: pendingSync == 0 ? 'Ready' : '$pendingSync',
                                          tint: const Color(0xFFFFEBD0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: _OverviewMetric(title: 'Livestock', value: livestockCount)),
                            Container(width: 1, height: 44, color: theme.colorScheme.outlineVariant),
                            Expanded(child: _OverviewMetric(title: 'Alerts', value: '$unreadNotifications')),
                            Container(width: 1, height: 44, color: theme.colorScheme.outlineVariant),
                            Expanded(
                              child: _OverviewMetric(
                                title: 'Status',
                                value: syncOverview.isSyncing
                                    ? 'Syncing'
                                    : pendingSync == 0
                                        ? 'Synced'
                                        : 'Pending',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (syncOverview.pendingCount > 0 || !syncOverview.hasConnection)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  syncOverview.hasConnection
                                      ? '$pendingSync updates are waiting to sync.'
                                      : 'You are offline. Changes will sync when connection returns.',
                                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.tonalIcon(
                                onPressed: syncOverview.isSyncing || !syncOverview.hasConnection
                                    ? null
                                    : () async {
                                        await ref.read(syncOverviewProvider.notifier).runSync();
                                      },
                                icon: const Icon(Icons.sync_rounded),
                                label: Text(syncOverview.isSyncing ? 'Syncing...' : 'Start sync'),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        language.tr(en: 'Recent activity', ha: 'Ayyukan baya-bayan nan', fr: 'Activite recente'),
                        style: theme.textTheme.titleLarge?.copyWith(color: primaryTextColor),
                      ),
                      const SizedBox(height: 14),
                      const ActivityFeed(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 17) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  double _calculateBalance(List<Transaction> transactions) {
    double total = 0;
    for (final Transaction transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        total += transaction.amount;
      } else {
        total -= transaction.amount;
      }
    }
    return total;
  }
}

class _SetupCallout extends StatelessWidget {
  const _SetupCallout({
    required this.userName,
  });

  final String userName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => context.go('/account-setup'),
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBD0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Finish setting up your workspace',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add ward, production focus, and contact details so $userName sees a more personalized dashboard.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedHeroCard extends StatefulWidget {
  const _AnimatedHeroCard({
    required this.greeting,
    required this.userName,
    required this.activeFarmName,
    required this.pendingSync,
    required this.themeMode,
    required this.onThemeToggle,
    required this.language,
  });

  final String greeting;
  final String userName;
  final String activeFarmName;
  final int pendingSync;
  final ThemeMode themeMode;
  final VoidCallback onThemeToggle;
  final AppLanguage language;

  @override
  State<_AnimatedHeroCard> createState() => _AnimatedHeroCardState();
}

class _AnimatedHeroCardState extends State<_AnimatedHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1F4D35),
            Color(0xFF3D8A51),
            Color(0xFF7BCB7A),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withOpacity(0.20),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: _HeroPainter(progress: _controller.value),
                );
              },
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.greeting,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white.withOpacity(0.84),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.userName,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 34,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: widget.onThemeToggle,
                      icon: Icon(
                        widget.themeMode == ThemeMode.dark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: Colors.white,
                      ),
                      tooltip: widget.language.tr(
                        en: 'Toggle theme',
                        ha: 'Canja jigo',
                        fr: 'Changer le theme',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Active focus: ${widget.activeFarmName.isEmpty ? 'Farm setup' : widget.activeFarmName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _HeroPill(
                      icon: Icons.sync_rounded,
                      label: widget.pendingSync == 0 ? 'Everything synced' : '${widget.pendingSync} updates pending',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroPill(
                      icon: Icons.auto_graph_rounded,
                      label: widget.language.tr(
                        en: 'Live dashboard metrics',
                        ha: 'Kididdiga kai tsaye',
                        fr: 'Mesures en direct',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStatCard extends StatelessWidget {
  const _AnimatedStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.delay,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double progress, Widget? child) {
        return Transform.translate(
          offset: Offset(0, 18 * (1 - progress)),
          child: Opacity(
            opacity: progress,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: Text(
                      value,
                      key: ValueKey<String>(value),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            color: AppColors.primary,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: tint.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.84 : 1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              value,
              key: ValueKey<String>(value),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary.withOpacity(0.70),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey<String>('${title}_$value'),
        children: <Widget>[
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  const _HeroPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final double radius = size.width * 0.35;
    final Offset center = Offset(size.width * 0.82, size.height * 0.12);
    canvas.drawCircle(center, radius + progress * 16, paint);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.88), 36 + progress * 10, paint);

    final Path wave = Path();
    for (double x = 0; x <= size.width; x++) {
      final double y = size.height * 0.72 + math.sin((x / size.width * 2 * math.pi) + progress * 2 * math.pi) * 8;
      if (x == 0) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    canvas.drawPath(wave, paint);
  }

  @override
  bool shouldRepaint(covariant _HeroPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
