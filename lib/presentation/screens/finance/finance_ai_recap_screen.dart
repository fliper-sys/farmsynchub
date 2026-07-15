import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../domain/models/farm.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class FinanceAiRecapScreen extends ConsumerStatefulWidget {
  const FinanceAiRecapScreen({super.key});

  static const String routeName = '/finance-ai-recap';

  @override
  ConsumerState<FinanceAiRecapScreen> createState() => _FinanceAiRecapScreenState();
}

class _FinanceAiRecapScreenState extends ConsumerState<FinanceAiRecapScreen> {
  static const String _storageKey = 'finance_ai_recap_history';
  final List<_RecapEntry> _history = <_RecapEntry>[];
  bool _isLoading = false;
  String? _errorMessage;
  String _recapText = '';
  DateTime? _generatedAt;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadHistory();
    await _refreshRecap();
  }

  Future<void> _loadHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_storageKey) ?? '[]';
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _history
        ..clear()
        ..addAll(decoded
            .whereType<Map>()
            .map((Map item) => _RecapEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false));
    } catch (_) {
      _history.clear();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<_RecapEntry> entries = _history.take(8).toList(growable: false);
    await prefs.setString(_storageKey, jsonEncode(entries.map((_RecapEntry entry) => entry.toJson()).toList()));
  }

  Future<void> _refreshRecap() async {
    final List<Transaction> transactions = ref.read(transactionsProvider).valueOrNull ?? <Transaction>[];
    final List<Farm> farms = ref.read(farmsProvider).valueOrNull ?? <Farm>[];
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final String recap = await GeminiService.instance.generateFinanceRecap(
        transactions: transactions,
        farms: farms,
      );
      final DateTime now = DateTime.now();
      setState(() {
        _recapText = recap;
        _generatedAt = now;
        _history.insert(
          0,
          _RecapEntry(
            generatedAt: now,
            recapText: recap,
            income: _financeIncome(transactions),
            expenses: _financeExpenses(transactions),
            balance: _financeIncome(transactions) - _financeExpenses(transactions),
            transactionCount: transactions.length,
            farmCount: farms.length,
          ),
        );
        if (_history.length > 8) {
          _history.removeRange(8, _history.length);
        }
      });
      await _saveHistory();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not generate recap: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _financeIncome(List<Transaction> transactions) {
    return transactions
        .where((Transaction transaction) => transaction.type == TransactionType.income)
        .fold<double>(0, (double sum, Transaction transaction) => sum + transaction.amount);
  }

  double _financeExpenses(List<Transaction> transactions) {
    return transactions
        .where((Transaction transaction) => transaction.type == TransactionType.expense)
        .fold<double>(0, (double sum, Transaction transaction) => sum + transaction.amount);
  }

  @override
  Widget build(BuildContext context) {
    final List<Transaction> transactions = ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final double income = _financeIncome(transactions);
    final double expenses = _financeExpenses(transactions);
    final double balance = income - expenses;
    final List<String> futureSuggestions = _extractBullets(_recapText, 'Next suggestions');
    final List<String> previousReviewPoints = _extractBullets(_recapText, 'Previous review focus');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SoftScreenScaffold(
      heroTitle: 'AI finance recap',
      heroSubtitle: 'Review current performance, revisit previous AI recaps, and get practical next-step suggestions.',
      heroIcon: Icons.auto_awesome_rounded,
      heroVariant: FarmArtworkVariant.dashboard,
      heroBadge: '${_history.length} reviews saved',
      showArtwork: false,
      sections: <Widget>[
        _QuickStatsRow(
          farms: farms.length,
          income: income,
          expenses: expenses,
          balance: balance,
          transactions: transactions.length,
        ),
        const SizedBox(height: 18),
        AppCard(
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
                        'Current AI recap',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    AppButton.secondary(
                      onPressed: _isLoading ? null : _refreshRecap,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Refresh'),
                    ),
                    const SizedBox(width: 12),
                    AppButton.secondary(
                      onPressed: _recapText.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(ClipboardData(text: _recapText));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Recap copied to clipboard.')),
                              );
                            },
                      child: const Text('Copy'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _generatedAt == null ? 'The recap will appear here after generation.' : 'Generated ${app_date.DateUtils.formatDateTime(_generatedAt!)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 14),
                if (_errorMessage != null) ...<Widget>[
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                if (_isLoading && _recapText.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SelectableText(
                    _recapText.isEmpty ? 'No AI recap available yet.' : _recapText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SoftSectionTitle(
          title: 'Previous reviews',
        ),
        if (_history.isEmpty)
          const _EmptyState(message: 'No saved reviews yet. Generate one to keep a history.')
        else
          ..._history.map(
            (_RecapEntry entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              app_date.DateUtils.formatDateTime(entry.generatedAt),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            CurrencyUtils.formatCompactCurrency(entry.balance),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${entry.farmCount} farms • ${entry.transactionCount} transactions • Income ${CurrencyUtils.formatCompactCurrency(entry.income)}',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _excerpt(entry.recapText),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _BulletCard(
                title: 'Previous review focus',
                bullets: previousReviewPoints.isEmpty
                    ? const <String>['Open the recap once to generate a review focus list.']
                    : previousReviewPoints,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BulletCard(
                title: 'Future suggestions',
                bullets: futureSuggestions.isEmpty
                    ? const <String>['Refresh the recap to get AI suggestions for the next 3 to 7 days.']
                    : futureSuggestions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: AppButton.primary(
                    onPressed: () => context.go('/finance'),
                    child: const Text('Back to finance'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.secondary(
                    onPressed: () => context.go('/sales-info'),
                    child: const Text('Open sales analytics'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ));
  }

  List<String> _extractBullets(String text, String heading) {
    final List<String> lines = text.split('\n');
    final int startIndex = lines.indexWhere((String line) => line.trim().toLowerCase() == heading.toLowerCase());
    if (startIndex == -1) {
      return const <String>[];
    }
    final List<String> bullets = <String>[];
    for (int index = startIndex + 1; index < lines.length; index++) {
      final String line = lines[index].trim();
      if (line.isEmpty) {
        continue;
      }
      if (!line.startsWith('-')) {
        break;
      }
      bullets.add(line.substring(1).trim());
    }
    return bullets;
  }

  String _excerpt(String text) {
    final String cleaned = text.replaceAll('\n', ' ').trim();
    if (cleaned.length <= 180) {
      return cleaned;
    }
    return '${cleaned.substring(0, 180)}...';
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.farms,
    required this.income,
    required this.expenses,
    required this.balance,
    required this.transactions,
  });

  final int farms;
  final double income;
  final double expenses;
  final double balance;
  final int transactions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        SizedBox(width: 170, child: _MetricCard(label: 'Farms', value: farms.toString(), icon: Icons.agriculture_rounded)),
        SizedBox(width: 170, child: _MetricCard(label: 'Income', value: CurrencyUtils.formatCompactCurrency(income), icon: Icons.trending_up_rounded)),
        SizedBox(width: 170, child: _MetricCard(label: 'Expenses', value: CurrencyUtils.formatCompactCurrency(expenses), icon: Icons.trending_down_rounded)),
        SizedBox(width: 170, child: _MetricCard(label: 'Balance', value: CurrencyUtils.formatCompactCurrency(balance), icon: Icons.account_balance_wallet_rounded)),
        SizedBox(width: 170, child: _MetricCard(label: 'Records', value: transactions.toString(), icon: Icons.receipt_long_rounded)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (bullets.isEmpty)
              const Text('No suggestions available yet.')
            else
              ...bullets.map(
                (String item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('• '),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
          ],
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

class _RecapEntry {
  const _RecapEntry({
    required this.generatedAt,
    required this.recapText,
    required this.income,
    required this.expenses,
    required this.balance,
    required this.transactionCount,
    required this.farmCount,
  });

  final DateTime generatedAt;
  final String recapText;
  final double income;
  final double expenses;
  final double balance;
  final int transactionCount;
  final int farmCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'generatedAt': generatedAt.toIso8601String(),
        'recapText': recapText,
        'income': income,
        'expenses': expenses,
        'balance': balance,
        'transactionCount': transactionCount,
        'farmCount': farmCount,
      };

  factory _RecapEntry.fromJson(Map<String, dynamic> json) {
    return _RecapEntry(
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? DateTime.now(),
      recapText: json['recapText'] as String? ?? '',
      income: (json['income'] as num?)?.toDouble() ?? 0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
      farmCount: (json['farmCount'] as num?)?.toInt() ?? 0,
    );
  }
}
