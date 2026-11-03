import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/inventory_item.dart';
import '../../../domain/models/stock_movement.dart';
import 'detail_ui.dart';

/// Shared building blocks for the money-and-stock screens (sales desk,
/// inventory, ready-to-sell, procurement, expenses) so they look and
/// navigate the same way.

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

enum FinanceSection { overview, sell, stock, readyToSell, buy, expenses }

class _SectionDef {
  const _SectionDef(this.section, this.label, this.icon, this.path);

  final FinanceSection section;
  final String label;
  final IconData icon;
  final String path;
}

const List<_SectionDef> _sections = <_SectionDef>[
  _SectionDef(FinanceSection.overview, 'Overview', Icons.space_dashboard_rounded,
      '/finance'),
  _SectionDef(
      FinanceSection.sell, 'Sell', Icons.point_of_sale_rounded, '/sales'),
  _SectionDef(FinanceSection.stock, 'Stock', Icons.inventory_2_rounded,
      '/inventory'),
  _SectionDef(FinanceSection.readyToSell, 'Ready to sell',
      Icons.storefront_rounded, '/for-sale'),
  _SectionDef(FinanceSection.buy, 'Buy', Icons.shopping_bag_rounded,
      '/procurement'),
  _SectionDef(FinanceSection.expenses, 'Expenses', Icons.receipt_long_rounded,
      '/expenses'),
];

/// One row of pills that jumps between the finance areas in a single tap.
class FinanceNavBar extends StatelessWidget {
  const FinanceNavBar({super.key, required this.current});

  final FinanceSection current;

