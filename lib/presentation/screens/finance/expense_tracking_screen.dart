import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/operations_history_report_service.dart';
import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_file_saver_base.dart';
import '../../../core/services/report_share_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/farm.dart';
import '../../../core/i18n/context_tr.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/detail_ui.dart';
import '../../common/widgets/finance_ui.dart';

class ExpenseTrackingScreen extends ConsumerStatefulWidget {
  const ExpenseTrackingScreen({super.key});

  static const String routeName = '/expenses';

  @override
  ConsumerState<ExpenseTrackingScreen> createState() => _ExpenseTrackingScreenState();
}

class _ExpenseTrackingScreenState extends ConsumerState<ExpenseTrackingScreen> {
  final OperationsHistoryReportService _reportService = OperationsHistoryReportService();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  final ReportShareService _shareService = const ReportShareService();
  final TextEditingController _searchController = TextEditingController();
  bool _isExporting = false;
  String _searchText = '';
  String _farmId = '';
  DateTime? _month;

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
    final List<Transaction> expenses = allTransactions
        .where((Transaction item) => item.type == TransactionType.expense && item.recordKind != TransactionRecordKind.procurement)
        .where((Transaction item) => _farmId.isEmpty || item.farmId == _farmId)
        .where((Transaction item) =>
            _month == null ||
            (item.transactionDate.year == _month!.year &&
                item.transactionDate.month == _month!.month))
        .where((Transaction item) {
          if (_searchText.isEmpty) return true;
          final String haystack = '${item.description} ${item.category.name} ${item.notes} ${item.receiptNumber}'.toLowerCase();
          return haystack.contains(_searchText);
        })
        .toList(growable: false)
      ..sort((Transaction a, Transaction b) => b.transactionDate.compareTo(a.transactionDate));

