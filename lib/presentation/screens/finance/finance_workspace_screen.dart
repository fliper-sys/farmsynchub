import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/finance_report_service.dart';
import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_file_saver_base.dart';
import '../../../core/services/report_share_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../domain/models/farm.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import 'product_detail_screen.dart';
import 'sales_information_screen.dart';
import '../sales/sales_desk_screen.dart';

class FinanceWorkspaceScreen extends ConsumerStatefulWidget {
  const FinanceWorkspaceScreen({super.key});

  @override
  ConsumerState<FinanceWorkspaceScreen> createState() => _FinanceWorkspaceScreenState();
}

class _FinanceWorkspaceScreenState extends ConsumerState<FinanceWorkspaceScreen> {
  final FinanceReportService _reportService = FinanceReportService();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  final ReportShareService _shareService = const ReportShareService();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Transaction> transactions = ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final OperationsHubState operations = ref.watch(operationsHubProvider);
    final FinanceMetrics metrics = FinanceMetrics.fromTransactions(transactions);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finance workspace'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Export report',
              onPressed: transactions.isEmpty || _isExporting
                  ? null
                  : () => _exportReport(metrics, transactions),
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Tab>[
              Tab(text: 'Products'),
              Tab(text: 'Sales desk'),
              Tab(text: 'Expenses'),
              Tab(text: 'Procurement'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            _FinanceSummaryStrip(metrics: metrics, farms: farms, inventoryCount: operations.inventory.length),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _ProductsTab(farms: farms, inventory: operations.inventory),
                  _SalesDeskLauncher(
                    farms: farms,
                    salesCount: transactions.where((Transaction item) => item.recordKind == TransactionRecordKind.sale).length,
                    customerCount: operations.partners.where((BusinessPartner partner) => partner.type == BusinessPartnerType.customer).length,
                  ),
                  _ExpensesTab(farms: farms),
                  _ProcurementTab(farms: farms, partners: operations.partners, inventory: operations.inventory),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReport(FinanceMetrics metrics, List<Transaction> transactions) async {
    setState(() => _isExporting = true);
    try {
      final String fileName = 'farmsync_finance_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final Uint8List bytes = await _reportService.buildFinanceReport(
        transactions: transactions,
        income: metrics.income,
        expenses: metrics.expenses,
        balance: metrics.balance,
        categoryTotals: metrics.categoryTotals,
      );
      final String savedPath = await _fileSaver.savePdf(
        bytes: bytes,
        fileName: fileName,
      );
      await _shareService.sharePdf(
        filePath: savedPath,
        fileName: fileName,
        message: 'FarmSync finance report is ready to share.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report saved to $savedPath')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

class _FinanceSummaryStrip extends StatelessWidget {
  const _FinanceSummaryStrip({
    required this.metrics,
    required this.farms,
    required this.inventoryCount,
  });

  final FinanceMetrics metrics;
  final List<Farm> farms;
  final int inventoryCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryTile(
              label: 'Income',
              value: CurrencyUtils.formatCompactCurrency(metrics.income),
              color: const Color(0xFFE5F5D8),
              icon: Icons.trending_up_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Expenses',
              value: CurrencyUtils.formatCompactCurrency(metrics.expenses),
              color: const Color(0xFFFFE7D7),
              icon: Icons.trending_down_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Balance',
              value: CurrencyUtils.formatCompactCurrency(metrics.balance),
              color: const Color(0xFFDFF1FF),
              icon: Icons.account_balance_wallet_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Products',
              value: '$inventoryCount',
              color: const Color(0xFFFFEBCF),
              icon: Icons.inventory_2_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = AppColors.chipBackgroundFor(
      color,
      isDark: isDark,
      surface: theme.colorScheme.surfaceContainerHighest,
    );
    final Color foreground = AppColors.chipForegroundFor(
      isDark: isDark,
      onSurface: theme.colorScheme.onSurface,
    );
    return AppCard(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(label,
                style: theme.textTheme.labelMedium?.copyWith(color: foreground)),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesDeskLauncher extends StatelessWidget {
  const _SalesDeskLauncher({
    required this.farms,
    required this.salesCount,
    required this.customerCount,
  });

  final List<Farm> farms;
  final int salesCount;
  final int customerCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Sales desk moved', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'The dedicated sales desk now handles catalog browsing, cart edits, customer linking, checkout, and shareable receipts.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _InfoPill(text: '${farms.length} farms'),
                    _InfoPill(text: '$customerCount customers'),
                    _InfoPill(text: '$salesCount receipts'),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton.primary(
                        onPressed: () => context.go(SalesDeskScreen.routeName),
                        child: const Text('Open sales desk'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton.secondary(
                        onPressed: () => context.go(SalesInformationScreen.routeName),
                        child: const Text('Sales analytics'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductsTab extends ConsumerStatefulWidget {
  const _ProductsTab({
    required this.farms,
    required this.inventory,
  });

  final List<Farm> farms;
  final List<InventoryItem> inventory;

  @override
  ConsumerState<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<_ProductsTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final List<InventoryItem> filtered = widget.inventory.where((InventoryItem item) {
      final String haystack = '${item.name} ${item.category} ${item.unit}'.toLowerCase();
      return query.isEmpty || haystack.contains(query);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AppTextField(
          controller: _searchController,
          label: 'Search products',
          hint: 'Search by name or category',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.primary(
            onPressed: widget.farms.isEmpty ? null : () => _openProductSheet(context),
            child: const Text('Create product'),
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const _EmptyState(message: 'No products found. Create the first product card to start selling stock.')
        else
          ...filtered.map(
            (InventoryItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProductCard(
                item: item,
                farmName: _farmName(item.farmId),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProductDetailScreen(productId: item.id),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _farmName(String farmId) {
    for (final Farm farm in widget.farms) {
      if (farm.id == farmId) {
        return farm.name;
      }
    }
    return 'Unknown farm';
  }

  Future<void> _openProductSheet(BuildContext context) async {
    final _ProductDraft? draft = await showModalBottomSheet<_ProductDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSheet(farms: widget.farms),
    );
    if (draft == null) return;

    await ref.read(operationsHubProvider.notifier).addInventoryItem(
          InventoryItem(
            id: const Uuid().v4(),
            farmId: draft.farmId,
            name: draft.name,
            category: draft.category,
            unit: draft.unit,
            availableQuantity: draft.quantity,
            costPrice: draft.costPrice,
            unitPrice: draft.unitPrice,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            emoji: draft.emoji,
          ),
        );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.farmName,
    this.onTap,
    this.onAddToCart,
  });

  final InventoryItem item;
  final String farmName;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4D8),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(item.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(item.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      if (onAddToCart != null)
                        IconButton(
                          tooltip: 'Add to cart',
                          onPressed: onAddToCart,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${item.category} - $farmName', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _InfoPill(text: '${item.availableQuantity.toStringAsFixed(2)} ${item.unit}'),
                      _InfoPill(text: 'Cost ${CurrencyUtils.formatCurrency(item.costPrice)}'),
                      _InfoPill(text: 'Sell ${CurrencyUtils.formatCurrency(item.unitPrice)}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesTab extends ConsumerStatefulWidget {
  const _SalesTab({
    required this.farms,
    required this.partners,
    required this.inventory,
    required this.isOwner,
  });

  final List<Farm> farms;
  final List<BusinessPartner> partners;
  final List<InventoryItem> inventory;
  final bool isOwner;

  @override
  ConsumerState<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends ConsumerState<_SalesTab> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Map<String, double> _cart = <String, double>{};
  late String _farmId;

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.isEmpty ? '' : widget.farms.first.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<InventoryItem> filtered = widget.inventory.where((InventoryItem item) {
      final bool matchesFarm = _farmId.isEmpty || item.farmId == _farmId;
      final String haystack = '${item.name} ${item.category} ${item.emoji}'.toLowerCase();
      return matchesFarm && ( _searchController.text.trim().isEmpty || haystack.contains(_searchController.text.trim().toLowerCase()));
    }).toList(growable: false);
    final List<Transaction> sales = ref.watch(transactionsProvider).valueOrNull
            ?.where((Transaction item) => item.recordKind == TransactionRecordKind.sale)
            .where((Transaction item) => _farmId.isEmpty || item.farmId == _farmId)
            .where((Transaction item) {
              final String query = _searchController.text.trim().toLowerCase();
              if (query.isEmpty) return true;
              final String haystack = '${item.productName} ${item.description} ${item.counterpartyName} ${item.receiptNumber}'.toLowerCase();
              return haystack.contains(query);
            })
            .toList(growable: false) ??
        <Transaction>[];
    final double cartTotal = _cart.entries.fold<double>(
      0,
      (double sum, MapEntry<String, double> entry) {
        final InventoryItem item = widget.inventory.firstWhere((InventoryItem value) => value.id == entry.key);
        return sum + (entry.value * item.unitPrice);
      },
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _FarmDropdown(
          farms: widget.farms,
          value: _farmId,
          onChanged: (String value) => setState(() {
            _farmId = value;
            _cart.clear();
          }),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _searchController,
          label: 'Search stock and sales',
          hint: 'Search product or sale history',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _customerController,
          label: 'Customer / buyer',
          hint: 'Optional buyer name',
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _notesController,
          label: 'Sale notes',
          hint: 'Delivery note, payment note, or special instructions',
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        if (_cart.isNotEmpty)
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Cart', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ..._cart.entries.map(
                    (MapEntry<String, double> entry) {
                      final InventoryItem item = widget.inventory.firstWhere((InventoryItem value) => value.id == entry.key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CartLine(
                          item: item,
                          quantity: entry.value,
                          onMinus: () => setState(() {
                            final double next = entry.value - 1;
                            if (next <= 0) {
                              _cart.remove(entry.key);
                            } else {
                              _cart[entry.key] = next;
                            }
                          }),
                          onPlus: () => setState(() => _cart[entry.key] = entry.value + 1),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Total',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(CurrencyUtils.formatCurrency(cartTotal)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppButton.primary(
                    onPressed: _cart.isEmpty ? null : () => _checkout(cartTotal),
                    child: const Text('Checkout sale'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text('Tap a product to add it to the cart', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const _EmptyState(message: 'No stock matches your search or selected farm.')
        else
          ...filtered.map(
            (InventoryItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProductCard(
                item: item,
                farmName: _farmName(item.farmId),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProductDetailScreen(productId: item.id),
                  ),
                ),
                onAddToCart: () => setState(() => _cart.update(item.id, (double value) => value + 1, ifAbsent: () => 1)),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Sale history',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (widget.isOwner)
              Text(
                'Owner controls enabled',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (sales.isEmpty)
          const _EmptyState(message: 'No sales recorded for this farm yet.')
        else
          ...sales.map(
            (Transaction sale) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TransactionCard(
                transaction: sale,
                showDelete: widget.isOwner,
                onDelete: widget.isOwner ? () => _deleteSale(sale) : null,
              ),
            ),
          ),
      ],
    );
  }

  void _checkout(double cartTotal) async {
    if (_farmId.isEmpty || _cart.isEmpty) return;
    final DateTime now = DateTime.now();
    final String receiptNumber = 'FS-${now.millisecondsSinceEpoch}';
    final String customerName = _customerController.text.trim();
    final String notes = _notesController.text.trim();

    for (final MapEntry<String, double> entry in _cart.entries) {
      final InventoryItem item = widget.inventory.firstWhere((InventoryItem value) => value.id == entry.key);
      if (entry.value > item.availableQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.name} does not have enough stock for that quantity.')),
        );
        return;
      }
    }

    for (final MapEntry<String, double> entry in _cart.entries) {
      final InventoryItem item = widget.inventory.firstWhere((InventoryItem value) => value.id == entry.key);
      final double quantity = entry.value;
      final Transaction transaction = Transaction(
        id: const Uuid().v4(),
        farmId: item.farmId,
        type: TransactionType.income,
        category: _categoryForItem(item),
        amount: quantity * item.unitPrice,
        description: '${item.name} sale',
        transactionDate: now,
        linkedEntityId: item.id,
        createdAt: now,
        updatedAt: now,
        isSynced: true,
        recordKind: TransactionRecordKind.sale,
        partyType: TransactionPartyType.customer,
        productName: item.name,
        quantity: quantity,
        unit: item.unit,
        unitPrice: item.unitPrice,
        counterpartyName: customerName,
        receiptNumber: receiptNumber,
        notes: notes.isEmpty ? 'Sale checkout total ${CurrencyUtils.formatCurrency(cartTotal)}' : notes,
      );
      await ref.read(transactionsProvider.notifier).addTransaction(transaction);
      await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
            farmId: item.farmId,
            productName: item.name,
            unit: item.unit,
            deltaQuantity: -quantity,
            unitPrice: item.unitPrice,
          );
    }

    if (!mounted) return;
    setState(() => _cart.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale checked out and stock updated.')),
    );
  }

  Future<void> _deleteSale(Transaction sale) async {
    await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
          farmId: sale.farmId,
          productName: sale.productName.isEmpty ? sale.description : sale.productName,
          unit: sale.unit,
          deltaQuantity: sale.quantity,
          unitPrice: sale.unitPrice,
        );
    await ref.read(transactionsProvider.notifier).deleteTransaction(sale.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale deleted and stock restored.')),
    );
  }

  TransactionCategory _categoryForItem(InventoryItem item) {
    final String lower = '${item.category} ${item.name}'.toLowerCase();
    if (lower.contains('live') || lower.contains('goat') || lower.contains('sheep') || lower.contains('cow') || lower.contains('egg')) {
      return TransactionCategory.livestockSale;
    }
    return TransactionCategory.cropSale;
  }

  String _farmName(String farmId) {
    for (final Farm farm in widget.farms) {
      if (farm.id == farmId) {
        return farm.name;
      }
    }
    return 'Unknown farm';
  }
}

class _ExpensesTab extends ConsumerStatefulWidget {
  const _ExpensesTab({required this.farms});

  final List<Farm> farms;

  @override
  ConsumerState<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<_ExpensesTab> {
  final TextEditingController _searchController = TextEditingController();
  late String _farmId;

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.isEmpty ? '' : widget.farms.first.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Transaction> expenses = ref.watch(transactionsProvider).valueOrNull
            ?.where((Transaction item) => item.type == TransactionType.expense && item.recordKind != TransactionRecordKind.procurement)
            .where((Transaction item) => _farmId.isEmpty || item.farmId == _farmId)
            .where((Transaction item) {
              final String query = _searchController.text.trim().toLowerCase();
              if (query.isEmpty) return true;
              final String haystack = '${item.description} ${item.category.name} ${item.notes} ${item.receiptNumber}'.toLowerCase();
              return haystack.contains(query);
            })
            .toList(growable: false) ??
        <Transaction>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _FarmDropdown(
          farms: widget.farms,
          value: _farmId,
          onChanged: (String value) => setState(() => _farmId = value),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _searchController,
          label: 'Search expenses',
          hint: 'Search by note, category, or receipt number',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.primary(
            onPressed: _farmId.isEmpty ? null : () => _openExpenseSheet(context),
            child: const Text('Add expense'),
          ),
        ),
        const SizedBox(height: 16),
        if (expenses.isEmpty)
          const _EmptyState(message: 'No expenses found for this farm.')
        else
          ...expenses.map(
            (Transaction item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TransactionCard(transaction: item, showDelete: false),
            ),
          ),
      ],
    );
  }

  Future<void> _openExpenseSheet(BuildContext context) async {
    final _ExpenseDraft? draft = await showModalBottomSheet<_ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseSheet(farms: widget.farms, initialFarmId: _farmId),
    );
    if (draft == null) return;

    final DateTime now = DateTime.now();
    final Transaction transaction = Transaction(
      id: const Uuid().v4(),
      farmId: draft.farmId,
      type: TransactionType.expense,
      category: draft.category,
      amount: draft.amount,
      description: draft.description,
      transactionDate: draft.transactionDate,
      linkedEntityId: draft.vendorName,
      createdAt: now,
      updatedAt: now,
      isSynced: true,
      recordKind: TransactionRecordKind.general,
      partyType: TransactionPartyType.provider,
      counterpartyName: draft.vendorName,
      counterpartyEmail: draft.vendorEmail,
      counterpartyPhone: draft.vendorPhone,
      receiptNumber: 'EXP-${now.millisecondsSinceEpoch}',
      notes: draft.notes,
      attachmentNames: draft.attachmentNames,
      attachmentBase64: draft.attachmentBase64,
    );
    await ref.read(transactionsProvider.notifier).addTransaction(transaction);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense saved with receipts.')),
    );
  }
}

class _ProcurementTab extends ConsumerStatefulWidget {
  const _ProcurementTab({
    required this.farms,
    required this.partners,
    required this.inventory,
  });

  final List<Farm> farms;
  final List<BusinessPartner> partners;
  final List<InventoryItem> inventory;

  @override
  ConsumerState<_ProcurementTab> createState() => _ProcurementTabState();
}

class _ProcurementTabState extends ConsumerState<_ProcurementTab> {
  final TextEditingController _searchController = TextEditingController();
  late String _farmId;

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.isEmpty ? '' : widget.farms.first.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Transaction> procurement = ref.watch(transactionsProvider).valueOrNull
            ?.where((Transaction item) => item.recordKind == TransactionRecordKind.procurement)
            .where((Transaction item) => _farmId.isEmpty || item.farmId == _farmId)
            .where((Transaction item) {
              final String query = _searchController.text.trim().toLowerCase();
              if (query.isEmpty) return true;
              final String haystack = '${item.description} ${item.counterpartyName} ${item.receiptNumber} ${item.notes}'.toLowerCase();
              return haystack.contains(query);
            })
            .toList(growable: false) ??
        <Transaction>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _FarmDropdown(
          farms: widget.farms,
          value: _farmId,
          onChanged: (String value) => setState(() => _farmId = value),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _searchController,
          label: 'Search procurement',
          hint: 'Search by supplier, note, or receipt number',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.primary(
            onPressed: _farmId.isEmpty ? null : () => _openProcurementSheet(context),
            child: const Text('Add procurement'),
          ),
        ),
        const SizedBox(height: 16),
        if (procurement.isEmpty)
          const _EmptyState(message: 'No procurement history for this farm.')
        else
          ...procurement.map(
            (Transaction item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TransactionCard(transaction: item, showDelete: false),
            ),
          ),
      ],
    );
  }

  Future<void> _openProcurementSheet(BuildContext context) async {
    final _ProcurementDraft? draft = await showModalBottomSheet<_ProcurementDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProcurementSheet(
        farms: widget.farms,
        partners: widget.partners,
        inventory: widget.inventory,
        initialFarmId: _farmId,
      ),
    );
    if (draft == null) return;

    final DateTime now = DateTime.now();
    final Transaction transaction = Transaction(
      id: const Uuid().v4(),
      farmId: draft.farmId,
      type: TransactionType.expense,
      category: draft.category,
      amount: draft.amount,
      description: draft.description,
      transactionDate: draft.transactionDate,
      linkedEntityId: draft.inventoryItemId.isEmpty ? draft.partnerId : draft.inventoryItemId,
      createdAt: now,
      updatedAt: now,
      isSynced: true,
      recordKind: TransactionRecordKind.procurement,
      partyType: TransactionPartyType.provider,
      productName: draft.productName,
      quantity: draft.quantity,
      unit: draft.unit,
      unitPrice: draft.unitPrice,
      counterpartyName: draft.vendorName,
      counterpartyEmail: draft.vendorEmail,
      counterpartyPhone: draft.vendorPhone,
      receiptNumber: 'PR-${now.millisecondsSinceEpoch}',
      notes: draft.notes,
      attachmentNames: draft.attachmentNames,
      attachmentBase64: draft.attachmentBase64,
    );
    InventoryItem? matchedItem;
    if (draft.inventoryItemId.isNotEmpty) {
      for (final InventoryItem item in widget.inventory) {
        if (item.id == draft.inventoryItemId) {
          matchedItem = item;
          break;
        }
      }
    }
    if (matchedItem != null) {
      await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
            farmId: matchedItem.farmId,
            productName: matchedItem.name,
            unit: matchedItem.unit,
            deltaQuantity: draft.quantity,
            unitPrice: matchedItem.unitPrice,
            costPrice: draft.unitPrice,
          );
    } else if (draft.productName.trim().isNotEmpty) {
      await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
            farmId: draft.farmId,
            productName: draft.productName,
            unit: draft.unit,
            deltaQuantity: draft.quantity,
            unitPrice: draft.unitPrice,
            costPrice: draft.unitPrice,
          );
    }
    await ref.read(transactionsProvider.notifier).addTransaction(transaction);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Procurement recorded.')),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.showDelete,
    this.onDelete,
  });

  final Transaction transaction;
  final bool showDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: transaction.type == TransactionType.income
                        ? const Color(0xFFE5F5D8)
                        : const Color(0xFFFFE7D7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    transaction.type == TransactionType.income ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        transaction.description,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${app_date.DateUtils.formatDate(transaction.transactionDate)} - ${transaction.receiptNumber}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (showDelete && onDelete != null)
                  IconButton(
                    tooltip: 'Delete sale',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoPill(text: transaction.category.name),
                _InfoPill(text: CurrencyUtils.formatCurrency(transaction.amount)),
                if (transaction.productName.isNotEmpty) _InfoPill(text: transaction.productName),
                if (transaction.counterpartyName.isNotEmpty) _InfoPill(text: transaction.counterpartyName),
                if (transaction.attachmentBase64.isNotEmpty) _InfoPill(text: '${transaction.attachmentBase64.length} attachments'),
              ],
            ),
            if (transaction.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(transaction.notes, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  final InventoryItem item;
  final double quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(item.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(child: Text(item.name)),
        IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
        Text(quantity.toStringAsFixed(0)),
        IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
      ],
    );
  }
}

class _FarmDropdown extends StatelessWidget {
  const _FarmDropdown({
    required this.farms,
    required this.value,
    required this.onChanged,
  });

  final List<Farm> farms;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (farms.isEmpty) {
      return const _EmptyState(message: 'Create a farm first to enable finance tracking.');
    }
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Farm',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: farms
              .map(
                (Farm farm) => DropdownMenuItem<String>(
                  value: farm.id,
                  child: Text(farm.name),
                ),
              )
              .toList(),
          onChanged: (String? next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message),
      ),
    );
  }
}

class _ProductSheet extends StatefulWidget {
  const _ProductSheet({required this.farms});

  final List<Farm> farms;

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(text: 'Farm produce');
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: 'bag');
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  late String _farmId;
  String _emoji = '🌾';

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _costPriceController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _FarmDropdown(
              farms: widget.farms,
              value: _farmId,
              onChanged: (String value) => setState(() => _farmId = value),
            ),
            const SizedBox(height: 12),
            AppTextField(controller: _nameController, label: 'Product name'),
            const SizedBox(height: 12),
            AppTextField(controller: _categoryController, label: 'Category'),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(controller: _quantityController, label: 'Quantity', keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(controller: _unitController, label: 'Unit'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(controller: _costPriceController, label: 'Cost price', keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(controller: _unitPriceController, label: 'Selling price', keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EmojiPicker(
              value: _emoji,
              onChanged: (String value) => setState(() => _emoji = value),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                onPressed: () {
                  Navigator.of(context).pop(
                    _ProductDraft(
                      farmId: _farmId,
                      name: _nameController.text.trim(),
                      category: _categoryController.text.trim(),
                      quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
                      unit: _unitController.text.trim().isEmpty ? 'unit' : _unitController.text.trim(),
                      costPrice: double.tryParse(_costPriceController.text.trim()) ?? 0,
                      unitPrice: double.tryParse(_unitPriceController.text.trim()) ?? 0,
                      emoji: _emoji,
                    ),
                  );
                },
                child: const Text('Save product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const List<String> _emojis = <String>[
    '🌾',
    '🥬',
    '🍅',
    '🌽',
    '🥚',
    '🥛',
    '🐐',
    '🐟',
    '🧪',
    '🍎',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _emojis
          .map(
            (String emoji) => ChoiceChip(
              label: Text(emoji),
              selected: value == emoji,
              onSelected: (_) => onChanged(emoji),
            ),
          )
          .toList(),
    );
  }
}

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet({
    required this.farms,
    required this.initialFarmId,
  });

  final List<Farm> farms;
  final String initialFarmId;

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _vendorNameController = TextEditingController();
  final TextEditingController _vendorEmailController = TextEditingController();
  final TextEditingController _vendorPhoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late String _farmId;
  TransactionCategory _category = TransactionCategory.other;
  final List<_AttachmentDraft> _attachments = <_AttachmentDraft>[];

  @override
  void initState() {
    super.initState();
    _farmId = widget.initialFarmId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _vendorNameController.dispose();
    _vendorEmailController.dispose();
    _vendorPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _FarmDropdown(
                farms: widget.farms,
                value: _farmId,
                onChanged: (String value) => setState(() => _farmId = value),
              ),
              const SizedBox(height: 12),
              _DropdownField<TransactionCategory>(
                label: 'Expense category',
                value: _category,
                items: const <TransactionCategory>[
                  TransactionCategory.feed,
                  TransactionCategory.fertiliser,
                  TransactionCategory.labour,
                  TransactionCategory.veterinary,
                  TransactionCategory.other,
                ],
                itemLabel: (TransactionCategory value) => value.name,
                onChanged: (TransactionCategory? value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _amountController, label: 'Amount', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              AppTextField(controller: _descriptionController, label: 'Description', hint: 'Fuel, feed, repair, labour', maxLines: 2),
              const SizedBox(height: 12),
              AppTextField(controller: _vendorNameController, label: 'Supplier / vendor'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: AppTextField(controller: _vendorEmailController, label: 'Email')),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(controller: _vendorPhoneController, label: 'Phone')),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _notesController, label: 'Notes', maxLines: 2),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Attachments', style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _attachments
                    .map(
                      (draft) => Chip(
                        label: Text(draft.name),
                        onDeleted: () => setState(() => _attachments.remove(draft)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: () => _pickAttachment(ImageSource.gallery),
                      child: const Text('Add receipt photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: () => _pickAttachment(ImageSource.camera),
                      child: const Text('Take photo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _ExpenseDraft(
                        farmId: _farmId,
                        category: _category,
                        amount: double.tryParse(_amountController.text.trim()) ?? 0,
                        description: _descriptionController.text.trim(),
                        vendorName: _vendorNameController.text.trim(),
                        vendorEmail: _vendorEmailController.text.trim(),
                        vendorPhone: _vendorPhoneController.text.trim(),
                        transactionDate: DateTime.now(),
                        notes: _notesController.text.trim(),
                        attachmentNames: _attachments.map((draft) => draft.name).toList(growable: false),
                        attachmentBase64: _attachments.map((draft) => draft.base64).toList(growable: false),
                      ),
                    );
                  },
                  child: const Text('Save expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAttachment(ImageSource source) async {
    final XFile? file = await _imagePicker.pickImage(source: source, imageQuality: 78);
    if (file == null) return;

    final Uint8List bytes = await file.readAsBytes();
    setState(() {
      _attachments.add(
        _AttachmentDraft(
          name: file.name,
          base64: base64Encode(bytes),
        ),
      );
    });
  }
}

class _ProcurementSheet extends StatefulWidget {
  const _ProcurementSheet({
    required this.farms,
    required this.partners,
    required this.inventory,
    required this.initialFarmId,
  });

  final List<Farm> farms;
  final List<BusinessPartner> partners;
  final List<InventoryItem> inventory;
  final String initialFarmId;

  @override
  State<_ProcurementSheet> createState() => _ProcurementSheetState();
}

class _ProcurementSheetState extends State<_ProcurementSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _unitController = TextEditingController(text: 'bag');
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late String _farmId;
  String? _partnerId;
  String? _inventoryItemId;
  final List<_AttachmentDraft> _attachments = <_AttachmentDraft>[];

  @override
  void initState() {
    super.initState();
    _farmId = widget.initialFarmId;
  }

  void _applyInventoryItem(InventoryItem item) {
    _productController.text = item.name;
    _unitController.text = item.unit;
    _unitPriceController.text = (item.costPrice > 0 ? item.costPrice : item.unitPrice).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptFiles({required bool allowPdf}) async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowPdf
          ? <String>['jpg', 'jpeg', 'png', 'pdf']
          : <String>['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null) {
      return;
    }

    setState(() {
      for (final PlatformFile file in result.files) {
        final Uint8List? bytes = file.bytes;
        if (bytes == null) {
          continue;
        }
        _attachments.add(
          _AttachmentDraft(
            name: file.name,
            base64: base64Encode(bytes),
            isPdf: file.extension?.toLowerCase() == 'pdf',
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<BusinessPartner> providers = widget.partners
        .where((BusinessPartner partner) => partner.type == BusinessPartnerType.provider)
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _FarmDropdown(
                farms: widget.farms,
                value: _farmId,
                onChanged: (String value) => setState(() => _farmId = value),
              ),
              const SizedBox(height: 12),
              if (providers.isNotEmpty)
                _DropdownField<String?>(
                  label: 'Provider',
                  value: _partnerId,
                  items: <String?>[null, ...providers.map((BusinessPartner partner) => partner.id)],
                  itemLabel: (String? value) {
                    if (value == null) return 'Select provider';
                    return providers.firstWhere((BusinessPartner partner) => partner.id == value).name;
                  },
                  onChanged: (String? value) => setState(() => _partnerId = value),
                ),
              if (providers.isNotEmpty) const SizedBox(height: 12),
              if (widget.inventory.where((InventoryItem item) => item.farmId == _farmId).isNotEmpty) ...<Widget>[
                _DropdownField<String?>(
                  label: 'Existing product',
                  value: _inventoryItemId,
                  items: <String?>[
                    null,
                    ...widget.inventory
                        .where((InventoryItem item) => item.farmId == _farmId)
                        .map((InventoryItem item) => item.id),
                  ],
                  itemLabel: (String? value) {
                    if (value == null) {
                      return 'Create new product match';
                    }
                    final InventoryItem selected = widget.inventory.firstWhere((InventoryItem item) => item.id == value);
                    return '${selected.emoji} ${selected.name}';
                  },
                  onChanged: (String? value) {
                    setState(() {
                      _inventoryItemId = value;
                      if (value == null) {
                        return;
                      }
                      final InventoryItem selected = widget.inventory.firstWhere((InventoryItem item) => item.id == value);
                      _applyInventoryItem(selected);
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              AppTextField(controller: _productController, label: 'Product / supply'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: AppTextField(controller: _quantityController, label: 'Quantity', keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(controller: _unitController, label: 'Unit')),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(controller: _unitPriceController, label: 'Unit price', keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _amountController, label: 'Total amount', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              AppTextField(controller: _descriptionController, label: 'Description', maxLines: 2),
              const SizedBox(height: 12),
              AppTextField(controller: _notesController, label: 'Notes', maxLines: 2),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Receipt attachments', style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _attachments
                    .map(
                      (attachment) => Chip(
                        avatar: Icon(
                          attachment.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                          size: 18,
                        ),
                        label: Text(attachment.name),
                        onDeleted: () => setState(() => _attachments.remove(attachment)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: () => _pickReceiptFiles(allowPdf: false),
                      child: const Text('Add image'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: () => _pickReceiptFiles(allowPdf: true),
                      child: const Text('Add PDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  onPressed: () {
                    final BusinessPartner? partner = _partnerId == null
                        ? null
                        : providers.firstWhere((BusinessPartner partner) => partner.id == _partnerId);
                    Navigator.of(context).pop(
                      _ProcurementDraft(
                        farmId: _farmId,
                        partnerId: partner?.id ?? '',
                        inventoryItemId: _inventoryItemId ?? '',
                        productName: _productController.text.trim(),
                        quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
                        unit: _unitController.text.trim().isEmpty ? 'unit' : _unitController.text.trim(),
                        unitPrice: double.tryParse(_unitPriceController.text.trim()) ?? 0,
                        amount: double.tryParse(_amountController.text.trim()) ?? 0,
                        description: _descriptionController.text.trim().isEmpty
                            ? _productController.text.trim()
                            : _descriptionController.text.trim(),
                        vendorName: partner?.name ?? '',
                        vendorEmail: partner?.email ?? '',
                        vendorPhone: partner?.phone ?? '',
                        transactionDate: DateTime.now(),
                        notes: _notesController.text.trim(),
                        attachmentNames: _attachments.map(( _AttachmentDraft attachment) => attachment.name).toList(growable: false),
                        attachmentBase64: _attachments.map(( _AttachmentDraft attachment) => attachment.base64).toList(growable: false),
                        category: TransactionCategory.other,
                      ),
                    );
                  },
                  child: const Text('Save procurement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items
              .map(
                (T item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class FinanceMetrics {
  const FinanceMetrics({
    required this.income,
    required this.expenses,
    required this.balance,
    required this.categoryTotals,
  });

  final double income;
  final double expenses;
  final double balance;
  final Map<TransactionCategory, double> categoryTotals;

  factory FinanceMetrics.fromTransactions(List<Transaction> transactions) {
    double income = 0;
    double expenses = 0;
    final Map<TransactionCategory, double> categoryTotals = <TransactionCategory, double>{};
    for (final Transaction transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else {
        expenses += transaction.amount;
      }
      categoryTotals.update(
        transaction.category,
        (double value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return FinanceMetrics(
      income: income,
      expenses: expenses,
      balance: income - expenses,
      categoryTotals: categoryTotals,
    );
  }
}

class _ProductDraft {
  const _ProductDraft({
    required this.farmId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.costPrice,
    required this.unitPrice,
    required this.emoji,
  });

  final String farmId;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final double costPrice;
  final double unitPrice;
  final String emoji;
}

class _ExpenseDraft {
  const _ExpenseDraft({
    required this.farmId,
    required this.category,
    required this.amount,
    required this.description,
    required this.vendorName,
    required this.vendorEmail,
    required this.vendorPhone,
    required this.transactionDate,
    required this.notes,
    required this.attachmentNames,
    required this.attachmentBase64,
  });

  final String farmId;
  final TransactionCategory category;
  final double amount;
  final String description;
  final String vendorName;
  final String vendorEmail;
  final String vendorPhone;
  final DateTime transactionDate;
  final String notes;
  final List<String> attachmentNames;
  final List<String> attachmentBase64;
}

class _ProcurementDraft {
  const _ProcurementDraft({
    required this.farmId,
    required this.partnerId,
    required this.inventoryItemId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.amount,
    required this.description,
    required this.vendorName,
    required this.vendorEmail,
    required this.vendorPhone,
    required this.transactionDate,
    required this.notes,
    required this.attachmentNames,
    required this.attachmentBase64,
    required this.category,
  });

  final String farmId;
  final String partnerId;
  final String inventoryItemId;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double amount;
  final String description;
  final String vendorName;
  final String vendorEmail;
  final String vendorPhone;
  final DateTime transactionDate;
  final String notes;
  final List<String> attachmentNames;
  final List<String> attachmentBase64;
  final TransactionCategory category;
}

class _AttachmentDraft {
  const _AttachmentDraft({
    required this.name,
    required this.base64,
    this.isPdf = false,
  });

  final String name;
  final String base64;
  final bool isPdf;
}
