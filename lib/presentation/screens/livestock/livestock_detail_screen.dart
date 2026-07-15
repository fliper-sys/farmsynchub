import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class LivestockDetailScreen extends ConsumerWidget {
  const LivestockDetailScreen({
    super.key,
    required this.livestockId,
  });

  final String livestockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Livestock> livestockItems = ref.watch(livestockProvider).valueOrNull ?? <Livestock>[];
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];

    Livestock? livestock;
    for (final Livestock item in livestockItems) {
      if (item.id == livestockId) {
        livestock = item;
        break;
      }
    }

    if (livestock == null) {
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
    final Iterable<FarmTodoItem> openTasks = livestock.todoItems.where((FarmTodoItem item) => !item.isCompleted);
    final List<LivestockProductionRecord> logs = livestock.productionLogs;
    final List<FarmTodoItem> openTaskList = openTasks.toList(growable: false);
    final int overdueTasks = openTaskList.where((FarmTodoItem item) => item.dueDate.isBefore(DateTime.now())).length;
    final int priorityTasks = openTaskList
        .where((FarmTodoItem item) => item.priority == FarmTodoPriority.high || item.priority == FarmTodoPriority.urgent)
        .length;
    final double totalDailyFeedKg = livestock.dailyFeedKg * livestock.count;
    final double totalDailyWaterLitres = livestock.dailyWaterLitres * livestock.count;
    final double valuePerHead = livestock.count <= 0 ? 0 : livestock.estimatedValue / livestock.count;
    final double inputCostPerHead = livestock.count <= 0 ? 0 : livestock.syncedInputCost / livestock.count;
    final String livestockWorkStatus = _livestockWorkStatus(
      livestock: livestock,
      overdueTasks: overdueTasks,
      priorityTasks: priorityTasks,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${livestock.emoji} ${_speciesLabel(livestock.species)}'),
      ),
      body: SoftScreenScaffold(
        heroTitle: _speciesLabel(livestock.species),
        heroSubtitle: '${livestock.breed} on ${farm?.name ?? 'Unknown farm'}',
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
                    child: livestock.coverImageBase64.isNotEmpty || livestock.profileImageBase64.isNotEmpty
                        ? Image.memory(
                            base64Decode(
                              livestock.coverImageBase64.isNotEmpty ? livestock.coverImageBase64 : livestock.profileImageBase64,
                            ),
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(livestock.emoji, style: const TextStyle(fontSize: 34)),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${livestock.count} animals', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          '${_purposeLabel(livestock.purpose)} · ${_housingLabel(livestock.housingLocation)} · ${farm?.name ?? 'Unknown farm'}',
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _MetaChip(text: '${livestock.averageWeightKg.toStringAsFixed(1)} kg avg'),
                            _MetaChip(text: '${livestock.dailyFeedKg.toStringAsFixed(1)} kg feed/day'),
                            _MetaChip(text: '${livestock.dailyWaterLitres.toStringAsFixed(1)} L water/day'),
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
          const SoftSectionTitle(title: 'Work focus'),
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Status: $livestockWorkStatus', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    _livestockWorkNarrative(
                      livestock: livestock,
                      overdueTasks: overdueTasks,
                      priorityTasks: priorityTasks,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MetaChip(text: '$overdueTasks overdue'),
                      _MetaChip(text: '$priorityTasks high priority'),
                      _MetaChip(text: '${livestock.openTaskCount} open reminders'),
                      _MetaChip(text: logs.isEmpty ? 'No production logs' : '${logs.length} production logs'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Animal growth cycle', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${livestock.averageAgeMonths} of ${livestock.targetMaturityMonths} target months. Current stage: ${_growthStageLabel(livestock.growthStage).toLowerCase()}.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  ...AnimalGrowthStage.values.map(
                    (AnimalGrowthStage stage) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CycleRow(
                        title: _growthStageLabel(stage),
                        subtitle: _growthAdvice(stage),
                        isActive: AnimalGrowthStage.values.indexOf(stage) <= AnimalGrowthStage.values.indexOf(livestock!.growthStage),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Group profile'),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  title: 'Animals',
                  value: '${livestock.count}',
                  note: '${livestock.maleCount} male • ${livestock.femaleCount} female',
                  tint: const Color(0xFFDFF1FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Purpose',
                  value: _purposeLabel(livestock.purpose),
                  note: _housingLabel(livestock.housingLocation),
                  tint: const Color(0xFFE8F4D8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  title: 'Health',
                  value: '${livestock.healthScore}%',
                  note: '${livestock.vaccinationStatus}% vaccinated',
                  tint: const Color(0xFFFFEBD0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Value',
                  value: CurrencyUtils.formatCurrency(livestock.estimatedValue),
                  note: '${livestock.mortalityCount} mortality recorded',
                  tint: const Color(0xFFEDE8FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Operating ratios'),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  title: 'Feed / day',
                  value: '${totalDailyFeedKg.toStringAsFixed(1)} kg',
                  note: '${livestock.dailyFeedKg.toStringAsFixed(1)} kg per head',
                  tint: const Color(0xFFE8F4D8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Water / day',
                  value: '${totalDailyWaterLitres.toStringAsFixed(1)} L',
                  note: '${livestock.dailyWaterLitres.toStringAsFixed(1)} L per head',
                  tint: const Color(0xFFDFF1FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  title: 'Value / head',
                  value: valuePerHead <= 0 ? 'Not set' : CurrencyUtils.formatCurrency(valuePerHead),
                  note: 'Estimated live value',
                  tint: const Color(0xFFFFEBD0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Input / head',
                  value: inputCostPerHead <= 0 ? 'Not ready' : CurrencyUtils.formatCurrency(inputCostPerHead),
                  note: '${livestock.inputRecords.length} input records',
                  tint: const Color(0xFFEDE8FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Production log'),
          if (logs.isEmpty)
            const _InfoCard(message: 'No daily, weekly, or monthly production records yet.')
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
              onPressed: () => _openProductionLogSheet(context, ref, livestock!),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Add production log'),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Care tasks'),
          if (openTasks.isEmpty)
            const _InfoCard(message: 'No open animal reminders yet. Add feeding, cleaning, vaccination, or inspection tasks from livestock records.')
          else
            ...openTasks.take(4).map(
              (FarmTodoItem task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskCard(task: task),
              ),
            ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Recent inputs'),
          if (livestock.inputRecords.isEmpty)
            const _InfoCard(message: 'No feed, veterinary, labour, or bedding records yet.')
          else
            ...livestock.inputRecords.take(4).map(
              (FarmInputRecord item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InputCard(item: item),
              ),
            ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'App suggestions'),
          _SuggestionCard(
            title: livestock.healthScore < 70 ? 'Health attention needed' : 'Maintain stable welfare',
            detail: _livestockAdvice(livestock),
            tint: const Color(0xFFFFEBD0),
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            title: livestock.vaccinationStatus < 75 ? 'Vaccination gap' : 'Plan production milestone',
            detail: livestock.vaccinationStatus < 75
                ? 'Vaccination coverage is below the safer range. Schedule the next round and mark it as a high-priority reminder.'
                : _productionPlanningAdvice(livestock),
            tint: const Color(0xFFDFF1FF),
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            title: livestock.species == LivestockSpecies.chicken
                ? livestock.purpose == LivestockPurpose.eggs
                    ? 'Layer routine'
                    : 'Broiler routine'
                : 'Feeding routine',
            detail: _feedAndHygieneAdvice(livestock),
            tint: const Color(0xFFE8F4D8),
          ),
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

String _livestockAdvice(Livestock livestock) {
  final String species = _speciesLabel(livestock.species).toLowerCase();
  if (livestock.healthScore < 70) {
    return 'Separate weak $species, check water access, review feed quality, and record any treatment or symptoms today.';
  }
  if (livestock.averageAgeMonths < 4) {
    return 'These are young $species. Keep warmth, hygiene, and starter feed strong while you watch growth daily.';
  }
  if (livestock.purpose == LivestockPurpose.eggs) {
    return 'Layer birds need steady feed, clean nests, and daily egg collection so inventory and sales stay accurate.';
  }
  if (livestock.purpose == LivestockPurpose.meat) {
    return 'Track weight gains weekly, keep feed conversion efficient, and tighten hygiene to protect finishing performance.';
  }
  return 'Keep body condition, housing cleanliness, and vaccination records up to date while logging weight and feed use.';
}

String _productionPlanningAdvice(Livestock livestock) {
  if (livestock.species == LivestockSpecies.chicken && livestock.purpose == LivestockPurpose.eggs) {
    return 'Use weekly logs to compare egg output, check shell quality, and forecast crates or loose egg sales before market day.';
  }
  if (livestock.species == LivestockSpecies.chicken) {
    return 'Broilers should be checked weekly for weight targets and feed conversion so sale timing stays profitable.';
  }
  return 'Use the next production cycle to plan sales, breeding, or replacements based on age, weight, and welfare trends.';
}

String _feedAndHygieneAdvice(Livestock livestock) {
  if (livestock.species == LivestockSpecies.chicken && livestock.purpose == LivestockPurpose.eggs) {
    return 'Layers do best on balanced layer mash, clean water, dry litter, and nest checks every day. Refresh feed and record egg counts daily.';
  }
  if (livestock.species == LivestockSpecies.chicken) {
    return 'Broilers need good quality finisher feed, dry housing, and weekly weight checks to keep growth moving fast.';
  }
  if (livestock.species == LivestockSpecies.goat || livestock.species == LivestockSpecies.sheep) {
    return 'Provide browse or hay, clean water, deworming reminders, and morning hygiene checks for feet and housing.';
  }
  if (livestock.species == LivestockSpecies.cattle) {
    return 'Balance forage, water, and grooming. Watch body condition weekly and keep the shed clean and dry.';
  }
  return 'Keep feed clean, water steady, and housing hygiene consistent while logging changes at least weekly.';
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
            color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
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
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
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
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
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
            if (record.weightKg > 0) 'Weight ${record.weightKg.toStringAsFixed(1)} kg',
            if (record.feedKg > 0) 'Feed ${record.feedKg.toStringAsFixed(1)} kg',
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
        subtitle: Text(task.notes.isEmpty ? 'Due ${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}' : task.notes),
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
    final Color iconBackground = isDark ? Color.alphaBlend(tint.withOpacity(0.22), theme.colorScheme.surface) : tint;
    final Color iconForeground = isDark ? theme.colorScheme.onSurface : const Color(0xFF44624E);

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
                border: Border.all(color: isDark ? tint.withOpacity(0.42) : Colors.transparent),
              ),
              child: Icon(Icons.lightbulb_outline_rounded, color: iconForeground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(detail, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
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
  final _ProductionLogDraft? draft = await showModalBottomSheet<_ProductionLogDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _ProductionLogSheet(livestock: livestock),
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
          productionLogs: <LivestockProductionRecord>[record, ...livestock.productionLogs],
          averageWeightKg: draft.weightKg > 0 ? draft.weightKg : livestock.averageWeightKg,
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
    _weightController = TextEditingController(text: widget.livestock.averageWeightKg.toStringAsFixed(1));
    _feedController = TextEditingController(text: widget.livestock.dailyFeedKg.toStringAsFixed(1));
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
      subtitle: 'Record daily, weekly, or monthly performance including weight, feed, and eggs.',
      children: <Widget>[
        _DropdownField<LivestockRecordPeriod>(
          label: 'Period',
          value: _period,
          items: LivestockRecordPeriod.values,
          itemLabel: (LivestockRecordPeriod value) => value.name[0].toUpperCase() + value.name.substring(1),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _feedController,
                label: 'Feed (kg)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    final String eggUnit = _eggUnitController.text.trim().isEmpty ? 'eggs' : _eggUnitController.text.trim();
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
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
            borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
