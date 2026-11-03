import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_file_saver_base.dart';
import '../../../core/services/report_share_service.dart';
import '../../../core/services/sales_receipt_report_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../core/utils/widget_image_capture.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/finance_ui.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class SalesDeskScreen extends ConsumerStatefulWidget {
  const SalesDeskScreen({super.key});

  static const String routeName = '/sales';

  @override
  ConsumerState<SalesDeskScreen> createState() => _SalesDeskScreenState();
}

class _SalesDeskScreenState extends ConsumerState<SalesDeskScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  final ReportShareService _shareService = const ReportShareService();
  final SalesReceiptReportService _receiptReportService =
      SalesReceiptReportService();
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  final Map<String, _CartLineDraft> _cart = <String, _CartLineDraft>{};
  bool _isCheckingOut = false;
  bool _isSharingReceipt = false;
  String? _selectedFarmId;
  String? _selectedCustomerId;
  String? _activeReceiptNumber;
  String _category = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Transaction> transactions =
        ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final OperationsHubState operations = ref.watch(operationsHubProvider);
    final List<BusinessPartner> customers = operations.partners
        .where((BusinessPartner partner) =>
            partner.type == BusinessPartnerType.customer)
        .toList(growable: false);
    final String selectedFarmId = _ensureFarmSelected(farms);
    final List<InventoryItem> inventory = operations.inventory
        .where((InventoryItem item) =>
            selectedFarmId.isEmpty || item.farmId == selectedFarmId)
        .toList(growable: false);
    final List<InventoryItem> filteredProducts =
        inventory.where((InventoryItem item) {
      final String query = _searchController.text.trim().toLowerCase();
      if (_category != 'All' && item.category != _category) return false;
      if (query.isEmpty) return true;
      final String haystack =
          '${item.name} ${item.category} ${item.unit} ${item.emoji}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
    final List<Transaction> recentSales = transactions
        .where(
            (Transaction item) => item.recordKind == TransactionRecordKind.sale)
        .where((Transaction item) =>
            selectedFarmId.isEmpty || item.farmId == selectedFarmId)
        .toList(growable: false)
      ..sort((Transaction a, Transaction b) =>
          b.transactionDate.compareTo(a.transactionDate));
    final List<_ReceiptGroup> recentReceipts =
        _groupReceipts(recentSales).take(8).toList(growable: false);
    final _CheckoutTotals totals = _checkoutTotals();
    final BusinessPartner? selectedCustomer = _selectedCustomerId == null
        ? null
        : customers
            .where(
                (BusinessPartner partner) => partner.id == _selectedCustomerId)
            .cast<BusinessPartner?>()
            .firstOrNull;

    final ThemeData theme = Theme.of(context);
    final List<String> categories = <String>[
      'All',
      ...(inventory.map((InventoryItem i) => i.category).toSet().toList()
        ..sort()),
    ];
    final String activeCategory =
        categories.contains(_category) ? _category : 'All';
    final double todayRevenue = recentSales
        .where((Transaction sale) =>
            app_date.DateUtils.isToday(sale.transactionDate))
        .fold<double>(0, (double sum, Transaction sale) => sum + sale.amount);
    final int lowCount = inventory
        .where((InventoryItem i) => stockLevelOf(i) != StockLevel.ok)
        .length;

    final Widget body = SoftScreenScaffold(
      heroTitle: 'Sales desk',
      heroSubtitle: '',
      heroIcon: Icons.point_of_sale_rounded,
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
                  Text(
                    language.tr(
                        en: 'Sell', ha: 'Sayarwa', fr: 'Vendre'),
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    language.tr(
                      en: 'Tap a product to add it. Your cart is at the bottom.',
                      ha: 'Danna kaya don kara shi. Keken yana kasa.',
                      fr: 'Touchez un produit pour l\'ajouter. Le panier est en bas.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Add',
              onSelected: (String v) {
                if (v == 'product') {
                  if (farms.isNotEmpty) _openProductSheet();
                } else {
                  _openCustomerSheet(context);
                }
              },
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                    value: 'product', child: Text('Add product')),
                PopupMenuItem<String>(
                    value: 'customer', child: Text('Add customer')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        const FinanceNavBar(current: FinanceSection.sell),
        const SizedBox(height: 14),
        MetricStrip(
          stats: <MetricStat>[
            MetricStat(
              icon: Icons.payments_rounded,
              label: 'Sold today',
              value: CurrencyUtils.formatCurrency(todayRevenue),
            ),
            MetricStat(
              icon: Icons.receipt_rounded,
              label: 'Receipts',
              value: '${recentReceipts.length}',
              color: const Color(0xFF0EA5A4),
            ),
            MetricStat(
              icon: Icons.inventory_2_rounded,
              label: 'Products',
              value: '${inventory.length}',
              color: const Color(0xFF8B5CF6),
            ),
            MetricStat(
              icon: Icons.warning_amber_rounded,
              label: 'Low / out',
              value: '$lowCount',
              color: lowCount > 0
                  ? const Color(0xFFD99A1E)
                  : const Color(0xFF2E9E5B),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (farms.length > 1) ...<Widget>[
          _FarmSelector(
            farms: farms,
            selectedFarmId: selectedFarmId,
            onChanged: (String value) => setState(() {
              _selectedFarmId = value;
              _cart.clear();
              _selectedCustomerId = null;
              _category = 'All';
            }),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search products',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_searchController.clear),
                  ),
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
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int i) => ChoiceChip(
              label: Text(categories[i]),
              selected: categories[i] == activeCategory,
              onSelected: (_) => setState(() => _category = categories[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _pickCustomer(customers),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.person_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedCustomer == null
                        ? 'Selling to: Walk-in customer'
                        : 'Selling to: ${selectedCustomer.name}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.unfold_more_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (filteredProducts.isEmpty)
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  const Text('🧺', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text(
                    inventory.isEmpty
                        ? 'No products yet. Add one, or record a harvest to stock it.'
                        : 'Nothing matches that search.',
                    textAlign: TextAlign.center,
                  ),
                  if (inventory.isEmpty && farms.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _openProductSheet,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add product'),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          AdaptiveTileGrid(
            children: <Widget>[
              for (int i = 0; i < filteredProducts.length; i++)
                ProductTile(
                  key: ValueKey<String>(filteredProducts[i].id),
                  item: filteredProducts[i],
                  index: i,
                  subtitle: filteredProducts[i].category,
                  inCart: _cart[filteredProducts[i].id]?.quantity ?? 0,
                  onAdd: () => _addToCart(filteredProducts[i]),
                  onRemoveOne: () => _removeOne(filteredProducts[i]),
                  onOpen: () => _openProductDetails(filteredProducts[i]),
                ),
            ],
          ),
        const SizedBox(height: 18),
        _RecentReceiptsCard(
          language: language,
          receipts: recentReceipts,
          onOpenReceipt: (String receiptNumber) =>
              _openReceipt(context, receiptNumber),
        ),
        if (_activeReceiptNumber != null) ...<Widget>[
          const SizedBox(height: 18),
          _ReceiptPreviewSection(
            language: language,
            boundaryKey: _receiptBoundaryKey,
            receiptNumber: _activeReceiptNumber!,
            transactions:
                _transactionsForReceipt(transactions, _activeReceiptNumber!),
            farmName: _farmName(selectedFarmId),
            sellerName:
                ref.watch(firebaseServiceProvider).currentUser?.displayName ??
                    'FarmSync Seller',
          ),
        ],
        const SizedBox(height: 18),
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Customer handoff',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Share the receipt as an image (best for WhatsApp - it shows inline in the chat) or as a PDF, to WhatsApp, email, or any installed app.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton.primary(
                        onPressed: _activeReceiptNumber == null || _isSharingReceipt
                            ? null
                            : () => _shareReceiptAsImage(context),
                        child: _isSharingReceipt
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Share as image'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton.secondary(
                        onPressed: _activeReceiptNumber == null || _isSharingReceipt
                            ? null
                            : () => _shareReceipt(context),
                        child: const Text('Share as PDF'),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: body,
      bottomNavigationBar: CartBar(
        itemCount: _cart.length,
        total: totals.total,
        onOpen: _openCart,
      ),
    );
  }

  String _ensureFarmSelected(List<Farm> farms) {
    if (farms.isEmpty) {
      _selectedFarmId = null;
      return '';
    }
    if (_selectedFarmId == null ||
        farms.every((Farm farm) => farm.id != _selectedFarmId)) {
      _selectedFarmId = farms.first.id;
    }
    return _selectedFarmId ?? '';
  }

  InventoryItem? _productById(String productId) {
    final OperationsHubState operations = ref.read(operationsHubProvider);
    for (final InventoryItem item in operations.inventory) {
      if (item.id == productId) {
        return item;
      }
    }
    return null;
  }

  String _farmName(String farmId) {
    final List<Farm> farms = ref.read(farmsProvider).valueOrNull ?? <Farm>[];
    for (final Farm farm in farms) {
      if (farm.id == farmId) {
        return farm.name;
      }
    }
    return 'Unknown farm';
  }

  void _removeOne(InventoryItem item) {
    final _CartLineDraft? line = _cart[item.id];
    if (line == null) return;
    setState(() {
      if (line.quantity - 1 <= 0) {
        _cart.remove(item.id);
      } else {
        _cart[item.id] = line.copyWith(quantity: line.quantity - 1);
      }
    });
  }

  Future<void> _pickCustomer(List<BusinessPartner> customers) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(
        customers: customers,
        selectedId: _selectedCustomerId,
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == '__new__') {
      await _openCustomerSheet(context);
      return;
    }
    setState(() => _selectedCustomerId = picked.isEmpty ? null : picked);
  }

  Future<void> _openCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(owner: this),
    );
  }

  void _addToCart(InventoryItem item) {
    final double already = _cart[item.id]?.quantity ?? 0;
    if (already + 1 > item.availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Only ${formatQty(item.availableQuantity)} ${item.unit} of ${item.name} left.')),
      );
      return;
    }
    setState(() {
      final _CartLineDraft current = _cart[item.id] ??
          _CartLineDraft(quantity: 0, unitPrice: item.unitPrice);
      _cart[item.id] = current.copyWith(
          quantity: current.quantity + 1,
          unitPrice:
              current.unitPrice == 0 ? item.unitPrice : current.unitPrice);
    });
  }

  void _updateCartLine(InventoryItem item, _CartLineDraft draft) {
    setState(() {
      _cart[item.id] = draft;
    });
  }

  void _removeCartLine(String productId) {
    setState(() {
      _cart.remove(productId);
    });
  }

  _CheckoutTotals _checkoutTotals() {
    double subtotal = 0;
    double quantity = 0;
    _cart.forEach((String productId, _CartLineDraft line) {
      final InventoryItem? item = _productById(productId);
      if (item == null) {
        return;
      }
      subtotal += line.quantity * line.unitPrice;
      quantity += line.quantity;
    });
    return _CheckoutTotals(
        subtotal: subtotal, total: subtotal, quantity: quantity);
  }

  List<_ReceiptGroup> _groupReceipts(List<Transaction> sales) {
    final Map<String, List<Transaction>> grouped =
        <String, List<Transaction>>{};
    for (final Transaction sale in sales) {
      grouped
          .putIfAbsent(
              sale.receiptNumber.isEmpty ? sale.id : sale.receiptNumber,
              () => <Transaction>[])
          .add(sale);
    }
    return grouped.entries
        .map(
          (MapEntry<String, List<Transaction>> entry) => _ReceiptGroup(
            receiptNumber: entry.key,
            transactions: entry.value
              ..sort((Transaction a, Transaction b) =>
                  a.transactionDate.compareTo(b.transactionDate)),
          ),
        )
        .toList()
      ..sort((_ReceiptGroup a, _ReceiptGroup b) => b
          .transactions.first.transactionDate
          .compareTo(a.transactions.first.transactionDate));
  }

  List<Transaction> _transactionsForReceipt(
      List<Transaction> transactions, String receiptNumber) {
    final List<Transaction> receiptTransactions = transactions
        .where((Transaction transaction) =>
            transaction.receiptNumber == receiptNumber ||
            (transaction.receiptNumber.isEmpty &&
                transaction.id == receiptNumber))
        .toList(growable: false);
    receiptTransactions.sort((Transaction a, Transaction b) =>
        a.transactionDate.compareTo(b.transactionDate));
    return receiptTransactions;
  }

  Future<void> _checkout(BuildContext context) async {
    final List<Farm> farms = ref.read(farmsProvider).valueOrNull ?? <Farm>[];
    final OperationsHubState operations = ref.read(operationsHubProvider);
    final List<BusinessPartner> customers = operations.partners
        .where((BusinessPartner partner) =>
            partner.type == BusinessPartnerType.customer)
        .toList(growable: false);
    final String farmId =
        _selectedFarmId ?? (farms.isEmpty ? '' : farms.first.id);
    if (farmId.isEmpty || _cart.isEmpty) {
      return;
    }

    final BusinessPartner? customer = _selectedCustomerId == null
        ? null
        : customers
            .where(
                (BusinessPartner partner) => partner.id == _selectedCustomerId)
            .cast<BusinessPartner?>()
            .firstOrNull;
    final DateTime now = DateTime.now();
    final String receiptNumber = 'FS-SALE-${now.millisecondsSinceEpoch}';

    for (final MapEntry<String, _CartLineDraft> entry in _cart.entries) {
      final InventoryItem? product = _productById(entry.key);
      if (product == null) {
        continue;
      }
      if (entry.value.quantity > product.availableQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${product.name} does not have enough stock for that quantity.')),
        );
        return;
      }
    }

    setState(() => _isCheckingOut = true);
    try {
      for (final MapEntry<String, _CartLineDraft> entry in _cart.entries) {
        final InventoryItem? product = _productById(entry.key);
        if (product == null) {
          continue;
        }
        final _CartLineDraft line = entry.value;
        final Transaction transaction = Transaction(
          id: const Uuid().v4(),
          farmId: product.farmId,
          type: TransactionType.income,
          category: _transactionCategoryForItem(product),
          amount: line.quantity * line.unitPrice,
          description: '${product.name} sale',
          transactionDate: now,
          linkedEntityId: customer?.id ?? '',
          createdAt: now,
          updatedAt: now,
          isSynced: true,
          recordKind: TransactionRecordKind.sale,
          partyType: TransactionPartyType.customer,
          productName: product.name,
          quantity: line.quantity,
          unit: product.unit,
          unitPrice: line.unitPrice,
          counterpartyName: customer?.name ?? 'Walk-in customer',
          counterpartyEmail: customer?.email ?? '',
          counterpartyPhone: customer?.phone ?? '',
          receiptNumber: receiptNumber,
          notes: _notesController.text.trim().isEmpty
              ? 'Sale checked out from the FarmSync sales desk.'
              : _notesController.text.trim(),
        );
        await ref
            .read(transactionsProvider.notifier)
            .addTransaction(transaction);
        await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
              farmId: product.farmId,
              productName: product.name,
              unit: product.unit,
              deltaQuantity: -line.quantity,
              unitPrice: line.unitPrice,
              costPrice: product.costPrice,
              type: StockMovementType.sale,
              note: 'Sales desk receipt $receiptNumber',
              linkedEntityId: receiptNumber,
            );
      }

      if (!mounted) return;
      setState(() {
        _activeReceiptNumber = receiptNumber;
        _cart.clear();
        _notesController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Checkout complete. Receipt $receiptNumber is ready.')),
      );
      await _openReceipt(context, receiptNumber);
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  TransactionCategory _transactionCategoryForItem(InventoryItem item) {
    final String lower = '${item.category} ${item.name}'.toLowerCase();
    if (lower.contains('live') ||
        lower.contains('goat') ||
        lower.contains('sheep') ||
        lower.contains('cow') ||
        lower.contains('egg')) {
      return TransactionCategory.livestockSale;
    }
    return TransactionCategory.cropSale;
  }

  Future<void> _openReceipt(BuildContext context, String receiptNumber) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesReceiptScreen(
          receiptNumber: receiptNumber,
        ),
      ),
    );
  }

  Future<void> _shareReceipt(BuildContext context) async {
    final String? receiptNumber = _activeReceiptNumber;
    if (receiptNumber == null || _isSharingReceipt) {
      return;
    }
    final List<Transaction> transactions =
        ref.read(transactionsProvider).valueOrNull ?? <Transaction>[];
    final List<Transaction> receiptTransactions =
        _transactionsForReceipt(transactions, receiptNumber);
    if (receiptTransactions.isEmpty) {
      return;
    }
    setState(() => _isSharingReceipt = true);
    try {
      final List<Farm> farms = ref.read(farmsProvider).valueOrNull ?? <Farm>[];
      final String farmName = _farmName(receiptTransactions.first.farmId);
      final String sellerName =
          ref.read(firebaseServiceProvider).currentUser?.displayName ??
              'FarmSync Seller';
      final Uint8List bytes = await _receiptReportService.buildReceipt(
        transactions: receiptTransactions,
        farmName:
            farmName.isEmpty && farms.isNotEmpty ? farms.first.name : farmName,
        sellerName: sellerName,
      );
      final String fileName = 'receipt_$receiptNumber.pdf';
      final String savedPath =
          await _fileSaver.savePdf(bytes: bytes, fileName: fileName);
      await _shareService.sharePdf(
        filePath: savedPath,
        fileName: fileName,
        message: 'FarmSync receipt $receiptNumber',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharingReceipt = false);
      }
    }
  }

  Future<void> _shareReceiptAsImage(BuildContext context) async {
    final String? receiptNumber = _activeReceiptNumber;
    if (receiptNumber == null || _isSharingReceipt) {
      return;
    }
    setState(() => _isSharingReceipt = true);
    try {
      final Uint8List? imageBytes =
          await captureBoundaryImage(_receiptBoundaryKey);
      if (imageBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not capture the receipt image.')));
        }
        return;
      }
      final String fileName = 'receipt_$receiptNumber.png';
      final String savedPath = await _fileSaver.saveBytes(
        bytes: imageBytes,
        fileName: fileName,
        mimeType: 'image/png',
      );
      await _shareService.shareImage(
        filePath: savedPath,
        fileName: fileName,
        message: 'FarmSync receipt $receiptNumber',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharingReceipt = false);
      }
    }
  }

  Future<void> _openCustomerSheet(BuildContext context) async {
    final _PartnerDraft? draft = await showModalBottomSheet<_PartnerDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          const _PartnerSheet(defaultType: BusinessPartnerType.customer),
    );
    if (draft == null) {
      return;
    }
    final BusinessPartner partner = BusinessPartner(
      id: const Uuid().v4(),
      name: draft.name,
      email: draft.email,
      phone: draft.phone,
      type: BusinessPartnerType.customer,
      createdAt: DateTime.now(),
    );
    await ref.read(operationsHubProvider.notifier).addPartner(partner);
    if (!mounted) return;
    setState(() => _selectedCustomerId = partner.id);
  }

  Future<void> _openProductSheet() async {
    final List<Farm> farms = ref.read(farmsProvider).valueOrNull ?? <Farm>[];
    if (farms.isEmpty) return;
    final _ProductDraft? draft = await showModalBottomSheet<_ProductDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSheet(farms: farms),
    );
    if (draft == null) {
      return;
    }
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

  void _openProductDetails(InventoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ProductDetailsPreview(
            item: item, farmName: _farmName(item.farmId)),
      ),
    );
  }

  Future<void> _editCartLine(InventoryItem item) async {
    final _CartLineDraft current = _cart[item.id] ??
        _CartLineDraft(quantity: 1, unitPrice: item.unitPrice);
    final _CartLineDraft? draft = await showModalBottomSheet<_CartLineDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartLineEditorSheet(
        item: item,
        initialQuantity: current.quantity,
        initialUnitPrice:
            current.unitPrice == 0 ? item.unitPrice : current.unitPrice,
      ),
    );
    if (draft == null) {
      return;
    }
    setState(() {
      _cart[item.id] = draft;
    });
  }
}

