import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/feeding_plan_widget.dart';
import '../../common/widgets/photo_journal_widget.dart';
import '../../common/widgets/ai_recommendations_widget.dart';
import '../../common/widgets/section_scroll_menu.dart';
import '../../common/widgets/soft_screen_scaffold.dart';
import '../../common/widgets/vaccination_calendar_widget.dart';
import '../../common/widgets/weight_gain_chart_widget.dart';

class LivestockDetailScreen extends ConsumerWidget {
  const LivestockDetailScreen({
    super.key,
    required this.livestockId,
  });

  final String livestockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final AsyncValue<List<Livestock>> livestockAsync =
        ref.watch(livestockProvider);
    final List<Livestock> livestockItems =
        livestockAsync.valueOrNull ?? <Livestock>[];
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];

    Livestock? livestock;
    for (final Livestock item in livestockItems) {
      if (item.id == livestockId) {
        livestock = item;
        break;
      }
    }

    if (livestock == null) {
      // Distinguish "records haven't loaded yet" from "genuinely missing" -
      // otherwise this briefly flashes "not found" on every load instead of
      // a loading state, until the provider resolves.
      if (livestockAsync.isLoading && !livestockAsync.hasValue) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Livestock group not found.')),
      );
    }

    Farm? farm;
    for (final Farm item in farms) {
      if (item.id == livestock.farmId) {
        farm = item;
        break;
      }
    }

    final double progress = livestock.growthProgress;
    final ThemeData theme = Theme.of(context);
    final Iterable<FarmTodoItem> openTasks =
        livestock.todoItems.where((FarmTodoItem item) => !item.isCompleted);
    final List<LivestockProductionRecord> logs = livestock.productionLogs;
    final List<FarmTodoItem> openTaskList = openTasks.toList(growable: false);
    final int overdueTasks = openTaskList
        .where((FarmTodoItem item) => item.dueDate.isBefore(DateTime.now()))
        .length;
    final int priorityTasks = openTaskList
        .where((FarmTodoItem item) =>
            item.priority == FarmTodoPriority.high ||
            item.priority == FarmTodoPriority.urgent)
        .length;
    final double totalDailyFeedKg = livestock.dailyFeedKg * livestock.count;
    final double totalDailyWaterLitres =
        livestock.dailyWaterLitres * livestock.count;
    final double valuePerHead =
        livestock.count <= 0 ? 0 : livestock.estimatedValue / livestock.count;
    final double inputCostPerHead =
        livestock.count <= 0 ? 0 : livestock.syncedInputCost / livestock.count;
    final String livestockWorkStatus = _livestockWorkStatus(
      livestock: livestock,
      overdueTasks: overdueTasks,
      priorityTasks: priorityTasks,
    );

    // Section keys for scroll-to navigation. GlobalObjectKey uses value
    // equality, so these stay stable across rebuilds even though this is a
    // stateless ConsumerWidget (a plain GlobalKey() here would be recreated
    // on every rebuild and would never match the mounted section widgets).
    final GlobalKey _workFocusKey = GlobalObjectKey('workFocus_$livestockId');
    final GlobalKey _growthCycleKey =
        GlobalObjectKey('growthCycle_$livestockId');
    final GlobalKey _groupProfileKey =
        GlobalObjectKey('groupProfile_$livestockId');
    final GlobalKey _operatingRatiosKey =
        GlobalObjectKey('operatingRatios_$livestockId');
    final GlobalKey _feedingPlanKey =
        GlobalObjectKey('feedingPlan_$livestockId');
    final GlobalKey _vaccinationKey =
        GlobalObjectKey('vaccination_$livestockId');
    final GlobalKey _productionLogKey =
        GlobalObjectKey('productionLog_$livestockId');
    final GlobalKey _weightGainKey =
        GlobalObjectKey('weightGain_$livestockId');
    final GlobalKey _photoJournalKey =
        GlobalObjectKey('photoJournal_$livestockId');
    final GlobalKey _careTasksKey = GlobalObjectKey('careTasks_$livestockId');
    final GlobalKey _recentInputsKey =
        GlobalObjectKey('recentInputs_$livestockId');
    final GlobalKey _aiRecommendationsKey =
        GlobalObjectKey('aiRecommendations_$livestockId');

    final List<SectionEntry> sections = <SectionEntry>[
      SectionEntry(
          title: language.tr(
              en: 'Work focus', ha: 'Manufar aiki', fr: 'Priorites de travail'),
          sectionKey: _workFocusKey,
          icon: Icons.assignment),
      SectionEntry(
          title: language.tr(
              en: 'Growth cycle',
              ha: 'Zagayen girma',
              fr: 'Cycle de croissance'),
          sectionKey: _growthCycleKey,
          icon: Icons.timeline),
      SectionEntry(
          title: language.tr(
              en: 'Group profile',
              ha: 'Bayanin kungiya',
              fr: 'Profil du groupe'),
          sectionKey: _groupProfileKey,
          icon: Icons.group),
      SectionEntry(
          title: language.tr(
              en: 'Operating ratios',
              ha: 'Ma\'aunin aiki',
              fr: 'Ratios operationnels'),
          sectionKey: _operatingRatiosKey,
          icon: Icons.bar_chart),
      SectionEntry(
          title: language.tr(
              en: 'Feeding Plan',
              ha: 'Tsarin Ciyarwa',
              fr: 'Plan d\'alimentation'),
          sectionKey: _feedingPlanKey,
          icon: Icons.restaurant),
      SectionEntry(
          title: language.tr(
              en: 'Vaccination & Health',
              ha: 'Alurar Riga Kafi & Lafiya',
              fr: 'Vaccination et sante'),
          sectionKey: _vaccinationKey,
          icon: Icons.health_and_safety),
      SectionEntry(
          title: language.tr(
              en: 'Production log',
              ha: 'Tarihin samarwa',
              fr: 'Journal de production'),
          sectionKey: _productionLogKey,
          icon: Icons.fact_check),
      SectionEntry(
          title: language.tr(
              en: 'Weight Gain Chart',
              ha: 'Ginshikin Kara Nauyi',
              fr: 'Graphique de prise de poids'),
          sectionKey: _weightGainKey,
          icon: Icons.show_chart),
      SectionEntry(
          title: language.tr(
              en: 'Photo Journal', ha: 'Littafin Hoto', fr: 'Journal photo'),
          sectionKey: _photoJournalKey,
          icon: Icons.photo_library),
      SectionEntry(
          title: language.tr(
              en: 'Care tasks', ha: 'Ayyukan kulawa', fr: 'Taches de soins'),
          sectionKey: _careTasksKey,
          icon: Icons.task_alt),
      SectionEntry(
          title: language.tr(
              en: 'Recent inputs',
              ha: 'Kayan da aka yi amfani da su kwanan nan',
              fr: 'Intrants recents'),
          sectionKey: _recentInputsKey,
          icon: Icons.inventory_2),
      SectionEntry(
          title: language.tr(
              en: 'AI Recommendations',
              ha: 'Shawarwarin AI',
              fr: 'Recommandations IA'),
          sectionKey: _aiRecommendationsKey,
          icon: Icons.auto_awesome),
    ];

    final ScrollController scrollController = ScrollController();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${livestock.emoji} ${_speciesLabel(livestock.species)}'),
        actions: <Widget>[
          SectionScrollMenu(
            sections: sections,
            scrollController: scrollController,
          ),
        ],
      ),
      body: SoftScreenScaffold(
        scrollController: scrollController,
        heroTitle: _speciesLabel(livestock.species),
        heroSubtitle: language.tr(
          en: '${livestock.breed} on ${farm?.name ?? 'Unknown farm'}',
          ha: '${livestock.breed} a ${farm?.name ?? 'gonar da ba a sani ba'}',
          fr: '${livestock.breed} sur ${farm?.name ?? 'ferme inconnue'}',
        ),
        heroIcon: Icons.pets_rounded,
        heroVariant: FarmArtworkVariant.field,
        heroBadge: '${(progress * 100).round()}% maturity progress',
        sections: <Widget>[
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: livestock.coverImageBase64.isNotEmpty ||
                            livestock.profileImageBase64.isNotEmpty
                        ? Image.memory(
                            base64Decode(
                              livestock.coverImageBase64.isNotEmpty
                                  ? livestock.coverImageBase64
                                  : livestock.profileImageBase64,
                            ),
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(livestock.emoji,
                                style: const TextStyle(fontSize: 34)),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${livestock.count} animals',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          '${_purposeLabel(livestock.purpose)} · ${_housingLabel(livestock.housingLocation)} · ${farm?.name ?? 'Unknown farm'}',
                          style:
                              theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _MetaChip(
                                text:
                                    '${livestock.averageWeightKg.toStringAsFixed(1)} kg avg'),
                            _MetaChip(
                                text:
                                    '${livestock.dailyFeedKg.toStringAsFixed(1)} kg feed/day'),
                            _MetaChip(
                                text:
                                    '${livestock.dailyWaterLitres.toStringAsFixed(1)} L water/day'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'Work focus',
                  ha: 'Manufar aiki',
                  fr: 'Priorites de travail')),
          Container(
            key: _workFocusKey,
            child: AppCard(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Status: $livestockWorkStatus',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      _livestockWorkNarrative(
                        livestock: livestock,
                        overdueTasks: overdueTasks,
                        priorityTasks: priorityTasks,
                      ),
                      style:
                          theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _MetaChip(text: '$overdueTasks overdue'),
                        _MetaChip(text: '$priorityTasks high priority'),
                        _MetaChip(
                            text:
                                '${livestock.openTaskCount} open reminders'),
                        _MetaChip(
                            text: logs.isEmpty
                                ? 'No production logs'
                                : '${logs.length} production logs'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: _growthCycleKey,
            child: AppCard(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                        language.tr(
                            en: 'Animal growth cycle',
                            ha: 'Zagayen girman dabba',
                            fr: 'Cycle de croissance animale'),
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${livestock.averageAgeMonths} of ${livestock.targetMaturityMonths} target months. Current stage: ${_growthStageLabel(livestock.growthStage).toLowerCase()}.',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    ...AnimalGrowthStage.values.map(
                      (AnimalGrowthStage stage) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CycleRow(
                          title: _growthStageLabel(stage),
                          subtitle: _growthAdvice(stage),
                          isActive: AnimalGrowthStage.values.indexOf(stage) <=
                              AnimalGrowthStage.values
                                  .indexOf(livestock!.growthStage),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'Group profile',
                  ha: 'Bayanin kungiya',
                  fr: 'Profil du groupe')),
          Container(
            key: _groupProfileKey,
            child: Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  title:
                      language.tr(en: 'Animals', ha: 'Dabbobi', fr: 'Animaux'),
                  value: '${livestock.count}',
                  note:
                      '${livestock.maleCount} male • ${livestock.femaleCount} female',
                  tint: const Color(0xFFDFF1FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title:
                      language.tr(en: 'Purpose', ha: 'Manufa', fr: 'Objectif'),
                  value: _purposeLabel(livestock.purpose),
                  note: _housingLabel(livestock.housingLocation),
                  tint: const Color(0xFFE8F4D8),
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  title: language.tr(en: 'Health', ha: 'Lafiya', fr: 'Sante'),
                  value: '${livestock.healthScore}%',
                  note: '${livestock.vaccinationStatus}% vaccinated',
                  tint: const Color(0xFFFFEBD0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: language.tr(en: 'Value', ha: 'Daraja', fr: 'Valeur'),
                  value: CurrencyUtils.formatCurrency(livestock.estimatedValue),
                  note: '${livestock.mortalityCount} mortality recorded',
                  tint: const Color(0xFFEDE8FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'Operating ratios',
                  ha: 'Ma\'aunin aiki',
                  fr: 'Ratios operationnels')),
          Container(
            key: _operatingRatiosKey,
            child: Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  title: language.tr(
                      en: 'Feed / day',
                      ha: 'Abinci / rana',
                      fr: 'Aliment / jour'),
                  value: '${totalDailyFeedKg.toStringAsFixed(1)} kg',
                  note:
                      '${livestock.dailyFeedKg.toStringAsFixed(1)} kg per head',
                  tint: const Color(0xFFE8F4D8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: language.tr(
                      en: 'Water / day', ha: 'Ruwa / rana', fr: 'Eau / jour'),
                  value: '${totalDailyWaterLitres.toStringAsFixed(1)} L',
                  note:
                      '${livestock.dailyWaterLitres.toStringAsFixed(1)} L per head',
                  tint: const Color(0xFFDFF1FF),
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  title: language.tr(
                      en: 'Value / head',
                      ha: 'Daraja / kai',
                      fr: 'Valeur / tete'),
                  value: valuePerHead <= 0
                      ? language.tr(
                          en: 'Not set', ha: 'Ba a saita ba', fr: 'Non defini')
                      : CurrencyUtils.formatCurrency(valuePerHead),
                  note: language.tr(
                      en: 'Estimated live value',
                      ha: 'Kimar rayuwa da aka kiyasta',
                      fr: 'Valeur vivante estimee'),
                  tint: const Color(0xFFFFEBD0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: language.tr(
                      en: 'Input / head',
                      ha: 'Kaya / kai',
                      fr: 'Intrant / tete'),
                  value: inputCostPerHead <= 0
                      ? language.tr(
                          en: 'Not ready', ha: 'Ba a shirya ba', fr: 'Non pret')
                      : CurrencyUtils.formatCurrency(inputCostPerHead),
                  note: '${livestock.inputRecords.length} input records',
                  tint: const Color(0xFFEDE8FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'Feeding Plan',
                  ha: 'Tsarin Ciyarwa',
                  fr: 'Plan d\'alimentation')),
          Container(key: _feedingPlanKey, child: FeedingPlanWidget(livestock: livestock)),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'Vaccination & Health',
                  ha: 'Alurar Riga Kafi & Lafiya',
                  fr: 'Vaccination et sante')),
          Container(key: _vaccinationKey, child: VaccinationCalendarWidget(livestock: livestock)),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'Production log',
                  ha: 'Tarihin samarwa',
                  fr: 'Journal de production')),
          Container(key: _productionLogKey, height: 0),
          if (logs.isEmpty)
            _InfoCard(
              message: language.tr(
                en: 'No daily, weekly, or monthly production records yet.',
                ha: 'Babu tarihin samarwa na yau da kullum, na mako-mako, ko na wata-wata har yanzu.',
                fr: 'Aucun registre de production quotidien, hebdomadaire ou mensuel pour le moment.',
              ),
            )
          else
            ...logs.take(4).map(
                  (LivestockProductionRecord record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProductionLogCard(record: record),
                  ),
                ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _openProductionLogSheet(context, ref, livestock!),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(language.tr(
                  en: 'Add production log',
                  ha: 'Kara tarihin samarwa',
                  fr: 'Ajouter un journal de production')),
            ),
          ),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'Weight Gain Chart',
                  ha: 'Ginshikin Kara Nauyi',
                  fr: 'Graphique de prise de poids')),
          Container(
              key: _weightGainKey,
              child: WeightGainChartWidget(livestock: livestock)),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'Photo Journal',
                  ha: 'Littafin Hoto',
                  fr: 'Journal photo')),
          Container(
              key: _photoJournalKey,
              child: PhotoJournalWidget(livestock: livestock)),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'Care tasks',
                  ha: 'Ayyukan kulawa',
                  fr: 'Taches de soins')),
          Container(key: _careTasksKey, height: 0),
          if (openTasks.isEmpty)
            _InfoCard(
              message: language.tr(
                en: 'No open animal reminders yet. Add feeding, cleaning, vaccination, or inspection tasks from livestock records.',
                ha: 'Babu wani tunatarwa na dabbobi har yanzu. Kara ayyukan ciyarwa, tsaftacewa, alurar riga kafi, ko duba daga bayanan dabbobi.',
                fr: 'Aucun rappel animal ouvert pour le moment. Ajoutez des taches d\'alimentation, de nettoyage, de vaccination ou d\'inspection depuis les registres de betail.',
              ),
            )
          else
            ...openTasks.take(4).map(
                  (FarmTodoItem task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TaskCard(task: task),
                  ),
                ),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'Recent inputs',
                  ha: 'Kayan da aka yi amfani da su kwanan nan',
                  fr: 'Intrants recents')),
          Container(key: _recentInputsKey, height: 0),
          if (livestock.inputRecords.isEmpty)
            _InfoCard(
              message: language.tr(
                en: 'No feed, veterinary, labour, or bedding records yet.',
                ha: 'Babu bayanan abinci, likitan dabbobi, ma\'aikata, ko shimfida har yanzu.',
                fr: 'Aucun registre d\'aliment, de veterinaire, de main-d\'oeuvre ou de litiere pour le moment.',
              ),
            )
          else
            ...livestock.inputRecords.take(4).map(
                  (FarmInputRecord item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InputCard(item: item),
                  ),
                ),
          const SizedBox(height: 18),
          SoftSectionTitle(
              title: language.tr(
                  en: 'AI Recommendations',
                  ha: 'Shawarwarin AI',
                  fr: 'Recommandations IA')),
          Container(
              key: _aiRecommendationsKey,
              child: AiRecommendationsWidget(livestock: livestock)),
        ],
      ),
    );
  }
}

