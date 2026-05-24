import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class CropDetailScreen extends ConsumerWidget {
  const CropDetailScreen({
    super.key,
    required this.cropId,
  });

  final String cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Crop> crops = ref.watch(cropsProvider).valueOrNull ?? <Crop>[];
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];

    Crop? crop;
    for (final Crop item in crops) {
      if (item.id == cropId) {
        crop = item;
        break;
      }
    }

    if (crop == null) {
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
    final Iterable<FarmTodoItem> openTasks = crop.todoItems.where((FarmTodoItem item) => !item.isCompleted);

    return Scaffold(
      appBar: AppBar(title: Text(crop.name)),
      body: SoftScreenScaffold(
        heroTitle: crop.name,
        heroSubtitle: '${crop.variety} on ${farm?.name ?? 'Unknown farm'}',
        heroIcon: Icons.spa_rounded,
        heroVariant: FarmArtworkVariant.crops,
        heroBadge: '${(progress * 100).round()}% through cycle',
        sections: <Widget>[
          AppCard(
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
                          'Growth cycle',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      _Pill(text: _stageLabel(crop.currentStage), color: const Color(0xFFE8F4D8)),
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
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Production profile'),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  title: 'Area',
                  value: '${crop.areaHa.toStringAsFixed(2)} ha',
                  note: crop.protectedEnvironment ? 'Protected crop' : 'Open-field crop',
                  tint: const Color(0xFFDFF1FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Target yield',
                  value: crop.targetYieldKg > 0 ? '${crop.targetYieldKg.toStringAsFixed(0)} kg' : 'Not set',
                  note: 'Cycle target',
                  tint: const Color(0xFFFFEBD0),
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
                  value: CurrencyUtils.formatCurrency(crop.totalInputCost),
                  note: '${crop.inputRecords.length} records',
                  tint: const Color(0xFFEDE8FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Open tasks',
                  value: '${crop.openTaskCount}',
                  note: '${crop.todoItems.length} total reminders',
                  tint: const Color(0xFFE8F4D8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Field tasks'),
          if (openTasks.isEmpty)
            const _InfoCard(message: 'No open crop reminders yet. Add scouting, irrigation, feeding, or harvest reminders from the crop records screen.')
          else
            ...openTasks.take(4).map(
              (FarmTodoItem task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskCard(task: task),
              ),
            ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Recent inputs'),
          if (crop.inputRecords.isEmpty)
            const _InfoCard(message: 'No input records yet. Add seed, fertiliser, labour, or equipment records from crop management.')
          else
            ...crop.inputRecords.take(4).map(
              (FarmInputRecord item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InputCard(item: item),
              ),
            ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'App suggestions'),
          _SuggestionCard(
            title: crop.currentStage == CropStage.flowering || crop.currentStage == CropStage.fruiting
                ? 'Protect yield-critical stage'
                : 'Push early stand quality',
            detail: crop.currentStage == CropStage.flowering || crop.currentStage == CropStage.fruiting
                ? 'Keep moisture steady, reduce stress, and check pest pressure every 1-2 days so flowering and fruit fill are not interrupted.'
                : 'Inspect gaps, weed pressure, and leaf colour now. Early corrections usually protect the rest of the cycle.',
            tint: const Color(0xFFE8F4D8),
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            title: crop.daysToHarvest <= 7 ? 'Prepare harvest logistics' : 'Keep cycle records current',
            detail: crop.daysToHarvest <= 7
                ? 'Line up labour, crates, buyers, and transport. Capture harvest dates and early sales so finance stays accurate.'
                : 'Update stage, tasks, and input records this week so the app can keep cycle timing and reminders useful.',
            tint: const Color(0xFFDFF1FF),
          ),
          if ((farm?.supportsGreenhouse ?? false) || crop.protectedEnvironment) ...<Widget>[
            const SizedBox(height: 12),
            const _SuggestionCard(
              title: 'Greenhouse routine',
              detail: 'Check heat build-up, ventilation, humidity, and disease spread in enclosed spaces before watering again.',
              tint: Color(0xFFFFEBD0),
            ),
          ],
        ],
      ),
    );
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text),
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
