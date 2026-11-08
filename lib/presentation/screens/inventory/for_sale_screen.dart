import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/stock_actions.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/detail_ui.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/finance_ui.dart';
import '../../common/widgets/soft_screen_scaffold.dart';
import 'stock_i18n.dart';

/// Harvested crops, eggs and mature animals that are ready to be sold -
/// one tap to sell some of it, or jump to the sales desk to build a cart.
class ForSaleScreen extends ConsumerStatefulWidget {
  const ForSaleScreen({super.key});

  static const String routeName = '/for-sale';

  @override
  ConsumerState<ForSaleScreen> createState() => _ForSaleScreenState();
}

class _ForSaleScreenState extends ConsumerState<ForSaleScreen> {
  InventoryGroup? _filter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<InventoryItem> sellable = ref
        .watch(operationsHubProvider)
        .inventory
        .where((InventoryItem i) => i.group != InventoryGroup.inputs)
        .toList();
    final List<InventoryItem> ready = sellable
        .where((InventoryItem i) =>
            i.availableQuantity > 0 && (_filter == null || i.group == _filter))
        .toList()
      ..sort((InventoryItem a, InventoryItem b) =>
          b.retailValue.compareTo(a.retailValue));
    final List<InventoryItem> unpriced = ready
        .where((InventoryItem i) => i.unitPrice <= 0)
        .toList(growable: false);
    final double potential =
        ready.fold<double>(0, (double s, InventoryItem i) => s + i.retailValue);
    final double profit = ready.fold<double>(
        0,
        (double s, InventoryItem i) =>
            s + (i.costPrice > 0 ? i.retailValue - i.availableQuantity * i.costPrice : 0));
    final int animals = ready
        .where((InventoryItem i) => i.group == InventoryGroup.animals)
        .fold<int>(0, (int s, InventoryItem i) => s + i.availableQuantity.round());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SoftScreenScaffold(
        heroTitle: stockTr(context, 'Ready to sell', 'A shirye don siyarwa', 'Prêt à vendre', 'Ready to sell'),
        heroSubtitle: '',
        heroIcon: Icons.storefront_rounded,
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
                    Text(stockTr(context, 'Ready to sell', 'A shirye don siyarwa', 'Prêt à vendre', 'Ready to sell'),
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    Text(
                      stockTr(context, 'Harvested crops, eggs and mature animals waiting for a buyer.', 'Amfanin gona da aka girba, kwai da manyan dabbobi masu jiran mai saye.', 'Récoltes, œufs et animaux adultes en attente d’acheteur.', 'Harvest crops, eggs and big animals wey dey wait for buyer.'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const FinanceNavBar(current: FinanceSection.readyToSell),
          const SizedBox(height: 14),
          MetricStrip(
            stats: <MetricStat>[
              MetricStat(
                icon: Icons.payments_rounded,
                label: stockTr(context, 'Potential sales', 'Yiwuwar tallace-tallace', 'Ventes potentielles', 'Sales wey fit happen'),
                value: CurrencyUtils.formatCompactCurrency(potential),
              ),
              MetricStat(
                icon: Icons.trending_up_rounded,
                label: stockTr(context, 'Est. profit', 'Kiyasin riba', 'Bénéfice estimé', 'Profit estimate'),
                value: CurrencyUtils.formatCompactCurrency(profit),
                color: const Color(0xFF2E9E5B),
              ),
              MetricStat(
                icon: Icons.inventory_2_rounded,
                label: stockTr(context, 'Lines', 'Layuka', 'Lignes', 'Lines'),
                value: '${ready.length}',
                color: const Color(0xFF8B5CF6),
              ),
              MetricStat(
                icon: Icons.pets_rounded,
                label: stockTr(context, 'Animals', 'Dabbobi', 'Animaux', 'Animals'),
                value: '$animals',
                color: const Color(0xFF0EA5A4),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                _chip(stockTr(context, 'All', 'Duka', 'Tout', 'All'), _filter == null, () => setState(() => _filter = null)),
                _chip(stockTr(context, 'Produce', 'Amfanin gona', 'Produits', 'Produce'), _filter == InventoryGroup.produce,
                    () => setState(() => _filter = InventoryGroup.produce)),
                _chip(stockTr(context, 'Animals', 'Dabbobi', 'Animaux', 'Animals'), _filter == InventoryGroup.animals,
                    () => setState(() => _filter = InventoryGroup.animals)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (unpriced.isNotEmpty)
            AttentionBanner(
              level: AttentionLevel.notice,
              title: stockTr(
                  context,
                  '${unpriced.length} item${unpriced.length == 1 ? '' : 's'} have no price',
                  '${unpriced.length} daga cikin kayayyaki ba su da farashi',
                  '${unpriced.length} article${unpriced.length == 1 ? '' : 's'} sans prix',
                  '${unpriced.length} item no get price'),
              message: stockTr(context, 'Set a price so you can sell them from the sales desk.', 'Sanya farashi don ku iya sayar da su daga teburin siyarwa.', 'Fixez un prix pour pouvoir les vendre depuis la caisse.', 'Put price so you fit sell dem from sales desk.'),
            ),
          if (unpriced.isNotEmpty) const SizedBox(height: 12),
          if (ready.isEmpty)
            AppCard(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: <Widget>[
                    const Text('🧺', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(
                      stockTr(context, 'Nothing is ready yet. Record a harvest on a crop, collect eggs, or move animals to sale stock from the livestock screen.', 'Babu abin da ya shirya tukuna. Rubuta girbi a amfanin gona, tattara kwai, ko mayar da dabbobi zuwa kayan siyarwa daga shafin dabbobi.', 'Rien n’est prêt. Enregistrez une récolte, ramassez des œufs ou déplacez des animaux vers le stock à vendre depuis l’écran du bétail.', 'Nothing ready yet. Record harvest for crop, collect egg, or move animals go sale stock from livestock screen.'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: () => context.go('/crops'),
                          child: Text(stockTr(context, 'Open crops', 'Bude amfanin gona', 'Ouvrir les cultures', 'Open crops')),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go('/livestock'),
                          child: Text(stockTr(context, 'Open livestock', 'Bude dabbobi', 'Ouvrir le bétail', 'Open animals')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            for (int i = 0; i < ready.length; i++)
              FadeInUp(
                index: i > 5 ? 5 : i,
                child: _ReadyCard(
                  item: ready[i],
                  onSell: () => _sell(ready[i]),
                  onSetPrice: () => _setPrice(ready[i]),
                ),
              ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.pushReplacement('/sales'),
              icon: const Icon(Icons.point_of_sale_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(stockTr(context, 'Open sales desk (cart)', 'Bude teburin siyarwa (kwando)', 'Ouvrir la caisse (panier)', 'Open sales desk (cart)')),
              ),
            ),
          ),
          const SizedBox(height: 24),
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

  Future<void> _setPrice(InventoryItem item) async {
    final TextEditingController c = TextEditingController(
        text: item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(0) : '');
    final double? price = await showDialog<double>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(stockTr(context, 'Price per ${item.unit}', 'Farashi a kowace ${item.unit}', 'Prix par ${item.unit}', 'Price for each ${item.unit}')),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: item.name, border: const OutlineInputBorder()),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(stockTr(context, 'Cancel', 'Soke', 'Annuler', 'Cancel'))),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(double.tryParse(c.text.trim())),
            child: Text(stockTr(context, 'Save', 'Adana', 'Enregistrer', 'Save')),
          ),
        ],
      ),
    );
    c.dispose();
    if (price == null || price < 0 || !mounted) return;
    await ref.read(operationsHubProvider.notifier).updateInventoryItem(
        item.copyWith(unitPrice: price, updatedAt: DateTime.now()));
  }

  Future<void> _sell(InventoryItem item) async {
    final _SellResult? r = await showModalBottomSheet<_SellResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SellSheet(item: item),
    );
    if (r == null || !mounted) return;
    final QuickSaleResult result = await StockActions.quickSale(
      ref,
      item: item,
      quantity: r.quantity,
      unitPrice: r.unitPrice,
      buyerName: r.buyer,
    );
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.isOk
          ? stockTr(context, 'Sold ${formatQty(r.quantity)} ${item.unit} of ${item.name} for ${CurrencyUtils.formatCurrency(r.quantity * r.unitPrice)}.', 'An sayar da ${formatQty(r.quantity)} ${item.unit} na ${item.name} a kan ${CurrencyUtils.formatCurrency(r.quantity * r.unitPrice)}.', '${formatQty(r.quantity)} ${item.unit} de ${item.name} vendu pour ${CurrencyUtils.formatCurrency(r.quantity * r.unitPrice)}.', 'We don sell ${formatQty(r.quantity)} ${item.unit} of ${item.name} for ${CurrencyUtils.formatCurrency(r.quantity * r.unitPrice)}.')
          : result.error ?? stockTr(context, 'Could not record that sale.', 'Ba a iya rubuta wannan siyarwar ba.', 'Impossible d’enregistrer cette vente.', 'We no fit record that sale.')),
    ));
  }
}

class _SellResult {
  const _SellResult(this.quantity, this.unitPrice, this.buyer);

  final double quantity;
  final double unitPrice;
  final String buyer;
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({
    required this.item,
    required this.onSell,
    required this.onSetPrice,
  });

  final InventoryItem item;
  final VoidCallback onSell;
  final VoidCallback onSetPrice;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool priced = item.unitPrice > 0;
    final Color tint = groupColor(item.group);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: <Color>[
                    tint.withOpacity(0.30),
                    tint.withOpacity(0.10),
                  ]),
                ),
                alignment: Alignment.center,
                child: Text(item.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    Text(
                      '${formatQty(item.availableQuantity)} ${item.unit} ${stockTr(context, 'ready', 'a shirye', 'prêt', 'ready')} · ${localGroupLabel(context, item.group)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    priced
                        ? CurrencyUtils.formatCurrency(item.retailValue)
                        : stockTr(context, 'No price', 'Babu farashi', 'Pas de prix', 'No price'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: priced
                          ? theme.colorScheme.primary
                          : const Color(0xFFD99A1E),
                    ),
                  ),
                  Text(
                    priced
                        ? '${CurrencyUtils.formatCurrency(item.unitPrice)} / ${item.unit}'
                        : stockTr(context, 'tap Set price', 'danna Sanya farashi', 'touchez Fixer le prix', 'tap Set price'),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSetPrice,
                  icon: const Icon(Icons.sell_outlined, size: 18),
                  label: Text(priced
                      ? stockTr(context, 'Edit price', 'Gyara farashi', 'Modifier le prix', 'Edit price')
                      : stockTr(context, 'Set price', 'Sanya farashi', 'Fixer le prix', 'Set price')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: priced ? onSell : null,
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: Text(stockTr(context, 'Quick sell', 'Siyarwa da sauri', 'Vente rapide', 'Quick sell')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SellSheet extends StatefulWidget {
  const _SellSheet({required this.item});

  final InventoryItem item;

  @override
  State<_SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends State<_SellSheet> {
  late final TextEditingController _qty =
      TextEditingController(text: formatQty(widget.item.availableQuantity));
  late final TextEditingController _price = TextEditingController(
      text: widget.item.unitPrice.toStringAsFixed(
          widget.item.unitPrice % 1 == 0 ? 0 : 2));
  final TextEditingController _buyer = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _buyer.dispose();
    super.dispose();
  }

  double get _q => double.tryParse(_qty.text.trim()) ?? 0;
  double get _p => double.tryParse(_price.text.trim()) ?? 0;

  void _submit() {
    if (_q <= 0) {
      setState(() => _error = stockTr(context, 'Enter a quantity above zero.', 'Shigar da adadi fiye da sifili.', 'Saisissez une quantité supérieure à zéro.', 'Put quantity wey pass zero.'));
      return;
    }
    if (_q > widget.item.availableQuantity) {
      setState(() => _error =
          stockTr(context, 'Only ${formatQty(widget.item.availableQuantity)} ${widget.item.unit} ready.', '${formatQty(widget.item.availableQuantity)} ${widget.item.unit} kawai ya shirya.', 'Seulement ${formatQty(widget.item.availableQuantity)} ${widget.item.unit} prêt.', 'Na only ${formatQty(widget.item.availableQuantity)} ${widget.item.unit} ready.'));
      return;
    }
    Navigator.of(context)
        .pop(_SellResult(_q, _p, _buyer.text.trim()));
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
              Text(stockTr(context, 'Sell ${widget.item.emoji} ${widget.item.name}', 'Sayar da ${widget.item.emoji} ${widget.item.name}', 'Vendre ${widget.item.emoji} ${widget.item.name}', 'Sell ${widget.item.emoji} ${widget.item.name}'),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _qty,
                      onChanged: (_) => setState(() => _error = null),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: stockTr(context, 'Quantity (${widget.item.unit})', 'Adadi (${widget.item.unit})', 'Quantité (${widget.item.unit})', 'Quantity (${widget.item.unit})'),
                        errorText: _error,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _price,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: stockTr(context, 'Price each', 'Farashi a kowanne', 'Prix unitaire', 'Price for one'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _buyer,
                decoration: InputDecoration(
                  labelText: stockTr(context, 'Buyer (optional)', 'Mai saye (ba dole ba)', 'Acheteur (facultatif)', 'Buyer (optional)'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${stockTr(context, 'Total', 'Jimla', 'Total', 'Total')} ${CurrencyUtils.formatCurrency(_q * _p)}',
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(stockTr(context, 'Record sale', 'Rubuta siyarwa', 'Enregistrer la vente', 'Record sale')),
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