String _speciesLabel(LivestockSpecies species) {
  switch (species) {
    case LivestockSpecies.goat:
      return 'Goats';
    case LivestockSpecies.chicken:
      return 'Chickens';
    case LivestockSpecies.pig:
      return 'Pigs';
    case LivestockSpecies.cattle:
      return 'Cattle';
    case LivestockSpecies.sheep:
      return 'Sheep';
    case LivestockSpecies.rabbit:
      return 'Rabbits';
    case LivestockSpecies.duck:
      return 'Ducks';
    case LivestockSpecies.fish:
      return 'Fish';
    case LivestockSpecies.snail:
      return 'Snails';
  }
}

String _purposeLabel(LivestockPurpose purpose) {
  switch (purpose) {
    case LivestockPurpose.meat:
      return 'Meat';
    case LivestockPurpose.milk:
      return 'Milk';
    case LivestockPurpose.eggs:
      return 'Eggs';
    case LivestockPurpose.breeding:
      return 'Breeding';
  }
}

String _housingLabel(HousingType housingType) {
  switch (housingType) {
    case HousingType.freeRange:
      return 'Free range';
    case HousingType.barn:
      return 'Barn';
    case HousingType.shed:
      return 'Shed';
    case HousingType.coop:
      return 'Coop';
  }
}