class SalesReceiptScreen extends ConsumerStatefulWidget {
  const SalesReceiptScreen({
    super.key,
    required this.receiptNumber,
  });

  final String receiptNumber;

  @override
  ConsumerState<SalesReceiptScreen> createState() => _SalesReceiptScreenState();
}

class _SalesReceiptScreenState extends ConsumerState<SalesReceiptScreen> {
  final ReportFileSaver _fileSaver = createReportFileSaver();
  final ReportShareService _shareService = const ReportShareService();
  final SalesReceiptReportService _receiptReportService =
      SalesReceiptReportService();
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  bool _isExporting = false;
  bool _isSharing = false;
  bool _isSharingImage = false;

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final List<Transaction> transactions =
        ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final List<Transaction> receiptTransactions = transactions
        .where((Transaction transaction) =>
            transaction.receiptNumber == widget.receiptNumber ||
            (transaction.receiptNumber.isEmpty &&
                transaction.id == widget.receiptNumber))
        .toList(growable: false)
      ..sort((Transaction a, Transaction b) =>
          a.transactionDate.compareTo(b.transactionDate));
    final Transaction? first =
        receiptTransactions.isEmpty ? null : receiptTransactions.first;
    final String sellerName =
        ref.watch(firebaseServiceProvider).currentUser?.displayName ??
            'FarmSync Seller';
    final String farmName = first == null ? 'Farm' : _farmName(first.farmId);

