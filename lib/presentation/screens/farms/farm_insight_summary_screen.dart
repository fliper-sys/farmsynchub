import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/farm_insight_report_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_share_service.dart';
import '../../../core/services/report_file_saver_base.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/livestock.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class FarmInsightSummaryScreen extends ConsumerStatefulWidget {
  const FarmInsightSummaryScreen({
    super.key,
    required this.farmId,
  });

  final String farmId;

  @override
  ConsumerState<FarmInsightSummaryScreen> createState() => _FarmInsightSummaryScreenState();
}

class _FarmInsightSummaryScreenState extends ConsumerState<FarmInsightSummaryScreen> {
  final FarmInsightReportService _reportService = FarmInsightReportService();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  final ReportShareService _shareService = const ReportShareService();

  Future<String>? _summaryFuture;
  String _summaryText = '';
  String _fingerprint = '';
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    Farm? farm;
    for (final Farm item in farms) {
      if (item.id == widget.farmId) {
        farm = item;
        break;
      }
    }
    if (farm == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Farm not found.')),
      );
    }

    final List<Crop> crops = (ref.watch(cropsProvider).valueOrNull ?? <Crop>[])
        .where((Crop item) => item.farmId == farm!.id)
        .toList(growable: false);
    final List<Livestock> livestock = (ref.watch(livestockProvider).valueOrNull ?? <Livestock>[])
        .where((Livestock item) => item.farmId == farm!.id)
        .toList(growable: false);
    final List<Transaction> transactions = (ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[])
        .where((Transaction item) => item.farmId == farm!.id)
        .toList(growable: false);

    final String fingerprint = _buildFingerprint(farm, crops, livestock, transactions);
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _summaryFuture = GeminiService.instance.generateFarmInsight(
        farm: farm,
        crops: crops,
        livestock: livestock,
        transactions: transactions,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SoftScreenScaffold(
        heroTitle: 'AI farm briefing',
        heroSubtitle: 'A practical briefing for ${farm.name} based on the stored farm, crop, livestock, and finance records.',
        heroIcon: Icons.insights_rounded,
        heroVariant: FarmArtworkVariant.dashboard,
        heroBadge: '${farm.documents.length} docs • ${farm.openWorkspaceTaskCount} open tasks',
        trailing: SizedBox(
          width: 52,
          height: 52,
          child: AppButton.primary(
            onPressed: _isExporting ? null : () => _exportPdf(context, farm!, crops, livestock, transactions),
            child: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
          ),
        ),
        sections: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryStat(
                  label: 'Income',
                  value: CurrencyUtils.formatCompactCurrency(_financeIncome(transactions)),
                  color: const Color(0xFFE5F5D8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryStat(
                  label: 'Expenses',
                  value: CurrencyUtils.formatCompactCurrency(_financeExpenses(transactions)),
                  color: const Color(0xFFFFE7D7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryStat(
                  label: 'Balance',
                  value: CurrencyUtils.formatCompactCurrency(_financeIncome(transactions) - _financeExpenses(transactions)),
                  color: const Color(0xFFDFF1FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryStat(
                  label: 'Crops',
                  value: '${crops.length}',
                  color: const Color(0xFFE8F4DB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryStat(
                  label: 'Livestock',
                  value: '${livestock.fold<int>(0, (int sum, Livestock item) => sum + item.count)}',
                  color: const Color(0xFFDFF1FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryStat(
                  label: 'Records',
                  value: '${farm.documents.length + farm.activityLog.length + transactions.length}',
                  color: const Color(0xFFFFEBD0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SoftSectionTitle(
            title: 'AI briefing',
            action: TextButton.icon(
              onPressed: () {
                setState(() {
                  _summaryText = '';
                  _fingerprint = '';
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ),
          FutureBuilder<String>(
            future: _summaryFuture,
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              final String briefing = snapshot.data?.trim().isNotEmpty == true
                  ? snapshot.data!.trim()
                  : _summaryText.trim().isNotEmpty
                      ? _summaryText
                      : _localFallbackBriefing(farm!, crops, livestock, transactions);

              if (snapshot.connectionState == ConnectionState.waiting && briefing.isEmpty) {
                return const AppCard(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (snapshot.hasData && snapshot.data!.trim().isNotEmpty) {
                _summaryText = snapshot.data!.trim();
              } else if (_summaryText.isEmpty) {
                _summaryText = briefing;
              }

              return AppCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SelectableText(
                    briefing,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Recommended next actions'),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _nextActions(farm, crops, livestock, transactions),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Important context'),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _MiniTag(text: farm.farmType.name),
                  _MiniTag(text: farm.soilType.name),
                  _MiniTag(text: farm.waterSource.name),
                  _MiniTag(text: '${farm.workspaceMembers.length} members'),
                  _MiniTag(text: '${farm.openWorkspaceTaskCount} open tasks'),
                  _MiniTag(text: app_date.DateUtils.formatDate(farm.updatedAt)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    Farm farm,
    List<Crop> crops,
    List<Livestock> livestock,
    List<Transaction> transactions,
  ) async {
    setState(() => _isExporting = true);
    try {
      final String fileName =
          'farmsync_hub_farm_insight_${farm.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final String briefing = _summaryText.trim().isNotEmpty
          ? _summaryText
          : _localFallbackBriefing(farm, crops, livestock, transactions);
      final Uint8List pdfBytes = await _reportService.buildReport(
        farm: farm,
        crops: crops,
        livestock: livestock,
        transactions: transactions,
        aiBriefing: briefing,
      );
      final String savedPath = await _fileSaver.savePdf(
        bytes: pdfBytes,
        fileName: fileName,
      );
      await _shareService.sharePdf(
        filePath: savedPath,
        fileName: fileName,
        message: 'Farm insight report is ready to share.',
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insight PDF saved: $savedPath')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _buildFingerprint(
    Farm farm,
    List<Crop> crops,
    List<Livestock> livestock,
    List<Transaction> transactions,
  ) {
    return [
      farm.updatedAt.millisecondsSinceEpoch,
      farm.documents.length,
      farm.activityLog.length,
      crops.length,
      livestock.length,
      transactions.length,
    ].join(':');
  }

  double _financeIncome(List<Transaction> transactions) {
    return transactions
        .where((Transaction item) => item.type == TransactionType.income)
        .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
  }

  double _financeExpenses(List<Transaction> transactions) {
    return transactions
        .where((Transaction item) => item.type == TransactionType.expense)
        .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
  }

  String _localFallbackBriefing(
    Farm farm,
    List<Crop> crops,
    List<Livestock> livestock,
    List<Transaction> transactions,
  ) {
    final double income = _financeIncome(transactions);
    final double expenses = _financeExpenses(transactions);
    final double balance = income - expenses;
    return '''
Situation snapshot
- Farm: ${farm.name}
- Ward: ${farm.ward}
- Size: ${farm.sizeHa.toStringAsFixed(2)} ha
- Balance: ${CurrencyUtils.formatCurrency(balance)}

Strengths
- ${crops.isEmpty ? 'No crop records yet, so this is a clean point to start tracking.' : 'Crop records are available and can be reviewed quickly.'}
- ${livestock.isEmpty ? 'No livestock groups are linked yet.' : 'Livestock groups are linked to the farm and can be monitored.'}
- ${farm.documents.isEmpty ? 'Document storage can still be improved.' : '${farm.documents.length} documents are already stored.'}

Risks
- ${farm.openWorkspaceTaskCount} open task(s) still need follow-up.
- ${farm.soilMoisturePercent < 30 ? 'Soil moisture is low; check watering or mulch coverage.' : farm.soilMoisturePercent > 80 ? 'Soil moisture is high; check drainage and root stress.' : 'Soil moisture looks stable.'}
- ${expenses > income ? 'Expenses are above income, so cost control matters now.' : 'The financial balance is currently positive.'}

Next 7 days
- Walk the farm and confirm crop, livestock, and finance entries.
- Update tasks, documents, and notes that are missing.
- Review the highest-cost crop or livestock group.
- Check water, drainage, and storage before the next weather change.
''';
  }

  List<Widget> _nextActions(
    Farm farm,
    List<Crop> crops,
    List<Livestock> livestock,
    List<Transaction> transactions,
  ) {
    final double income = _financeIncome(transactions);
    final double expenses = _financeExpenses(transactions);
    final List<String> actions = <String>[
      "Visit the field or pens and verify today's state against the saved records.",
      if (farm.openWorkspaceTaskCount > 0) 'Complete the ${farm.openWorkspaceTaskCount} open farm task(s) and update the activity log.',
      if (farm.documents.isEmpty) 'Add permits, receipts, and photos so the record set becomes easier to review later.',
      if (crops.isNotEmpty) 'Inspect the most advanced crop for pest, water, and harvest readiness.',
      if (livestock.isNotEmpty) 'Review animal health, feed, water, and vaccination notes for the largest livestock group.',
      if (expenses > income) 'Pause unnecessary spending and focus on the cost items with the biggest effect on balance.',
      'Export the report after the next update cycle so the latest record set is preserved.',
    ];

    return actions
        .map(
          (String action) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('- '),
                Expanded(child: Text(action)),
              ],
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text),
    );
  }
}
