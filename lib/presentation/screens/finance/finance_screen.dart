import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/finance_report_service.dart';
import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_file_saver_base.dart';
import '../../../core/services/report_share_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../core/utils/validators.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/procurement_order.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../../providers/procurement_provider.dart';
import 'market_trends_screen.dart';
import 'finance_workspace_screen.dart';
import 'finance_ai_recap_screen.dart';
import '../sales/sales_desk_screen.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final FinanceReportService _reportService = FinanceReportService();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  final ReportShareService _shareService = const ReportShareService();
  bool _isExporting = false;

  /// Period filter: 0 = this week, 1 = this month, 2 = this year
  int _selectedPeriodIndex = 1;

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Transaction> transactions =
        ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final List<Transaction> periodTransactions =
        _filterByPeriod(transactions, _selectedPeriodIndex);
    final FinanceSnapshot snapshot =
        FinanceSnapshot.fromTransactions(periodTransactions);
    final List<Transaction> sales = periodTransactions
        .where(
            (Transaction item) => item.recordKind == TransactionRecordKind.sale)
        .toList(growable: false);
    final List<Transaction> procurement = periodTransactions
        .where((Transaction item) =>
            item.recordKind == TransactionRecordKind.procurement)
        .toList(growable: false);
    final List<Transaction> recentActivities = transactions.toList(
        growable: false)
      ..sort((Transaction a, Transaction b) =>
          b.transactionDate.compareTo(a.transactionDate));
    final List<Transaction> topRecentActivities =
        recentActivities.take(6).toList(growable: false);
    final List<InventoryItem> inventory =
        ref.watch(operationsHubProvider).inventory;
    final List<ProcurementOrder> procurementOrders =
        ref.watch(procurementOrdersProvider).valueOrNull ??
            <ProcurementOrder>[];

    final expenseCategories = _buildExpenseCategories(snapshot.categoryTotals);
    final List<Transaction> previousPeriodTransactions =
        _filterByPreviousPeriod(transactions, _selectedPeriodIndex);
    final FinanceSnapshot previousSnapshot =
        FinanceSnapshot.fromTransactions(previousPeriodTransactions);
    final double incomeChange = _percentChange(
        current: snapshot.income, previous: previousSnapshot.income);
    final double expenseChange = _percentChange(
        current: snapshot.expenses, previous: previousSnapshot.expenses);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAddMenu(context, farms),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            children: <Widget>[
              // ─── PREMIUM GRADIENT HERO HEADER ─────────────────────────
              _PremiumHeroHeader(
                language: language,
                balance: snapshot.balance,
                income: snapshot.income,
                expenses: snapshot.expenses,
                incomeChange: incomeChange,
                expenseChange: expenseChange,
                selectedPeriodIndex: _selectedPeriodIndex,
                onPeriodChanged: (index) =>
                    setState(() => _selectedPeriodIndex = index),
              ),

              // ─── QUICK ACTION STRIP ────────────────────────────────────
              _QuickActionStrip(
                language: language,
                farms: farms,
                sales: sales,
                procurement: procurement,
                transactions: recentActivities,
                snapshot: snapshot,
                onExport: _isExporting || transactions.isEmpty
                    ? null
                    : () => _exportReport(snapshot, transactions),
              ),

              const SizedBox(height: 24),

              // ─── SPENDING BREAKDOWN ────────────────────────────────────
              if (expenseCategories.isNotEmpty)
                _SpendingBreakdownCard(
                  language: language,
                  categories: expenseCategories,
                  totalExpenses: snapshot.expenses,
                ),

              if (expenseCategories.isNotEmpty) const SizedBox(height: 20),

              // ─── RECENT ACTIVITY FEED ──────────────────────────────────
              _RecentActivityCard(
                language: language,
                activities: topRecentActivities,
                onViewAll: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FinanceWorkspaceScreen(),
                  ),
                ),
                onTapTransaction: (Transaction transaction) =>
                    _openReceiptDetail(context, transaction),
              ),

              const SizedBox(height: 20),

              // ─── SMART INSIGHTS CARD ──────────────────────────────────
              _SmartInsightsCard(
                language: language,
                farmCount: farms.length,
                transactionCount: transactions.length,
                topCategory: expenseCategories.isNotEmpty
                    ? expenseCategories.first.name
                    : 'N/A',
                income: snapshot.income,
                expenses: snapshot.expenses,
              ),

              const SizedBox(height: 20),

              // ─── INVENTORY & PROCUREMENT CARD ─────────────────────────
              _InventoryProcurementCard(
                language: language,
                inventory: inventory,
                procurementOrders: procurementOrders,
                onManage: () => context.go('/procurement'),
              ),

              const SizedBox(height: 20),

              // ─── QUICK EXPORT BAR ──────────────────────────────────────
              _QuickExportBar(
                language: language,
                isExporting: _isExporting,
                hasTransactions: transactions.isNotEmpty,
                onExport: () => _exportReport(snapshot, transactions),
                onShareSummary: () => _shareSummary(snapshot, transactions),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Filters transactions to the selected period (0 = week, 1 = month, 2 = year).
  List<Transaction> _filterByPeriod(
      List<Transaction> transactions, int periodIndex) {
    final DateTime now = DateTime.now();
    final DateTime start = switch (periodIndex) {
      0 => DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6)),
      2 => DateTime(now.year, 1, 1),
      _ => DateTime(now.year, now.month, 1),
    };
    return transactions
        .where((Transaction item) => !item.transactionDate.isBefore(start))
        .toList(growable: false);
  }

  /// Filters transactions to the period immediately before the selected one,
  /// so the hero header can show a real period-over-period trend instead of
  /// a fixed placeholder percentage.
  List<Transaction> _filterByPreviousPeriod(
      List<Transaction> transactions, int periodIndex) {
    final DateTime now = DateTime.now();
    final DateTime start;
    final DateTime end;
    switch (periodIndex) {
      case 0:
        end = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        start = end.subtract(const Duration(days: 7));
        break;
      case 2:
        start = DateTime(now.year - 1, 1, 1);
        end = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 1);
    }
    return transactions
        .where((Transaction item) =>
            !item.transactionDate.isBefore(start) &&
            item.transactionDate.isBefore(end))
        .toList(growable: false);
  }

  double _percentChange({required double current, required double previous}) {
    if (previous <= 0) {
      return current > 0 ? 100 : 0;
    }
    return ((current - previous) / previous) * 100;
  }

  Future<void> _showQuickAddMenu(BuildContext context, List<Farm> farms) async {
    final _QuickAddAction? action = await showModalBottomSheet<_QuickAddAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _QuickAddMenu(hasFarms: farms.isNotEmpty),
    );
    if (action == null || !context.mounted) {
      return;
    }
    switch (action) {
      case _QuickAddAction.transaction:
        await _openTransactionSheet(context, farms: farms);
        break;
      case _QuickAddAction.inventory:
        await _openInventorySheet(context, farms);
        break;
      case _QuickAddAction.contact:
        await _openPartnerSheet(context);
        break;
      case _QuickAddAction.manageContacts:
        await _openContactsList(context);
        break;
    }
  }

  List<_ExpenseCategoryData> _buildExpenseCategories(
      Map<TransactionCategory, double> categoryTotals) {
    final List<MapEntry<TransactionCategory, double>> sorted =
        categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(5)
        .map((entry) => _ExpenseCategoryData(
              name: _categoryLabel(entry.key),
              icon: _categoryIcon(entry.key),
              amount: entry.value,
              color: _categoryColor(entry.key),
            ))
        .toList();
  }

  Future<void> _exportReport(
      FinanceSnapshot snapshot, List<Transaction> transactions) async {
    setState(() => _isExporting = true);
    try {
      final String fileName =
          'farmsync_finance_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final Uint8List bytes = await _reportService.buildFinanceReport(
        transactions: transactions,
        income: snapshot.income,
        expenses: snapshot.expenses,
        balance: snapshot.balance,
        categoryTotals: snapshot.categoryTotals,
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported: $savedPath')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareSummary(
      FinanceSnapshot snapshot, List<Transaction> transactions) async {
    setState(() => _isExporting = true);
    try {
      final String fileName =
          'farmsync_summary_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final Uint8List bytes = await _reportService.buildFinanceReport(
        transactions: transactions,
        income: snapshot.income,
        expenses: snapshot.expenses,
        balance: snapshot.balance,
        categoryTotals: snapshot.categoryTotals,
      );
      final String savedPath = await _fileSaver.savePdf(
        bytes: bytes,
        fileName: fileName,
      );
      await _shareService.sharePdf(
        filePath: savedPath,
        fileName: fileName,
        message: 'FarmSync finance summary is ready to share.',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Summary exported: $savedPath')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _openPartnerSheet(BuildContext context,
      {BusinessPartner? existing}) async {
    final _PartnerDraft? draft = await showModalBottomSheet<_PartnerDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _PartnerSheet(existing: existing),
    );
    if (draft == null) {
      return;
    }
    if (existing != null) {
      await ref.read(operationsHubProvider.notifier).updatePartner(
            BusinessPartner(
              id: existing.id,
              name: draft.name,
              email: draft.email,
              phone: draft.phone,
              type: draft.type,
              createdAt: existing.createdAt,
            ),
          );
      return;
    }
    await ref.read(operationsHubProvider.notifier).addPartner(
          BusinessPartner(
            id: const Uuid().v4(),
            name: draft.name,
            email: draft.email,
            phone: draft.phone,
            type: draft.type,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> _openContactsList(BuildContext rootContext) async {
    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final List<BusinessPartner> partners =
              ref.watch(operationsHubProvider).partners;
          return _ContactsListSheet(
            partners: partners,
            onEdit: (BusinessPartner partner) async {
              Navigator.of(sheetContext).pop();
              if (!rootContext.mounted) {
                return;
              }
              await _openPartnerSheet(rootContext, existing: partner);
            },
            onDelete: (BusinessPartner partner) async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) => AlertDialog(
                  title: const Text('Remove contact?'),
                  content: Text('Remove "${partner.name}" from contacts?'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref
                    .read(operationsHubProvider.notifier)
                    .deletePartner(partner.id);
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _openInventorySheet(
      BuildContext context, List<Farm> farms) async {
    final _InventoryDraft? draft = await showModalBottomSheet<_InventoryDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _InventorySheet(farms: farms),
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
          ),
        );
  }

  Future<void> _openTransactionSheet(BuildContext context,
      {required List<Farm> farms}) async {
    final OperationsHubState operations = ref.read(operationsHubProvider);
    final _TransactionDraft? draft =
        await showModalBottomSheet<_TransactionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _TransactionFormSheet(
        farms: farms,
        operations: operations,
      ),
    );
    if (draft == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final Transaction transaction = Transaction(
      id: const Uuid().v4(),
      farmId: draft.farmId,
      type: draft.type,
      category: draft.category,
      amount: draft.amount,
      description: draft.description,
      transactionDate: draft.transactionDate,
      linkedEntityId: draft.partnerId,
      createdAt: now,
      updatedAt: now,
      isSynced: true,
      recordKind: draft.recordKind,
      partyType: draft.partyType,
      productName: draft.productName,
      quantity: draft.quantity,
      unit: draft.unit,
      unitPrice: draft.unitPrice,
      counterpartyName: draft.counterpartyName,
      counterpartyEmail: draft.counterpartyEmail,
      counterpartyPhone: draft.counterpartyPhone,
      receiptNumber: 'FS-${DateTime.now().millisecondsSinceEpoch}',
      notes: draft.notes,
    );
    await ref.read(transactionsProvider.notifier).addTransaction(transaction);

    final double delta = draft.recordKind == TransactionRecordKind.sale
        ? -draft.quantity
        : draft.recordKind == TransactionRecordKind.procurement
            ? draft.quantity
            : 0;
    if (delta != 0 && draft.productName.trim().isNotEmpty) {
      await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
            farmId: draft.farmId,
            productName: draft.productName,
            unit: draft.unit,
            deltaQuantity: delta,
            unitPrice: draft.unitPrice,
          );
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          draft.recordKind == TransactionRecordKind.sale
              ? 'Sale recorded and receipt generated.'
              : draft.recordKind == TransactionRecordKind.procurement
                  ? 'Procurement recorded successfully.'
                  : 'Transaction recorded successfully.',
        ),
      ),
    );
  }

  void _openReceiptDetail(BuildContext context, Transaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptDetailScreen(transaction: transaction),
      ),
    );
  }
}

