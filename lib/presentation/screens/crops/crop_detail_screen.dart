import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../data/services/crop_advice_catalog.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_button.dart';
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
    final CropAdviceSummary advice = CropAdviceCatalog.summarize(crop);
    final List<FarmTodoItem> openTaskList = openTasks.toList(growable: false);
    final int overdueTasks = openTaskList.where((FarmTodoItem item) => item.dueDate.isBefore(DateTime.now())).length;
    final int priorityTasks = openTaskList
        .where((FarmTodoItem item) => item.priority == FarmTodoPriority.high || item.priority == FarmTodoPriority.urgent)
        .length;
    final double costPerHa = crop.areaHa <= 0 ? 0 : crop.totalInputCost / crop.areaHa;
    final double targetYieldPerHa = crop.areaHa <= 0 ? 0 : crop.targetYieldKg / crop.areaHa;
    final double inputCostPerTargetKg = crop.targetYieldKg <= 0 ? 0 : crop.totalInputCost / crop.targetYieldKg;
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
      ),
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
          const SoftSectionTitle(title: 'Crop intelligence'),
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${advice.profile.name} guidance', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Detected land size: ${advice.areaLabel}', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('Seed requirement: ${advice.seedRequirementLabel}', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('Fertiliser: ${advice.fertiliserSummary}', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: advice.otherInputs.map((String item) => _Pill(text: item, color: const Color(0xFFE8F4D8))).toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  AppButton.secondary(
                    onPressed: () => _openPreviousRecommendations(context, crop!),
                    child: const Text('Previous recommendations'),
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
                  Text('Status: $cropWorkStatus', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    _cropWorkNarrative(
                      crop: crop,
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
                      _Pill(text: '$overdueTasks overdue', color: const Color(0xFFFFEBD0)),
                      _Pill(text: '$priorityTasks high priority', color: const Color(0xFFEDE8FF)),
                      _Pill(text: '${crop.openTaskCount} open reminders', color: const Color(0xFFE8F4D8)),
                      _Pill(text: _harvestWindowLabel(crop), color: const Color(0xFFDFF1FF)),
                    ],
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
          const SoftSectionTitle(title: 'Performance ratios'),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  title: 'Cost / ha',
                  value: crop.areaHa <= 0 ? 'Not ready' : CurrencyUtils.formatCurrency(costPerHa),
                  note: '${crop.inputRecords.length} input records',
                  tint: const Color(0xFFEDE8FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Yield / ha',
                  value: crop.targetYieldKg <= 0 || crop.areaHa <= 0 ? 'Not set' : '${targetYieldPerHa.toStringAsFixed(0)} kg',
                  note: 'Target density',
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
                  title: 'Input / kg',
                  value: inputCostPerTargetKg <= 0 ? 'Not ready' : CurrencyUtils.formatCurrency(inputCostPerTargetKg),
                  note: 'Against target yield',
                  tint: const Color(0xFFFFEBD0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Records',
                  value: '${crop.inputRecords.length + crop.todoItems.length}',
                  note: 'Inputs plus reminders',
                  tint: const Color(0xFFDFF1FF),
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
        ],
      ),
    );
  }

  Future<void> _openPreviousRecommendations(BuildContext context, Crop crop) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreviousCropRecommendationsScreen(cropName: crop.name),
      ),
    );
  }

  Future<void> _openHarvestSheet(BuildContext context, WidgetRef ref, Crop crop) async {
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
          unitPrice: 0,
          costPrice: crop.areaHa > 0 ? crop.totalInputCost / crop.areaHa : 0,
        );
    await ref.read(cropsProvider.notifier).updateCrop(
          crop.copyWith(
            status: CropStatus.harvested,
            currentStage: CropStage.fruiting,
            updatedAt: now,
            isSynced: false,
            intelligenceNotes: '${crop.name} harvested in ${draft.quantityLabel}.',
            lastIntelligenceSyncAt: now,
          ),
        );
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

  Future<void> _renewCrop(BuildContext context, WidgetRef ref, Crop crop) async {
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
        const SnackBar(content: Text('New crop cycle created from this profile.')),
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
  if (crop.currentStage == CropStage.flowering || crop.currentStage == CropStage.fruiting) {
    return 'Yield protection';
  }
  return 'Cycle on track';
}

String _cropWorkNarrative({
  required Crop crop,
  required int overdueTasks,
  required int priorityTasks,
}) {
  if (overdueTasks > 0) {
    return 'Clear overdue reminders before adding new work. Start with scouting, irrigation, pest checks, and input applications that affect the current stage.';
  }
  if (priorityTasks > 0) {
    return 'High-priority reminders are open. Assign labour, confirm supplies, and record completion so the cycle timeline stays reliable.';
  }
  if (crop.daysToHarvest <= 7) {
    return crop.daysToHarvest < 0
        ? 'Harvest is due. Confirm quality, crates, labour, buyers, transport, and stock entry before produce leaves the field.'
        : 'Harvest is close. Prepare labour, crates, post-harvest handling, buyer commitments, and finance records now.';
  }
  if (crop.currentStage == CropStage.flowering || crop.currentStage == CropStage.fruiting) {
    return 'This is a yield-sensitive stage. Keep moisture steady, avoid missed feeding, scout pests often, and reduce handling stress.';
  }
  return 'Use this window to keep records tight: update stage, inspect stand quality, confirm input stock, and schedule the next field operation.';
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
    final List<Crop> crops = ref.watch(cropsProvider).valueOrNull ?? <Crop>[];
    final String normalized = cropName.trim().toLowerCase();
    final List<Crop> previous = crops
        .where((Crop crop) => crop.name.trim().toLowerCase() == normalized)
        .toList(growable: false)
      ..sort((Crop a, Crop b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(title: Text('$cropName history')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const SoftSectionTitle(title: 'Previous recommendations'),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'This page collects earlier $cropName cycles so you can reuse what worked, adjust fertilizer plans, and avoid repeating problems.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (previous.isEmpty)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No previous crop profiles found yet. Once you complete a cycle, its notes and recommendations will appear here.'),
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
                        Text(crop.variety, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Land: ${crop.landSizeLabel} | Stage: ${_stageLabel(crop.currentStage)}'),
                        const SizedBox(height: 6),
                        Text(crop.intelligenceNotes.isEmpty ? 'No stored notes for this cycle.' : crop.intelligenceNotes),
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
  final TextEditingController _quantityController = TextEditingController(text: '1');
  String _unit = 'kg';

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Record harvest', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _unit,
              items: const <String>['kg', 'ton', 'bags']
                  .map((String value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                  .toList(growable: false),
              onChanged: (String? value) {
                if (value != null) setState(() => _unit = value);
              },
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
            const SizedBox(height: 18),
            AppButton.primary(
              onPressed: () {
                final double quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
                Navigator.of(context).pop(
                  _HarvestDraft(
                    quantity: quantity,
                    unit: _unit,
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
  });

  final double quantity;
  final String unit;

  String get quantityLabel => '${quantity.toStringAsFixed(quantity >= 10 ? 0 : 1)} $unit';
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color markerColor = isDark ? Color.alphaBlend(tint.withOpacity(0.24), theme.colorScheme.surface) : tint;

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
                border: Border.all(color: isDark ? tint.withOpacity(0.44) : Colors.transparent),
              ),
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
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = isDark ? Color.alphaBlend(color.withOpacity(0.22), theme.colorScheme.surface) : color;
    final Color foreground = isDark ? theme.colorScheme.onSurface : const Color(0xFF284231);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isDark ? color.withOpacity(0.44) : color.withOpacity(0.85)),
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
