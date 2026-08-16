import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_file_saver_base.dart';
import '../../../core/services/report_share_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/widget_image_capture.dart';
import '../../../data/services/crop_advice_catalog.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/crop_harvest_record.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/crop_calendar_schedule_widget.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/growth_timeline_widget.dart';
import '../../common/widgets/photo_journal_widget.dart';
import '../../common/widgets/ai_recommendations_widget.dart';
import '../../common/widgets/section_scroll_menu.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class CropDetailScreen extends ConsumerStatefulWidget {
  const CropDetailScreen({
    super.key,
    required this.cropId,
  });

  final String cropId;

  @override
  ConsumerState<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends ConsumerState<CropDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _shareBoundaryKey = GlobalKey();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  final ReportShareService _shareService = const ReportShareService();
  bool _isSharingStatus = false;

  // GlobalKeys for each major section
  final GlobalKey _growthCycleKey = GlobalKey();
  final GlobalKey _cropIntelligenceKey = GlobalKey();
  final GlobalKey _workFocusKey = GlobalKey();
  final GlobalKey _productionProfileKey = GlobalKey();
  final GlobalKey _performanceRatiosKey = GlobalKey();
  final GlobalKey _growthTimelineKey = GlobalKey();
  final GlobalKey _calendarScheduleKey = GlobalKey();
  final GlobalKey _photoJournalKey = GlobalKey();
  final GlobalKey _fieldTasksKey = GlobalKey();
  final GlobalKey _recentInputsKey = GlobalKey();
  final GlobalKey _aiRecommendationsKey = GlobalKey();

  List<SectionEntry> _mappedSections(AppLanguage language) => <SectionEntry>[
        SectionEntry(
            title: language.tr(
                en: 'Growth cycle',
                ha: 'Zagayen girma',
                fr: 'Cycle de croissance'),
            sectionKey: _growthCycleKey,
            icon: Icons.autorenew_rounded),
        SectionEntry(
            title: language.tr(
                en: 'Crop intelligence',
                ha: 'Basirar amfanin gona',
                fr: 'Intelligence culturale'),
            sectionKey: _cropIntelligenceKey,
            icon: Icons.lightbulb_outline_rounded),
        SectionEntry(
            title: language.tr(
                en: 'Work focus',
                ha: 'Manufar aiki',
                fr: 'Priorites de travail'),
            sectionKey: _workFocusKey,
            icon: Icons.task_alt_rounded),
        SectionEntry(
            title: language.tr(
                en: 'Production profile',
                ha: 'Bayanin samarwa',
                fr: 'Profil de production'),
            sectionKey: _productionProfileKey,
            icon: Icons.analytics_outlined),
        SectionEntry(
            title: language.tr(
                en: 'Performance ratios',
                ha: 'Ma\'aunin aiki',
                fr: 'Ratios de performance'),
            sectionKey: _performanceRatiosKey,
            icon: Icons.bar_chart_rounded),
        SectionEntry(
            title: language.tr(
                en: 'Growth Timeline',
                ha: 'Layin lokacin girma',
                fr: 'Chronologie de croissance'),
            sectionKey: _growthTimelineKey,
            icon: Icons.timeline_rounded),
        SectionEntry(
            title: language.tr(
                en: 'Calendar Schedule',
                ha: 'Jadawalin Kalanda',
                fr: 'Calendrier'),
            sectionKey: _calendarScheduleKey,
            icon: Icons.calendar_month_rounded),
        SectionEntry(
            title: language.tr(
                en: 'Photo Journal', ha: 'Littafin Hoto', fr: 'Journal photo'),
            sectionKey: _photoJournalKey,
            icon: Icons.photo_library_rounded),
        SectionEntry(
            title: language.tr(
                en: 'Field tasks', ha: 'Ayyukan gona', fr: 'Taches de terrain'),
            sectionKey: _fieldTasksKey,
            icon: Icons.checklist_rounded),
        SectionEntry(
            title: language.tr(
                en: 'Recent inputs',
                ha: 'Kayan da aka yi amfani da su kwanan nan',
                fr: 'Intrants recents'),
            sectionKey: _recentInputsKey,
            icon: Icons.inventory_2_rounded),
        SectionEntry(
            title: language.tr(
                en: 'AI Recommendations',
                ha: 'Shawarwarin AI',
                fr: 'Recommandations IA'),
            sectionKey: _aiRecommendationsKey,
            icon: Icons.psychology_rounded),
      ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final AsyncValue<List<Crop>> cropsAsync = ref.watch(cropsProvider);
    final List<Crop> crops = cropsAsync.valueOrNull ?? <Crop>[];
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];

    Crop? crop;
    for (final Crop item in crops) {
      if (item.id == widget.cropId) {
        crop = item;
        break;
      }
    }

    if (crop == null) {
      // Distinguish "records haven't loaded yet" from "genuinely missing" -
      // otherwise this briefly flashes "not found" on every load instead of
      // a loading state, until the provider resolves.
      if (cropsAsync.isLoading && !cropsAsync.hasValue) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Crop not found.')),
      );
    }

    Farm? farm;
    for (final Farm item in farms) {
      if (item.id == crop.farmId) {
        farm = item;
        break;
      }
    }

    final ThemeData theme = Theme.of(context);
    final double progress = crop.growthProgress;
    final List<_CyclePoint> cycle = _buildCropCycle(crop.currentStage);
    final Iterable<FarmTodoItem> openTasks =
        crop.todoItems.where((FarmTodoItem item) => !item.isCompleted);
    final CropAdviceSummary advice = CropAdviceCatalog.summarize(crop);
    final List<FarmTodoItem> openTaskList = openTasks.toList(growable: false);
    final int overdueTasks = openTaskList
        .where((FarmTodoItem item) => item.dueDate.isBefore(DateTime.now()))
        .length;
    final int priorityTasks = openTaskList
        .where((FarmTodoItem item) =>
            item.priority == FarmTodoPriority.high ||
            item.priority == FarmTodoPriority.urgent)
        .length;
    final double costPerHa =
        crop.areaHa <= 0 ? 0 : crop.totalInputCost / crop.areaHa;
    final bool hasActualYield = crop.actualYieldKg > 0;
    final double yieldPerHa = crop.areaHa <= 0
        ? 0
        : (hasActualYield ? crop.actualYieldKg : crop.targetYieldKg) /
            crop.areaHa;
    final double referenceYieldKg =
        hasActualYield ? crop.actualYieldKg : crop.targetYieldKg;
    final double inputCostPerTargetKg =
        referenceYieldKg <= 0 ? 0 : crop.totalInputCost / referenceYieldKg;
    final String cropWorkStatus = _cropWorkStatus(
      crop: crop,
      overdueTasks: overdueTasks,
      priorityTasks: priorityTasks,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(crop.name),
        actions: <Widget>[
          IconButton(
            tooltip: crop.isFavorite ? 'Unpin' : 'Pin to top of crop list',
            icon: Icon(
              crop.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: crop.isFavorite ? Colors.amber : null,
            ),
            onPressed: () => _toggleFavorite(crop!),
          ),
          IconButton(
            tooltip: 'Share status',
            icon: _isSharingStatus
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
            onPressed: _isSharingStatus ? null : () => _shareStatus(crop!),
          ),
          SectionScrollMenu(
            sections: _mappedSections(language),
            scrollController: _scrollController,
          ),
        ],
      ),
      body: SoftScreenScaffold(
        scrollController: _scrollController,
        heroTitle: crop.name,
        heroSubtitle: '${crop.variety} on ${farm?.name ?? 'Unknown farm'}',
        heroIcon: Icons.spa_rounded,
        heroVariant: FarmArtworkVariant.crops,
        heroBadge: '${(progress * 100).round()}% through cycle',
        sections: <Widget>[
          Container(
            key: _growthCycleKey,
            child: RepaintBoundary(
              key: _shareBoundaryKey,
              child: AppCard(
              color: theme.colorScheme.surfaceContainerHighest,
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
                                en: 'Growth cycle',
                                ha: 'Zagayen girma',
                                fr: 'Cycle de croissance'),
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        _Pill(
                            text: _stageLabel(crop.currentStage),
                            color: const Color(0xFFE8F4D8)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Day ${crop.daysSincePlanting.clamp(0, crop.cycleLengthDays)} of ${crop.cycleLengthDays} planned days. ${crop.daysToHarvest >= 0 ? '${crop.daysToHarvest} days to harvest.' : 'Harvest window is open.'}',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    ...cycle.map(
                      (_CyclePoint point) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CycleListTile(
                          title: point.title,
                          subtitle: point.subtitle,
                          isActive: point.isActive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _cropIntelligenceKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SoftSectionTitle(
                    title: language.tr(
                        en: 'Crop intelligence',
                        ha: 'Basirar amfanin gona',
                        fr: 'Intelligence culturale')),
                AppCard(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${advice.profile.name} guidance',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Detected land size: ${advice.areaLabel}',
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Text('Seed requirement: ${advice.seedRequirementLabel}',
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Text('Fertiliser: ${advice.fertiliserSummary}',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(height: 1.5)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: advice.otherInputs
                              .map((String item) => _Pill(
                                  text: item, color: const Color(0xFFE8F4D8)))
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 12),
                        AppButton.secondary(
                          onPressed: () =>
                              _openPreviousRecommendations(context, crop!),
                          child: Text(language.tr(
                              en: 'Previous recommendations',
                              ha: 'Shawarwarin da suka gabata',
                              fr: 'Recommandations precedentes')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _workFocusKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SoftSectionTitle(
                    title: language.tr(
                        en: 'Work focus',
                        ha: 'Manufar aiki',
                        fr: 'Priorites de travail')),
                AppCard(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _Pill(
                          text: cropWorkStatus,
                          color: _workStatusColor(overdueTasks, priorityTasks),
                          emphasized: true,
                        ),
                        _Pill(
                            text: '$overdueTasks overdue',
                            color: const Color(0xFFFFEBD0)),
                        _Pill(
                            text: '$priorityTasks high priority',
                            color: const Color(0xFFEDE8FF)),
                        _Pill(
                            text: '${crop.openTaskCount} open reminders',
                            color: const Color(0xFFE8F4D8)),
                        _Pill(
                            text: _harvestWindowLabel(crop),
                            color: const Color(0xFFDFF1FF)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _productionProfileKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SoftSectionTitle(
                    title: language.tr(
                        en: 'Production profile',
                        ha: 'Bayanin samarwa',
                        fr: 'Profil de production')),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricCard(
                        title: 'Area',
                        value: '${crop.areaHa.toStringAsFixed(2)} ha',
                        note: crop.protectedEnvironment
                            ? 'Protected crop'
                            : 'Open-field crop',
                        tint: const Color(0xFFDFF1FF),
                        icon: Icons.crop_square_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Target yield',
                        value: crop.targetYieldKg > 0
                            ? '${crop.targetYieldKg.toStringAsFixed(0)} kg'
                            : 'Not set',
                        note: 'Cycle target',
                        tint: const Color(0xFFFFEBD0),
                        icon: Icons.grass_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricCard(
                        title: 'Input spend',
                        value:
                            CurrencyUtils.formatCurrency(crop.totalInputCost),
                        note: '${crop.inputRecords.length} records',
                        tint: const Color(0xFFEDE8FF),
                        icon: Icons.shopping_basket_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Open tasks',
                        value: '${crop.openTaskCount}',
                        note: '${crop.todoItems.length} total reminders',
                        tint: const Color(0xFFE8F4D8),
                        icon: Icons.checklist_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _performanceRatiosKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SoftSectionTitle(
                    title: language.tr(
                        en: 'Performance ratios',
                        ha: 'Ma\'aunin aiki',
                        fr: 'Ratios de performance')),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricCard(
                        title: 'Cost / ha',
                        value: crop.areaHa <= 0
                            ? 'Not ready'
                            : CurrencyUtils.formatCurrency(costPerHa),
                        note: '${crop.inputRecords.length} input records',
                        tint: const Color(0xFFEDE8FF),
                        icon: Icons.payments_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Yield / ha',
                        value: referenceYieldKg <= 0 || crop.areaHa <= 0
                            ? 'Not set'
                            : '${yieldPerHa.toStringAsFixed(0)} kg',
                        note: hasActualYield
                            ? 'Actual harvest'
                            : 'Target density',
                        tint: const Color(0xFFE8F4D8),
                        icon: Icons.eco_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricCard(
                        title: 'Input / kg',
                        value: inputCostPerTargetKg <= 0
                            ? 'Not ready'
                            : CurrencyUtils.formatCurrency(
                                inputCostPerTargetKg),
                        note: 'Against target yield',
                        tint: const Color(0xFFFFEBD0),
                        icon: Icons.scale_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Records',
                        value:
                            '${crop.inputRecords.length + crop.todoItems.length}',
                        note: 'Inputs plus reminders',
                        tint: const Color(0xFFDFF1FF),
                        icon: Icons.folder_copy_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _growthTimelineKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SoftSectionTitle(
                    title: language.tr(
                        en: 'Growth Timeline',
                        ha: 'Layin lokacin girma',
                        fr: 'Chronologie de croissance')),
                GrowthTimelineWidget(crop: crop),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _calendarScheduleKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SoftSectionTitle(
                    title: language.tr(
                        en: 'Calendar Schedule',
                        ha: 'Jadawalin Kalanda',
                        fr: 'Calendrier')),
                CropCalendarScheduleWidget(crop: crop),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _photoJournalKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SoftSectionTitle(
                    title: language.tr(
                        en: 'Photo Journal',
                        ha: 'Littafin Hoto',
                        fr: 'Journal photo')),
                PhotoJournalWidget(crop: crop),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _fieldTasksKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SoftSectionTitle(
                    title: language.tr(
                        en: 'Field tasks',
                        ha: 'Ayyukan gona',
                        fr: 'Taches de terrain')),
                if (openTasks.isEmpty)
                  const _InfoCard(
                      message:
                          'No open crop reminders yet. Add scouting, irrigation, feeding, or harvest reminders from the crop records screen.')
                else
                  ...openTasks.take(4).map(
                        (FarmTodoItem task) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TaskCard(task: task),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _recentInputsKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SoftSectionTitle(
                    title: language.tr(
                        en: 'Recent inputs',
                        ha: 'Kayan da aka yi amfani da su kwanan nan',
                        fr: 'Intrants recents')),
                if (crop.inputRecords.isEmpty)
                  const _InfoCard(
                      message:
                          'No input records yet. Add seed, fertiliser, labour, or equipment records from crop management.')
                else
                  ...crop.inputRecords.take(4).map(
                        (FarmInputRecord item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InputCard(item: item),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _aiRecommendationsKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SoftSectionTitle(
                    title: language.tr(
                        en: 'AI Recommendations',
                        ha: 'Shawarwarin AI',
                        fr: 'Recommandations IA')),
                AiRecommendationsWidget(crop: crop),
                if ((farm?.supportsGreenhouse ?? false) ||
                    crop.protectedEnvironment) ...<Widget>[
                  const SizedBox(height: 12),
                  const _SuggestionCard(
                    title: 'Greenhouse routine',
                    detail:
                        'Check heat build-up, ventilation, humidity, and disease spread in enclosed spaces before watering again.',
                    tint: Color(0xFFFFEBD0),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton.primary(
                  onPressed: () => _openHarvestSheet(context, ref, crop!),
                  child: const Text('Record harvest'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.secondary(
                  onPressed: () => _renewCrop(context, ref, crop!),
                  child: const Text('Renew crop'),
                ),
              ),
            ],
          ),
        ], // end of sections list
      ), // end of SoftScreenScaffold
    ); // end of Scaffold
  }

  Future<void> _toggleFavorite(Crop crop) async {
    await ref.read(cropsProvider.notifier).updateCrop(
          crop.copyWith(
            isFavorite: !crop.isFavorite,
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );
  }

  Future<void> _shareStatus(Crop crop) async {
    setState(() => _isSharingStatus = true);
    try {
      final Uint8List? imageBytes =
          await captureBoundaryImage(_shareBoundaryKey);
      if (imageBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not capture the status card.')));
        }
        return;
      }
      final String fileName =
          'crop_status_${crop.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final String savedPath = await _fileSaver.saveBytes(
        bytes: imageBytes,
        fileName: fileName,
        mimeType: 'image/png',
      );
      await _shareService.shareImage(
        filePath: savedPath,
        fileName: fileName,
        message: '${crop.name} status from FarmSync Hub',
      );
    } finally {
      if (mounted) setState(() => _isSharingStatus = false);
    }
  }

  Future<void> _openPreviousRecommendations(
      BuildContext context, Crop crop) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreviousCropRecommendationsScreen(cropName: crop.name),
      ),
    );
  }

  Future<void> _openHarvestSheet(
      BuildContext context, WidgetRef ref, Crop crop) async {
    final _HarvestDraft? draft = await showModalBottomSheet<_HarvestDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HarvestSheet(crop: crop),
    );
    if (draft == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final double quantityHa = draft.quantity;
    await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
          farmId: crop.farmId,
          productName: crop.name,
          unit: draft.unit,
          deltaQuantity: quantityHa,
          unitPrice: draft.unitPrice,
          costPrice: crop.areaHa > 0 ? crop.totalInputCost / crop.areaHa : 0,
        );
    final CropHarvestRecord harvestRecord = CropHarvestRecord(
      id: const Uuid().v4(),
      cropId: crop.id,
      harvestedAt: now,
      quantity: draft.quantity,
      unit: draft.unit,
      unitPrice: draft.unitPrice,
    );
    await ref.read(cropsProvider.notifier).updateCrop(
          crop.copyWith(
            status: CropStatus.harvested,
            currentStage: CropStage.fruiting,
            updatedAt: now,
            isSynced: false,
            harvestRecords: <CropHarvestRecord>[
              harvestRecord,
              ...crop.harvestRecords,
            ],
            // Append rather than overwrite - a harvest note used to wipe out
            // every prior intelligence note on the crop.
            intelligenceNotes:
                '[${now.day}/${now.month}] ${crop.name} harvested: ${draft.quantityLabel}.\n${crop.intelligenceNotes}',
            lastIntelligenceSyncAt: now,
          ),
        );
    if (draft.unitPrice > 0) {
      await ref.read(transactionsProvider.notifier).addTransaction(
            Transaction(
              id: const Uuid().v4(),
              farmId: crop.farmId,
              type: TransactionType.income,
              category: TransactionCategory.cropSale,
              amount: harvestRecord.totalValue,
              description: '${crop.name} harvest (${draft.quantityLabel})',
              transactionDate: now,
              linkedEntityId: crop.id,
              createdAt: now,
              updatedAt: now,
              isSynced: true,
              recordKind: TransactionRecordKind.sale,
              partyType: TransactionPartyType.internal,
              productName: crop.name,
              quantity: draft.quantity,
              unit: draft.unit,
              unitPrice: draft.unitPrice,
              receiptNumber: 'HV-${now.millisecondsSinceEpoch}',
              notes: 'Auto-recorded when the harvest was logged.',
            ),
          );
    }
    final List<Farm> farms = ref.read(farmsProvider).valueOrNull ?? <Farm>[];
    Farm? farm;
    for (final Farm item in farms) {
      if (item.id == crop.farmId) {
        farm = item;
        break;
      }
    }
    if (farm != null) {
      await ref.read(farmsProvider.notifier).updateFarm(
            farm.copyWith(
              activityLog: <FarmActivityRecord>[
                FarmActivityRecord(
                  id: const Uuid().v4(),
                  actorName: 'You',
                  actorRole: FarmWorkspaceRole.owner,
                  action: 'Crop harvested',
                  detail: '${crop.name} recorded as ${draft.quantityLabel}',
                  audience: FarmActivityAudience.owners,
                  createdAt: now,
                ),
                ...farm.activityLog,
              ],
              updatedAt: now,
              isSynced: false,
            ),
          );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harvest recorded and stock updated.')),
      );
    }
  }

  Future<void> _renewCrop(
      BuildContext context, WidgetRef ref, Crop crop) async {
    final DateTime now = DateTime.now();
    final Crop nextCrop = Crop(
      id: const Uuid().v4(),
      farmId: crop.farmId,
      name: crop.name,
      variety: crop.variety,
      areaHa: crop.areaHa,
      plantingDate: now,
      expectedHarvestDate: now.add(Duration(days: crop.cycleLengthDays)),
      currentStage: CropStage.seeding,
      status: CropStatus.planted,
      totalInputCost: 0,
      cycleLengthDays: crop.cycleLengthDays,
      notes: crop.notes,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      profileImageBase64: crop.profileImageBase64,
      landSizeValue: crop.landSizeValue,
      landSizeUnit: crop.landSizeUnit,
      targetYieldKg: crop.targetYieldKg,
      protectedEnvironment: crop.protectedEnvironment,
      todoItems: const <FarmTodoItem>[],
      inputRecords: const <FarmInputRecord>[],
      intelligenceNotes: 'Renewed from previous ${crop.name} cycle.',
      lastIntelligenceSyncAt: now,
    );
    await ref.read(cropsProvider.notifier).addCrop(
          nextCrop,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('New crop cycle created from this profile.')),
      );
    }
  }
}

class _CyclePoint {
  const _CyclePoint({
    required this.title,
    required this.subtitle,
    required this.isActive,
  });

  final String title;
  final String subtitle;
  final bool isActive;
}

List<_CyclePoint> _buildCropCycle(CropStage currentStage) {
  const List<CropStage> stages = <CropStage>[
    CropStage.seeding,
    CropStage.germination,
    CropStage.vegetative,
    CropStage.flowering,
    CropStage.fruiting,
  ];
  return stages
      .map(
        (CropStage stage) => _CyclePoint(
          title: _stageLabel(stage),
          subtitle: _stageAdvice(stage),
          isActive: stages.indexOf(stage) <= stages.indexOf(currentStage),
        ),
      )
      .toList(growable: false);
}

String _stageLabel(CropStage stage) {
  switch (stage) {
    case CropStage.seeding:
      return 'Seeding';
    case CropStage.germination:
      return 'Germination';
    case CropStage.vegetative:
      return 'Vegetative';
    case CropStage.flowering:
      return 'Flowering';
    case CropStage.fruiting:
      return 'Fruiting';
  }
}

String _stageAdvice(CropStage stage) {
  switch (stage) {
    case CropStage.seeding:
      return 'Protect seedbed moisture and emergence.';
    case CropStage.germination:
      return 'Check gaps, damping off, and bird damage.';
    case CropStage.vegetative:
      return 'Push rooting, nutrition, and weed control.';
    case CropStage.flowering:
      return 'Reduce stress and maintain even moisture.';
    case CropStage.fruiting:
      return 'Track quality, picking window, and market prep.';
  }
}

String _cropWorkStatus({
  required Crop crop,
  required int overdueTasks,
  required int priorityTasks,
}) {
  if (overdueTasks > 0) {
    return 'Overdue work';
  }
  if (priorityTasks > 0) {
    return 'Priority reminders';
  }
  if (crop.daysToHarvest <= 7) {
    return crop.daysToHarvest < 0 ? 'Harvest due' : 'Harvest window';
  }
  if (crop.currentStage == CropStage.flowering ||
      crop.currentStage == CropStage.fruiting) {
    return 'Yield protection';
  }
  return 'Cycle on track';
}

Color _workStatusColor(int overdueTasks, int priorityTasks) {
  if (overdueTasks > 0) return const Color(0xFFE0685F);
  if (priorityTasks > 0) return const Color(0xFFB98A2E);
  return const Color(0xFF3F8B4C);
}

String _harvestWindowLabel(Crop crop) {
  if (crop.daysToHarvest < 0) {
    return 'Harvest due';
  }
  if (crop.daysToHarvest == 0) {
    return 'Harvest today';
  }
  return '${crop.daysToHarvest} days to harvest';
}

class PreviousCropRecommendationsScreen extends ConsumerWidget {
  const PreviousCropRecommendationsScreen({
    super.key,
    required this.cropName,
  });

  final String cropName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final List<Crop> crops = ref.watch(cropsProvider).valueOrNull ?? <Crop>[];
    final String normalized = cropName.trim().toLowerCase();
    final List<Crop> previous = crops
        .where((Crop crop) => crop.name.trim().toLowerCase() == normalized)
        .toList(growable: false)
      ..sort((Crop a, Crop b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          language.tr(
              en: '$cropName history',
              ha: 'Tarihin $cropName',
              fr: 'Historique de $cropName'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SoftSectionTitle(
              title: language.tr(
                  en: 'Previous recommendations',
                  ha: 'Shawarwarin da suka gabata',
                  fr: 'Recommandations precedentes')),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                language.tr(
                  en: 'This page collects earlier $cropName cycles so you can reuse what worked, adjust fertilizer plans, and avoid repeating problems.',
                  ha: 'Wannan shafi yana tattara zagayowar $cropName na baya domin ka sake amfani da abin da ya yi aiki, ka gyara shirin taki, kuma ka guji sake maimaita matsaloli.',
                  fr: 'Cette page rassemble les cycles precedents de $cropName afin de reutiliser ce qui a fonctionne, ajuster les plans d\'engrais et eviter de repeter les problemes.',
                ),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (previous.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  language.tr(
                    en: 'No previous crop profiles found yet. Once you complete a cycle, its notes and recommendations will appear here.',
                    ha: 'Ba a sami bayanan amfanin gona na baya ba tukuna. Da zarar ka kammala zagaye, bayanansa da shawarwari za su bayyana anan.',
                    fr: 'Aucun profil de culture precedent trouve pour le moment. Une fois un cycle termine, ses notes et recommandations apparaitront ici.',
                  ),
                ),
              ),
            )
          else
            ...previous.map(
              (Crop crop) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(crop.variety,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                            'Land: ${crop.landSizeLabel} | Stage: ${_stageLabel(crop.currentStage)}'),
                        const SizedBox(height: 6),
                        Text(crop.intelligenceNotes.isEmpty
                            ? 'No stored notes for this cycle.'
                            : crop.intelligenceNotes),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HarvestSheet extends StatefulWidget {
  const _HarvestSheet({required this.crop});

  final Crop crop;

  @override
  State<_HarvestSheet> createState() => _HarvestSheetState();
}

class _HarvestSheetState extends State<_HarvestSheet> {
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final TextEditingController _unitPriceController = TextEditingController();
  String _unit = 'kg';

  @override
  void dispose() {
    _quantityController.dispose();
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
            Text('Record harvest',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _unit,
              items: const <String>['kg', 'ton', 'bags']
                  .map((String value) => DropdownMenuItem<String>(
                      value: value, child: Text(value)))
                  .toList(growable: false),
              onChanged: (String? value) {
                if (value != null) setState(() => _unit = value);
              },
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unitPriceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Sale price per unit (optional)',
                hintText: 'Leave blank if not sold yet',
              ),
            ),
            const SizedBox(height: 18),
            AppButton.primary(
              onPressed: () {
                final double quantity =
                    double.tryParse(_quantityController.text.trim()) ?? 0;
                final double unitPrice =
                    double.tryParse(_unitPriceController.text.trim()) ?? 0;
                Navigator.of(context).pop(
                  _HarvestDraft(
                    quantity: quantity,
                    unit: _unit,
                    unitPrice: unitPrice,
                  ),
                );
              },
              child: const Text('Save harvest'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HarvestDraft {
  const _HarvestDraft({
    required this.quantity,
    required this.unit,
    this.unitPrice = 0,
  });

  final double quantity;
  final String unit;
  final double unitPrice;

  String get quantityLabel =>
      '${quantity.toStringAsFixed(quantity >= 10 ? 0 : 1)} $unit';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.note,
    required this.tint,
    required this.icon,
  });

  final String title;
  final String value;
  final String note;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color markerColor = isDark
        ? Color.alphaBlend(tint.withOpacity(0.24), theme.colorScheme.surface)
        : tint;
    final Color iconColor = isDark ? theme.colorScheme.onSurface : Colors.black87;

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: markerColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color:
                        isDark ? tint.withOpacity(0.44) : Colors.transparent),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(title),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(note, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.emphasized = false});

  final String text;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = emphasized
        ? color
        : isDark
            ? Color.alphaBlend(color.withOpacity(0.22), theme.colorScheme.surface)
            : color;
    final Color foreground = emphasized
        ? Colors.white
        : isDark
            ? theme.colorScheme.onSurface
            : const Color(0xFF284231);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: isDark ? color.withOpacity(0.44) : color.withOpacity(0.85)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CycleListTile extends StatelessWidget {
  const _CycleListTile({
    required this.title,
    required this.subtitle,
    required this.isActive,
  });

  final String title;
  final String subtitle;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final FarmTodoItem task;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.event_note_rounded),
        title: Text(task.title),
        subtitle: Text(task.notes.isEmpty
            ? 'Due ${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}'
            : task.notes),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.item});

  final FarmInputRecord item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.inventory_2_rounded),
        title: Text(item.name),
        subtitle: Text('${item.quantity} ${item.unit} - ${item.category.name}'),
        trailing: Text(CurrencyUtils.formatCurrency(item.totalCost)),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.title,
    required this.detail,
    required this.tint,
  });

  final String title;
  final String detail;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color iconBackground = isDark
        ? Color.alphaBlend(tint.withOpacity(0.22), theme.colorScheme.surface)
        : tint;
    final Color iconForeground =
        isDark ? theme.colorScheme.onSurface : const Color(0xFF44624E);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color:
                        isDark ? tint.withOpacity(0.42) : Colors.transparent),
              ),
              child:
                  Icon(Icons.lightbulb_outline_rounded, color: iconForeground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(detail,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