String _growthStageLabel(AnimalGrowthStage stage) {
  switch (stage) {
    case AnimalGrowthStage.starter:
      return 'Starter';
    case AnimalGrowthStage.grower:
      return 'Grower';
    case AnimalGrowthStage.mature:
      return 'Mature';
    case AnimalGrowthStage.breeding:
      return 'Breeding';
    case AnimalGrowthStage.finishing:
      return 'Finishing';
  }
}

String _growthAdvice(AnimalGrowthStage stage) {
  switch (stage) {
    case AnimalGrowthStage.starter:
      return 'Protect heat, hygiene, and feed access for young stock.';
    case AnimalGrowthStage.grower:
      return 'Track conversion, growth rate, and disease pressure.';
    case AnimalGrowthStage.mature:
      return 'Maintain body condition and production stability.';
    case AnimalGrowthStage.breeding:
      return 'Monitor fertility, housing stress, and replacement planning.';
    case AnimalGrowthStage.finishing:
      return 'Prepare sale weight, market timing, and final health checks.';
  }
}

String _livestockWorkStatus({
  required Livestock livestock,
  required int overdueTasks,
  required int priorityTasks,
}) {
  if (livestock.healthScore < 70) {
    return 'Health attention';
  }
  if (livestock.vaccinationStatus < 75) {
    return 'Vaccination gap';
  }
  if (overdueTasks > 0) {
    return 'Overdue care';
  }
  if (priorityTasks > 0) {
    return 'Priority care';
  }
  if (livestock.growthStage == AnimalGrowthStage.finishing) {
    return 'Sale planning';
  }
  return 'Stable care';
}

