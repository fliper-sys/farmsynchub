import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../domain/models/farm.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../../providers/stock_ledger_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/detail_ui.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/finance_ui.dart';
import '../../common/widgets/soft_screen_scaffold.dart';
import 'stock_i18n.dart';

enum _StockAction { use, restock, count, loss }

String _tr(BuildContext c, String en, String ha, String fr, String pcm) =>
    stockTr(c, en, ha, fr, pcm);

class _ActionResult {
  const _ActionResult({required this.quantity, this.unitCost, this.note = ''});

  final double quantity;
  final double? unitCost;
  final String note;
}

/// Everything the farm holds - seed, feed, chemicals, harvested produce and
/// animals for sale - with how much is left, what it is worth, how fast it
/// is going, and a full history of every change.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  static const String routeName = '/inventory';

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _search = TextEditingController();
  InventoryGroup? _group;
  bool _onlyAttention = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _farmName(List<Farm> farms, String id) {
    for (final Farm f in farms) {
      if (f.id == id) return f.name;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final OperationsHubState ops = ref.watch(operationsHubProvider);
    final List<StockMovement> ledger = ref.watch(stockLedgerProvider);
    final List<InventoryItem> all = ops.inventory;

    final double stockValue =
        all.fold<double>(0, (double s, InventoryItem i) => s + i.costValue);
    final int attention =
        all.where((InventoryItem i) => stockLevelOf(i) != StockLevel.ok).length;
    final int expiring = all
        .where((InventoryItem i) =>
            i.isExpiringWithin(const Duration(days: 14)))
        .length;

    final String q = _search.text.trim().toLowerCase();
    final List<InventoryItem> shown = all.where((InventoryItem i) {
      if (_group != null && i.group != _group) return false;
      if (_onlyAttention && stockLevelOf(i) == StockLevel.ok) return false;
      if (q.isEmpty) return true;
      return '${i.name} ${i.category} ${i.unit}'.toLowerCase().contains(q);
    }).toList()
      ..sort((InventoryItem a, InventoryItem b) {
        final int la = stockLevelOf(a).index;
        final int lb = stockLevelOf(b).index;
        if (la != lb) return la.compareTo(lb); // out, low, ok
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: farms.isEmpty ? null : () => _addItem(farms),
        icon: const Icon(Icons.add_rounded),
        label: const Text(_tr(context, 'New item', 'Sabon kaya', 'Nouvel article', 'New item')),
      ),
      body: SoftScreenScaffold(
        heroTitle: _tr(context, 'Stock', 'Kaya', 'Stock', 'Stock'),
        heroSubtitle: '',
        heroIcon: Icons.inventory_2_rounded,
        heroVariant: FarmArtworkVariant.dashboard,
        showHero: false,
        showArtwork: false,
        sections: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).canPop()
                    ? Navigator.of(context).pop()
                    : context.go('/finance'),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_tr(context, 'Stock', 'Kaya', 'Stock', 'Stock'),
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    Text(
                      _tr(context, 'Everything you hold, how much is left, and where it went.', 'Duk abin da kake da shi, nawa ya rage, da inda ya tafi.', 'Tout ce que vous détenez, ce qu\'il reste et où cela est allé.', 'Everything wey you get, how much remain, and where e go.'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const FinanceNavBar(current: FinanceSection.stock),
          const SizedBox(height: 14),
          MetricStrip(
            stats: <MetricStat>[
              MetricStat(
                icon: Icons.account_balance_wallet_rounded,
                label: _tr(context, 'Stock value', 'Darajar kaya', 'Valeur du stock', 'Value of stock'),
                value: CurrencyUtils.formatCompactCurrency(stockValue),
              ),
              MetricStat(
                icon: Icons.inventory_2_rounded,
                label: _tr(context, 'Items', 'Kayayyaki', 'Articles', 'Items'),
                value: '${all.length}',
                color: const Color(0xFF8B5CF6),
              ),
              MetricStat(
                icon: Icons.warning_amber_rounded,
                label: _tr(context, 'Low / out', 'Kadan / an gama', 'Faible / épuisé', 'Low / don finish'),
                value: '$attention',
                color: attention > 0
                    ? const Color(0xFFD99A1E)
                    : const Color(0xFF2E9E5B),
              ),
              MetricStat(
                icon: Icons.hourglass_bottom_rounded,
                label: _tr(context, 'Expiring 14d', 'Zai kare cikin kwana 14', 'Expire sous 14 j', 'Go expire inside 14d'),
                value: '$expiring',
                color: expiring > 0
                    ? const Color(0xFFE0524A)
                    : const Color(0xFF2E9E5B),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _tr(context, 'Search stock', 'Nemi kaya', 'Rechercher dans le stock', 'Search stock'),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                _chip(_tr(context, 'All', 'Duka', 'Tout', 'All'), _group == null && !_onlyAttention, () {
                  setState(() {
                    _group = null;
                    _onlyAttention = false;
                  });
                }),
                for (final InventoryGroup g in InventoryGroup.values)
                  _chip(localGroupLabel(context, g), _group == g,
                      () => setState(() => _group = _group == g ? null : g)),
                _chip(_tr(context, 'Needs attention', 'Yana bukatar kulawa', 'À surveiller', 'Need attention'), _onlyAttention,
                    () => setState(() => _onlyAttention = !_onlyAttention)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            AppCard(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: <Widget>[
                    const Text('📦', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(
                      all.isEmpty
                          ? _tr(context, 'No stock yet. Add seed, feed or chemicals with "New item" - harvests and eggs add themselves.', 'Babu kaya tukuna. Kara iri, abinci ko magani da "Sabon kaya" - girbi da kwai suna shiga da kansu.', 'Pas encore de stock. Ajoutez semences, aliments ou produits avec "Nouvel article" - les récoltes et les œufs s\'ajoutent seuls.', 'No stock yet. Add seed, feed or chemical with "New item" - harvest and egg go add by themselves.')
                          : _tr(context, 'Nothing matches those filters.', 'Babu abin da ya dace da wadannan tacewa.', 'Rien ne correspond à ces filtres.', 'Nothing match those filters.'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            for (int i = 0; i < shown.length; i++)
              FadeInUp(
                index: i > 5 ? 5 : i,
                child: _ItemCard(
                  item: shown[i],
                  farmName: farms.length > 1 ? _farmName(farms, shown[i].farmId) : '',
                  ledger: ledger,
                  onAction: (_StockAction a) => _runAction(shown[i], a),
                  onHistory: () => _showHistory(shown[i], ledger),
                ),
              ),
          const SizedBox(height: 18),
          Text(_tr(context, 'Recent movements', 'Motsin kaya na kwanan nan', 'Mouvements récents', 'Recent movements'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (ledger.isEmpty)
            Text(
              _tr(context, 'Changes to your stock will be listed here.', 'Canje-canje a kayanka za su bayyana a nan.', 'Les changements de votre stock apparaîtront ici.', 'Changes for your stock go show here.'),
              style: theme.textTheme.bodySmall,
            )
          else
            for (final StockMovement m in ledger.take(12))
              _MovementTile(movement: m),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );

  Future<void> _runAction(InventoryItem item, _StockAction action) async {
    final _ActionResult? result = await showModalBottomSheet<_ActionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(item: item, action: action),
    );
    if (result == null || !mounted) return;
    final OperationsHubNotifier hub = ref.read(operationsHubProvider.notifier);
    bool ok = false;
    String message = '';
    switch (action) {
      case _StockAction.use:
        ok = await hub.recordUsage(
          itemId: item.id,
          quantity: result.quantity,
          note: result.note.isEmpty ? _tr(context, 'Used', 'An yi amfani', 'Utilisé', 'Used') : result.note,
        );
        message = ok
            ? _tr(context, 'Recorded ${formatQty(result.quantity)} ${item.unit} used.', 'An rubuta ${formatQty(result.quantity)} ${item.unit} da aka yi amfani.', '${formatQty(result.quantity)} ${item.unit} utilisé enregistré.', 'We don record ${formatQty(result.quantity)} ${item.unit} wey you use.')
            : _tr(context, 'You only have ${formatQty(item.availableQuantity)} ${item.unit} left.', 'Ka rage da ${formatQty(item.availableQuantity)} ${item.unit} kawai.', 'Il ne vous reste que ${formatQty(item.availableQuantity)} ${item.unit}.', 'Na only ${formatQty(item.availableQuantity)} ${item.unit} remain for you.');
        break;
      case _StockAction.loss:
        ok = await hub.recordUsage(
          itemId: item.id,
          quantity: result.quantity,
          note: result.note.isEmpty ? _tr(context, 'Lost / spoiled', 'Bata / lalace', 'Perdu / gâté', 'Lost / spoil') : result.note,
          type: StockMovementType.loss,
        );
        message = ok
            ? _tr(context, 'Recorded ${formatQty(result.quantity)} ${item.unit} lost.', 'An rubuta asarar ${formatQty(result.quantity)} ${item.unit}.', 'Perte de ${formatQty(result.quantity)} ${item.unit} enregistrée.', 'We don record ${formatQty(result.quantity)} ${item.unit} wey lost.')
            : _tr(context, 'You only have ${formatQty(item.availableQuantity)} ${item.unit} left.', 'Ka rage da ${formatQty(item.availableQuantity)} ${item.unit} kawai.', 'Il ne vous reste que ${formatQty(item.availableQuantity)} ${item.unit}.', 'Na only ${formatQty(item.availableQuantity)} ${item.unit} remain for you.');
        break;
      case _StockAction.restock:
        ok = await hub.restock(
          itemId: item.id,
          quantity: result.quantity,
          unitCost: result.unitCost,
          note: result.note.isEmpty ? _tr(context, 'Restocked', 'An sake cikawa', 'Réapprovisionné', 'Restocked') : result.note,
        );
        message = ok
            ? _tr(context, 'Added ${formatQty(result.quantity)} ${item.unit}.', 'An kara ${formatQty(result.quantity)} ${item.unit}.', '${formatQty(result.quantity)} ${item.unit} ajouté.', 'We don add ${formatQty(result.quantity)} ${item.unit}.')
            : _tr(context, 'Could not add stock.', 'Ba a iya kara kaya ba.', 'Impossible d\'ajouter au stock.', 'We no fit add stock.');
        break;
      case _StockAction.count:
        ok = await hub.setCount(
          itemId: item.id,
          counted: result.quantity,
          note: result.note,
        );
        message = ok
            ? _tr(context, 'Stock-take saved: ${formatQty(result.quantity)} ${item.unit}.', 'An adana kidayar kaya: ${formatQty(result.quantity)} ${item.unit}.', 'Inventaire enregistré : ${formatQty(result.quantity)} ${item.unit}.', 'Stock count don save: ${formatQty(result.quantity)} ${item.unit}.')
            : _tr(context, 'Could not save the count.', 'Ba a iya adana kidayar ba.', 'Impossible d\'enregistrer le comptage.', 'We no fit save the count.');
        break;
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addItem(List<Farm> farms) async {
    final InventoryItem? item = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewItemSheet(farms: farms),
    );
    if (item == null || !mounted) return;
    await ref.read(operationsHubProvider.notifier).addInventoryItem(item);
  }

  void _showHistory(InventoryItem item, List<StockMovement> ledger) {
    final List<StockMovement> rows = StockAnalytics.forItem(ledger, item.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_tr(context, '${item.emoji} ${item.name} history', '${item.emoji} Tarihin ${item.name}', '${item.emoji} Historique de ${item.name}', '${item.emoji} ${item.name} history'),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                    _tr(context, 'Now: ${formatQty(item.availableQuantity)} ${item.unit}', 'Yanzu: ${formatQty(item.availableQuantity)} ${item.unit}', 'Actuel : ${formatQty(item.availableQuantity)} ${item.unit}', 'Now: ${formatQty(item.availableQuantity)} ${item.unit}'),
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                Flexible(
                  child: rows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(_tr(context, 'No movements recorded yet.', 'Babu motsin da aka rubuta tukuna.', 'Aucun mouvement enregistré.', 'No movement don record yet.')),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: <Widget>[
                            for (final StockMovement m in rows)
                              _MovementTile(movement: m, showName: false),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.farmName,
    required this.ledger,
    required this.onAction,
    required this.onHistory,
  });

  final InventoryItem item;
  final String farmName;
  final List<StockMovement> ledger;
  final ValueChanged<_StockAction> onAction;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StockLevel level = stockLevelOf(item);
    final Color color = stockLevelColor(level);
    final double peak = StockAnalytics.peak(ledger, item);
    final double fill = peak <= 0 ? 0 : item.availableQuantity / peak;
    final int? cover = StockAnalytics.daysOfCover(ledger, item);
    final double used30 = StockAnalytics.consumedIn(ledger, item.id);
    final double sold30 = StockAnalytics.soldIn(ledger, item.id);
    final bool expiring = item.isExpiringWithin(const Duration(days: 14));
    final bool canSell = item.group != InventoryGroup.inputs;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: level == StockLevel.ok
              ? theme.colorScheme.outlineVariant
              : color.withOpacity(0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: groupColor(item.group).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(item.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    Text(
                      [
                        localGroupLabel(context, item.group),
                        item.category,
                        if (farmName.isNotEmpty) farmName,
                      ].where((String s) => s.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatQty(item.availableQuantity),
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900, color: color),
                  ),
                  Text(
                    level == StockLevel.out
                        ? _tr(context, 'out of stock', 'an gama', 'épuisé', 'don finish')
                        : _tr(context, '${item.unit} left', '${item.unit} ya rage', '${item.unit} restant', '${item.unit} remain'),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          StockLevelBar(value: fill, color: color),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _tag(context, _tr(context, 'Worth ${CurrencyUtils.formatCompactCurrency(item.costValue)}', 'Darajar ${CurrencyUtils.formatCompactCurrency(item.costValue)}', 'Valeur ${CurrencyUtils.formatCompactCurrency(item.costValue)}', 'Worth ${CurrencyUtils.formatCompactCurrency(item.costValue)}')),
              if (used30 > 0) _tag(context, _tr(context, 'Used ${formatQty(used30)} in 30d', 'An yi amfani da ${formatQty(used30)} cikin kwana 30', '${formatQty(used30)} utilisés en 30 j', 'Use ${formatQty(used30)} inside 30d')),
              if (sold30 > 0) _tag(context, _tr(context, 'Sold ${formatQty(sold30)} in 30d', 'An sayar da ${formatQty(sold30)} cikin kwana 30', '${formatQty(sold30)} vendus en 30 j', 'Sell ${formatQty(sold30)} inside 30d')),
              if (cover != null)
                _tag(context, _tr(context, 'Lasts ~$cover days', 'Zai isa kusan kwana $cover', 'Suffisant ~$cover jours', 'Go reach ~$cover days'),
                    warn: cover <= 7),
              if (item.isLowStock) _tag(context, _tr(context, 'Low stock', 'Kaya ya yi kadan', 'Stock faible', 'Stock low'), warn: true),
              if (expiring)
                _tag(
                    context,
                    _tr(context, 'Expires ${app_date.DateUtils.formatDate(item.expiryDate!)}', 'Zai kare ${app_date.DateUtils.formatDate(item.expiryDate!)}', 'Expire ${app_date.DateUtils.formatDate(item.expiryDate!)}', 'E go expire ${app_date.DateUtils.formatDate(item.expiryDate!)}'),
                    warn: true),
              if (canSell && item.margin != 0)
                _tag(context, _tr(context, 'Margin ${(item.margin * 100).toStringAsFixed(0)}%', 'Riba ${(item.margin * 100).toStringAsFixed(0)}%', 'Marge ${(item.margin * 100).toStringAsFixed(0)}%', 'Profit ${(item.margin * 100).toStringAsFixed(0)}%')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _action(context, Icons.remove_circle_outline_rounded,
                    _tr(context, 'Use', 'Yi amfani', 'Utiliser', 'Use'), () => onAction(_StockAction.use)),
              ),
              Expanded(
                child: _action(context, Icons.add_circle_outline_rounded,
                    _tr(context, 'Add', 'Kara', 'Ajouter', 'Add'), () => onAction(_StockAction.restock)),
              ),
              Expanded(
                child: _action(context, Icons.fact_check_outlined, _tr(context, 'Count', 'Kirga', 'Compter', 'Count'),
                    () => onAction(_StockAction.count)),
              ),
              Expanded(
                child: _action(context, Icons.delete_sweep_outlined, _tr(context, 'Loss', 'Asara', 'Perte', 'Loss'),
                    () => onAction(_StockAction.loss)),
              ),
              Expanded(
                child: _action(
                    context, Icons.history_rounded, _tr(context, 'History', 'Tarihi', 'Historique', 'History'), onHistory),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, String text, {bool warn = false}) {
    final Color c = warn ? const Color(0xFFD99A1E) : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _action(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, this.showName = true});

  final StockMovement movement;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool inflow = movement.isInflow;
    final Color color =
        inflow ? const Color(0xFF2E9E5B) : const Color(0xFFE0524A);
    final String qty =
        '${inflow ? '+' : '-'}${formatQty(movement.quantity.abs())} ${movement.unit}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              inflow ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  showName
                      ? '${movement.itemName} · ${localMovementLabel(context, movement.type)}'
                      : localMovementLabel(context, movement.type),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  [
                    app_date.DateUtils.formatDateTime(movement.createdAt),
                    if (movement.note.isNotEmpty) movement.note,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(qty,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900)),
              Text(_tr(context, 'left ${formatQty(movement.balanceAfter)}', 'ya rage ${formatQty(movement.balanceAfter)}', 'reste ${formatQty(movement.balanceAfter)}', 'remain ${formatQty(movement.balanceAfter)}'),
                  style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionSheet extends StatefulWidget {
  const _ActionSheet({required this.item, required this.action});

  final InventoryItem item;
  final _StockAction action;

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet> {
  final TextEditingController _qty = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.action == _StockAction.count) {
      _qty.text = formatQty(widget.item.availableQuantity);
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.action) {
      case _StockAction.use:
        return _tr(context, 'Use ${widget.item.name}', 'Yi amfani da ${widget.item.name}', 'Utiliser ${widget.item.name}', 'Use ${widget.item.name}');
      case _StockAction.restock:
        return _tr(context, 'Add stock: ${widget.item.name}', 'Kara kaya: ${widget.item.name}', 'Ajouter du stock : ${widget.item.name}', 'Add stock: ${widget.item.name}');
      case _StockAction.count:
        return _tr(context, 'Stock-take: ${widget.item.name}', 'Kidayar kaya: ${widget.item.name}', 'Inventaire : ${widget.item.name}', 'Stock count: ${widget.item.name}');
      case _StockAction.loss:
        return _tr(context, 'Record loss: ${widget.item.name}', 'Rubuta asara: ${widget.item.name}', 'Enregistrer une perte : ${widget.item.name}', 'Record loss: ${widget.item.name}');
    }
  }

  String get _qtyLabel {
    switch (widget.action) {
      case _StockAction.count:
        return _tr(context, 'Counted quantity (${widget.item.unit})', 'Adadin da aka kirga (${widget.item.unit})', 'Quantité comptée (${widget.item.unit})', 'Quantity wey you count (${widget.item.unit})');
      case _StockAction.restock:
        return _tr(context, 'Quantity added (${widget.item.unit})', 'Adadin da aka kara (${widget.item.unit})', 'Quantité ajoutée (${widget.item.unit})', 'Quantity wey you add (${widget.item.unit})');
      default:
        return _tr(context, 'Quantity (${widget.item.unit})', 'Adadi (${widget.item.unit})', 'Quantité (${widget.item.unit})', 'Quantity (${widget.item.unit})');
    }
  }

  void _submit() {
    final double? q = double.tryParse(_qty.text.trim());
    final bool isCount = widget.action == _StockAction.count;
    if (q == null || q < 0 || (!isCount && q <= 0)) {
      setState(() => _error = _tr(context, 'Enter a valid quantity.', 'Shigar da adadi mai inganci.', 'Saisissez une quantité valide.', 'Put correct quantity.'));
      return;
    }
    final bool takesOut = widget.action == _StockAction.use ||
        widget.action == _StockAction.loss;
    if (takesOut && q > widget.item.availableQuantity) {
      setState(() => _error =
          _tr(context, 'Only ${formatQty(widget.item.availableQuantity)} ${widget.item.unit} left.', '${formatQty(widget.item.availableQuantity)} ${widget.item.unit} kawai ya rage.', 'Il ne reste que ${formatQty(widget.item.availableQuantity)} ${widget.item.unit}.', 'Na only ${formatQty(widget.item.availableQuantity)} ${widget.item.unit} remain.'));
      return;
    }
    Navigator.of(context).pop(_ActionResult(
      quantity: q,
      unitCost: double.tryParse(_cost.text.trim()),
      note: _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                  _tr(context, 'Now: ${formatQty(widget.item.availableQuantity)} ${widget.item.unit}', 'Yanzu: ${formatQty(widget.item.availableQuantity)} ${widget.item.unit}', 'Actuel : ${formatQty(widget.item.availableQuantity)} ${widget.item.unit}', 'Now: ${formatQty(widget.item.availableQuantity)} ${widget.item.unit}'),
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 14),
              TextField(
                controller: _qty,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _qtyLabel,
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (widget.action == _StockAction.restock) ...<Widget>[
                const SizedBox(height: 12),
                TextField(
                  controller: _cost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _tr(context, 'Cost per ${widget.item.unit} (optional)', 'Farashi a kowace ${widget.item.unit} (ba dole ba)', 'Coût par ${widget.item.unit} (facultatif)', 'Cost for each ${widget.item.unit} (optional)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: InputDecoration(
                  labelText: _tr(context, 'Note (optional)', 'Bayani (ba dole ba)', 'Note (facultatif)', 'Note (optional)'),
                  hintText: _tr(context, 'e.g. fed layers, sprayed plot 2', 'misali ciyar da kaji, fesa fili na 2', 'p. ex. nourri les pondeuses, traité la parcelle 2', 'e.g. feed layers, spray plot 2'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_tr(context, 'Save', 'Adana', 'Enregistrer', 'Save')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewItemSheet extends StatefulWidget {
  const _NewItemSheet({required this.farms});

  final List<Farm> farms;

  @override
  State<_NewItemSheet> createState() => _NewItemSheetState();
}

class _NewItemSheetState extends State<_NewItemSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _qty = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _threshold = TextEditingController();
  late String _farmId = widget.farms.first.id;
  String _category = 'Feed';
  String _unit = 'kg';
  String? _error;

  static const List<String> _categories = <String>[
    'Feed',
    'Seed',
    'Fertilizer',
    'Chemicals',
    'Medicine',
    'Tools',
    'Produce',
    'Other',
  ];
  static const List<String> _units = <String>[
    'kg',
    'bag',
    'litre',
    'piece',
    'crate',
    'tray',
  ];

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _cost.dispose();
    _price.dispose();
    _threshold.dispose();
    super.dispose();
  }

  String get _emoji {
    switch (_category) {
      case 'Feed':
        return '🌽';
      case 'Seed':
        return '🌱';
      case 'Fertilizer':
        return '🧪';
      case 'Chemicals':
        return '🧴';
      case 'Medicine':
        return '💊';
      case 'Tools':
        return '🧰';
      case 'Produce':
        return '🧺';
      default:
        return '📦';
    }
  }

  void _save() {
    final String name = _name.text.trim();
    final double qty = double.tryParse(_qty.text.trim()) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = _tr(context, 'Give the item a name.', 'Ba kayan suna.', 'Donnez un nom à l\'article.', 'Give the item name.'));
      return;
    }
    if (qty < 0) {
      setState(() => _error = _tr(context, 'Quantity cannot be negative.', 'Adadi ba zai iya zama ƙasa da sifili ba.', 'La quantité ne peut pas être négative.', 'Quantity no fit dey negative.'));
      return;
    }
    final DateTime now = DateTime.now();
    Navigator.of(context).pop(InventoryItem(
      id: const Uuid().v4(),
      farmId: _farmId,
      name: name,
      category: _category,
      unit: _unit,
      availableQuantity: qty,
      costPrice: double.tryParse(_cost.text.trim()) ?? 0,
      unitPrice: double.tryParse(_price.text.trim()) ?? 0,
      createdAt: now,
      updatedAt: now,
      emoji: _emoji,
      lowStockThreshold: double.tryParse(_threshold.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_tr(context, 'New stock item', 'Sabon kayan ajiya', 'Nouvel article en stock', 'New stock item'),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: _tr(context, 'Name', 'Suna', 'Nom', 'Name'),
                    hintText: _tr(context, 'e.g. Layers mash, NPK 15-15-15', 'misali abincin kaji, NPK 15-15-15', 'p. ex. aliment pondeuses, NPK 15-15-15', 'e.g. Layers mash, NPK 15-15-15'),
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (widget.farms.length > 1) ...<Widget>[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _farmId,
                    decoration: InputDecoration(
                        labelText: _tr(context, 'Farm', 'Gona', 'Ferme', 'Farm'),
                        border: const OutlineInputBorder()),
                    items: <DropdownMenuItem<String>>[
                      for (final Farm f in widget.farms)
                        DropdownMenuItem<String>(
                            value: f.id, child: Text(f.name)),
                    ],
                    onChanged: (String? v) =>
                        setState(() => _farmId = v ?? _farmId),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(
                            labelText: _tr(context, 'Category', 'Rukuni', 'Catégorie', 'Category'),
                            border: const OutlineInputBorder()),
                        items: <DropdownMenuItem<String>>[
                          for (final String c in _categories)
                            DropdownMenuItem<String>(value: c, child: Text(localCategoryLabel(context, c))),
                        ],
                        onChanged: (String? v) =>
                            setState(() => _category = v ?? _category),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        decoration: InputDecoration(
                            labelText: _tr(context, 'Unit', 'Ma\'auni', 'Unité', 'Unit'),
                            border: const OutlineInputBorder()),
                        items: <DropdownMenuItem<String>>[
                          for (final String u in _units)
                            DropdownMenuItem<String>(value: u, child: Text(u)),
                        ],
                        onChanged: (String? v) =>
                            setState(() => _unit = v ?? _unit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(child: _num(_qty, _tr(context, 'Quantity now', 'Adadin yanzu', 'Quantité actuelle', 'Quantity now'))),
                    const SizedBox(width: 12),
                    Expanded(child: _num(_threshold, _tr(context, 'Warn me below', 'Gargade ni idan ya yi kasa da', 'M\'alerter en dessous de', 'Warn me if e dey below'))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(child: _num(_cost, _tr(context, 'Cost per unit', 'Farashi a kowane daya', 'Coût unitaire', 'Cost for one'))),
                    const SizedBox(width: 12),
                    Expanded(child: _num(_price, _tr(context, 'Selling price', 'Farashin siyarwa', 'Prix de vente', 'Selling price'))),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_tr(context, 'Add to stock', 'Kara a kaya', 'Ajouter au stock', 'Add to stock')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );
}
