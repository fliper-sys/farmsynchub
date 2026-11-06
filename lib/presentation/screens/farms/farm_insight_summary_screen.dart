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
import '../../common/widgets/detail_ui.dart';
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
          FadeInUp(
            child: _BalanceHero(
              income: _financeIncome(transactions),
              expenses: _financeExpenses(transactions),
            ),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            index: 1,
            child: Row(
              children: <Widget>[
                _InsightStat(
                    icon: Icons.grass_rounded,
                    label: 'Crops',
                    value: '${crops.length}',
                    color: const Color(0xFF2E9E5B)),
                const SizedBox(width: 10),
                _InsightStat(
                    icon: Icons.pets_rounded,
                    label: 'Livestock',
                    value:
                        '${livestock.fold<int>(0, (int sum, Livestock item) => sum + item.count)}',
                    color: const Color(0xFF3B82C4)),
                const SizedBox(width: 10),
                _InsightStat(
                    icon: Icons.folder_copy_rounded,
                    label: 'Records',
                    value:
                        '${farm.documents.length + farm.activityLog.length + transactions.length}',
                    color: const Color(0xFFE08A1E)),
              ],
            ),
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
              final bool waiting =
                  snapshot.connectionState == ConnectionState.waiting;
              final String briefing = snapshot.data?.trim().isNotEmpty == true
                  ? snapshot.data!.trim()
                  : _summaryText.trim().isNotEmpty
                      ? _summaryText
                      : _localFallbackBriefing(
                          farm!, crops, livestock, transactions);

              if (waiting && _summaryText.trim().isEmpty) {
                return const _BriefingLoading();
              }

              if (snapshot.hasData && snapshot.data!.trim().isNotEmpty) {
                _summaryText = snapshot.data!.trim();
              } else if (_summaryText.isEmpty) {
                _summaryText = briefing;
              }

              return _BriefingView(
                key: ValueKey<int>(briefing.hashCode),
                text: briefing,
              );
            },
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Recommended next actions'),
          FadeInUp(
            child: _ActionChecklist(
              actions: _nextActionTexts(farm, crops, livestock, transactions),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Important context'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _ContextChip(Icons.agriculture_rounded, farm.farmType.name),
              _ContextChip(Icons.terrain_rounded, farm.soilType.name),
              _ContextChip(Icons.water_drop_rounded, farm.waterSource.name),
              _ContextChip(Icons.groups_rounded,
                  '${farm.workspaceMembers.length} members'),
              _ContextChip(Icons.task_alt_rounded,
                  '${farm.openWorkspaceTaskCount} open tasks'),
              _ContextChip(Icons.update_rounded,
                  app_date.DateUtils.formatDate(farm.updatedAt)),
            ],
          ),
          const SizedBox(height: 24),
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

  List<String> _nextActionTexts(
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

    return actions;
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.income, required this.expenses});

  final double income;
  final double expenses;

  @override
  Widget build(BuildContext context) {
    final double balance = income - expenses;
    final bool positive = balance >= 0;
    final double total = income + expenses;
    final double incomeShare = total <= 0 ? 0.5 : income / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: positive
              ? const <Color>[Color(0xFF0E5A41), Color(0xFF2E9E5B)]
              : const <Color>[Color(0xFF8A2D1E), Color(0xFFD9622B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Net balance',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 13)),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: balance),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double v, Widget? c) => Text(
              CurrencyUtils.formatCurrency(v),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: incomeShare),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double v, Widget? c) =>
                  LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Income ${CurrencyUtils.formatCompactCurrency(income)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              Text('Expenses ${CurrencyUtils.formatCompactCurrency(expenses)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightStat extends StatelessWidget {
  const _InsightStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            Text(label,
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _BriefingLoading extends StatefulWidget {
  const _BriefingLoading();

  @override
  State<_BriefingLoading> createState() => _BriefingLoadingState();
}

class _BriefingLoadingState extends State<_BriefingLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        final Color bar = theme.colorScheme.onSurface
            .withOpacity(0.06 + 0.08 * _c.value);
        Widget line(double w) => Container(
              height: 12,
              width: w,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: bar, borderRadius: BorderRadius.circular(6)),
            );
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                Icon(Icons.auto_awesome_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Analysing your farm records...',
                    style: theme.textTheme.labelLarge),
              ]),
              const SizedBox(height: 16),
              line(double.infinity),
              line(260),
              line(double.infinity),
              line(180),
            ],
          ),
        );
      },
    );
  }
}