String _livestockWorkNarrative({
  required Livestock livestock,
  required int overdueTasks,
  required int priorityTasks,
}) {
  if (livestock.healthScore < 70) {
    return 'Start with weak or isolated animals, water access, feed quality, bedding, and any treatment notes. Record symptoms before routine production work.';
  }
  if (livestock.vaccinationStatus < 75) {
    return 'Vaccination coverage is below target. Schedule the next round, confirm stock handling, and mark the reminder high priority.';
  }
  if (overdueTasks > 0) {
    return 'Clear overdue care reminders first. Feeding, cleaning, inspection, and medication tasks should be closed before adding more work.';
  }
  if (priorityTasks > 0) {
    return 'High-priority care is open. Assign labour, confirm supplies, and update completion so health and production records stay dependable.';
  }
  if (livestock.growthStage == AnimalGrowthStage.finishing) {
    return 'This group is near sale or transfer decisions. Check weight, buyer timing, feed use, and final health status before committing stock.';
  }
  if (livestock.productionLogs.isEmpty) {
    return 'Care looks stable, but production history is empty. Add a baseline log for weight, feed, eggs, or notes so future trends have a starting point.';
  }
  return 'Core care looks stable. Keep production logs current, monitor feed and water use, and review mortality or vaccination changes weekly.';
}