    final double totalExpenses = expenses.fold<double>(0, (double sum, Transaction item) => sum + item.amount);
    final double averageExpense = expenses.isEmpty ? 0 : totalExpenses / expenses.length;
    final Map<TransactionCategory, double> categoryTotals = <TransactionCategory, double>{};
    for (final Transaction expense in expenses) {
      categoryTotals.update(
        expense.category,
        (double value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final DateTime nowDate = DateTime.now();
    final List<DateTime> months = <DateTime>[
      for (int i = 0; i < 4; i++) DateTime(nowDate.year, nowDate.month - i),
    ];
    final List<MapEntry<TransactionCategory, double>> topCategories =
        categoryTotals.entries.toList()
          ..sort((MapEntry<TransactionCategory, double> a,
                  MapEntry<TransactionCategory, double> b) =>
              b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/finance'),
        ),
        title: Text(ctr(context, 'Expense tracking', 'Bin diddigin kashe kudi', 'Suivi des dépenses', 'Expense tracking')),
        actions: <Widget>[
          IconButton(
            tooltip: ctr(context, 'Export expense history', 'Fitar da tarihin kashe kudi', 'Exporter l’historique des dépenses', 'Export expense history'),
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            onPressed: expenses.isEmpty || _isExporting
                ? null
                : () => _exportHistory(context, farms, expenses, totalExpenses, categoryTotals),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const FinanceNavBar(current: FinanceSection.expenses),
          const SizedBox(height: 14),
          FadeInUp(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF9E2F2F), Color(0xFFE0524A)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF9E2F2F).withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                      _month == null
                          ? ctr(context, 'Total spent', 'Jimillar kashe kudi', 'Total dépensé', 'Total wey you spend')
                          : ctr(context, 'Spent this month', 'An kashe a wannan wata', 'Dépensé ce mois-ci', 'Wey you spend this month'),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85), fontSize: 13)),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: totalExpenses),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (BuildContext context, double v, Widget? c) =>
                        Text(CurrencyUtils.formatCurrency(v),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _heroStat(ctr(context, 'Entries', 'Shigarwa', 'Entrées', 'Entries'), '${expenses.length}'),
                      ),
                      Expanded(
                        child: _heroStat(ctr(context, 'Average', 'Matsakaici', 'Moyenne', 'Average'),
                            CurrencyUtils.formatCompactCurrency(averageExpense)),
                      ),
                      Expanded(
                        child: _heroStat(
                            ctr(context, 'Top category', 'Babban rukuni', 'Catégorie principale', 'Top category'),
                            topCategories.isEmpty
                                ? '-'
                                : _categoryName(context, topCategories.first.key)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC800),
                            foregroundColor: const Color(0xFF3A1F00),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.go('/finance');
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: Text(ctr(context, 'Add expense', 'Kara kashe kudi', 'Ajouter une dépense', 'Add expense')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: ctr(context, 'Share PDF', 'Raba PDF', 'Partager le PDF', 'Share PDF'),
                        onPressed: expenses.isEmpty || _isExporting
                            ? null
                            : () => _exportHistory(context, farms, expenses,
                                totalExpenses, categoryTotals),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(ctr(context, 'All time', 'Kowane lokaci', 'Toute la période', 'All time')),
                    selected: _month == null,
                    onSelected: (_) => setState(() => _month = null),
                  ),
                ),
                for (final DateTime m in months)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_monthLabel(context, m)),
                      selected: _month != null &&
                          _month!.year == m.year &&
                          _month!.month == m.month,
                      onSelected: (_) => setState(() => _month = m),
                    ),
                  ),
              ],
            ),
          ),
          if (topCategories.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(ctr(context, 'Where it went', 'Inda ya tafi', 'Où cela est allé', 'Where e go'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  for (final MapEntry<TransactionCategory, double> e
                      in topCategories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(_categoryIcon(e.key),
                                  size: 16, color: _categoryColor(e.key)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(_categoryName(context, e.key),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                              Text(
                                  '${CurrencyUtils.formatCompactCurrency(e.value)} · ${totalExpenses <= 0 ? 0 : (e.value / totalExpenses * 100).round()}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          StockLevelBar(
                              value: totalExpenses <= 0
                                  ? 0
                                  : e.value / totalExpenses,
                              color: _categoryColor(e.key)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppTextField(
            controller: _searchController,
            label: ctr(context, 'Search expenses', 'Nemi kashe kudi', 'Rechercher des dépenses', 'Search expenses'),
            hint: ctr(context, 'Search by note, category, or receipt number', 'Nema ta bayani, rukuni ko lambar rasit', 'Rechercher par note, catégorie ou numéro de reçu', 'Search by note, category, or receipt number'),
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
          if (expenses.isEmpty)
            _EmptyState(message: ctr(context, 'No expense history matches the current filters.', 'Babu tarihin kashe kudi da ya dace da tacewar yanzu.', 'Aucun historique de dépenses ne correspond aux filtres.', 'No expense history match the filters.'))
          else
            ...expenses.map(
              (Transaction item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryCard(
                  title: item.description,
                  subtitle: _categoryName(context, item.category),
                  category: item.category,
                  meta: '${item.receiptNumber} • ${appDate(item.transactionDate)}',
                  amount: CurrencyUtils.formatCurrency(item.amount),
                ),
              ),
            ),
          const SizedBox(height: 10),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                ctr(context, 'Tip: expense entry and editing live in the Finance workspace. This page keeps the expense history easy to review and export.', 'Shawara: ana shigar da kashe kudi da gyara su a wurin aikin Kudi. Wannan shafin yana sauƙaƙa duba da fitar da tarihin kashe kudi.', 'Astuce : la saisie et la modification des dépenses se font dans l’espace Finances. Cette page facilite la consultation et l’export de l’historique.', 'Tip: you go enter and edit expense for Finance workspace. This page dey make am easy to check and export expense history.'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
          ),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 12)),
        ],
      );

  Future<void> _exportHistory(
    BuildContext context,
    List<Farm> farms,
    List<Transaction> expenses,
    double totalExpenses,
    Map<TransactionCategory, double> categoryTotals,
  ) async {
    setState(() => _isExporting = true);
    try {
      final String fileName = 'farmsync_expense_history_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final Uint8List bytes = await _reportService.buildReport(
        title: 'Expense history',
        subtitle: 'Expense review exported from FarmSync Hub',
        farms: farms,
        entries: expenses,
        income: 0,
        expenses: totalExpenses,
        categoryTotals: categoryTotals,
      );
      final String path = await _fileSaver.savePdf(bytes: bytes, fileName: fileName);
      await _shareService.sharePdf(
        filePath: path,
        fileName: fileName,
        message: 'FarmSync expense history is ready to share.',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ctr(context, 'Expense PDF saved: $path', 'An adana PDF na kashe kudi: $path', 'PDF des dépenses enregistré : $path', 'Expense PDF don save: $path'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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
      decoration: InputDecoration(
          labelText: ctr(context, 'Farm', 'Gona', 'Ferme', 'Farm')),
      items: <DropdownMenuItem<String>>[
        DropdownMenuItem<String>(
            value: '',
            child: Text(ctr(context, 'All farms', 'Dukkan gonaki', 'Toutes les fermes', 'All farms'))),
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

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.amount,
    required this.category,
  });

  final String title;
  final String subtitle;
  final String meta;
  final String amount;
  final TransactionCategory category;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color c = _categoryColor(category);
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: c.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_categoryIcon(category), color: c),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  Text(subtitle,
                      style: TextStyle(
                          color: c, fontSize: 12, fontWeight: FontWeight.w800)),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('-$amount',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE0524A))),
          ],
        ),
      ),
    );
  }
}