class _BriefingBlock {
  _BriefingBlock(this.heading);
  final String heading;
  final List<String> lines = <String>[];
}

List<_BriefingBlock> _parseBriefing(String text) {
  final List<_BriefingBlock> blocks = <_BriefingBlock>[];
  _BriefingBlock? current;
  for (final String raw in text.split('\n')) {
    String line = raw.trim();
    if (line.isEmpty) continue;
    line = line.replaceAll('**', '').replaceAll(RegExp(r'^#+\s*'), '');
    final bool bullet = RegExp(r'^([-*\u2022]|\d+[.)])\s+').hasMatch(line);
    if (bullet) {
      line = line.replaceFirst(RegExp(r'^([-*\u2022]|\d+[.)])\s+'), '');
      current ??= _BriefingBlock('');
      if (!blocks.contains(current)) blocks.add(current);
      current.lines.add(line);
    } else if (line.length <= 48 && !line.endsWith('.')) {
      current = _BriefingBlock(line.replaceAll(RegExp(r':$'), ''));
      blocks.add(current);
    } else {
      current ??= _BriefingBlock('');
      if (!blocks.contains(current)) blocks.add(current);
      current.lines.add(line);
    }
  }
  return blocks;
}

IconData _headingIcon(String h) {
  final String t = h.toLowerCase();
  if (t.contains('risk')) return Icons.warning_amber_rounded;
  if (t.contains('strength')) return Icons.thumb_up_alt_rounded;
  if (t.contains('next') || t.contains('action') || t.contains('recommend')) {
    return Icons.flag_rounded;
  }
  if (t.contains('situation') || t.contains('snapshot') || t.contains('summary')) {
    return Icons.insights_rounded;
  }
  return Icons.auto_awesome_rounded;
}

Color _headingColor(String h) {
  final String t = h.toLowerCase();
  if (t.contains('risk')) return const Color(0xFFD9622B);
  if (t.contains('strength')) return const Color(0xFF2E9E5B);
  if (t.contains('next') || t.contains('action')) return const Color(0xFF3B82C4);
  return const Color(0xFF7A5BC4);
}

class _BriefingView extends StatelessWidget {
  const _BriefingView({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_BriefingBlock> blocks = _parseBriefing(text);
    if (blocks.isEmpty) {
      return SelectableText(text);
    }
    return Column(
      children: <Widget>[
        for (int i = 0; i < blocks.length; i++)
          FadeInUp(
            index: i,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border(
                  left: BorderSide(
                      color: _headingColor(blocks[i].heading), width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (blocks[i].heading.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: <Widget>[
                        Icon(_headingIcon(blocks[i].heading),
                            size: 18, color: _headingColor(blocks[i].heading)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(blocks[i].heading,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ),
                  for (final String line in blocks[i].lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 7, right: 10),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _headingColor(blocks[i].heading),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(line,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionChecklist extends StatefulWidget {
  const _ActionChecklist({required this.actions});

  final List<String> actions;

  @override
  State<_ActionChecklist> createState() => _ActionChecklistState();
}

class _ActionChecklistState extends State<_ActionChecklist> {
  final Set<int> _done = <int>{};

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < widget.actions.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() {
                if (!_done.add(i)) _done.remove(i);
              }),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _done.contains(i)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withOpacity(0.12),
                      ),
                      child: _done.contains(i)
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: (theme.textTheme.bodyMedium ??
                                const TextStyle())
                            .copyWith(
                          height: 1.4,
                          decoration: _done.contains(i)
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: _done.contains(i)
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                        child: Text(widget.actions[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