class _CycleRow extends StatelessWidget {
  const _CycleRow({
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.note,
    required this.tint,
  });

  final String title;
  final String value;
  final String note;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 12),
            Text(title),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ProductionLogCard extends StatelessWidget {
  const _ProductionLogCard({required this.record});

  final LivestockProductionRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(record.period.name.substring(0, 1).toUpperCase()),
        ),
        title: Text('${record.period.name.toUpperCase()} record'),
        subtitle: Text(
          [
            if (record.weightKg > 0)
              'Weight ${record.weightKg.toStringAsFixed(1)} kg',
            if (record.feedKg > 0)
              'Feed ${record.feedKg.toStringAsFixed(1)} kg',
            if (record.eggCount > 0) '${record.eggCount} ${record.eggUnit}',
            if (record.notes.isNotEmpty) record.notes,
          ].join(' · '),
        ),
        trailing: Text('${record.recordedAt.day}/${record.recordedAt.month}'),
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
        subtitle: Text('${item.quantity} ${item.unit} • ${item.category.name}'),
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

Future<void> _openProductionLogSheet(
  BuildContext context,
  WidgetRef ref,
  Livestock livestock,
) async {
  final _ProductionLogDraft? draft =
      await showModalBottomSheet<_ProductionLogDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) =>
        _ProductionLogSheet(livestock: livestock),
  );
  if (draft == null) {
    return;
  }

  final DateTime now = DateTime.now();
  final LivestockProductionRecord record = LivestockProductionRecord(
    id: const Uuid().v4(),
    period: draft.period,
    recordedAt: draft.recordedAt,
    createdAt: now,
    updatedAt: now,
    weightKg: draft.weightKg,
    feedKg: draft.feedKg,
    eggCount: draft.eggCount,
    eggUnit: draft.eggUnit,
    notes: draft.notes,
  );

  await ref.read(livestockProvider.notifier).updateLivestock(
        livestock.copyWith(
          productionLogs: <LivestockProductionRecord>[
            record,
            ...livestock.productionLogs
          ],
          averageWeightKg:
              draft.weightKg > 0 ? draft.weightKg : livestock.averageWeightKg,
          dailyFeedKg: draft.feedKg > 0 ? draft.feedKg : livestock.dailyFeedKg,
          updatedAt: now,
          isSynced: false,
        ),
      );

  if (context.mounted) {
    context.showSnackBar('Production log saved.');
  }
}