  void _go(BuildContext context, _SectionDef target) {
    if (target.section == current) return;
    HapticFeedback.selectionClick();
    if (target.section == FinanceSection.overview) {
      context.go('/finance');
    } else if (current == FinanceSection.overview) {
      context.push(target.path);
    } else {
      // Sibling screens replace each other so Back always returns to the hub.
      context.pushReplacement(target.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final _SectionDef def = _sections[i];
          final bool selected = def.section == current;
          return GestureDetector(
            onTap: () => _go(context, def),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    def.icon,
                    size: 18,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    def.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stock helpers
// ---------------------------------------------------------------------------

enum StockLevel { out, low, ok }

StockLevel stockLevelOf(InventoryItem item) {
  if (item.availableQuantity <= 0) return StockLevel.out;
  if (item.isLowStock) return StockLevel.low;
  return StockLevel.ok;
}

Color stockLevelColor(StockLevel level) {
  switch (level) {
    case StockLevel.out:
      return const Color(0xFFE0524A);
    case StockLevel.low:
      return const Color(0xFFD99A1E);
    case StockLevel.ok:
      return const Color(0xFF2E9E5B);
  }
}

Color groupColor(InventoryGroup group) {
  switch (group) {
    case InventoryGroup.inputs:
      return const Color(0xFF8B5CF6);
    case InventoryGroup.produce:
      return const Color(0xFF2E9E5B);
    case InventoryGroup.animals:
      return const Color(0xFF0EA5A4);
  }
}

String groupLabel(InventoryGroup group) {
  switch (group) {
    case InventoryGroup.inputs:
      return 'Inputs';
    case InventoryGroup.produce:
      return 'Produce';
    case InventoryGroup.animals:
      return 'Animals';
  }
}

String formatQty(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(v.abs() < 10 ? 2 : 1);
}

/// Slim bar showing how full a stock is.
class StockLevelBar extends StatelessWidget {
  const StockLevelBar({super.key, required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double target = value.isNaN ? 0 : value.clamp(0.0, 1.0).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, Widget? child) => Container(
        height: 7,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v <= 0 ? 0.0 : (v < 0.04 ? 0.04 : v),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Product catalogue tile
// ---------------------------------------------------------------------------

/// A catalogue card: big emoji, price, how much is left, and an inline
/// add / quantity stepper so the farmer can build a cart without leaving
/// the list.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.item,
    required this.inCart,
    required this.onAdd,
    required this.onRemoveOne,
    required this.onOpen,
    this.index = 0,
    this.subtitle,
  });

  final InventoryItem item;
  final double inCart;
  final VoidCallback onAdd;
  final VoidCallback onRemoveOne;
  final VoidCallback onOpen;
  final int index;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StockLevel level = stockLevelOf(item);
    final Color levelColor = stockLevelColor(level);
    final Color tint = groupColor(item.group);
    final bool out = level == StockLevel.out;
    final bool atMax = inCart >= item.availableQuantity;

    return FadeInUp(
      index: index > 5 ? 5 : index,
      child: GestureDetector(
        onTap: onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: inCart > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: inCart > 0 ? 2 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(
                    theme.brightness == Brightness.dark ? 0.25 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Opacity(
                    opacity: out ? 0.45 : 1,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            tint.withOpacity(0.28),
                            tint.withOpacity(0.10),
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(item.emoji,
                          style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      out
                          ? 'Out'
                          : '${formatQty(item.availableQuantity)} ${item.unit}',
                      style: TextStyle(
                        color: levelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle ?? item.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: CurrencyUtils.formatCurrency(item.unitPrice),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${item.unit}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (Widget child, Animation<double> anim) =>
                    ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: out
                    ? Container(
                        key: const ValueKey<String>('out'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Out of stock',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      )
                    : inCart <= 0
                        ? SizedBox(
                            key: const ValueKey<String>('add'),
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                onAdd();
                              },
                              icon: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 18),
                              label: const Text('Add'),
                            ),
                          )
                        : Container(
                            key: const ValueKey<String>('stepper'),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  color: theme.colorScheme.onPrimary,
                                  icon: const Icon(Icons.remove_rounded),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    onRemoveOne();
                                  },
                                ),
                                Text(
                                  formatQty(inCart),
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  color: theme.colorScheme.onPrimary,
                                  icon: const Icon(Icons.add_rounded),
                                  onPressed: atMax
                                      ? null
                                      : () {
                                          HapticFeedback.selectionClick();
                                          onAdd();
                                        },
                                ),
                              ],
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

/// Lays children out in 2-4 equal columns without nesting a scroll view.
class AdaptiveTileGrid extends StatelessWidget {
  const AdaptiveTileGrid({
    super.key,
    required this.children,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final int columns = box.maxWidth > 900
            ? 4
            : box.maxWidth > 600
                ? 3
                : 2;
        final double width = (box.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final Widget c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Cart bar
// ---------------------------------------------------------------------------

/// Sticky bottom bar that summarises the cart and opens it.
class CartBar extends StatelessWidget {
  const CartBar({
    super.key,
    required this.itemCount,
    required this.total,
    required this.onOpen,
  });

  final int itemCount;
  final double total;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (Widget child, Animation<double> anim) =>
          SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: itemCount <= 0
          ? const SizedBox.shrink(key: ValueKey<String>('empty'))
          : SafeArea(
              key: const ValueKey<String>('bar'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: GestureDetector(
                  onTap: onOpen,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF0E5A41), Color(0xFF1B7A55)],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFF0E5A41).withOpacity(0.45),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            const Icon(Icons.shopping_cart_rounded,
                                color: Colors.white, size: 26),
                            Positioned(
                              right: -8,
                              top: -8,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder:
                                    (Widget c, Animation<double> a) =>
                                        ScaleTransition(scale: a, child: c),
                                child: Container(
                                  key: ValueKey<int>(itemCount),
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFC800),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$itemCount',
                                    style: const TextStyle(
                                      color: Color(0xFF3A1F00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'View cart',
                                style: theme.textTheme.labelMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.8)),
                              ),
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: total),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                builder: (BuildContext context, double v,
                                        Widget? child) =>
                                    Text(
                                  CurrencyUtils.formatCurrency(v),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC800),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: <Widget>[
                              Text(
                                'Checkout',
                                style: TextStyle(
                                  color: Color(0xFF3A1F00),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 18, color: Color(0xFF3A1F00)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric strip
// ---------------------------------------------------------------------------

class MetricStat {
  const MetricStat({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
}

/// Compact horizontally scrollable stat tiles.
class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.stats});

  final List<MetricStat> stats;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int i) {
          final MetricStat s = stats[i];
          final Color color = s.color ?? theme.colorScheme.primary;
          return Container(
            width: 132,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(s.icon, size: 15, color: color),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    s.value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
