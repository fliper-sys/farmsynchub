import 'dart:typed_data';

import 'package:farmsynchub/core/services/report_file_saver_base.dart' show ReportFileSaver;
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
import '../../../providers/operations_hub_provider.dart';
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
  final OperationsHistoryReportService _reportService = OperationsHistoryReportService();
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
    final List<Transaction> allTransactions = ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final OperationsHubState operations = ref.watch(operationsHubProvider);
    final List<Transaction> procurement = allTransactions
        .where((Transaction item) => item.recordKind == TransactionRecordKind.procurement)
        .where((Transaction item) => _farmId.isEmpty || item.farmId == _farmId)
        .where((Transaction item) {
          if (_searchText.isEmpty) return true;
          final String haystack = '${item.description} ${item.productName} ${item.counterpartyName} ${item.receiptNumber} ${item.notes}'.toLowerCase();
          return haystack.contains(_searchText);
        })
        .toList(growable: false)
      ..sort((Transaction a, Transaction b) => b.transactionDate.compareTo(a.transactionDate));

    final double totalSpend = procurement.fold<double>(0, (double sum, Transaction item) => sum + item.amount);
    final double averageSpend = procurement.isEmpty ? 0 : totalSpend / procurement.length;
    final int supplierCount = procurement.map((Transaction item) => item.counterpartyName.trim()).where((String value) => value.isNotEmpty).toSet().length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/finance'),
        ),
        title: const Text('Procurement'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Export procurement history',
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
                  Text('Procurement management', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Track supplier history, compare purchasing costs, and open the full workspace when you need to add a new procurement entry.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _MetricChip(label: 'Entries', value: procurement.length.toString()),
                      _MetricChip(label: 'Suppliers', value: supplierCount.toString()),
                      _MetricChip(label: 'Spend', value: CurrencyUtils.formatCompactCurrency(totalSpend)),
                      _MetricChip(label: 'Average', value: CurrencyUtils.formatCompactCurrency(averageSpend)),
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
                        onPressed: procurement.isEmpty || _isExporting
                            ? null
                            : () => _exportHistory(context, farms, procurement, totalSpend),
                        child: const Text('Share PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (operations.inventory.isNotEmpty) ...<Widget>[
            AppCard(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Stock-ready products', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('These products are available for procurement documentation and stock updates from the shared operations catalog.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: operations.inventory
                          .where((InventoryItem item) => _farmId.isEmpty || item.farmId == _farmId)
                          .take(6)
                          .map(
                            (InventoryItem item) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('${item.emoji} ${item.name}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text('${item.availableQuantity.toStringAsFixed(0)} ${item.unit} • ${CurrencyUtils.formatCurrency(item.unitPrice)}'),
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
            label: 'Search procurement',
            hint: 'Search by supplier, product, receipt, or note',
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
            const _EmptyState(message: 'No procurement history matches the current filters.')
          else
            ...procurement.map(
              (Transaction transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryCard(
                  title: transaction.productName.isEmpty ? transaction.description : transaction.productName,
                  subtitle: transaction.counterpartyName.isEmpty ? 'Supplier not set' : transaction.counterpartyName,
                  meta: '${transaction.receiptNumber} • ${transaction.unit} • ${appDate(transaction.transactionDate)}',
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
                'Tip: procurement entries are fully managed in the Finance workspace, while this page gives you a focused buying history and export view.',
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
      final String fileName = 'farmsync_procurement_history_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final Uint8List bytes = await _reportService.buildReport(
        title: 'Procurement history',
        subtitle: 'Supplier and buying history exported from FarmSync Hub',
        farms: farms,
        entries: procurement,
        income: 0,
        expenses: totalSpend,
        categoryTotals: _categoryTotals(procurement),
      );
      final String path = await _fileSaver.savePdf(bytes: bytes, fileName: fileName);
      await _shareService.sharePdf(
        filePath: path,
        fileName: fileName,
        message: 'FarmSync procurement history is ready to share.',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Procurement PDF saved: $path')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Map<TransactionCategory, double> _categoryTotals(List<Transaction> items) {
    final Map<TransactionCategory, double> totals = <TransactionCategory, double>{};
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
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
        trailing: Text(amount, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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

String appDate(DateTime dateTime) => '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