class _ProductionLogSheet extends StatefulWidget {
  const _ProductionLogSheet({required this.livestock});

  final Livestock livestock;

  @override
  State<_ProductionLogSheet> createState() => _ProductionLogSheetState();
}

class _ProductionLogSheetState extends State<_ProductionLogSheet> {
  late final TextEditingController _weightController;
  late final TextEditingController _feedController;
  late final TextEditingController _eggCountController;
  late final TextEditingController _eggUnitController;
  late final TextEditingController _notesController;
  DateTime _recordedAt = DateTime.now();
  LivestockRecordPeriod _period = LivestockRecordPeriod.daily;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
        text: widget.livestock.averageWeightKg.toStringAsFixed(1));
    _feedController = TextEditingController(
        text: widget.livestock.dailyFeedKg.toStringAsFixed(1));
    _eggCountController = TextEditingController(text: '0');
    _eggUnitController = TextEditingController(text: 'eggs');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _feedController.dispose();
    _eggCountController.dispose();
    _eggUnitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Production log',
      subtitle:
          'Record daily, weekly, or monthly performance including weight, feed, and eggs.',
      children: <Widget>[
        _DropdownField<LivestockRecordPeriod>(
          label: 'Period',
          value: _period,
          items: LivestockRecordPeriod.values,
          itemLabel: (LivestockRecordPeriod value) =>
              value.name[0].toUpperCase() + value.name.substring(1),
          onChanged: (LivestockRecordPeriod? value) {
            if (value != null) setState(() => _period = value);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: AppTextField(
                controller: _weightController,
                label: 'Weight (kg)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _feedController,
                label: 'Feed (kg)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: AppTextField(
                controller: _eggCountController,
                label: 'Egg count',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _eggUnitController,
                label: 'Egg unit',
                hint: 'eggs / crates',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DateTile(
          label: 'Recorded at',
          value: _recordedAt,
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _recordedAt,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              setState(() => _recordedAt = picked);
            }
          },
        ),
        const SizedBox(height: 12),
        AppTextField(controller: _notesController, label: 'Notes', maxLines: 3),
        const SizedBox(height: 18),
        AppButton.primary(onPressed: _submit, child: const Text('Save log')),
      ],
    );
  }

  void _submit() {
    final double weightKg = double.tryParse(_weightController.text.trim()) ?? 0;
    final double feedKg = double.tryParse(_feedController.text.trim()) ?? 0;
    final int eggCount = int.tryParse(_eggCountController.text.trim()) ?? 0;
    final String eggUnit = _eggUnitController.text.trim().isEmpty
        ? 'eggs'
        : _eggUnitController.text.trim();
    Navigator.of(context).pop(
      _ProductionLogDraft(
        period: _period,
        weightKg: weightKg,
        feedKg: feedKg,
        eggCount: eggCount,
        eggUnit: eggUnit,
        notes: _notesController.text.trim(),
        recordedAt: _recordedAt,
      ),
    );
  }
}

class _ProductionLogDraft {
  const _ProductionLogDraft({
    required this.period,
    required this.weightKg,
    required this.feedKg,
    required this.eggCount,
    required this.eggUnit,
    required this.notes,
    required this.recordedAt,
  });

  final LivestockRecordPeriod period;
  final double weightKg;
  final double feedKg;
  final int eggCount;
  final String eggUnit;
  final String notes;
  final DateTime recordedAt;
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5)),
                const SizedBox(height: 18),
                ...children,
              ],
            ),
          ),
        ),
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

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: InputDecorator(
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
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: Text('${value.day}/${value.month}/${value.year}')),
            const Icon(Icons.calendar_today_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
