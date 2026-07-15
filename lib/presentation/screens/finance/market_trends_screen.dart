import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/services/market_data_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';
import 'product_detail_screen.dart';

class MarketTrendsScreen extends ConsumerStatefulWidget {
  const MarketTrendsScreen({super.key});

  @override
  ConsumerState<MarketTrendsScreen> createState() => _MarketTrendsScreenState();
}

class _MarketTrendsScreenState extends ConsumerState<MarketTrendsScreen> {
  late final TextEditingController _searchController;
  String _searchText = '';
  bool _showLocalOnly = false;
  String _deviceLocationLabel = '';
  bool _isResolvingLocation = false;
  bool _isLoadingLiveMarketData = false;
  String _lastRequestedLocation = '';
  List<MarketPricePoint> _liveMarketPrices = const <MarketPricePoint>[];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLiveMarketData();
      }
    });
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _searchText = _searchController.text.trim().toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Transaction> transactions = ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final OperationsHubState operations = ref.watch(operationsHubProvider);
    final AppLanguage language = ref.watch(appLanguageProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final String? activeFarmId = ref.watch(activeFarmProvider);
    Farm? activeFarm;
    for (final Farm farm in farms) {
      if (farm.id == activeFarmId) {
        activeFarm = farm;
        break;
      }
    }
    activeFarm ??= farms.isNotEmpty ? farms.first : null;

    final List<_MarketTrendGroup> trends = _buildTrends(
      farms: farms,
      inventory: operations.inventory,
      transactions: transactions,
    )
      ..sort((a, b) => b.activityScore.compareTo(a.activityScore));

    final String locationFocus = _deviceLocationLabel.isNotEmpty
        ? _deviceLocationLabel
        : activeFarm?.ward.isNotEmpty == true
            ? '${activeFarm!.ward} ward'
            : profile?.ward.trim().isNotEmpty == true
                ? profile!.ward
                : language.tr(en: 'No location set', ha: 'Babu wurin da aka saita', fr: 'Aucun emplacement');

    final List<_MarketTrendGroup> visible = trends.where((group) {
      final bool matchesSearch = _searchText.isEmpty ||
          group.productName.toLowerCase().contains(_searchText) ||
          group.category.toLowerCase().contains(_searchText) ||
          group.locationLabel.toLowerCase().contains(_searchText);
      final bool matchesLocal = !_showLocalOnly || group.isLocalTo(locationFocus);
      return matchesSearch && matchesLocal;
    }).toList(growable: false);

    if (locationFocus.isNotEmpty && locationFocus != _lastRequestedLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadLiveMarketData(location: locationFocus, products: visible.take(4).map((group) => group.productName).toList(growable: false));
        }
      });
    }

    final String aiInsight = GeminiService.instance.buildLocalMarketTrendInsight(
      location: locationFocus,
      trendData: visible
          .take(4)
          .map((group) => <String, dynamic>{
                'productName': group.productName,
                'currentPrice': group.latestPrice,
                'previousAverage': group.previousAverage,
                'proposedFuturePrice': group.proposedFuturePrice,
                'unit': group.unit,
                'trendPercent': group.trendPercent,
                'direction': group.isRising ? 'rising' : 'falling',
              })
          .toList(growable: false),
      nearbyMarketData: _liveMarketPrices
          .take(3)
          .map((point) => <String, dynamic>{
                'productName': point.productName,
                'price': point.price,
                'unit': point.unit,
                'marketName': point.marketName,
              })
          .toList(growable: false),
    );

    return SoftScreenScaffold(
      onBack: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/finance'),
      heroTitle: language.tr(
        en: 'Market trends',
        ha: 'Yanayin kasuwa',
        fr: 'Tendances du marche',
      ),
      heroSubtitle: language.tr(
        en: 'Search product prices from your own sales, procurement, and inventory history. Proposed future prices are estimates only.',
        ha: 'Bincika farashin kayayyaki daga tarihin siyarwa, saye, da kaya. Farashin nan gaba hasashe ne kawai.',
        fr: 'Recherchez les prix a partir de votre historique de ventes, achats et stocks. Les prix futurs proposes restent des estimations.',
      ),
      heroIcon: Icons.insights_rounded,
      heroVariant: FarmArtworkVariant.dashboard,
      heroBadge: language.tr(
        en: '${visible.length} live products',
        ha: '${visible.length} kayayyaki kai tsaye',
        fr: '${visible.length} produits suivis',
      ),
      showArtwork: false,
      sections: <Widget>[
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppTextField(
                  controller: _searchController,
                  label: 'Search products',
                  hint: 'Maize, eggs, feed...',
                  prefix: const Icon(Icons.search_rounded),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilterChip(
                      selected: _showLocalOnly,
                      label: Text('Local focus: $locationFocus'),
                      onSelected: (bool value) => setState(() => _showLocalOnly = value),
                    ),
                    FilterChip(
                      selected: false,
                      label: const Text('Based on your app history'),
                      onSelected: (_) {},
                    ),
                    ActionChip(
                      avatar: _isResolvingLocation
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(
                        _deviceLocationLabel.isEmpty ? 'Use my location' : _deviceLocationLabel,
                      ),
                      onPressed: _isResolvingLocation ? null : _resolveLocation,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: _TrendSummaryCard(
                label: 'Tracked products',
                value: visible.length.toString(),
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFFE8F4D8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TrendSummaryCard(
                label: 'Last update',
                value: trends.isEmpty ? 'No data' : _dateLabel(trends.first.lastUpdated),
                icon: Icons.update_rounded,
                color: const Color(0xFFDFF1FF),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _TrendSummaryCard(
                label: 'Future price note',
                value: 'Estimate only',
                icon: Icons.info_outline_rounded,
                color: Color(0xFFFFEBD0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.auto_awesome_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('AI market outlook', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 10),
                Text(aiInsight, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                if (_isLoadingLiveMarketData) ...<Widget>[
                  const SizedBox(height: 8),
                  const Text('Refreshing nearby market feed...'),
                ],
                if (_liveMarketPrices.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('Nearby market snapshot', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  ..._liveMarketPrices.take(3).map((MarketPricePoint point) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '• ${point.productName} @ ${point.marketName}: ${CurrencyUtils.formatCurrency(point.price)}/${point.unit}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (visible.isEmpty)
          const _EmptyTrendState()
        else
          ...visible.map(
            (_MarketTrendGroup group) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TrendCard(
                group: group,
                onTap: group.productId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProductDetailScreen(productId: group.productId!),
                          ),
                        ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Disclaimer: proposed future prices are calculated from your recorded prices and recent movement only. They are not guaranteed market prices. If you want GPS-based nearby market data or an external price API, we can add a permission-backed location feed or API connector next.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadLiveMarketData({String? location, List<String>? products}) async {
    final String currentLocation = (location ?? _deviceLocationLabel).trim();
    final List<String> selectedProducts = (products ?? <String>[]).where((String item) => item.trim().isNotEmpty).toList(growable: false);
    if (currentLocation.isEmpty || selectedProducts.isEmpty) {
      return;
    }

    if (_lastRequestedLocation == currentLocation && _liveMarketPrices.isNotEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingLiveMarketData = true;
      _lastRequestedLocation = currentLocation;
    });

    try {
      final MarketDataService service = MarketDataService(
        baseUrl: const String.fromEnvironment('MARKET_API_BASE_URL', defaultValue: ''),
        apiKey: const String.fromEnvironment('MARKET_API_KEY', defaultValue: ''),
      );
      final List<MarketPricePoint> prices = await service.fetchNearbyMarketPrices(
        location: currentLocation,
        products: selectedProducts,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _liveMarketPrices = prices;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _liveMarketPrices = const <MarketPricePoint>[];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLiveMarketData = false;
        });
      }
    }
  }

  Future<void> _resolveLocation() async {
    setState(() => _isResolvingLocation = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turn on location services to use nearby market filtering.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is needed for nearby market filtering.')),
          );
        }
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      final Placemark? placemark = placemarks.isNotEmpty ? placemarks.first : null;
      final String label = [
        placemark?.locality,
        placemark?.subAdministrativeArea,
        placemark?.administrativeArea,
      ].whereType<String>().firstWhere((String value) => value.trim().isNotEmpty, orElse: () => '');
      if (!mounted) {
        return;
      }
      setState(() {
        _deviceLocationLabel = label.isNotEmpty ? label : 'Current location';
        _showLocalOnly = true;
      });
      await _loadLiveMarketData(location: _deviceLocationLabel, products: <String>['maize', 'eggs', 'feed']);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
  }

  List<_MarketTrendGroup> _buildTrends({
    required List<Farm> farms,
    required List<InventoryItem> inventory,
    required List<Transaction> transactions,
  }) {
    final Map<String, _MarketTrendGroup> groups = <String, _MarketTrendGroup>{};
    final Map<String, String> farmWardById = <String, String>{
      for (final Farm farm in farms) farm.id: farm.ward,
    };

    void addPoint({
      required String productName,
      required String unit,
      required double price,
      required DateTime at,
      required String source,
      required String farmId,
      required String emoji,
      required String category,
      required String productId,
    }) {
      final String key = '${productName.trim().toLowerCase()}__$unit';
      final _MarketTrendGroup next = groups[key] ??
          _MarketTrendGroup(
            productName: productName,
            unit: unit,
            category: category,
            emoji: emoji,
            productId: productId,
            locationLabel: farmWardById[farmId]?.trim().isNotEmpty == true ? '${farmWardById[farmId]} ward' : 'App history',
          );
      groups[key] = next.addPoint(_PricePoint(price: price, at: at, source: source));
    }

    for (final InventoryItem item in inventory) {
      addPoint(
        productName: item.name,
        unit: item.unit,
        price: item.unitPrice > 0 ? item.unitPrice : item.costPrice,
        at: item.updatedAt,
        source: 'Inventory',
        farmId: item.farmId,
        emoji: item.emoji,
        category: item.category,
        productId: item.id,
      );
    }

    for (final Transaction transaction in transactions) {
      if (transaction.productName.trim().isEmpty || transaction.quantity <= 0) {
        continue;
      }
      final double unitPrice = transaction.unitPrice > 0
          ? transaction.unitPrice
          : transaction.quantity > 0
              ? transaction.amount / transaction.quantity
              : transaction.amount;
      addPoint(
        productName: transaction.productName,
        unit: transaction.unit,
        price: unitPrice,
        at: transaction.updatedAt,
        source: transaction.recordKind == TransactionRecordKind.procurement ? 'Procurement' : 'Sale',
        farmId: transaction.farmId,
        emoji: _emojiForName(transaction.productName),
        category: transaction.recordKind == TransactionRecordKind.procurement ? 'Input' : 'Produce',
        productId: transaction.linkedEntityId,
      );
    }

    return groups.values.toList(growable: false);
  }

  String _dateLabel(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return 'Just now';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _emojiForName(String name) {
    final String lower = name.toLowerCase();
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('feed')) return '🌽';
    if (lower.contains('fertil')) return '🧪';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('pepper')) return '🌶️';
    if (lower.contains('maize') || lower.contains('corn')) return '🌽';
    return '🌾';
  }
}

class _MarketTrendGroup {
  const _MarketTrendGroup({
    required this.productName,
    required this.unit,
    required this.category,
    required this.emoji,
    required this.locationLabel,
    this.productId,
    this.points = const <_PricePoint>[],
  });

  final String productName;
  final String unit;
  final String category;
  final String emoji;
  final String locationLabel;
  final String? productId;
  final List<_PricePoint> points;

  _MarketTrendGroup addPoint(_PricePoint point) {
    final List<_PricePoint> next = <_PricePoint>[point, ...points]
      ..sort((a, b) => b.at.compareTo(a.at));
    return _MarketTrendGroup(
      productName: productName,
      unit: unit,
      category: category,
      emoji: emoji,
      locationLabel: locationLabel,
      productId: productId,
      points: next,
    );
  }

  String get currentPriceLabel => CurrencyUtils.formatCurrency(latestPrice);
  double get latestPrice => points.isEmpty ? 0 : points.first.price;
  double get previousAverage => points.length <= 1
      ? latestPrice
      : points.skip(1).map((_PricePoint p) => p.price).reduce((double a, double b) => a + b) / (points.length - 1);
  double get trendDelta => latestPrice - previousAverage;
  double get trendPercent => previousAverage <= 0 ? 0 : (trendDelta / previousAverage) * 100;
  double get proposedFuturePrice {
    final double base = latestPrice + (trendDelta * 0.4);
    return base <= 0 ? latestPrice : base;
  }
  bool get isRising => trendDelta >= 0;
  DateTime get lastUpdated => points.isEmpty ? DateTime.now() : points.first.at;
  int get activityScore => points.length * 100 + lastUpdated.millisecondsSinceEpoch.remainder(100);

  bool isLocalTo(String location) {
    return locationLabel.toLowerCase().contains(location.toLowerCase()) || location == 'App history';
  }
}

class _PricePoint {
  const _PricePoint({
    required this.price,
    required this.at,
    required this.source,
  });

  final double price;
  final DateTime at;
  final String source;
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.group,
    this.onTap,
  });

  final _MarketTrendGroup group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = group.isRising ? const Color(0xFFE5F5D8) : const Color(0xFFFFE7D7);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(group.emoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(group.productName, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('${group.category} · ${group.locationLabel}'),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(group.currentPriceLabel, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      group.isRising ? '+${group.trendPercent.toStringAsFixed(1)}%' : '${group.trendPercent.toStringAsFixed(1)}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: group.isRising ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _TrendChip(label: 'Latest', value: group.currentPriceLabel),
                _TrendChip(label: 'Previous avg', value: CurrencyUtils.formatCurrency(group.previousAverage)),
                _TrendChip(label: 'Future estimate', value: CurrencyUtils.formatCurrency(group.proposedFuturePrice)),
                _TrendChip(label: 'Unit', value: group.unit),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (group.points.length / 6).clamp(0, 1).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 12),
            Text(
              'Price source: ${group.points.map((_PricePoint e) => e.source).toSet().join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.points.take(3).map((_PricePoint point) {
                return _TrendChip(
                  label: _shortDate(point.at),
                  value: CurrencyUtils.formatCurrency(point.price),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _TrendSummaryCard extends StatelessWidget {
  const _TrendSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrendState extends StatelessWidget {
  const _EmptyTrendState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No priced products were found yet. Add inventory items or record sales/procurement entries with product names so the trend view can start learning from your own history.',
        ),
      ),
    );
  }
}

String _shortDate(DateTime date) {
  return '${date.day}/${date.month}';
}
