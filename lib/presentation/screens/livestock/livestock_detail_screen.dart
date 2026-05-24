import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../common/widgets/app_card.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(_speciesLabel(livestock.species))),
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
                        isActive: AnimalGrowthStage.values.indexOf(stage) <= AnimalGrowthStage.values.indexOf(livestock.growthStage),
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
                  note: '${livestock.maleCount} male - ${livestock.femaleCount} female',
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
            detail: livestock.healthScore < 70
                ? 'Separate weak animals, review feed and water access, and record symptoms or treatment before losses increase.'
                : 'Keep daily checks consistent and log weight, stock, or treatment updates so the growth cycle stays accurate.',
            tint: const Color(0xFFFFEBD0),
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            title: livestock.vaccinationStatus < 75 ? 'Vaccination gap' : 'Plan production milestone',
            detail: livestock.vaccinationStatus < 75
                ? 'Vaccination coverage is below the safer range. Schedule the next round and mark it as a high-priority reminder.'
                : 'Use the current growth stage to plan breeding, sale timing, or production targets before the next cycle change.',
            tint: const Color(0xFFDFF1FF),
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
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.lightbulb_outline_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