String _categoryLabel(TransactionCategory category) {
  switch (category) {
    case TransactionCategory.cropSale:
      return 'Crop Sales';
    case TransactionCategory.livestockSale:
      return 'Livestock Sales';
    case TransactionCategory.feed:
      return 'Feed';
    case TransactionCategory.fertiliser:
      return 'Fertiliser';
    case TransactionCategory.labour:
      return 'Labour';
    case TransactionCategory.veterinary:
      return 'Veterinary';
    case TransactionCategory.other:
      return 'Other';
  }
}

IconData _categoryIcon(TransactionCategory category) {
  switch (category) {
    case TransactionCategory.cropSale:
      return Icons.spa_rounded;
    case TransactionCategory.livestockSale:
      return Icons.pets_rounded;
    case TransactionCategory.feed:
      return Icons.grass_rounded;
    case TransactionCategory.fertiliser:
      return Icons.science_rounded;
    case TransactionCategory.labour:
      return Icons.engineering_rounded;
    case TransactionCategory.veterinary:
      return Icons.medical_services_rounded;
    case TransactionCategory.other:
      return Icons.more_horiz_rounded;
  }
}

Color _categoryColor(TransactionCategory category) {
  switch (category) {
    case TransactionCategory.cropSale:
      return const Color(0xFF32D583);
    case TransactionCategory.livestockSale:
      return const Color(0xFF14B8A6);
    case TransactionCategory.feed:
      return const Color(0xFFFBBF24);
    case TransactionCategory.fertiliser:
      return const Color(0xFF8B5CF6);
    case TransactionCategory.labour:
      return const Color(0xFFF97316);
    case TransactionCategory.veterinary:
      return const Color(0xFFEF4444);
    case TransactionCategory.other:
      return const Color(0xFF8A93A2);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _PremiumHeroHeader extends StatelessWidget {
  const _PremiumHeroHeader({
    required this.language,
    required this.balance,
    required this.income,
    required this.expenses,
    required this.incomeChange,
    required this.expenseChange,
    required this.selectedPeriodIndex,
    required this.onPeriodChanged,
  });

  final AppLanguage language;
  final double balance;
  final double income;
  final double expenses;
  final double incomeChange;
  final double expenseChange;
  final int selectedPeriodIndex;
  final ValueChanged<int> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<String> periods = <String>[
      language.tr(en: 'Week', ha: 'Mako', fr: 'Semaine'),
      language.tr(en: 'Month', ha: 'Wata', fr: 'Mois'),
      language.tr(en: 'Year', ha: 'Shekara', fr: 'Annee'),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[
                  const Color(0xFF0D1B1A),
                  const Color(0xFF0A1628),
                ]
              : <Color>[
                  const Color(0xFF0F3D3E),
                  const Color(0xFF1A5B5C),
                  const Color(0xFF103F4B),
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Decorative circles
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Back + Title row
                Row(
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.of(context).canPop()
                            ? Navigator.of(context).pop()
                            : context.go('/dashboard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      language.tr(en: 'Finance', ha: 'Kudi', fr: 'Finances'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.more_horiz_rounded,
                            color: Colors.white),
                        onPressed: () => context.go('/settings'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Balance label
                Text(
                  language.tr(
                      en: 'Total Balance',
                      ha: 'Jimlar Ma\'auni',
                      fr: 'Solde total'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),

                // Balance amount
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyUtils.formatCurrency(balance),
                    maxLines: 1,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Income / Expense row
                Row(
                  children: <Widget>[
                    // Income
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF32D583).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.trending_up_rounded,
                                color: Color(0xFF32D583),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    language.tr(
                                        en: 'Income',
                                        ha: 'Kudin shiga',
                                        fr: 'Revenus'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      CurrencyUtils.formatCompactCurrency(
                                          income),
                                      maxLines: 1,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (incomeChange != 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: incomeChange > 0
                                      ? const Color(0xFF32D583).withOpacity(0.2)
                                      : const Color(0xFFEF4444)
                                          .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${incomeChange > 0 ? '+' : ''}${incomeChange.toStringAsFixed(1)}%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: incomeChange > 0
                                        ? const Color(0xFF32D583)
                                        : const Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Expense
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.trending_down_rounded,
                                color: Color(0xFFF97316),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    language.tr(
                                        en: 'Expenses',
                                        ha: 'Kashewa',
                                        fr: 'Depenses'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      CurrencyUtils.formatCompactCurrency(
                                          expenses),
                                      maxLines: 1,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (expenseChange != 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: expenseChange < 0
                                      ? const Color(0xFF32D583).withOpacity(0.2)
                                      : const Color(0xFFEF4444)
                                          .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${expenseChange > 0 ? '+' : ''}${expenseChange.toStringAsFixed(1)}%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: expenseChange < 0
                                        ? const Color(0xFF32D583)
                                        : const Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Period selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(
                    periods.length,
                    (int index) => Padding(
                      padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 8, right: index == 2 ? 0 : 8),
                      child: GestureDetector(
                        onTap: () => onPeriodChanged(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: selectedPeriodIndex == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            periods[index],
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: selectedPeriodIndex == index
                                  ? const Color(0xFF0F3D3E)
                                  : Colors.white.withOpacity(0.8),
                              fontWeight: selectedPeriodIndex == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK ACTION STRIP
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickActionStrip extends StatelessWidget {
  const _QuickActionStrip({
    required this.language,
    required this.farms,
    required this.sales,
    required this.procurement,
    required this.transactions,
    required this.snapshot,
    required this.onExport,
  });

  final AppLanguage language;
  final List<Farm> farms;
  final List<Transaction> sales;
  final List<Transaction> procurement;
  final List<Transaction> transactions;
  final FinanceSnapshot snapshot;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final List<_QuickActionItem> actions = <_QuickActionItem>[
      _QuickActionItem(
        icon: Icons.point_of_sale_rounded,
        label: language.tr(
            en: 'Sales Desk',
            ha: 'Tebur Tallace-tallace',
            fr: 'Bureau des ventes'),
        color: const Color(0xFF32D583),
        onTap: () => context.go(SalesDeskScreen.routeName),
      ),
      _QuickActionItem(
        icon: Icons.receipt_long_outlined,
        label: language.tr(en: 'Expenses', ha: 'Kashewa', fr: 'Depenses'),
        color: const Color(0xFFF97316),
        onTap: () => context.go('/expenses'),
      ),
      _QuickActionItem(
        icon: Icons.shopping_cart_outlined,
        label: language.tr(
            en: 'Procurement', ha: 'Sayayya', fr: 'Approvisionnement'),
        color: const Color(0xFF8B5CF6),
        onTap: () => context.go('/procurement'),
      ),
      _QuickActionItem(
        icon: Icons.auto_awesome_rounded,
        label: language.tr(en: 'AI Recap', ha: 'Takaitawar AI', fr: 'Recap IA'),
        color: const Color(0xFF14B8A6),
        onTap: () => context.push(FinanceAiRecapScreen.routeName),
      ),
      _QuickActionItem(
        icon: Icons.show_chart_rounded,
        label: language.tr(en: 'Market', ha: 'Kasuwa', fr: 'Marche'),
        color: const Color(0xFF3B82F6),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const MarketTrendsScreen(),
          ),
        ),
      ),
      _QuickActionItem(
        icon: Icons.grid_view_rounded,
        label: language.tr(
            en: 'Workspace', ha: 'Wurin aiki', fr: 'Espace de travail'),
        color: const Color(0xFF8A93A2),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const FinanceWorkspaceScreen(),
          ),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: <Widget>[
                Text(
                  language.tr(
                      en: 'Quick Actions',
                      ha: 'Ayyuka Masu Sauri',
                      fr: 'Actions rapides'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${farms.length} farms · ${sales.length + procurement.length} records',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: actions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (BuildContext context, int index) {
                final _QuickActionItem action = actions[index];
                return _ActionCircleTile(
                  icon: action.icon,
                  label: action.label,
                  color: action.color,
                  onTap: action.onTap,
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _ActionCircleTile extends StatelessWidget {
  const _ActionCircleTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    color.withOpacity(isDark ? 0.3 : 0.15),
                    color.withOpacity(isDark ? 0.15 : 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: color.withOpacity(isDark ? 0.3 : 0.2),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: color.withOpacity(isDark ? 0.1 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark
                    ? theme.colorScheme.onSurface.withOpacity(0.8)
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPENDING BREAKDOWN
// ═══════════════════════════════════════════════════════════════════════════════

class _ExpenseCategoryData {
  const _ExpenseCategoryData({
    required this.name,
    required this.icon,
    required this.amount,
    required this.color,
  });

  final String name;
  final IconData icon;
  final double amount;
  final Color color;
}

class _SpendingBreakdownCard extends StatelessWidget {
  const _SpendingBreakdownCard({
    required this.language,
    required this.categories,
    required this.totalExpenses,
  });

  final AppLanguage language;
  final List<_ExpenseCategoryData> categories;
  final double totalExpenses;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color:
              isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pie_chart_rounded,
                      color: Color(0xFFF97316),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    language.tr(
                        en: 'Spending Breakdown',
                        ha: 'Rarrabuwar Kashewa',
                        fr: 'Repartition des depenses'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyUtils.formatCompactCurrency(totalExpenses),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...categories.map(
                (_ExpenseCategoryData category) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CategoryBar(
                    name: category.name,
                    icon: category.icon,
                    amount: category.amount,
                    color: category.color,
                    totalExpenses: totalExpenses,
                    isDark: isDark,
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

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.name,
    required this.icon,
    required this.amount,
    required this.color,
    required this.totalExpenses,
    required this.isDark,
  });

  final String name;
  final IconData icon;
  final double amount;
  final Color color;
  final double totalExpenses;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double fraction = totalExpenses > 0 ? amount / totalExpenses : 0;
    final double percentage = fraction * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white.withOpacity(0.9)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              CurrencyUtils.formatCompactCurrency(amount),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.08)
                : color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECENT ACTIVITY FEED
// ═══════════════════════════════════════════════════════════════════════════════

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.language,
    required this.activities,
    required this.onViewAll,
    required this.onTapTransaction,
  });

  final AppLanguage language;
  final List<Transaction> activities;
  final VoidCallback onViewAll;
  final ValueChanged<Transaction> onTapTransaction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color:
              isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    language.tr(
                        en: 'Recent Activity',
                        ha: 'Ayyukan Baya-bayan nan',
                        fr: 'Activite recente'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onViewAll,
                    child: Text(
                      language.tr(
                          en: 'View All', ha: 'Duba Duka', fr: 'Voir tout'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (activities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      language.tr(
                        en: 'No recent transactions yet.\nStart by recording a sale or expense.',
                        ha: 'Babu ma\'amaloli na baya-bayan nan tukuna.\nFara ta hanyar rubuta tallace-tallace ko kashewa.',
                        fr: 'Aucune transaction recente pour le moment.\nCommencez par enregistrer une vente ou une depense.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              else
                ...activities.map(
                  (Transaction transaction) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ActivityRow(
                      transaction: transaction,
                      isDark: isDark,
                      onTap: () => onTapTransaction(transaction),
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

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.transaction,
    required this.isDark,
    required this.onTap,
  });

  final Transaction transaction;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isIncome = transaction.type == TransactionType.income;
    final Color accentColor =
        isIncome ? const Color(0xFF32D583) : const Color(0xFFF97316);
    final IconData icon =
        isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  transaction.description.isNotEmpty
                      ? transaction.description
                      : transaction.productName.isNotEmpty
                          ? transaction.productName
                          : 'Transaction',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  app_date.DateUtils.formatDate(transaction.transactionDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyUtils.formatCurrency(transaction.amount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color:
                  isIncome ? const Color(0xFF32D583) : const Color(0xFFF97316),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SMART INSIGHTS CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _SmartInsightsCard extends StatelessWidget {
  const _SmartInsightsCard({
    required this.language,
    required this.farmCount,
    required this.transactionCount,
    required this.topCategory,
    required this.income,
    required this.expenses,
  });

  final AppLanguage language;
  final int farmCount;
  final int transactionCount;
  final String topCategory;
  final double income;
  final double expenses;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final double profitMargin =
        income > 0 ? ((income - expenses) / income * 100) : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? <Color>[
                    const Color(0xFF0F3D3E).withOpacity(0.3),
                    const Color(0xFF0D1B1A).withOpacity(0.4),
                  ]
                : <Color>[
                    const Color(0xFFE8F8F5),
                    const Color(0xFFF0FDF4),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF32D583).withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF32D583).withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF32D583).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF32D583),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    language.tr(
                        en: 'Smart Insights',
                        ha: 'Basirar Fasaha',
                        fr: 'Analyses intelligentes'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F3D3E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: <Widget>[
                    _InsightStat(
                      label: language.tr(
                          en: 'Profit Margin',
                          ha: 'Ribar Riba',
                          fr: 'Marge beneficiaire'),
                      value: '${profitMargin.toStringAsFixed(1)}%',
                      icon: Icons.trending_up_rounded,
                      color: profitMargin >= 0
                          ? const Color(0xFF32D583)
                          : const Color(0xFFEF4444),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        final List<Widget> stats = <Widget>[
                          _InsightStat(
                            label: language.tr(
                                en: 'Farms', ha: 'Gonaki', fr: 'Fermes'),
                            value: '$farmCount',
                            icon: Icons.agriculture_rounded,
                            color: const Color(0xFF14B8A6),
                            isDark: isDark,
                            compact: true,
                          ),
                          _InsightStat(
                            label: language.tr(
                                en: 'Txns', ha: 'Ma\'amaloli', fr: 'Trans.'),
                            value: '$transactionCount',
                            icon: Icons.receipt_rounded,
                            color: const Color(0xFF8B5CF6),
                            isDark: isDark,
                            compact: true,
                          ),
                          _InsightStat(
                            label: language.tr(
                                en: 'Top category',
                                ha: 'Babban rukuni',
                                fr: 'Categorie principale'),
                            value: topCategory,
                            icon: Icons.star_rounded,
                            color: const Color(0xFFFBBF24),
                            isDark: isDark,
                            compact: true,
                          ),
                        ];

                        if (constraints.maxWidth >= 360) {
                          return Row(
                            children: <Widget>[
                              for (int i = 0;
                                  i < stats.length;
                                  i++) ...<Widget>[
                                if (i > 0) const SizedBox(width: 10),
                                Expanded(child: stats[i]),
                              ],
                            ],
                          );
                        }

                        return Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(child: stats[0]),
                                const SizedBox(width: 10),
                                Expanded(child: stats[1]),
                              ],
                            ),
                            const SizedBox(height: 10),
                            stats[2],
                          ],
                        );
                      },
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

class _InsightStat extends StatelessWidget {
  const _InsightStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (compact) {
      return Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F3D3E),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F3D3E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INVENTORY & PROCUREMENT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _InventoryProcurementCard extends StatelessWidget {
  const _InventoryProcurementCard({
    required this.language,
    required this.inventory,
    required this.procurementOrders,
    required this.onManage,
  });

  final AppLanguage language;
  final List<InventoryItem> inventory;
  final List<ProcurementOrder> procurementOrders;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final double inventoryValue = inventory.fold<double>(
      0,
      (double sum, InventoryItem item) =>
          sum + (item.availableQuantity * item.unitPrice),
    );
    final int lowStockCount =
        inventory.where((InventoryItem item) => item.isLowStock).length;
    final int expiringSoonCount = inventory
        .where((InventoryItem item) =>
            item.isExpiringWithin(const Duration(days: 7)))
        .length;
    final int pendingOrderCount = procurementOrders
        .where((ProcurementOrder order) =>
            order.status == ProcurementOrderStatus.pending ||
            order.status == ProcurementOrderStatus.ordered)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color:
              isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      language.tr(
                          en: 'Inventory & Procurement',
                          ha: 'Kaya & Sayayya',
                          fr: 'Stocks et approvisionnement'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    CurrencyUtils.formatCompactCurrency(inventoryValue),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                language.tr(
                  en: 'Stock value on hand, plus items that need attention.',
                  ha: 'Darajar kayan da ke hannu, tare da abubuwan da ke bukatar kulawa.',
                  fr: 'Valeur des stocks disponibles, plus les articles necessitant une attention.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _InsightStat(
                      label: language.tr(
                          en: 'Low stock',
                          ha: 'Karancin kaya',
                          fr: 'Stock faible'),
                      value: '$lowStockCount',
                      icon: Icons.production_quantity_limits_rounded,
                      color: const Color(0xFFF97316),
                      isDark: isDark,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InsightStat(
                      label: language.tr(
                          en: 'Expiring soon',
                          ha: 'Zai kare kwanan nan',
                          fr: 'Expire bientot'),
                      value: '$expiringSoonCount',
                      icon: Icons.hourglass_bottom_rounded,
                      color: const Color(0xFFEF4444),
                      isDark: isDark,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InsightStat(
                      label: language.tr(
                          en: 'Orders pending',
                          ha: 'Odar da ke jira',
                          fr: 'Commandes en attente'),
                      value: '$pendingOrderCount',
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onManage,
                  child: Text(language.tr(
                      en: 'Manage inventory & orders',
                      ha: 'Sarrafa kaya & oda',
                      fr: 'Gerer les stocks et commandes')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK EXPORT BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickExportBar extends StatelessWidget {
  const _QuickExportBar({
    required this.language,
    required this.isExporting,
    required this.hasTransactions,
    required this.onExport,
    required this.onShareSummary,
  });

  final AppLanguage language;
  final bool isExporting;
  final bool hasTransactions;
  final VoidCallback? onExport;
  final VoidCallback? onShareSummary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color:
              isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed:
                        isExporting || !hasTransactions ? null : onExport,
                    icon: isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(language.tr(
                        en: 'Export Report',
                        ha: 'Fitar da Rahoto',
                        fr: 'Exporter le rapport')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3D3E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed:
                        isExporting || !hasTransactions ? null : onShareSummary,
                    icon: const Icon(Icons.share_rounded),
                    label: Text(language.tr(
                        en: 'Share Summary',
                        ha: 'Raba Takaitawa',
                        fr: 'Partager le resume')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F3D3E),
                      side: const BorderSide(
                        color: Color(0xFF0F3D3E),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEGACY WIDGETS (kept for sub-routes and sheets)
// ═══════════════════════════════════════════════════════════════════════════════

class ReceiptDetailScreen extends ConsumerStatefulWidget {
  const ReceiptDetailScreen({
    super.key,
    required this.transaction,
  });

  final Transaction transaction;

  @override
  ConsumerState<ReceiptDetailScreen> createState() =>
      _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends ConsumerState<ReceiptDetailScreen> {
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final Transaction transaction = widget.transaction;
    final Farm? farm = ref.watch(farmsProvider).valueOrNull?.firstWhere(
          (Farm item) => item.id == transaction.farmId,
          orElse: () => Farm(
            id: '',
            name: 'Unknown farm',
            ward: '',
            sizeHa: 0,
            farmType: FarmType.combined,
            farmerCategory: FarmerCategory.subsistence,
            soilType: SoilType.loamy,
            waterSource: WaterSource.rainfall,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isSynced: true,
          ),
        );
    final String sellerEmail =
        ref.watch(firebaseServiceProvider).currentUser?.email ?? '';
    final String sellerName =
        ref.watch(firebaseServiceProvider).currentUser?.displayName ??
            'FarmSync Seller';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          transaction.recordKind == TransactionRecordKind.procurement
              ? language.tr(
                  en: 'Procurement Detail',
                  ha: 'Bayanin Sayayya',
                  fr: 'Detail d\'approvisionnement')
              : language.tr(
                  en: 'Receipt Detail',
                  ha: 'Bayanin Rasit',
                  fr: 'Detail du recu'),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _isExporting
                ? null
                : () => _exportReceipt(
                      transaction: transaction,
                      farmName: farm?.name ?? 'Farm',
                      sellerName: sellerName,
                    ),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: language.tr(
                en: 'Export PDF', ha: 'Fitar da PDF', fr: 'Exporter en PDF'),
          ),
          IconButton(
            onPressed: _isExporting ? null : _exportReceiptImage,
            icon: const Icon(Icons.image_outlined),
            tooltip: language.tr(
                en: 'Export image',
                ha: 'Fitar da Hoto',
                fr: 'Exporter l\'image'),
          ),
          IconButton(
            onPressed: () => _composeEmail(
              buyerEmail: transaction.counterpartyEmail,
              sellerEmail: sellerEmail,
              receiptNumber: transaction.receiptNumber,
              total: transaction.amount,
            ),
            icon: const Icon(Icons.email_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            RepaintBoundary(
              key: _receiptBoundaryKey,
              child: _ReceiptPreviewCard(
                language: language,
                transaction: transaction,
                farmName: farm?.name ?? 'Farm',
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
                      'Export options',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A styled receipt preview is available here. PDF export is supported directly from this screen, and email handoff pre-fills buyer and seller details when an email address is present.',
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

  Future<void> _exportReceipt({
    required Transaction transaction,
    required String farmName,
    required String sellerName,
  }) async {
    setState(() => _isExporting = true);
    try {
      final Uint8List bytes = await FinanceReportService().buildSalesReceipt(
        transaction: transaction,
        farmName: farmName,
        sellerName: sellerName,
      );
      final String path = await createReportFileSaver().savePdf(
        bytes: bytes,
        fileName:
            'receipt_${transaction.receiptNumber.isEmpty ? transaction.id : transaction.receiptNumber}.pdf',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt exported: $path')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportReceiptImage() async {
    setState(() => _isExporting = true);
    try {
      final RenderRepaintBoundary? boundary = _receiptBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Receipt preview is not ready yet.');
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Could not render receipt image.');
      }
      final Uint8List bytes = byteData.buffer.asUint8List();
      final String path = await createReportFileSaver().saveBytes(
        bytes: bytes,
        fileName:
            'receipt_${widget.transaction.receiptNumber.isEmpty ? widget.transaction.id : widget.transaction.receiptNumber}.png',
        mimeType: 'image/png',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt image exported: $path')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _composeEmail({
    required String buyerEmail,
    required String sellerEmail,
    required String receiptNumber,
    required double total,
  }) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: buyerEmail.isEmpty ? sellerEmail : buyerEmail,
      queryParameters: <String, String>{
        if (sellerEmail.isNotEmpty && buyerEmail.isNotEmpty) 'cc': sellerEmail,
        'subject': 'FarmSync Receipt $receiptNumber',
        'body':
            'Receipt number: $receiptNumber\nTotal: ${CurrencyUtils.formatCurrency(total)}',
      },
    );
    await launchUrl(uri);
  }
}

class _ReceiptPreviewCard extends StatelessWidget {
  const _ReceiptPreviewCard({
    required this.language,
    required this.transaction,
    required this.farmName,
    required this.sellerName,
  });

  final AppLanguage language;
  final Transaction transaction;
  final String farmName;
  final String sellerName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
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
                      Text(
                        transaction.recordKind ==
                                TransactionRecordKind.procurement
                            ? language.tr(
                                en: 'Procurement Record',
                                ha: 'Bayanin Sayayya',
                                fr: 'Registre d\'approvisionnement')
                            : language.tr(
                                en: 'Sales Receipt',
                                ha: 'Rasit na Talla',
                                fr: 'Recu de vente'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(transaction.receiptNumber),
                    ],
                  ),
                ),
                Text(
                  CurrencyUtils.formatCurrency(transaction.amount),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ReceiptLine(label: 'Farm', value: farmName),
            _ReceiptLine(label: 'Seller', value: sellerName),
            _ReceiptLine(
              label: transaction.recordKind == TransactionRecordKind.procurement
                  ? 'Provider'
                  : 'Buyer',
              value: transaction.counterpartyName.isEmpty
                  ? 'Walk-in'
                  : transaction.counterpartyName,
            ),
            _ReceiptLine(
              label: 'Product',
              value: transaction.productName.isEmpty
                  ? transaction.description
                  : transaction.productName,
            ),
            _ReceiptLine(
              label: 'Quantity',
              value:
                  '${transaction.quantity.toStringAsFixed(2)} ${transaction.unit}',
            ),
            _ReceiptLine(
              label: 'Unit price',
              value: CurrencyUtils.formatCurrency(transaction.unitPrice),
            ),
            _ReceiptLine(
              label: 'Date',
              value: app_date.DateUtils.formatDate(transaction.transactionDate),
            ),
            if (transaction.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                transaction.notes,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(height: 1.5),
              ),
            ],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceSnapshot {
  const FinanceSnapshot({
    required this.income,
    required this.expenses,
    required this.balance,
    required this.categoryTotals,
  });

  final double income;
  final double expenses;
  final double balance;
  final Map<TransactionCategory, double> categoryTotals;

  factory FinanceSnapshot.fromTransactions(List<Transaction> transactions) {
    double income = 0;
    double expenses = 0;
    final Map<TransactionCategory, double> categoryTotals =
        <TransactionCategory, double>{};
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
    return FinanceSnapshot(
      income: income,
      expenses: expenses,
      balance: income - expenses,
      categoryTotals: categoryTotals,
    );
  }
}

// ─── BOTTOM SHEET WIDGETS (preserved from original) ─────────────────────────

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet({
    required this.farms,
    required this.operations,
  });

  final List<Farm> farms;
  final OperationsHubState operations;

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final TextEditingController _unitController =
      TextEditingController(text: 'bag');
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late String _farmId;
  TransactionRecordKind _recordKind = TransactionRecordKind.sale;
  TransactionCategory _category = TransactionCategory.cropSale;
  final DateTime _transactionDate = DateTime.now();
  String? _partnerId;

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.first.id;
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

  List<TransactionCategory> _categoryOptionsFor(TransactionRecordKind kind) {
    if (kind == TransactionRecordKind.sale) {
      return const <TransactionCategory>[
        TransactionCategory.cropSale,
        TransactionCategory.livestockSale,
      ];
    }
    return const <TransactionCategory>[
      TransactionCategory.feed,
      TransactionCategory.fertiliser,
      TransactionCategory.labour,
      TransactionCategory.veterinary,
      TransactionCategory.other,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<BusinessPartner> partners =
        widget.operations.partners.where((BusinessPartner item) {
      if (_recordKind == TransactionRecordKind.sale) {
        return item.type == BusinessPartnerType.customer;
      }
      if (_recordKind == TransactionRecordKind.procurement) {
        return item.type == BusinessPartnerType.provider;
      }
      return true;
    }).toList(growable: false);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Record sale or procurement',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 14),
                _DropdownField<String>(
                  label: 'Farm',
                  value: _farmId,
                  items: widget.farms.map((Farm farm) => farm.id).toList(),
                  itemLabel: (String value) => widget.farms
                      .firstWhere((Farm farm) => farm.id == value)
                      .name,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _farmId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _DropdownField<TransactionRecordKind>(
                  label: 'Record type',
                  value: _recordKind,
                  items: const <TransactionRecordKind>[
                    TransactionRecordKind.sale,
                    TransactionRecordKind.procurement,
                    TransactionRecordKind.general,
                  ],
                  itemLabel: (TransactionRecordKind value) {
                    switch (value) {
                      case TransactionRecordKind.sale:
                        return 'Sale';
                      case TransactionRecordKind.procurement:
                        return 'Procurement';
                      case TransactionRecordKind.general:
                        return 'General';
                    }
                  },
                  onChanged: (TransactionRecordKind? value) {
                    if (value != null) {
                      setState(() {
                        _recordKind = value;
                        _category = _categoryOptionsFor(value).first;
                        _partnerId = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _DropdownField<TransactionCategory>(
                  label: 'Category',
                  value: _category,
                  items: _categoryOptionsFor(_recordKind),
                  itemLabel: _categoryLabel,
                  onChanged: (TransactionCategory? value) {
                    if (value != null) {
                      setState(() => _category = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (partners.isNotEmpty)
                  _DropdownField<String?>(
                    label: _recordKind == TransactionRecordKind.procurement
                        ? 'Provider'
                        : 'Customer',
                    value: _partnerId,
                    items: <String?>[
                      null,
                      ...partners.map((BusinessPartner item) => item.id)
                    ],
                    itemLabel: (String? value) {
                      if (value == null) {
                        return 'Walk-in / unregistered';
                      }
                      return partners
                          .firstWhere(
                              (BusinessPartner item) => item.id == value)
                          .name;
                    },
                    onChanged: (String? value) =>
                        setState(() => _partnerId = value),
                  ),
                if (partners.isNotEmpty) const SizedBox(height: 12),
                AppTextField(
                    controller: _productController,
                    label: 'Product',
                    hint: 'Maize, eggs, feed'),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _quantityController,
                        label: 'Quantity',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                          controller: _unitController,
                          label: 'Unit',
                          hint: 'bag, crate, kg'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _unitPriceController,
                        label: 'Unit price',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _amountController,
                  label: 'Total amount',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Market sale or farm supply note',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _notesController,
                  label: 'Receipt notes',
                  hint: 'Delivery details, payment note, or stock observation',
                  maxLines: 2,
                ),
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
                        onPressed: () => _submit(partners),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit(List<BusinessPartner> partners) {
    final String? amountError = Validators.combine(
      <String? Function(String?)>[
        (String? value) =>
            Validators.required(value, fieldName: 'Total amount'),
        Validators.amount,
      ],
      _amountController.text.trim(),
    );
    if (amountError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(amountError)));
      return;
    }

    final BusinessPartner? partner = _partnerId == null
        ? null
        : partners.firstWhere((BusinessPartner item) => item.id == _partnerId);
    final TransactionType type =
        _recordKind == TransactionRecordKind.procurement
            ? TransactionType.expense
            : TransactionType.income;

    Navigator.of(context).pop(
      _TransactionDraft(
        farmId: _farmId,
        type: type,
        category: _category,
        amount: double.parse(_amountController.text.trim()),
        description: _descriptionController.text.trim().isEmpty
            ? _productController.text.trim()
            : _descriptionController.text.trim(),
        transactionDate: _transactionDate,
        recordKind: _recordKind,
        partyType: _recordKind == TransactionRecordKind.procurement
            ? TransactionPartyType.provider
            : TransactionPartyType.customer,
        productName: _productController.text.trim(),
        quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
        unit: _unitController.text.trim().isEmpty
            ? 'unit'
            : _unitController.text.trim(),
        unitPrice: double.tryParse(_unitPriceController.text.trim()) ?? 0,
        counterpartyName: partner?.name ?? '',
        counterpartyEmail: partner?.email ?? '',
        counterpartyPhone: partner?.phone ?? '',
        partnerId: partner?.id ?? '',
        notes: _notesController.text.trim(),
      ),
    );
  }
}

class _InventorySheet extends StatefulWidget {
  const _InventorySheet({required this.farms});

  final List<Farm> farms;

  @override
  State<_InventorySheet> createState() => _InventorySheetState();
}

class _InventorySheetState extends State<_InventorySheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController =
      TextEditingController(text: 'Farm produce');
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController =
      TextEditingController(text: 'bag');
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  late String _farmId;

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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _DropdownField<String>(
              label: 'Farm',
              value: _farmId,
              items: widget.farms.map((Farm farm) => farm.id).toList(),
              itemLabel: (String value) =>
                  widget.farms.firstWhere((Farm item) => item.id == value).name,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _farmId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            AppTextField(controller: _nameController, label: 'Product name'),
            const SizedBox(height: 12),
            AppTextField(controller: _categoryController, label: 'Category'),
            const SizedBox(height: 12),
            AppTextField(
                controller: _quantityController, label: 'Available quantity'),
            const SizedBox(height: 12),
            AppTextField(controller: _unitController, label: 'Unit'),
            const SizedBox(height: 12),
            AppTextField(controller: _costPriceController, label: 'Cost price'),
            const SizedBox(height: 12),
            AppTextField(
                controller: _unitPriceController, label: 'Selling price'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                onPressed: _submit,
                child: const Text('Save inventory'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      _InventoryDraft(
        farmId: _farmId,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
        unit: _unitController.text.trim(),
        costPrice: double.tryParse(_costPriceController.text.trim()) ?? 0,
        unitPrice: double.tryParse(_unitPriceController.text.trim()) ?? 0,
      ),
    );
  }
}

enum _QuickAddAction { transaction, inventory, contact, manageContacts }

class _QuickAddMenu extends StatelessWidget {
  const _QuickAddMenu({required this.hasFarms});

  final bool hasFarms;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Quick add', style: theme.textTheme.titleMedium),
              ),
            ),
            ListTile(
              enabled: hasFarms,
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('Log transaction'),
              subtitle: hasFarms ? null : const Text('Add a farm first'),
              onTap: () =>
                  Navigator.of(context).pop(_QuickAddAction.transaction),
            ),
            ListTile(
              enabled: hasFarms,
              leading: const Icon(Icons.inventory_2_rounded),
              title: const Text('Add stock item'),
              subtitle: hasFarms ? null : const Text('Add a farm first'),
              onTap: () =>
                  Navigator.of(context).pop(_QuickAddAction.inventory),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: const Text('Add contact'),
              subtitle: const Text('Customer or provider'),
              onTap: () => Navigator.of(context).pop(_QuickAddAction.contact),
            ),
            ListTile(
              leading: const Icon(Icons.contacts_rounded),
              title: const Text('Manage contacts'),
              subtitle: const Text('Edit or remove customers & providers'),
              onTap: () =>
                  Navigator.of(context).pop(_QuickAddAction.manageContacts),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsListSheet extends StatelessWidget {
  const _ContactsListSheet({
    required this.partners,
    required this.onEdit,
    required this.onDelete,
  });

  final List<BusinessPartner> partners;
  final ValueChanged<BusinessPartner> onEdit;
  final ValueChanged<BusinessPartner> onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Contacts', style: theme.textTheme.titleMedium),
              ),
            ),
            Flexible(
              child: partners.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Text(
                        'No contacts yet. Add a customer or provider to see them here.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: partners.length,
                      itemBuilder: (BuildContext context, int index) {
                        final BusinessPartner partner = partners[index];
                        final bool isProvider =
                            partner.type == BusinessPartnerType.provider;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isProvider
                                ? const Color(0xFF8B5CF6).withOpacity(0.15)
                                : const Color(0xFF32D583).withOpacity(0.15),
                            child: Icon(
                              isProvider
                                  ? Icons.local_shipping_rounded
                                  : Icons.storefront_rounded,
                              color: isProvider
                                  ? const Color(0xFF8B5CF6)
                                  : const Color(0xFF32D583),
                            ),
                          ),
                          title: Text(partner.name.isEmpty
                              ? 'Unnamed contact'
                              : partner.name),
                          subtitle: Text(<String>[
                            isProvider ? 'Provider' : 'Customer',
                            if (partner.phone.isNotEmpty) partner.phone,
                          ].join(' · ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'Edit contact',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => onEdit(partner),
                              ),
                              IconButton(
                                tooltip: 'Remove contact',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => onDelete(partner),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerSheet extends StatefulWidget {
  const _PartnerSheet({this.existing});

  final BusinessPartner? existing;

  @override
  State<_PartnerSheet> createState() => _PartnerSheetState();
}

class _PartnerSheetState extends State<_PartnerSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _emailController =
      TextEditingController(text: widget.existing?.email ?? '');
  late final TextEditingController _phoneController =
      TextEditingController(text: widget.existing?.phone ?? '');
  late BusinessPartnerType _type =
      widget.existing?.type ?? BusinessPartnerType.customer;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppTextField(controller: _nameController, label: 'Name'),
            const SizedBox(height: 12),
            AppTextField(controller: _emailController, label: 'Email'),
            const SizedBox(height: 12),
            AppTextField(controller: _phoneController, label: 'Phone'),
            const SizedBox(height: 12),
            _DropdownField<BusinessPartnerType>(
              label: 'Contact type',
              value: _type,
              items: BusinessPartnerType.values,
              itemLabel: (BusinessPartnerType value) =>
                  value == BusinessPartnerType.customer
                      ? 'Customer'
                      : 'Provider',
              onChanged: (BusinessPartnerType? value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                onPressed: _submit,
                child: Text(
                    widget.existing == null ? 'Save contact' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
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
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
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

class _TransactionDraft {
  const _TransactionDraft({
    required this.farmId,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    required this.transactionDate,
    required this.recordKind,
    required this.partyType,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.counterpartyName,
    required this.counterpartyEmail,
    required this.counterpartyPhone,
    required this.partnerId,
    required this.notes,
  });

  final String farmId;
  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final String description;
  final DateTime transactionDate;
  final TransactionRecordKind recordKind;
  final TransactionPartyType partyType;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final String counterpartyName;
  final String counterpartyEmail;
  final String counterpartyPhone;
  final String partnerId;
  final String notes;
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

class _InventoryDraft {
  const _InventoryDraft({
    required this.farmId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.costPrice,
    required this.unitPrice,
  });

  final String farmId;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final double costPrice;
  final double unitPrice;
}
