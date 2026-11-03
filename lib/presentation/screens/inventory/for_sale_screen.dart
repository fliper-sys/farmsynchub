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
        heroTitle: 'Ready to sell',
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
                    Text('Ready to sell',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    Text(
                      'Harvested crops, eggs and mature animals waiting for a buyer.',
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
                label: 'Potential sales',
                value: CurrencyUtils.formatCompactCurrency(potential),
              ),
              MetricStat(
                icon: Icons.trending_up_rounded,
                label: 'Est. profit',
                value: CurrencyUtils.formatCompactCurrency(profit),
                color: const Color(0xFF2E9E5B),
              ),
              MetricStat(
                icon: Icons.inventory_2_rounded,
                label: 'Lines',
                value: '${ready.length}',
                color: const Color(0xFF8B5CF6),
              ),
              MetricStat(
                icon: Icons.pets_rounded,
                label: 'Animals',
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
                _chip('All', _filter == null, () => setState(() => _filter = null)),
                _chip('Produce', _filter == InventoryGroup.produce,
                    () => setState(() => _filter = InventoryGroup.produce)),
                _chip('Animals', _filter == InventoryGroup.animals,
                    () => setState(() => _filter = InventoryGroup.animals)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (unpriced.isNotEmpty)
            AttentionBanner(
              level: AttentionLevel.notice,
              title:
                  '${unpriced.length} item${unpriced.length == 1 ? '' : 's'} have no price',
              message: 'Set a price so you can sell them from the sales desk.',
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
                    const Text(
                      'Nothing is ready yet. Record a harvest on a crop, collect eggs, or move animals to sale stock from the livestock screen.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: () => context.go('/crops'),
                          child: const Text('Open crops'),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go('/livestock'),
                          child: const Text('Open livestock'),
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
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Open sales desk (cart)'),
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
        title: Text('Price per ${item.unit}'),
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
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(double.tryParse(c.text.trim())),
            child: const Text('Save'),
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
          ? 'Sold ${formatQty(r.quantity)} ${item.unit} of ${item.name} for ${CurrencyUtils.formatCurrency(r.quantity * r.unitPrice)}.'
          : result.error ?? 'Could not record that sale.'),
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
                      '${formatQty(item.availableQuantity)} ${item.unit} ready · ${groupLabel(item.group)}',
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
                        : 'No price',
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
                        : 'tap Set price',
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
                  label: Text(priced ? 'Edit price' : 'Set price'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: priced ? onSell : null,
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Quick sell'),
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
      setState(() => _error = 'Enter a quantity above zero.');
      return;
    }
    if (_q > widget.item.availableQuantity) {
      setState(() => _error =
          'Only ${formatQty(widget.item.availableQuantity)} ${widget.item.unit} ready.');
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
              Text('Sell ${widget.item.emoji} ${widget.item.name}',
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
                        labelText: 'Quantity (${widget.item.unit})',
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
                      decoration: const InputDecoration(
                        labelText: 'Price each',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _buyer,
                decoration: const InputDecoration(
                  labelText: 'Buyer (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Total ${CurrencyUtils.formatCurrency(_q * _p)}',
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Record sale'),
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