String _categoryName(BuildContext ctx, TransactionCategory c) {
  switch (c) {
    case TransactionCategory.cropSale:
      return ctr(ctx, 'Crop sales', 'Tallan amfanin gona', 'Ventes de cultures', 'Crop sales');
    case TransactionCategory.livestockSale:
      return ctr(ctx, 'Livestock sales', 'Tallan dabbobi', 'Ventes de bétail', 'Animal sales');
    case TransactionCategory.feed:
      return ctr(ctx, 'Feed', 'Abincin dabbobi', 'Aliment', 'Feed');
    case TransactionCategory.fertiliser:
      return ctr(ctx, 'Fertiliser', 'Taki', 'Engrais', 'Fertiliser');
    case TransactionCategory.labour:
      return ctr(ctx, 'Labour', 'Ma\'aikata', 'Main-d’œuvre', 'Labour');
    case TransactionCategory.veterinary:
      return ctr(ctx, 'Veterinary', 'Likitan dabbobi', 'Vétérinaire', 'Vet');
    case TransactionCategory.other:
      return ctr(ctx, 'Other', 'Wasu', 'Autre', 'Other');
  }
}

IconData _categoryIcon(TransactionCategory c) {
  switch (c) {
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

Color _categoryColor(TransactionCategory c) {
  switch (c) {
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

String _monthLabel(BuildContext ctx, DateTime d) {
  final List<String> names = <String>[
    ctr(ctx, 'Jan', 'Jan', 'janv.', 'Jan'),
    ctr(ctx, 'Feb', 'Fab', 'févr.', 'Feb'),
    ctr(ctx, 'Mar', 'Mar', 'mars', 'Mar'),
    ctr(ctx, 'Apr', 'Afr', 'avr.', 'Apr'),
    ctr(ctx, 'May', 'May', 'mai', 'May'),
    ctr(ctx, 'Jun', 'Yun', 'juin', 'Jun'),
    ctr(ctx, 'Jul', 'Yul', 'juil.', 'Jul'),
    ctr(ctx, 'Aug', 'Agu', 'août', 'Aug'),
    ctr(ctx, 'Sep', 'Sat', 'sept.', 'Sep'),
    ctr(ctx, 'Oct', 'Okt', 'oct.', 'Oct'),
    ctr(ctx, 'Nov', 'Nuw', 'nov.', 'Nov'),
    ctr(ctx, 'Dec', 'Dis', 'déc.', 'Dec'),
  ];
  return '${names[d.month - 1]} ${d.year}';
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
