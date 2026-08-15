import 'dart:typed_data';

import 'package:farmsynchub/core/services/report_file_saver_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/operations_history_report_service.dart';
import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_share_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';

class SalesInformationScreen extends ConsumerStatefulWidget {
  const SalesInformationScreen({super.key});

  static const String routeName = '/sales-info';

  @override
  ConsumerState<SalesInformationScreen> createState() =>
      _SalesInformationScreenState();
}

class _SalesInformationScreenState
    extends ConsumerState<SalesInformationScreen> {
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
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Transaction> allTransactions =
        ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final List<Transaction> sales = allTransactions
        .where(
            (Transaction item) => item.recordKind == TransactionRecordKind.sale)
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

    final double totalRevenue = sales.fold<double>(
        0, (double sum, Transaction item) => sum + item.amount);
    final double averageSale = sales.isEmpty ? 0 : totalRevenue / sales.length;
    final int customerCount = sales
        .map((Transaction item) => item.counterpartyName.trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .length;
    final Map<String, double> productRevenue = <String, double>{};
    for (final Transaction sale in sales) {
      final String key = sale.productName.trim().isEmpty
          ? sale.description.trim()
          : sale.productName.trim();
      productRevenue.update(key.isEmpty ? 'Unknown product' : key,
          (double value) => value + sale.amount,
          ifAbsent: () => sale.amount);
    }
    final List<MapEntry<String, double>> topProducts = productRevenue.entries
        .toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go('/finance'),
        ),
        title: const Text('Sales information'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Export sales history',
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            onPressed: sales.isEmpty || _isExporting
                ? null
                : () => _exportHistory(context, farms, sales, totalRevenue),
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
                  Text('Sales analytics',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'See buyer trends, product revenue, and a focused sales history. Use the workspace for full sale entry and receipt actions.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _MetricChip(
                          label: 'Sales', value: sales.length.toString()),
                      _MetricChip(
                          label: 'Revenue',
                          value: CurrencyUtils.formatCompactCurrency(
                              totalRevenue)),
                      _MetricChip(
                          label: 'Customers', value: customerCount.toString()),
                      _MetricChip(
                          label: 'Average',
                          value:
                              CurrencyUtils.formatCompactCurrency(averageSale)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      AppButton.primary(
                        onPressed: () => context.go('/finance'),
                        child: const Text('Open workspace'),
                      ),
                      AppButton.secondary(
                        onPressed: sales.isEmpty || _isExporting
                            ? null
                            : () => _exportHistory(
                                context, farms, sales, totalRevenue),
                        child: const Text('Share PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _searchController,
            label: 'Search sales',
            hint: 'Search by customer, product, receipt, or note',
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
          if (topProducts.isNotEmpty) ...<Widget>[
            Text('Top products',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...topProducts.take(3).map(
                  (MapEntry<String, double> entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryCard(
                      title: entry.key,
                      subtitle: 'Revenue leader',
                      meta: CurrencyUtils.formatCurrency(entry.value),
                      amount: CurrencyUtils.formatCurrency(entry.value),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
          ],
          if (sales.isEmpty)
            const _EmptyState(
                message: 'No sales history matches the current filters.')
          else
            ...sales.map(
              (Transaction transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryCard(
                  title: transaction.productName.isEmpty
                      ? transaction.description
                      : transaction.productName,
                  subtitle: transaction.counterpartyName.isEmpty
                      ? 'Customer not set'
                      : transaction.counterpartyName,
                  meta:
                      '${transaction.receiptNumber} • ${appDate(transaction.transactionDate)}',
                  amount: CurrencyUtils.formatCurrency(transaction.amount),
                ),
              ),
            ),
          const SizedBox(height: 10),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Tip: this page is optimized for reviewing sales patterns, while the Finance workspace remains the full entry and receipt management area.',
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
    List<Transaction> sales,
    double totalRevenue,
  ) async {
    setState(() => _isExporting = true);
    try {
      final String fileName =
          'farmsync_sales_history_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final Uint8List bytes = await _reportService.buildReport(
        title: 'Sales history',
        subtitle: 'Revenue and buyer history exported from FarmSync Hub',
        farms: farms,
        entries: sales,
        income: totalRevenue,
        expenses: 0,
        categoryTotals: _categoryTotals(sales),
      );
      final String path =
          await _fileSaver.savePdf(bytes: bytes, fileName: fileName);
      await _shareService.sharePdf(
        filePath: path,
        fileName: fileName,
        message: 'FarmSync sales history is ready to share.',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sales PDF saved: $path')),
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
