import 'dart:typed_data';

import 'package:farmsynchub/core/services/report_file_saver_base.dart'
    show ReportFileSaver;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/operations_history_report_service.dart';
import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_share_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/procurement_order.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../../providers/procurement_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';

class ProcurementScreen extends ConsumerStatefulWidget {
  const ProcurementScreen({super.key});

  static const String routeName = '/procurement';

  @override
  ConsumerState<ProcurementScreen> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends ConsumerState<ProcurementScreen> {
  final OperationsHistoryReportService _reportService =
      OperationsHistoryReportService();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  final ReportShareService _shareService = const ReportShareService();
  final TextEditingController _searchController = TextEditingController();
  bool _isExporting = false;
  String _searchText = '';
  String _farmId = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(
            () => _searchText = _searchController.text.trim().toLowerCase());
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
    final AppLanguage language = ref.watch(appLanguageProvider);
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Transaction> allTransactions =
        ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final OperationsHubState operations = ref.watch(operationsHubProvider);
    final List<Transaction> procurement = allTransactions
        .where((Transaction item) =>
            item.recordKind == TransactionRecordKind.procurement)
        .where((Transaction item) => _farmId.isEmpty || item.farmId == _farmId)
        .where((Transaction item) {
      if (_searchText.isEmpty) return true;
      final String haystack =
          '${item.description} ${item.productName} ${item.counterpartyName} ${item.receiptNumber} ${item.notes}'
              .toLowerCase();
      return haystack.contains(_searchText);
    }).toList(growable: false)
      ..sort((Transaction a, Transaction b) =>
          b.transactionDate.compareTo(a.transactionDate));

    final double totalSpend = procurement.fold<double>(
        0, (double sum, Transaction item) => sum + item.amount);
    final double averageSpend =
        procurement.isEmpty ? 0 : totalSpend / procurement.length;
    final int supplierCount = procurement
        .map((Transaction item) => item.counterpartyName.trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go('/finance'),
        ),
        title: Text(language.tr(
            en: 'Procurement', ha: 'Sayayya', fr: 'Approvisionnement')),
        actions: <Widget>[
          IconButton(
            tooltip: language.tr(
                en: 'Export procurement history',
                ha: 'Fitar da tarihin sayayya',
                fr: 'Exporter l\'historique d\'approvisionnement'),
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            onPressed: procurement.isEmpty || _isExporting
                ? null
                : () => _exportHistory(context, farms, procurement, totalSpend),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                      language.tr(
                          en: 'Procurement management',
                          ha: 'Gudanar da Sayayya',
                          fr: 'Gestion des approvisionnements'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    language.tr(
                      en: 'Track supplier history, compare purchasing costs, and open the full workspace when you need to add a new procurement entry.',
                      ha: 'Bin diddigin tarihin masu bayar da kaya, kwatanta farashin sayayya, kuma ka bude cikakken wurin aiki idan kana bukatar kara sabon shigarwar sayayya.',
                      fr: 'Suivez l\'historique des fournisseurs, comparez les couts d\'achat et ouvrez l\'espace de travail complet pour ajouter une nouvelle entree d\'approvisionnement.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _MetricChip(
                          label: language.tr(
                              en: 'Entries', ha: 'Shigarwa', fr: 'Entrees'),
                          value: procurement.length.toString()),
                      _MetricChip(
                          label: language.tr(
                              en: 'Suppliers',
                              ha: 'Masu bayar da kaya',
                              fr: 'Fournisseurs'),
                          value: supplierCount.toString()),
                      _MetricChip(
                          label: language.tr(
                              en: 'Spend', ha: 'Kashewa', fr: 'Depenses'),
                          value:
                              CurrencyUtils.formatCompactCurrency(totalSpend)),
                      _MetricChip(
                          label: language.tr(
                              en: 'Average', ha: 'Matsakaici', fr: 'Moyenne'),
                          value: CurrencyUtils.formatCompactCurrency(
                              averageSpend)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      AppButton.primary(
                        onPressed: farms.isEmpty
                            ? null
                            : () => _openAddOrderSheet(context, farms),
                        child: Text(language.tr(
                            en: 'Add order',
                            ha: 'Kara Oda',
                            fr: 'Ajouter une commande')),
                      ),
                      AppButton.secondary(
                        onPressed: () => context.go('/finance'),
                        child: Text(language.tr(
                            en: 'Open workspace',
                            ha: 'Bude Wurin Aiki',
                            fr: 'Ouvrir l\'espace de travail')),
                      ),
                      AppButton.secondary(
                        onPressed: procurement.isEmpty || _isExporting
                            ? null
                            : () => _exportHistory(
                                context, farms, procurement, totalSpend),
                        child: Text(language.tr(
                            en: 'Share PDF',
                            ha: 'Raba PDF',
                            fr: 'Partager le PDF')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _TrackedOrdersSection(farmId: _farmId),
          const SizedBox(height: 16),
          if (operations.inventory.isNotEmpty) ...<Widget>[
            AppCard(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                        language.tr(
                            en: 'Stock-ready products',
                            ha: 'Kayan da suke a shirye',
                            fr: 'Produits prets en stock'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                        language.tr(
                          en: 'These products are available for procurement documentation and stock updates from the shared operations catalog.',
                          ha: 'Wadannan kayayyaki suna samuwa domin takardun sayayya da sabunta kaya daga jerin ayyukan da aka raba.',
                          fr: 'Ces produits sont disponibles pour la documentation d\'approvisionnement et les mises a jour de stock depuis le catalogue partage.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: operations.inventory
                          .where((InventoryItem item) =>
                              _farmId.isEmpty || item.farmId == _farmId)
                          .take(6)
                          .map(
                            (InventoryItem item) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('${item.emoji} ${item.name}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${item.availableQuantity.toStringAsFixed(0)} ${item.unit} • ${CurrencyUtils.formatCurrency(item.unitPrice)}'),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppTextField(
            controller: _searchController,
            label: language.tr(
                en: 'Search procurement',
                ha: 'Nemi Sayayya',
                fr: 'Rechercher un approvisionnement'),
            hint: language.tr(
                en: 'Search by supplier, product, receipt, or note',
                ha: 'Nemi ta mai bayar da kaya, kaya, rasit, ko bayani',
                fr: 'Rechercher par fournisseur, produit, recu ou note'),
            prefix: const Icon(Icons.search_rounded),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _FarmDropdown(
            farms: farms,
            value: _farmId,
            onChanged: (String value) => setState(() => _farmId = value),
          ),
          const SizedBox(height: 16),
          if (procurement.isEmpty)
            _EmptyState(
                message: language.tr(
              en: 'No procurement history matches the current filters.',
              ha: 'Babu tarihin sayayya da ya dace da tace-tacen yanzu.',
              fr: 'Aucun historique d\'approvisionnement ne correspond aux filtres actuels.',
            ))
          else
            ...procurement.map(
              (Transaction transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryCard(
                  title: transaction.productName.isEmpty
                      ? transaction.description
                      : transaction.productName,
                  subtitle: transaction.counterpartyName.isEmpty
                      ? language.tr(
                          en: 'Supplier not set',
                          ha: 'Ba a saita mai bayarwa ba',
                          fr: 'Fournisseur non defini')
                      : transaction.counterpartyName,
                  meta:
                      '${transaction.receiptNumber} • ${transaction.unit} • ${appDate(transaction.transactionDate)}',
                  amount: CurrencyUtils.formatCurrency(transaction.amount),
                ),
              ),
            ),
          const SizedBox(height: 10),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                language.tr(
                  en: 'Tip: procurement entries are fully managed in the Finance workspace, while this page gives you a focused buying history and export view.',
                  ha: 'Shawara: ana gudanar da shigarwar sayayya gaba daya a wurin aikin Kudi, yayin da wannan shafi ke ba ka takamaiman tarihin saye da fitarwa.',
                  fr: 'Astuce : les entrees d\'approvisionnement sont entierement gerees dans l\'espace Finances, tandis que cette page vous offre un historique d\'achat cible et une vue d\'export.',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportHistory(
    BuildContext context,
    List<Farm> farms,
    List<Transaction> procurement,
    double totalSpend,
  ) async {
    setState(() => _isExporting = true);
    try {
      final String fileName =
          'farmsync_procurement_history_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final Uint8List bytes = await _reportService.buildReport(
        title: 'Procurement history',
        subtitle: 'Supplier and buying history exported from FarmSync Hub',
        farms: farms,
        entries: procurement,
        income: 0,
        expenses: totalSpend,
        categoryTotals: _categoryTotals(procurement),
      );
      final String path =
          await _fileSaver.savePdf(bytes: bytes, fileName: fileName);
      await _shareService.sharePdf(
        filePath: path,
        fileName: fileName,
        message: 'FarmSync procurement history is ready to share.',
      );
      if (!context.mounted) return;
      final AppLanguage language = ref.read(appLanguageProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(language.tr(
                en: 'Procurement PDF saved: $path',
                ha: 'An adana PDF na sayayya: $path',
                fr: 'PDF d\'approvisionnement enregistre : $path'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Map<TransactionCategory, double> _categoryTotals(List<Transaction> items) {
    final Map<TransactionCategory, double> totals =
        <TransactionCategory, double>{};
    for (final Transaction item in items) {
      totals.update(
        item.category,
        (double value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }
    return totals;
  }

  Future<void> _openAddOrderSheet(
      BuildContext context, List<Farm> farms) async {
    final AppLanguage sheetLanguage = ref.read(appLanguageProvider);
    final ProcurementOrder? draft =
        await showModalBottomSheet<ProcurementOrder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddOrderSheet(
          language: sheetLanguage, farms: farms, initialFarmId: _farmId),
    );
    if (draft == null) {
      return;
    }
    await ref.read(procurementOrdersProvider.notifier).addOrder(draft);
    if (!context.mounted) return;
    final AppLanguage language = ref.read(appLanguageProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(language.tr(
              en: 'Order added to tracked procurement.',
              ha: 'An kara oda zuwa sayayyar da ake bibiya.',
              fr: 'Commande ajoutee au suivi d\'approvisionnement.'))),
    );
  }
}

class _TrackedOrdersSection extends ConsumerWidget {
  const _TrackedOrdersSection({required this.farmId});

  final String farmId;

  static const List<ProcurementOrderStatus> _statusOrder =
      <ProcurementOrderStatus>[
    ProcurementOrderStatus.pending,
    ProcurementOrderStatus.ordered,
    ProcurementOrderStatus.delivered,
    ProcurementOrderStatus.cancelled,
  ];

  String _statusLabel(AppLanguage language, ProcurementOrderStatus status) {
    switch (status) {
      case ProcurementOrderStatus.pending:
        return language.tr(en: 'Pending', ha: 'Ana jira', fr: 'En attente');
      case ProcurementOrderStatus.ordered:
        return language.tr(en: 'Ordered', ha: 'An yi oda', fr: 'Commande');
      case ProcurementOrderStatus.delivered:
        return language.tr(en: 'Delivered', ha: 'An kai', fr: 'Livre');
      case ProcurementOrderStatus.cancelled:
        return language.tr(en: 'Cancelled', ha: 'An soke', fr: 'Annule');
    }
  }

  Future<void> _markOrdered(WidgetRef ref, ProcurementOrder order) async {
    await ref.read(procurementOrdersProvider.notifier).updateOrder(
          order.copyWith(
              status: ProcurementOrderStatus.ordered,
              updatedAt: DateTime.now()),
        );
  }

  Future<void> _markDelivered(WidgetRef ref, ProcurementOrder order) async {
    await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
          farmId: order.farmId,
          productName: order.productName,
          unit: order.unit,
          deltaQuantity: order.quantity,
          unitPrice: order.unitPrice,
        );
    await ref.read(procurementOrdersProvider.notifier).updateOrder(
          order.copyWith(
              status: ProcurementOrderStatus.delivered,
              updatedAt: DateTime.now()),
        );
    // A delivered order is real money spent - record it as an expense so
    // it actually shows up in Finance/expense totals instead of only
    // moving stock silently. Previously this step was missing entirely,
    // so procurement done through "Add order" never counted as spend
    // anywhere in the app.
    final DateTime now = DateTime.now();
    await ref.read(transactionsProvider.notifier).addTransaction(
          Transaction(
            id: const Uuid().v4(),
            farmId: order.farmId,
            type: TransactionType.expense,
            category: _categoryFor(order.productName),
            amount: order.totalAmount,
            description: '${order.productName} delivered from ${order.providerName.isEmpty ? 'supplier' : order.providerName}',
            transactionDate: now,
            linkedEntityId: '',
            createdAt: now,
            updatedAt: now,
            isSynced: true,
            recordKind: TransactionRecordKind.procurement,
            partyType: TransactionPartyType.provider,
            productName: order.productName,
            quantity: order.quantity,
            unit: order.unit,
            unitPrice: order.unitPrice,
            counterpartyName: order.providerName,
            receiptNumber: 'PR-${now.millisecondsSinceEpoch}',
            notes: 'Auto-recorded when the tracked order was marked delivered.',
          ),
        );
  }

  TransactionCategory _categoryFor(String productName) {
    final String lower = productName.toLowerCase();
    if (lower.contains('feed')) return TransactionCategory.feed;
    if (lower.contains('fertil')) return TransactionCategory.fertiliser;
    if (lower.contains('vet') || lower.contains('vaccine') || lower.contains('drug')) {
      return TransactionCategory.veterinary;
    }
    return TransactionCategory.other;
  }

  Future<void> _cancel(WidgetRef ref, ProcurementOrder order) async {
    await ref.read(procurementOrdersProvider.notifier).updateOrder(
          order.copyWith(
              status: ProcurementOrderStatus.cancelled,
              updatedAt: DateTime.now()),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final AsyncValue<List<ProcurementOrder>> ordersAsync =
        ref.watch(procurementOrdersProvider);

    return ordersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (List<ProcurementOrder> orders) {
        final List<ProcurementOrder> filtered = orders
            .where((ProcurementOrder order) =>
                farmId.isEmpty || order.farmId == farmId)
            .toList(growable: false);
        if (filtered.isEmpty) {
          return const SizedBox.shrink();
        }

        return AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                    language.tr(
                        en: 'Tracked orders',
                        ha: 'Odar da ake bibiya',
                        fr: 'Commandes suivies'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  language.tr(
                    en: 'Mark an order "delivered" once stock physically arrives — that is what adds it to inventory.',
                    ha: 'Alama oda a matsayin "an kai" da zarar kaya ya iso a zahiri — wannan shine abin da ke kara shi cikin kaya.',
                    fr: 'Marquez une commande comme « livree » une fois le stock physiquement arrive — c\'est ce qui l\'ajoute a l\'inventaire.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                for (final ProcurementOrderStatus status in _statusOrder)
                  if (filtered.any((ProcurementOrder order) =>
                      order.status == status)) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _statusLabel(language, status),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ...filtered
                        .where(
                            (ProcurementOrder order) => order.status == status)
                        .map(
                          (ProcurementOrder order) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TrackedOrderCard(
                              language: language,
                              order: order,
                              onMarkOrdered: () => _markOrdered(ref, order),
                              onMarkDelivered: () => _markDelivered(ref, order),
                              onCancel: () => _cancel(ref, order),
                            ),
                          ),
                        ),
                    const SizedBox(height: 6),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrackedOrderCard extends StatelessWidget {
  const _TrackedOrderCard({
    required this.language,
    required this.order,
    required this.onMarkOrdered,
    required this.onMarkDelivered,
    required this.onCancel,
  });

  final AppLanguage language;
  final ProcurementOrder order;
  final VoidCallback onMarkOrdered;
  final VoidCallback onMarkDelivered;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bool canAct = order.status == ProcurementOrderStatus.pending ||
        order.status == ProcurementOrderStatus.ordered;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  order.productName,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                CurrencyUtils.formatCurrency(order.totalAmount),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${order.providerName.isEmpty ? language.tr(en: 'Provider not set', ha: 'Ba a saita mai bayarwa ba', fr: 'Fournisseur non defini') : order.providerName} • ${order.quantity.toStringAsFixed(0)} ${order.unit} • ${CurrencyUtils.formatCurrency(order.unitPrice)}/${order.unit}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            language.tr(
              en: 'Ordered ${appDate(order.orderDate)} • Expected ${appDate(order.expectedDeliveryDate)}',
              ha: 'An yi oda ${appDate(order.orderDate)} • Ana sa ran ${appDate(order.expectedDeliveryDate)}',
              fr: 'Commande le ${appDate(order.orderDate)} • Prevue le ${appDate(order.expectedDeliveryDate)}',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (canAct) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (order.status == ProcurementOrderStatus.pending)
                  TextButton(
                      onPressed: onMarkOrdered,
                      child: Text(language.tr(
                          en: 'Mark ordered',
                          ha: 'Alama an yi oda',
                          fr: 'Marquer comme commande'))),
                TextButton(
                    onPressed: onMarkDelivered,
                    child: Text(language.tr(
                        en: 'Mark delivered',
                        ha: 'Alama an kai',
                        fr: 'Marquer comme livre'))),
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                  child: Text(
                      language.tr(en: 'Cancel', ha: 'Soke', fr: 'Annuler')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddOrderSheet extends StatefulWidget {
  const _AddOrderSheet({
    required this.language,
    required this.farms,
    required this.initialFarmId,
  });

  final AppLanguage language;
  final List<Farm> farms;
  final String initialFarmId;

  @override
  State<_AddOrderSheet> createState() => _AddOrderSheetState();
}

class _AddOrderSheetState extends State<_AddOrderSheet> {
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController =
      TextEditingController(text: 'unit');
  final TextEditingController _unitPriceController = TextEditingController();
  String? _farmId;
  DateTime _orderDate = DateTime.now();
  DateTime _expectedDeliveryDate = DateTime.now().add(const Duration(days: 3));

  @override
  void initState() {
    super.initState();
    _farmId = widget.initialFarmId.isNotEmpty
        ? widget.initialFarmId
        : widget.farms.firstOrNull?.id;
  }

  @override
  void dispose() {
    _providerController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_quantityController.text.trim()) ?? 0;
  double get _unitPrice =>
      double.tryParse(_unitPriceController.text.trim()) ?? 0;
  double get _total => _quantity * _unitPrice;

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
              Text(
                  widget.language.tr(
                      en: 'Add procurement order',
                      ha: 'Kara oda na sayayya',
                      fr: 'Ajouter une commande d\'approvisionnement'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _farmId,
                items: widget.farms
                    .map((Farm farm) => DropdownMenuItem<String>(
                        value: farm.id, child: Text(farm.name)))
                    .toList(growable: false),
                onChanged: (String? value) => setState(() => _farmId = value),
                decoration: InputDecoration(
                    labelText:
                        widget.language.tr(en: 'Farm', ha: 'Gona', fr: 'Ferme'),
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _providerController,
                  label: widget.language.tr(
                      en: 'Supplier / provider',
                      ha: 'Mai bayarwa',
                      fr: 'Fournisseur'),
                  hint: 'e.g. Jos Agro Supplies'),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _productController,
                  label: widget.language
                      .tr(en: 'Product', ha: 'Kaya', fr: 'Produit'),
                  hint: 'e.g. Broiler feed'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _quantityController,
                      label: widget.language
                          .tr(en: 'Quantity', ha: 'Yawa', fr: 'Quantite'),
                      hint: '0',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                        controller: _unitController,
                        label: widget.language
                            .tr(en: 'Unit', ha: 'Naúi', fr: 'Unite'),
                        hint: 'e.g. bag'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _unitPriceController,
                label: widget.language.tr(
                    en: 'Unit price', ha: 'Farashin naúi', fr: 'Prix unitaire'),
                hint: '0',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(widget.language
                        .tr(en: 'Total', ha: 'Jimla', fr: 'Total')),
                    Text(
                      CurrencyUtils.formatCurrency(_total),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DatePickerField(
                      label: widget.language.tr(
                          en: 'Order date',
                          ha: 'Ranar oda',
                          fr: 'Date de commande'),
                      value: _orderDate,
                      onChanged: (DateTime value) =>
                          setState(() => _orderDate = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatePickerField(
                      label: widget.language.tr(
                          en: 'Expected delivery',
                          ha: 'Ranar kai da ake sa ran',
                          fr: 'Livraison prevue'),
                      value: _expectedDeliveryDate,
                      onChanged: (DateTime value) =>
                          setState(() => _expectedDeliveryDate = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(widget.language
                          .tr(en: 'Cancel', ha: 'Soke', fr: 'Annuler')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.primary(
                      onPressed: _canSubmit ? _submit : null,
                      child: Text(widget.language.tr(
                          en: 'Save order',
                          ha: 'Ajiye oda',
                          fr: 'Enregistrer la commande')),
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

  bool get _canSubmit =>
      _farmId != null &&
      _productController.text.trim().isNotEmpty &&
      _quantity > 0 &&
      _unitPrice > 0;

  void _submit() {
    if (!_canSubmit) {
      return;
    }
    final DateTime now = DateTime.now();
    Navigator.of(context).pop(
      ProcurementOrder(
        id: const Uuid().v4(),
        farmId: _farmId!,
        providerName: _providerController.text.trim(),
        productName: _productController.text.trim(),
        quantity: _quantity,
        unit: _unitController.text.trim().isEmpty
            ? 'unit'
            : _unitController.text.trim(),
        unitPrice: _unitPrice,
        totalAmount: _total,
        orderDate: _orderDate,
        expectedDeliveryDate: _expectedDeliveryDate,
        status: ProcurementOrderStatus.pending,
        createdAt: now,
        updatedAt: now,
        isSynced: false,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        child: Text(appDate(value)),
      ),
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
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      decoration: const InputDecoration(labelText: 'Farm'),
      items: <DropdownMenuItem<String>>[
        const DropdownMenuItem<String>(value: '', child: Text('All farms')),
        ...farms.map(
          (Farm farm) => DropdownMenuItem<String>(
            value: farm.id,
            child: Text(farm.name),
          ),
        ),
      ],
      onChanged: (String? next) => onChanged(next ?? ''),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.amount,
  });

  final String title;
  final String subtitle;
  final String meta;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(title),
        subtitle: Text('$subtitle\n$meta'),
        isThreeLine: true,
        trailing: Text(amount,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
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

String appDate(DateTime dateTime) =>
    '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