    return Scaffold(
      appBar: AppBar(
        title: Text(language.tr(en: 'Receipt', ha: 'Rasit', fr: 'Recu')),
        actions: <Widget>[
          IconButton(
            tooltip: language.tr(
                en: 'Export PDF', ha: 'Fitar da PDF', fr: 'Exporter en PDF'),
            onPressed: receiptTransactions.isEmpty || _isExporting
                ? null
                : () =>
                    _exportReceipt(receiptTransactions, farmName, sellerName),
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded),
          ),
          IconButton(
            tooltip: language.tr(
                en: 'Share as image (best for WhatsApp)',
                ha: 'Raba a matsayin hoto (mafi kyau ga WhatsApp)',
                fr: 'Partager en image (ideal pour WhatsApp)'),
            onPressed: receiptTransactions.isEmpty || _isSharingImage
                ? null
                : _shareReceiptAsImage,
            icon: _isSharingImage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.image_rounded),
          ),
          IconButton(
            tooltip: language.tr(
                en: 'Share as PDF', ha: 'Raba a matsayin PDF', fr: 'Partager en PDF'),
            onPressed: receiptTransactions.isEmpty || _isSharing
                ? null
                : () =>
                    _shareReceipt(receiptTransactions, farmName, sellerName),
            icon: _isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            RepaintBoundary(
              key: _receiptBoundaryKey,
              child: _ReceiptCard(
                language: language,
                receiptTransactions: receiptTransactions,
                receiptNumber: widget.receiptNumber,
                farmName: farmName,
                sellerName: sellerName,
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                        language.tr(
                            en: 'Receipt actions',
                            ha: 'Ayyukan Rasit',
                            fr: 'Actions du recu'),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      language.tr(
                        en: 'This receipt is stored against every checkout line. You can export it as PDF or share it directly to other apps, including WhatsApp, email, and cloud drives.',
                        ha: 'Ana adana wannan rasit din da kowanne layin biya. Za ka iya fitar da shi a matsayin PDF ko ka raba shi kai tsaye zuwa wasu manhajoji, hada da WhatsApp, imel, da girgije.',
                        fr: 'Ce recu est enregistre avec chaque ligne de commande. Vous pouvez l\'exporter en PDF ou le partager directement vers d\'autres applications, dont WhatsApp, l\'e-mail et le cloud.',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _farmName(String farmId) {
    final List<Farm> farms = ref.read(farmsProvider).valueOrNull ?? <Farm>[];
    for (final Farm farm in farms) {
      if (farm.id == farmId) return farm.name;
    }
    return 'Farm';
  }

  Future<void> _exportReceipt(List<Transaction> receiptTransactions,
      String farmName, String sellerName) async {
    setState(() => _isExporting = true);
    try {
      final Uint8List bytes = await _receiptReportService.buildReceipt(
        transactions: receiptTransactions,
        farmName: farmName,
        sellerName: sellerName,
      );
      final String fileName = 'receipt_${widget.receiptNumber}.pdf';
      final String path =
          await _fileSaver.savePdf(bytes: bytes, fileName: fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Receipt saved to $path')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareReceipt(List<Transaction> receiptTransactions,
      String farmName, String sellerName) async {
    setState(() => _isSharing = true);
    try {
      final Uint8List bytes = await _receiptReportService.buildReceipt(
        transactions: receiptTransactions,
        farmName: farmName,
        sellerName: sellerName,
      );
      final String fileName = 'receipt_${widget.receiptNumber}.pdf';
      final String path =
          await _fileSaver.savePdf(bytes: bytes, fileName: fileName);
      await _shareService.sharePdf(
        filePath: path,
        fileName: fileName,
        message: 'FarmSync receipt ${widget.receiptNumber}',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _shareReceiptAsImage() async {
    setState(() => _isSharingImage = true);
    try {
      final Uint8List? imageBytes =
          await captureBoundaryImage(_receiptBoundaryKey);
      if (imageBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not capture the receipt image.')));
        }
        return;
      }
      final String fileName = 'receipt_${widget.receiptNumber}.png';
      final String path = await _fileSaver.saveBytes(
        bytes: imageBytes,
        fileName: fileName,
        mimeType: 'image/png',
      );
      await _shareService.shareImage(
        filePath: path,
        fileName: fileName,
        message: 'FarmSync receipt ${widget.receiptNumber}',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharingImage = false);
      }
    }
  }
}

class _FarmSelector extends StatelessWidget {
  const _FarmSelector({
    required this.farms,
    required this.selectedFarmId,
    required this.onChanged,
  });

  final List<Farm> farms;
  final String selectedFarmId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: farms.any((Farm farm) => farm.id == selectedFarmId)
          ? selectedFarmId
          : null,
      decoration: const InputDecoration(
        labelText: 'Active farm',
        border: OutlineInputBorder(),
      ),
      items: farms
          .map((Farm farm) =>
              DropdownMenuItem<String>(value: farm.id, child: Text(farm.name)))
          .toList(growable: false),
      onChanged: (String? value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _TotalsPanel extends StatelessWidget {
  const _TotalsPanel({required this.language, required this.totals});

  final AppLanguage language;
  final _CheckoutTotals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          _totalsRow(language.tr(en: 'Items', ha: 'Kayayyaki', fr: 'Articles'),
              totals.quantity.toStringAsFixed(2)),
          const SizedBox(height: 8),
          _totalsRow(
              language.tr(en: 'Subtotal', ha: 'Jimlar Kashi', fr: 'Sous-total'),
              CurrencyUtils.formatCurrency(totals.subtotal)),
          const SizedBox(height: 8),
          _totalsRow(
              language.tr(
                  en: 'Grand total', ha: 'Babbar Jimla', fr: 'Total general'),
              CurrencyUtils.formatCurrency(totals.total),
              emphasize: true),
        ],
      ),
    );
  }

  Widget _totalsRow(String label, String value, {bool emphasize = false}) {
    final TextStyle? style =
        emphasize ? const TextStyle(fontWeight: FontWeight.w800) : null;
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _RecentReceiptsCard extends StatelessWidget {
  const _RecentReceiptsCard({
    required this.language,
    required this.receipts,
    required this.onOpenReceipt,
  });

  final AppLanguage language;
  final List<_ReceiptGroup> receipts;
  final ValueChanged<String> onOpenReceipt;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
                language.tr(
                    en: 'Recent receipts',
                    ha: 'Rasitocin Baya-bayan nan',
                    fr: 'Recus recents'),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (receipts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  language.tr(
                    en: 'No receipts yet. Complete a checkout to see receipts here.',
                    ha: 'Babu rasit tukuna. Kammala biya domin ganin rasitoci a nan.',
                    fr: 'Aucun recu pour le moment. Finalisez une commande pour voir les recus ici.',
                  ),
                ),
              )
            else
              ...receipts.map(
                (_ReceiptGroup receipt) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    color: Theme.of(context).colorScheme.surface,
                    child: ListTile(
                      title: Text(receipt.receiptNumber,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${receipt.transactions.first.counterpartyName.isEmpty ? language.tr(en: 'Walk-in customer', ha: 'Abokin ciniki na zuwa kai tsaye', fr: 'Client de passage') : receipt.transactions.first.counterpartyName} • ${receipt.transactions.length} lines • ${CurrencyUtils.formatCurrency(receipt.total)}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => onOpenReceipt(receipt.receiptNumber),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptPreviewSection extends StatelessWidget {
  const _ReceiptPreviewSection({
    required this.language,
    required this.boundaryKey,
    required this.receiptNumber,
    required this.transactions,
    required this.farmName,
    required this.sellerName,
  });

  final AppLanguage language;
  final GlobalKey boundaryKey;
  final String receiptNumber;
  final List<Transaction> transactions;
  final String farmName;
  final String sellerName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                      language.tr(
                          en: 'Receipt preview',
                          ha: 'Duban Rasit',
                          fr: 'Apercu du recu'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Text(receiptNumber,
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 14),
            RepaintBoundary(
              key: boundaryKey,
              child: _ReceiptCard(
                language: language,
                receiptTransactions: transactions,
                receiptNumber: receiptNumber,
                farmName: farmName,
                sellerName: sellerName,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.language,
    required this.receiptTransactions,
    required this.receiptNumber,
    required this.farmName,
    required this.sellerName,
  });

  final AppLanguage language;
  final List<Transaction> receiptTransactions;
  final String receiptNumber;
  final String farmName;
  final String sellerName;

  @override
  Widget build(BuildContext context) {
    final Transaction first = receiptTransactions.first;
    final double total = receiptTransactions.fold<double>(
        0, (double sum, Transaction item) => sum + item.amount);
    return AppCard(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F5D8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.receipt_long_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Sales Receipt',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(receiptNumber),
                    ],
                  ),
                ),
                Text(CurrencyUtils.formatCurrency(total),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 18),
            _ReceiptLine(label: 'Farm', value: farmName),
            _ReceiptLine(label: 'Seller', value: sellerName),
            _ReceiptLine(
                label: 'Customer',
                value: first.counterpartyName.isEmpty
                    ? 'Walk-in customer'
                    : first.counterpartyName),
            _ReceiptLine(
                label: 'Email',
                value: first.counterpartyEmail.isEmpty
                    ? 'Not provided'
                    : first.counterpartyEmail),
            _ReceiptLine(
                label: 'Phone',
                value: first.counterpartyPhone.isEmpty
                    ? 'Not provided'
                    : first.counterpartyPhone),
            _ReceiptLine(
                label: 'Date',
                value: app_date.DateUtils.formatDate(first.transactionDate)),
            const SizedBox(height: 16),
            ...receiptTransactions.map(
              (Transaction item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBF5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                                item.productName.isEmpty
                                    ? item.description
                                    : item.productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                                '${item.quantity.toStringAsFixed(2)} ${item.unit} × ${CurrencyUtils.formatCurrency(item.unitPrice)}'),
                          ],
                        ),
                      ),
                      Text(CurrencyUtils.formatCurrency(item.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5DE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(first.notes.isEmpty
                  ? 'Generated by FarmSync sales desk.'
                  : first.notes),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _CartLineEditorSheet extends StatefulWidget {
  const _CartLineEditorSheet({
    required this.item,
    required this.initialQuantity,
    required this.initialUnitPrice,
  });

  final InventoryItem item;
  final double initialQuantity;
  final double initialUnitPrice;

  @override
  State<_CartLineEditorSheet> createState() => _CartLineEditorSheetState();
}

class _CartLineEditorSheetState extends State<_CartLineEditorSheet> {
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _quantityController =
        TextEditingController(text: widget.initialQuantity.toStringAsFixed(2));
    _priceController =
        TextEditingController(text: widget.initialUnitPrice.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 80),
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Edit cart line',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(widget.item.name,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            AppTextField(
              controller: _quantityController,
              label: 'Quantity',
              hint: 'Enter sold quantity',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _priceController,
              label: 'Unit price',
              hint: 'Override sale price',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton.secondary(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.primary(
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final double quantity = double.tryParse(_quantityController.text.trim()) ??
        widget.initialQuantity;
    final double unitPrice = double.tryParse(_priceController.text.trim()) ??
        widget.initialUnitPrice;
    Navigator.of(context).pop(
      _CartLineDraft(
          quantity: quantity <= 0 ? 1 : quantity,
          unitPrice: unitPrice < 0 ? 0 : unitPrice),
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
  final TextEditingController _categoryController =
      TextEditingController(text: 'Farm produce');
  final TextEditingController _unitController =
      TextEditingController(text: 'unit');
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String? _farmId;

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.firstOrNull?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 56),
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Create product',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _farmId,
                items: widget.farms
                    .map((Farm farm) => DropdownMenuItem<String>(
                        value: farm.id, child: Text(farm.name)))
                    .toList(growable: false),
                onChanged: (String? value) => setState(() => _farmId = value),
                decoration: const InputDecoration(
                    labelText: 'Farm', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _nameController,
                  label: 'Product name',
                  hint: 'e.g. Eggs'),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _categoryController,
                  label: 'Category',
                  hint: 'e.g. Livestock'),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _unitController,
                  label: 'Unit',
                  hint: 'e.g. crate'),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _quantityController,
                  label: 'Opening quantity',
                  hint: '0',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _costController,
                  label: 'Cost price',
                  hint: '0',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _priceController,
                  label: 'Sale price',
                  hint: '0',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.primary(
                      onPressed: _submit,
                      child: const Text('Save product'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_farmId == null || _nameController.text.trim().isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _ProductDraft(
        farmId: _farmId!,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'Farm produce'
            : _categoryController.text.trim(),
        unit: _unitController.text.trim().isEmpty
            ? 'unit'
            : _unitController.text.trim(),
        quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
        costPrice: double.tryParse(_costController.text.trim()) ?? 0,
        unitPrice: double.tryParse(_priceController.text.trim()) ?? 0,
        emoji: '🌾',
      ),
    );
  }
}

class _PartnerSheet extends StatefulWidget {
  const _PartnerSheet({this.defaultType = BusinessPartnerType.customer});

  final BusinessPartnerType defaultType;

  @override
  State<_PartnerSheet> createState() => _PartnerSheetState();
}

class _PartnerSheetState extends State<_PartnerSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  late BusinessPartnerType _type;

  @override
  void initState() {
    super.initState();
    _type = widget.defaultType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 56),
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Create customer',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              AppTextField(
                  controller: _nameController,
                  label: 'Name',
                  hint: 'Customer name'),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Optional email',
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  hint: 'Optional phone',
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.primary(
                      onPressed: _submit,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      _PartnerDraft(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        type: _type,
      ),
    );
  }
}

class _ProductDetailsPreview extends StatelessWidget {
  const _ProductDetailsPreview({
    required this.item,
    required this.farmName,
  });

  final InventoryItem item;
  final String farmName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(item.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 12),
                Text(item.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${item.category} • $farmName'),
                const SizedBox(height: 12),
                Text(
                    '${item.availableQuantity.toStringAsFixed(2)} ${item.unit} available'),
                const SizedBox(height: 6),
                Text('Cost ${CurrencyUtils.formatCurrency(item.costPrice)}'),
                const SizedBox(height: 6),
                Text('Sell ${CurrencyUtils.formatCurrency(item.unitPrice)}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartSheet extends StatefulWidget {
  const _CartSheet({required this.owner});

  final _SalesDeskScreenState owner;

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  _SalesDeskScreenState get owner => widget.owner;

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    if (owner._cart.isEmpty) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLanguage language = owner.ref.read(appLanguageProvider);
    final _CheckoutTotals totals = owner._checkoutTotals();
    final List<BusinessPartner> customers = owner.ref
        .read(operationsHubProvider)
        .partners
        .where((BusinessPartner p) => p.type == BusinessPartnerType.customer)
        .toList(growable: false);
    BusinessPartner? customer;
    for (final BusinessPartner p in customers) {
      if (p.id == owner._selectedCustomerId) customer = p;
    }
    final List<MapEntry<String, _CartLineDraft>> lines =
        owner._cart.entries.toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        language.tr(
                            en: 'Your cart',
                            ha: 'Keken Sayayya',
                            fr: 'Votre panier'),
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        owner.setState(owner._cart.clear);
                        _refresh();
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: <Widget>[
                    for (final MapEntry<String, _CartLineDraft> e in lines)
                      _line(context, e.key, e.value),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        await owner._pickCustomer(customers);
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.person_rounded,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                customer == null
                                    ? 'Walk-in customer'
                                    : customer.name,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text('Change',
                                style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: owner._notesController,
                      label: language.tr(
                          en: 'Receipt notes',
                          ha: 'Bayanin Rasit',
                          fr: 'Notes du recu'),
                      hint: language.tr(
                          en: 'Delivery or payment note (optional)',
                          ha: 'Bayanin isarwa ko biya (na zabi)',
                          fr: 'Note de livraison ou de paiement (facultatif)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    _TotalsPanel(language: language, totals: totals),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: owner._cart.isEmpty || owner._isCheckingOut
                        ? null
                        : () async {
                            final BuildContext deskContext = owner.context;
                            Navigator.of(context).pop();
                            await owner._checkout(deskContext);
                          },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(
                      '${language.tr(en: 'Complete sale', ha: 'Kammala Sayarwa', fr: 'Finaliser la vente')} - ${CurrencyUtils.formatCurrency(totals.total)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String id, _CartLineDraft draft) {
    final ThemeData theme = Theme.of(context);
    final InventoryItem? item = owner._productById(id);
    if (item == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: groupColor(item.group).withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                GestureDetector(
                  onTap: () async {
                    await owner._editCartLine(item);
                    if (mounted) setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${CurrencyUtils.formatCurrency(draft.unitPrice)} / ${item.unit}  ✎',
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                ),
                Text(
                  CurrencyUtils.formatCurrency(
                      draft.quantity * draft.unitPrice),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          Column(
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _StepperButton(
                    icon: Icons.remove_rounded,
                    onPressed: () {
                      owner._removeOne(item);
                      _refresh();
                    },
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      formatQty(draft.quantity),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  _StepperButton(
                    icon: Icons.add_rounded,
                    onPressed: () {
                      owner._addToCart(item);
                      _refresh();
                    },
                  ),
                ],
              ),
              TextButton(
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact),
                onPressed: () {
                  owner._removeCartLine(id);
                  _refresh();
                },
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({
    required this.customers,
    required this.selectedId,
  });

  final List<BusinessPartner> customers;
  final String? selectedId;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String q = _query.trim().toLowerCase();
    final List<BusinessPartner> shown = widget.customers
        .where((BusinessPartner p) =>
            q.isEmpty ||
            '${p.name} ${p.phone} ${p.email}'.toLowerCase().contains(q))
        .toList(growable: false);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Who is buying?',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                onChanged: (String v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search customers',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.directions_walk_rounded),
                      title: const Text('Walk-in customer'),
                      trailing: widget.selectedId == null
                          ? const Icon(Icons.check_circle_rounded)
                          : null,
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                    for (final BusinessPartner p in shown)
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(
                              p.name.isEmpty ? '?' : p.name[0].toUpperCase()),
                        ),
                        title: Text(p.name),
                        subtitle: p.phone.isEmpty ? null : Text(p.phone),
                        trailing: widget.selectedId == p.id
                            ? const Icon(Icons.check_circle_rounded)
                            : null,
                        onTap: () => Navigator.of(context).pop(p.id),
                      ),
                    ListTile(
                      leading: const Icon(Icons.person_add_alt_1_rounded),
                      title: const Text('New customer'),
                      onTap: () => Navigator.of(context).pop('__new__'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartLineDraft {
  const _CartLineDraft({
    required this.quantity,
    required this.unitPrice,
  });

  final double quantity;
  final double unitPrice;

  _CartLineDraft copyWith({
    double? quantity,
    double? unitPrice,
  }) {
    return _CartLineDraft(
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

class _ProductDraft {
  const _ProductDraft({
    required this.farmId,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.costPrice,
    required this.unitPrice,
    required this.emoji,
  });

  final String farmId;
  final String name;
  final String category;
  final String unit;
  final double quantity;
  final double costPrice;
  final double unitPrice;
  final String emoji;
}

class _PartnerDraft {
  const _PartnerDraft({
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
  });

  final String name;
  final String email;
  final String phone;
  final BusinessPartnerType type;
}

class _ReceiptGroup {
  const _ReceiptGroup({
    required this.receiptNumber,
    required this.transactions,
  });

  final String receiptNumber;
  final List<Transaction> transactions;

  double get total => transactions.fold<double>(
      0, (double sum, Transaction item) => sum + item.amount);
}

class _CheckoutTotals {
  const _CheckoutTotals({
    required this.subtotal,
    required this.total,
    required this.quantity,
  });

  final double subtotal;
  final double total;
  final double quantity;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
