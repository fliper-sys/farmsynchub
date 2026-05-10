import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/finance_report_service.dart';
import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_file_saver_base.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../core/utils/validators.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final FinanceReportService _reportService = FinanceReportService();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Transaction>> transactionsAsync = ref.watch(transactionsProvider);
    final List<Farm> farms = ref.watch(farmsProvider).maybeWhen(
          data: (List<Farm> value) => value,
          orElse: () => <Farm>[],
        );
    final List<Transaction> transactions = transactionsAsync.maybeWhen(
      data: (List<Transaction> value) => value,
      orElse: () => <Transaction>[],
    );
    final FinanceSnapshot snapshot = FinanceSnapshot.fromTransactions(transactions);

    return SoftScreenScaffold(
      heroTitle: 'Farm balance',
      heroSubtitle: 'See sales, expenses, cash movement, and export-ready records in one cleaner ledger view.',
      heroIcon: Icons.account_balance_wallet_rounded,
      heroVariant: FarmArtworkVariant.dashboard,
      heroBadge: 'This month',
      trailing: Column(
        children: <Widget>[
          AppButton.primary(
            onPressed: farms.isEmpty ? null : () => _openTransactionSheet(context, farms: farms),
            child: const Text('Add record'),
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            onPressed: _isExporting || transactions.isEmpty ? null : () => _exportReport(snapshot, transactions),
            child: Text(_isExporting ? 'Exporting...' : 'Export PDF'),
          ),
        ],
      ),
      sections: <Widget>[
        if (farms.isEmpty) ...<Widget>[
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Text('Create a farm first before recording income or expenses so each transaction can be linked to a real operation.'),
            ),
          ),
          const SizedBox(height: 18),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: SoftInfoChip(
                label: 'Income',
                value: CurrencyUtils.formatCompactCurrency(snapshot.income),
                color: const Color(0xFFE5F5D8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: 'Expenses',
                value: CurrencyUtils.formatCompactCurrency(snapshot.expenses),
                color: const Color(0xFFFFE7D7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: 'Balance',
                value: CurrencyUtils.formatCompactCurrency(snapshot.balance),
                color: const Color(0xFFDFF1FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(
          title: 'Transaction tools',
          action: TextButton.icon(
            onPressed: farms.isEmpty ? null : () => _openTransactionSheet(context, farms: farms),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ),
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    farms.isEmpty
                        ? 'Finance records unlock after at least one farm has been created.'
                        : 'Capture crop sales, livestock sales, labour costs, feed, fertiliser, or other expenses from here.',
                  ),
                ),
                const SizedBox(width: 12),
                AppButton.primary(
                  onPressed: farms.isEmpty ? null : () => _openTransactionSheet(context, farms: farms),
                  child: const Text('Quick record'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SoftSectionTitle(title: 'Financial overview'),
        Row(
          children: <Widget>[
            Expanded(
              child: _InsightCard(
                title: 'Transactions',
                value: '${transactions.length}',
                note: 'Recorded cash events',
                color: const Color(0xFFEAF4DD),
                icon: Icons.receipt_long_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightCard(
                title: 'Largest income',
                value: CurrencyUtils.formatCompactCurrency(snapshot.largestIncome),
                note: 'Best sale this cycle',
                color: const Color(0xFFDDEEFF),
                icon: Icons.trending_up_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightCard(
                title: 'Largest expense',
                value: CurrencyUtils.formatCompactCurrency(snapshot.largestExpense),
                note: 'Highest cost item',
                color: const Color(0xFFFFEBD9),
                icon: Icons.trending_down_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SoftSectionTitle(title: 'Category breakdown'),
        ...snapshot.categoryTotals.entries.map(
          (MapEntry<TransactionCategory, double> entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CategoryBreakdownTile(
              category: _readableCategory(entry.key),
              amount: CurrencyUtils.formatCurrency(entry.value),
              ratio: snapshot.totalFlow == 0 ? 0 : entry.value / snapshot.totalFlow,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SoftSectionTitle(title: 'Reporting details'),
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _ReportMeta(
                    label: 'Reporting period',
                    value: '${app_date.DateUtils.formatDate(snapshot.startDate)} - ${app_date.DateUtils.formatDate(snapshot.endDate)}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReportMeta(
                    label: 'Sync state',
                    value: snapshot.pendingSyncCount == 0 ? 'All synced' : '${snapshot.pendingSyncCount} pending',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SoftSectionTitle(title: 'Recent transactions'),
        if (transactions.isEmpty)
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No transactions recorded yet.'),
            ),
          ),
        ...transactions.take(6).map(
          (Transaction transaction) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TransactionTile(transaction: transaction),
          ),
        ),
      ],
    );
  }

  Future<void> _exportReport(FinanceSnapshot snapshot, List<Transaction> transactions) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _reportService.buildFinanceReport(
        transactions: transactions,
        income: snapshot.income,
        expenses: snapshot.expenses,
        balance: snapshot.balance,
        categoryTotals: snapshot.categoryTotals,
      );
      final String savedPath = await _fileSaver.savePdf(
        bytes: bytes,
        fileName: 'farmsync_finance_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported: $savedPath')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _openTransactionSheet(
    BuildContext context, {
    required List<Farm> farms,
  }) async {
    final _TransactionDraft? draft = await showModalBottomSheet<_TransactionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _TransactionFormSheet(farms: farms),
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
      linkedEntityId: draft.farmId,
      createdAt: now,
      updatedAt: now,
      isSynced: true,
    );

    await ref.read(transactionsProvider.notifier).addTransaction(transaction);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction recorded successfully.')),
    );
  }

  String _readableCategory(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.cropSale:
        return 'Crop sale';
      case TransactionCategory.livestockSale:
        return 'Livestock sale';
      case TransactionCategory.feed:
        return 'Feed purchase';
      case TransactionCategory.fertiliser:
        return 'Fertiliser';
      case TransactionCategory.labour:
        return 'Labour payout';
      case TransactionCategory.veterinary:
        return 'Veterinary care';
      case TransactionCategory.other:
        return 'Other transaction';
    }
  }
}

class FinanceSnapshot {
  const FinanceSnapshot({
    required this.income,
    required this.expenses,
    required this.balance,
    required this.largestIncome,
    required this.largestExpense,
    required this.pendingSyncCount,
    required this.categoryTotals,
    required this.startDate,
    required this.endDate,
  });

  final double income;
  final double expenses;
  final double balance;
  final double largestIncome;
  final double largestExpense;
  final int pendingSyncCount;
  final Map<TransactionCategory, double> categoryTotals;
  final DateTime startDate;
  final DateTime endDate;

  double get totalFlow => income + expenses;

  factory FinanceSnapshot.fromTransactions(List<Transaction> transactions) {
    double income = 0;
    double expenses = 0;
    double largestIncome = 0;
    double largestExpense = 0;
    int pendingSyncCount = 0;
    final Map<TransactionCategory, double> categoryTotals = <TransactionCategory, double>{};

    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();

    if (transactions.isNotEmpty) {
      final List<Transaction> sorted = List<Transaction>.from(transactions)
        ..sort((Transaction a, Transaction b) => a.transactionDate.compareTo(b.transactionDate));
      startDate = sorted.first.transactionDate;
      endDate = sorted.last.transactionDate;
    }

    for (final Transaction transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
        if (transaction.amount > largestIncome) {
          largestIncome = transaction.amount;
        }
      } else {
        expenses += transaction.amount;
        if (transaction.amount > largestExpense) {
          largestExpense = transaction.amount;
        }
      }

      if (!transaction.isSynced) {
        pendingSyncCount++;
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
      largestIncome: largestIncome,
      largestExpense: largestExpense,
      pendingSyncCount: pendingSyncCount,
      categoryTotals: categoryTotals,
      startDate: startDate,
      endDate: endDate,
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.value,
    required this.note,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String note;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon),
            ),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontSize: 22)),
            const SizedBox(height: 6),
            Text(note, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownTile extends StatelessWidget {
  const _CategoryBreakdownTile({
    required this.category,
    required this.amount,
    required this.ratio,
  });

  final String category;
  final String amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(category)),
                Text(amount),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: ratio.clamp(0.0, 1.0).toDouble(),
                backgroundColor: const Color(0xFFF0F1EA),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4D8F5E)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportMeta extends StatelessWidget {
  const _ReportMeta({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool positive = transaction.type == TransactionType.income;
    final String amount = '${positive ? '+' : '-'}${CurrencyUtils.formatCurrency(transaction.amount)}';

    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: positive ? const Color(0xFFE5F5D8) : const Color(0xFFFFE7D7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(positive ? Icons.south_west_rounded : Icons.north_east_rounded),
        ),
        title: Text(
          _readableCategory(transaction.category),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(transaction.description),
            const SizedBox(height: 4),
            Text(
              app_date.DateUtils.formatDate(transaction.transactionDate),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Text(
          amount,
          style: theme.textTheme.labelLarge?.copyWith(
            color: positive ? const Color(0xFF2C7A39) : const Color(0xFFB45533),
          ),
        ),
      ),
    );
  }

  String _readableCategory(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.cropSale:
        return 'Crop sale';
      case TransactionCategory.livestockSale:
        return 'Livestock sale';
      case TransactionCategory.feed:
        return 'Feed purchase';
      case TransactionCategory.fertiliser:
        return 'Fertiliser';
      case TransactionCategory.labour:
        return 'Labour payout';
      case TransactionCategory.veterinary:
        return 'Veterinary care';
      case TransactionCategory.other:
        return 'Other transaction';
    }
  }
}

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet({
    required this.farms,
  });

  final List<Farm> farms;

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late String _farmId;
  TransactionType _type = TransactionType.income;
  TransactionCategory _category = TransactionCategory.cropSale;
  DateTime _transactionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.first.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Add transaction',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Record a real income or expense and connect it to the correct farm.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                _DropdownField<String>(
                  label: 'Farm',
                  value: _farmId,
                  items: widget.farms.map((Farm farm) => farm.id).toList(),
                  itemLabel: (String value) => widget.farms.firstWhere((Farm farm) => farm.id == value).name,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _farmId = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _DropdownField<TransactionType>(
                  label: 'Type',
                  value: _type,
                  items: TransactionType.values,
                  itemLabel: (TransactionType value) => value == TransactionType.income ? 'Income' : 'Expense',
                  onChanged: (TransactionType? value) {
                    if (value != null) {
                      setState(() {
                        _type = value;
                        _category = value == TransactionType.income
                            ? TransactionCategory.cropSale
                            : TransactionCategory.feed;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                _DropdownField<TransactionCategory>(
                  label: 'Category',
                  value: _category,
                  items: _categoriesForType(_type),
                  itemLabel: _categoryLabel,
                  onChanged: (TransactionCategory? value) {
                    if (value != null) {
                      setState(() => _category = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _amountController,
                  label: 'Amount',
                  hint: '250000',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Tomato sales from market day',
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _transactionDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _transactionDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Transaction date',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: Text('${_transactionDate.day}/${_transactionDate.month}/${_transactionDate.year}')),
                        const Icon(Icons.calendar_today_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
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
      ),
    );
  }

  void _submit() {
    final String? amountError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Amount'),
        Validators.amount,
      ],
      _amountController.text.trim(),
    );
    final String? descriptionError = Validators.required(
      _descriptionController.text.trim(),
      fieldName: 'Description',
    );

    if (amountError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(amountError)));
      return;
    }
    if (descriptionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(descriptionError)));
      return;
    }

    Navigator.of(context).pop(
      _TransactionDraft(
        farmId: _farmId,
        type: _type,
        category: _category,
        amount: double.parse(_amountController.text.trim()),
        description: _descriptionController.text.trim(),
        transactionDate: _transactionDate,
      ),
    );
  }

  List<TransactionCategory> _categoriesForType(TransactionType type) {
    if (type == TransactionType.income) {
      return <TransactionCategory>[
        TransactionCategory.cropSale,
        TransactionCategory.livestockSale,
        TransactionCategory.other,
      ];
    }
    return <TransactionCategory>[
      TransactionCategory.feed,
      TransactionCategory.fertiliser,
      TransactionCategory.labour,
      TransactionCategory.veterinary,
      TransactionCategory.other,
    ];
  }

  String _categoryLabel(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.cropSale:
        return 'Crop sale';
      case TransactionCategory.livestockSale:
        return 'Livestock sale';
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
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
  });

  final String farmId;
  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final String description;
  final DateTime transactionDate;
}
