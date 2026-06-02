import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../domain/models/livestock.dart';
import '../../../domain/models/notification.dart' as farm_notification;
import '../../../domain/models/transaction.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';
import 'livestock_detail_screen.dart';

class LivestockScreen extends ConsumerWidget {
  const LivestockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Livestock>> livestockAsync = ref.watch(livestockProvider);
    final AsyncValue<List<Farm>> farmsAsync = ref.watch(farmsProvider);
    final List<Livestock> livestock = livestockAsync.maybeWhen(
      data: (List<Livestock> items) => items,
      orElse: () => <Livestock>[],
    );
    final List<Farm> farms = farmsAsync.maybeWhen(
      data: (List<Farm> items) => items,
      orElse: () => <Farm>[],
    );
    final Map<String, Farm> farmById = <String, Farm>{
      for (final Farm farm in farms) farm.id: farm,
    };
    final List<Farm> eligibleFarms = farms.where((Farm farm) => farm.supportsLivestock).toList(growable: false);

    final int animalCount = livestock.fold(0, (int sum, Livestock item) => sum + item.count);
    final int vaccinatedAverage = livestock.isEmpty
        ? 0
        : (livestock.fold(0, (int sum, Livestock item) => sum + item.vaccinationStatus) / livestock.length).round();
    final int healthAverage = livestock.isEmpty
        ? 0
        : (livestock.fold(0, (int sum, Livestock item) => sum + item.healthScore) / livestock.length).round();
    final int openTaskCount = livestock.fold<int>(0, (int sum, Livestock item) => sum + item.openTaskCount);
    final double inputSpend = livestock.fold<double>(0, (double sum, Livestock item) => sum + item.syncedInputCost);

    return SoftScreenScaffold(
      heroTitle: 'Livestock care',
      heroSubtitle: 'Assign each herd or flock to a specific farm so housing, welfare, and value records stay in the right place.',
      heroIcon: Icons.pets_rounded,
      heroVariant: FarmArtworkVariant.field,
      heroBadge: '${livestock.length} linked groups',
      trailing: IconButton(
        onPressed: eligibleFarms.isEmpty ? null : () => _openLivestockSheet(context, ref, farms: eligibleFarms),
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
      sections: <Widget>[
        if (eligibleFarms.isEmpty) ...<Widget>[
          const _InlineNotice(
            label: 'Farm link required',
            message: 'Create a farm first before adding livestock groups so each record belongs to a real farm.',
            tint: Color(0xFFFFE9D0),
          ),
          const SizedBox(height: 18),
        ],
        const SoftSectionTitle(title: 'Herd health'),
        Row(
          children: <Widget>[
            Expanded(
              child: SoftInfoChip(
                label: 'Open tasks',
                value: '$openTaskCount',
                color: const Color(0xFFE9F4DB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: 'Vaccinated',
                value: '$vaccinatedAverage%',
                color: const Color(0xFFDFF1FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: 'Health score',
                value: '$healthAverage%',
                color: const Color(0xFFFFE9D0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: SoftInfoChip(
                label: 'Animals',
                value: '$animalCount',
                color: const Color(0xFFEDE8FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: 'Inputs synced',
                value: CurrencyUtils.formatCurrency(inputSpend),
                color: const Color(0xFFFFF2C7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(
          title: 'Groups',
          action: TextButton.icon(
            onPressed: eligibleFarms.isEmpty ? null : () => _openLivestockSheet(context, ref, farms: eligibleFarms),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add group'),
          ),
        ),
        if (livestockAsync.isLoading && livestock.isEmpty)
          const _LoadingCard(message: 'Loading livestock records...')
        else if (livestock.isEmpty)
          _EmptyState(
            title: 'No livestock groups yet',
            message: eligibleFarms.isEmpty
                ? 'Create a livestock or combined farm first, then come back to add livestock groups.'
                : 'Add your first livestock group and link it to a specific farm.',
            actionLabel: 'Add first group',
            onPressed: eligibleFarms.isEmpty ? null : () => _openLivestockSheet(context, ref, farms: eligibleFarms),
          )
        else
          ...livestock.map(
            (Livestock item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AnimalGroupCard(
                livestock: item,
                farmName: farmById[item.farmId]?.name ?? 'Unknown farm',
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LivestockDetailScreen(livestockId: item.id),
                  ),
                ),
                onEdit: () => _openLivestockSheet(context, ref, farms: farms, livestock: item),
                onDelete: () => _confirmDelete(context, ref, item),
                onAddTask: () => _openLivestockTaskSheet(context, ref, item),
                onAddInput: () => _openLivestockInputSheet(context, ref, item),
                onAdjustStock: () => _openStockCountSheet(context, ref, item),
                onRecordEggCollection: item.species == LivestockSpecies.chicken || item.purpose == LivestockPurpose.eggs
                    ? () => _openEggCollectionSheet(context, ref, item)
                    : null,
                onToggleTask: (FarmTodoItem task) => _toggleLivestockTask(context, ref, item, task),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openLivestockSheet(
    BuildContext context,
    WidgetRef ref, {
    required List<Farm> farms,
    Livestock? livestock,
  }) async {
    final LivestockDraft? draft = await showModalBottomSheet<LivestockDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _LivestockFormSheet(
        farms: farms,
        initialLivestock: livestock,
      ),
    );

    if (draft == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final Livestock nextItem = Livestock(
      id: livestock?.id ?? const Uuid().v4(),
      farmId: draft.farmId,
      species: draft.species,
      breed: draft.breed,
      count: draft.count,
      maleCount: draft.maleCount,
      femaleCount: draft.femaleCount,
      purpose: draft.purpose,
      housingLocation: draft.housingLocation,
      acquisitionDate: draft.acquisitionDate,
      estimatedValue: draft.estimatedValue,
      vaccinationStatus: draft.vaccinationStatus,
      healthScore: draft.healthScore,
      growthStage: draft.growthStage,
      averageAgeMonths: draft.averageAgeMonths,
      targetMaturityMonths: draft.targetMaturityMonths,
      createdAt: livestock?.createdAt ?? now,
      updatedAt: now,
      isSynced: livestock?.isSynced ?? false,
      emoji: draft.emoji,
      profileImageBase64: livestock?.profileImageBase64 ?? '',
      coverImageBase64: draft.coverImageBase64.isNotEmpty
          ? draft.coverImageBase64
          : livestock?.coverImageBase64 ?? livestock?.profileImageBase64 ?? '',
      averageWeightKg: draft.averageWeightKg,
      dailyFeedKg: draft.dailyFeedKg,
      dailyWaterLitres: draft.dailyWaterLitres,
      mortalityCount: draft.mortalityCount,
      todoItems: livestock?.todoItems ?? const <FarmTodoItem>[],
      inputRecords: livestock?.inputRecords ?? const <FarmInputRecord>[],
      productionLogs: livestock?.productionLogs ?? const <LivestockProductionRecord>[],
      stockNotes: livestock?.stockNotes ?? _stockSummary(draft.count, draft.maleCount, draft.femaleCount),
      intelligenceNotes: _livestockIntelligenceSummary(
        draft.species,
        draft.healthScore,
        draft.vaccinationStatus,
        draft.averageAgeMonths,
        draft.averageWeightKg,
        draft.purpose,
      ),
      lastIntelligenceSyncAt: now,
    );

    if (livestock == null) {
      await ref.read(livestockProvider.notifier).addLivestock(nextItem);
      if (context.mounted) {
        context.showSnackBar('Livestock group linked to farm successfully');
      }
    } else {
      await ref.read(livestockProvider.notifier).updateLivestock(nextItem);
      if (context.mounted) {
        context.showSnackBar('Livestock record updated successfully');
      }
    }
  }

  Future<void> _openLivestockTaskSheet(BuildContext context, WidgetRef ref, Livestock livestock) async {
    final FarmTodoItem? task = await showModalBottomSheet<FarmTodoItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _TodoFormSheet(entityName: _speciesLabel(livestock.species)),
    );
    if (task == null) {
      return;
    }
    await ref.read(livestockProvider.notifier).updateLivestock(
          livestock.copyWith(
            todoItems: <FarmTodoItem>[task, ...livestock.todoItems],
            updatedAt: DateTime.now(),
            isSynced: false,
            intelligenceNotes: _livestockIntelligenceSummary(
              livestock.species,
              livestock.healthScore,
              livestock.vaccinationStatus,
              livestock.averageAgeMonths,
              livestock.averageWeightKg,
              livestock.purpose,
            ),
            lastIntelligenceSyncAt: DateTime.now(),
          ),
        );
    if (task.pushNotificationEnabled) {
      ref.read(notificationsProvider.notifier).addNotification(
            title: 'Animal reminder: ${task.title}',
            message:
                '${_speciesLabel(livestock.species)} reminder due ${_dateLabel(task.dueDate)}.${task.dailyReminder ? ' Repeats daily.' : ''}',
            type: farm_notification.NotificationType.info,
            actionUrl: '/livestock',
            metadata: <String, dynamic>{
              'entityType': 'livestock',
              'entityId': livestock.id,
              'priority': task.priority.name,
            },
          );
    }
    if (context.mounted) {
      context.showSnackBar('Animal reminder saved for sync and notification planning.');
    }
  }

  Future<void> _openLivestockInputSheet(BuildContext context, WidgetRef ref, Livestock livestock) async {
    final FarmInputRecord? input = await showModalBottomSheet<FarmInputRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _InputFormSheet(entityName: _speciesLabel(livestock.species)),
    );
    if (input == null) {
      return;
    }

    final String transactionId = const Uuid().v4();
    final FarmInputRecord syncedInput = FarmInputRecord(
      id: input.id,
      name: input.name,
      category: input.category,
      quantity: input.quantity,
      unit: input.unit,
      unitCost: input.unitCost,
      supplier: input.supplier,
      notes: input.notes,
      recordedAt: input.recordedAt,
      financeSynced: input.totalCost > 0,
      financeTransactionId: input.totalCost > 0 ? transactionId : '',
      createdAt: input.createdAt,
      updatedAt: DateTime.now(),
    );

    if (input.totalCost > 0) {
      final DateTime now = DateTime.now();
      await ref.read(transactionsProvider.notifier).addTransaction(
            Transaction(
              id: transactionId,
              farmId: livestock.farmId,
              type: TransactionType.expense,
              category: _transactionCategoryForInput(input.category),
              amount: input.totalCost,
              description: '${input.name} for ${_speciesLabel(livestock.species)}',
              transactionDate: input.recordedAt,
              linkedEntityId: livestock.id,
              createdAt: now,
              updatedAt: now,
              isSynced: false,
              recordKind: TransactionRecordKind.procurement,
              partyType: TransactionPartyType.provider,
              productName: input.name,
              quantity: input.quantity,
              unit: input.unit,
              unitPrice: input.unitCost,
              counterpartyName: input.supplier,
              notes: input.notes,
            ),
          );
    }

    await ref.read(livestockProvider.notifier).updateLivestock(
          livestock.copyWith(
            inputRecords: <FarmInputRecord>[syncedInput, ...livestock.inputRecords],
            updatedAt: DateTime.now(),
            isSynced: false,
            intelligenceNotes: _livestockIntelligenceSummary(
              livestock.species,
              livestock.healthScore,
              livestock.vaccinationStatus,
              livestock.averageAgeMonths,
              livestock.averageWeightKg,
              livestock.purpose,
            ),
            lastIntelligenceSyncAt: DateTime.now(),
          ),
        );
    if (context.mounted) {
      context.showSnackBar(input.totalCost > 0 ? 'Animal input saved and synced to finance.' : 'Animal input stock saved.');
    }
  }

  Future<void> _openStockCountSheet(BuildContext context, WidgetRef ref, Livestock livestock) async {
    final _StockCountDraft? draft = await showModalBottomSheet<_StockCountDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _StockCountSheet(livestock: livestock),
    );
    if (draft == null) {
      return;
    }
    await ref.read(livestockProvider.notifier).updateLivestock(
          livestock.copyWith(
            count: draft.count,
            maleCount: draft.maleCount,
            femaleCount: draft.femaleCount,
            stockNotes: draft.notes,
            updatedAt: DateTime.now(),
            isSynced: false,
            intelligenceNotes: _livestockIntelligenceSummary(
              livestock.species,
              livestock.healthScore,
              livestock.vaccinationStatus,
              livestock.averageAgeMonths,
              livestock.averageWeightKg,
              livestock.purpose,
            ),
            lastIntelligenceSyncAt: DateTime.now(),
          ),
        );
    if (context.mounted) {
      context.showSnackBar('Stock count updated and marked for sync.');
    }
  }

  Future<void> _toggleLivestockTask(BuildContext context, WidgetRef ref, Livestock livestock, FarmTodoItem task) async {
    final DateTime now = DateTime.now();
    final List<FarmTodoItem> tasks = livestock.todoItems
        .map(
          (FarmTodoItem item) => item.id == task.id
              ? item.copyWith(
                  isCompleted: !item.isCompleted,
                  completedAt: item.isCompleted ? null : now,
                  clearCompletedAt: item.isCompleted,
                  updatedAt: now,
                )
              : item,
        )
        .toList();
    await ref.read(livestockProvider.notifier).updateLivestock(
          livestock.copyWith(todoItems: tasks, updatedAt: now, isSynced: false),
        );
    if (context.mounted) {
      context.showSnackBar('Animal task updated.');
    }
  }

  Future<void> _openEggCollectionSheet(BuildContext context, WidgetRef ref, Livestock livestock) async {
    final _EggCollectionDraft? draft = await showModalBottomSheet<_EggCollectionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _EggCollectionSheet(livestock: livestock),
    );
    if (draft == null || draft.count <= 0) {
      return;
    }

    final String unitLabel = draft.unit == EggSaleUnit.crate ? 'crate' : 'number';
    final double quantity = draft.unit == EggSaleUnit.crate ? draft.count.toDouble() : draft.count.toDouble();
    final DateTime now = DateTime.now();
    await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
          farmId: livestock.farmId,
          productName: 'Eggs',
          unit: unitLabel,
          deltaQuantity: quantity,
          unitPrice: draft.unitPrice,
          costPrice: draft.costPrice,
        );

    final List<LivestockProductionRecord> logs = <LivestockProductionRecord>[
      LivestockProductionRecord(
        id: const Uuid().v4(),
        period: draft.period,
        recordedAt: draft.recordedAt,
        createdAt: now,
        updatedAt: now,
        weightKg: livestock.averageWeightKg,
        feedKg: livestock.dailyFeedKg,
        eggCount: draft.count,
        eggUnit: unitLabel,
        notes: draft.notes,
      ),
      ...livestock.productionLogs,
    ];
    await ref.read(livestockProvider.notifier).updateLivestock(
          livestock.copyWith(
            productionLogs: logs,
            updatedAt: now,
            isSynced: false,
            intelligenceNotes: _livestockIntelligenceSummary(
              livestock.species,
              livestock.healthScore,
              livestock.vaccinationStatus,
              livestock.averageAgeMonths,
              livestock.averageWeightKg,
              livestock.purpose,
            ),
            lastIntelligenceSyncAt: now,
          ),
        );
    if (context.mounted) {
      context.showSnackBar('Egg collection added to inventory and production history.');
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Livestock livestock) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete livestock group'),
        content: Text('Remove this ${_speciesLabel(livestock.species).toLowerCase()} group from your records?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(livestockProvider.notifier).deleteLivestock(livestock.id);
    if (context.mounted) {
      context.showSnackBar('Livestock group deleted');
    }
  }
}

class _LivestockFormSheet extends StatefulWidget {
  const _LivestockFormSheet({
    required this.farms,
    this.initialLivestock,
  });

  final List<Farm> farms;
  final Livestock? initialLivestock;

  @override
  State<_LivestockFormSheet> createState() => _LivestockFormSheetState();
}

class _LivestockFormSheetState extends State<_LivestockFormSheet> {
  final ImagePicker _imagePicker = ImagePicker();
  late final VoidCallback _formListener;
  late final TextEditingController _breedController;
  late final TextEditingController _countController;
  late final TextEditingController _maleCountController;
  late final TextEditingController _femaleCountController;
  late final TextEditingController _estimatedValueController;
  late final TextEditingController _vaccinationController;
  late final TextEditingController _healthScoreController;
  late final TextEditingController _ageMonthsController;
  late final TextEditingController _targetMaturityController;
  late final TextEditingController _mortalityController;
  late final TextEditingController _emojiController;
  late final TextEditingController _weightController;
  late final TextEditingController _feedController;
  late final TextEditingController _waterController;

  late String _farmId;
  late LivestockSpecies _species;
  late LivestockPurpose _purpose;
  late HousingType _housingType;
  late AnimalGrowthStage _growthStage;
  late DateTime _acquisitionDate;
  String _coverImageBase64 = '';
  String _coverImageName = '';

  @override
  void initState() {
    super.initState();
    final Livestock? livestock = widget.initialLivestock;
    _breedController = TextEditingController(text: livestock?.breed ?? '');
    _countController = TextEditingController(text: livestock?.count.toString() ?? '');
    _maleCountController = TextEditingController(text: livestock?.maleCount.toString() ?? '');
    _femaleCountController = TextEditingController(text: livestock?.femaleCount.toString() ?? '');
    _estimatedValueController = TextEditingController(
      text: livestock == null ? '' : livestock.estimatedValue.toStringAsFixed(0),
    );
    _vaccinationController = TextEditingController(
      text: livestock?.vaccinationStatus.toString() ?? '80',
    );
    _healthScoreController = TextEditingController(
      text: livestock?.healthScore.toString() ?? '80',
    );
    _ageMonthsController = TextEditingController(text: livestock?.averageAgeMonths.toString() ?? '0');
    _targetMaturityController = TextEditingController(text: livestock?.targetMaturityMonths.toString() ?? '12');
    _mortalityController = TextEditingController(text: livestock?.mortalityCount.toString() ?? '0');
    _emojiController = TextEditingController(text: livestock?.emoji ?? _emojiForSpecies(LivestockSpecies.goat));
    _weightController = TextEditingController(text: livestock?.averageWeightKg.toStringAsFixed(1) ?? '0');
    _feedController = TextEditingController(text: livestock?.dailyFeedKg.toStringAsFixed(1) ?? '0');
    _waterController = TextEditingController(text: livestock?.dailyWaterLitres.toStringAsFixed(1) ?? '0');
    _farmId = livestock?.farmId ?? widget.farms.first.id;
    _species = livestock?.species ?? LivestockSpecies.goat;
    _purpose = livestock?.purpose ?? LivestockPurpose.meat;
    _housingType = livestock?.housingLocation ?? HousingType.shed;
    _growthStage = livestock?.growthStage ?? AnimalGrowthStage.grower;
    _acquisitionDate = livestock?.acquisitionDate ?? DateTime.now();
    _coverImageBase64 = livestock?.coverImageBase64 ?? livestock?.profileImageBase64 ?? '';
    _formListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _countController.addListener(_formListener);
    _ageMonthsController.addListener(_formListener);
    _targetMaturityController.addListener(_formListener);
    _weightController.addListener(_formListener);
    _feedController.addListener(_formListener);
    _waterController.addListener(_formListener);
  }

  @override
  void dispose() {
    _countController.removeListener(_formListener);
    _ageMonthsController.removeListener(_formListener);
    _targetMaturityController.removeListener(_formListener);
    _weightController.removeListener(_formListener);
    _feedController.removeListener(_formListener);
    _waterController.removeListener(_formListener);
    _breedController.dispose();
    _countController.dispose();
    _maleCountController.dispose();
    _femaleCountController.dispose();
    _estimatedValueController.dispose();
    _vaccinationController.dispose();
    _healthScoreController.dispose();
    _ageMonthsController.dispose();
    _targetMaturityController.dispose();
    _mortalityController.dispose();
    _emojiController.dispose();
    _weightController.dispose();
    _feedController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _coverImageBase64 = base64Encode(bytes);
      _coverImageName = file.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initialLivestock != null;

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
                Text(
                  isEditing ? 'Edit livestock group' : 'Add livestock group',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Link this livestock group to a specific farm so housing, health, and value records stay organized.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: _coverImageBase64.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.memory(
                                base64Decode(_coverImageBase64),
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(_emojiController.text.trim().isEmpty ? _emojiForSpecies(_species) : _emojiController.text.trim(), style: const TextStyle(fontSize: 30)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          AppTextField(
                            controller: _emojiController,
                            label: 'Emoji',
                            hint: '🐔',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: AppButton.secondary(
                                  onPressed: _pickImage,
                                  child: Text(_coverImageBase64.isEmpty ? 'Add image' : 'Replace image'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppButton.secondary(
                                  onPressed: _coverImageBase64.isEmpty
                                      ? null
                                      : () => setState(() {
                                            _coverImageBase64 = '';
                                            _coverImageName = '';
                                          }),
                                  child: const Text('Clear'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_coverImageBase64.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_coverImageName, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 18),
                _DropdownField<String>(
                  label: 'Farm',
                  value: _farmId,
                  items: widget.farms.map((Farm farm) => farm.id).toList(),
                  itemLabel: (String farmId) => widget.farms.firstWhere((Farm farm) => farm.id == farmId).name,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _farmId = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _DropdownField<LivestockSpecies>(
                  label: 'Species',
                  value: _species,
                  items: LivestockSpecies.values,
                  itemLabel: _speciesLabel,
                  onChanged: (LivestockSpecies? value) {
                    if (value != null) {
                      setState(() => _species = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _breedController,
                  label: 'Breed',
                  hint: 'West African Dwarf',
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _countController,
                        label: 'Count',
                        hint: '46',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _maleCountController,
                        label: 'Male count',
                        hint: '12',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _femaleCountController,
                        label: 'Female count',
                        hint: '34',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DropdownField<LivestockPurpose>(
                  label: 'Purpose',
                  value: _purpose,
                  items: LivestockPurpose.values,
                  itemLabel: _purposeLabel,
                  onChanged: (LivestockPurpose? value) {
                    if (value != null) {
                      setState(() => _purpose = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _DropdownField<HousingType>(
                  label: 'Housing',
                  value: _housingType,
                  items: HousingType.values,
                  itemLabel: _housingLabel,
                  onChanged: (HousingType? value) {
                    if (value != null) {
                      setState(() => _housingType = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _DateTile(
                  label: 'Acquisition date',
                  value: _acquisitionDate,
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _acquisitionDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _acquisitionDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _estimatedValueController,
                  label: 'Estimated value',
                  hint: '920000',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _vaccinationController,
                        label: 'Vaccination %',
                        hint: '92',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _healthScoreController,
                        label: 'Health score %',
                        hint: '88',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _weightController,
                        label: 'Average weight (kg)',
                        hint: '35.5',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _feedController,
                        label: 'Daily feed (kg)',
                        hint: '1.2',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _waterController,
                  label: 'Daily water (litres)',
                  hint: '2.5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                _DropdownField<AnimalGrowthStage>(
                  label: 'Growth stage',
                  value: _growthStage,
                  items: AnimalGrowthStage.values,
                  itemLabel: _growthStageLabel,
                  onChanged: (AnimalGrowthStage? value) {
                    if (value != null) {
                      setState(() => _growthStage = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _LivestockPlanningCard(
                  summary: _livestockPlanningSummary(),
                  onApply: _applyLivestockSuggestions,
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _ageMonthsController,
                        label: 'Average age (months)',
                        hint: '7',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _targetMaturityController,
                        label: 'Target maturity (months)',
                        hint: '12',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _mortalityController,
                  label: 'Mortality recorded',
                  hint: '0',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton.secondary(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton.primary(
                        onPressed: _submit,
                        child: Text(isEditing ? 'Save changes' : 'Add group'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _LivestockPlanningSummary _livestockPlanningSummary() {
    final int count = int.tryParse(_countController.text.trim()) ?? 0;
    final int ageMonths = int.tryParse(_ageMonthsController.text.trim()) ?? 0;
    final int maturityMonths = _suggestedMaturityMonths(_species, _purpose, ageMonths, _growthStage);
    final double feedPerAnimal = _feedPerAnimalKg(_species, _growthStage, ageMonths, _purpose);
    final double waterPerAnimal = _waterPerAnimalLitres(_species, _growthStage, ageMonths, _purpose);
    final double groupFeed = feedPerAnimal * count;
    final double groupWater = waterPerAnimal * count;
    final double maturityProgress = maturityMonths <= 0 ? 0 : (ageMonths / maturityMonths).clamp(0, 1).toDouble();
    final String stageNote = switch (_growthStage) {
      AnimalGrowthStage.starter => 'Starter animals need smaller, frequent rations and closer health checks.',
      AnimalGrowthStage.grower => 'Grower stage is for consistent feed, clean water, and quick weight tracking.',
      AnimalGrowthStage.mature => 'Mature animals should stay on stable feed and hygiene routines.',
      AnimalGrowthStage.breeding => 'Breeding stock needs strong body condition and careful water access.',
      AnimalGrowthStage.finishing => 'Finishing stock should be monitored for weight gain and market timing.',
    };
    final String purposeNote = switch (_purpose) {
      LivestockPurpose.meat => 'Plan weight gain and market timing around body condition.',
      LivestockPurpose.milk => 'Milk animals need steady feed and water to keep output stable.',
      LivestockPurpose.eggs => 'Layers benefit from regular feed, calcium support, and daily egg collection.',
      LivestockPurpose.breeding => 'Breeding groups need balanced nutrition, housing hygiene, and fertility checks.',
    };
    final String speciesNote = switch (_species) {
      LivestockSpecies.chicken => _purpose == LivestockPurpose.eggs
          ? 'Use the feed estimate to support laying birds and track crates or loose eggs in inventory.'
          : 'Chicken groups respond best to stable feed, dry litter, and fast health checks.',
      LivestockSpecies.goat => 'Goats need clean water, fibre, and steady body-condition checks.',
      LivestockSpecies.pig => 'Pigs need clean housing, strict feed hygiene, and quick growth tracking.',
      LivestockSpecies.cattle => 'Cattle need more water and a slower maturity plan than small stock.',
      LivestockSpecies.sheep => 'Sheep do best with regular grazing, shelter, and parasite checks.',
    };

    return _LivestockPlanningSummary(
      maturityMonths: maturityMonths,
      maturityProgress: maturityProgress,
      feedPerAnimal: feedPerAnimal,
      waterPerAnimal: waterPerAnimal,
      groupFeedKg: groupFeed,
      groupWaterLitres: groupWater,
      stageNote: stageNote,
      purposeNote: purposeNote,
      speciesNote: speciesNote,
      ageNote: ageMonths == 0
          ? 'Enter age to refine the estimate.'
          : 'Age is being compared with the target maturity window to keep the plan practical.',
      eggNote: _species == LivestockSpecies.chicken && _purpose == LivestockPurpose.eggs
          ? 'For layers, collect eggs daily and track crates or loose egg counts in inventory.'
          : 'Egg collection guidance will appear automatically if you switch to layers.',
      vaccinationNote: 'Use vaccination and health scores as a quick check, then keep them updated in production logs.',
    );
  }

  void _applyLivestockSuggestions() {
    final _LivestockPlanningSummary summary = _livestockPlanningSummary();
    setState(() {
      _targetMaturityController.text = summary.maturityMonths.toString();
      _feedController.text = summary.groupFeedKg.toStringAsFixed(1);
      _waterController.text = summary.groupWaterLitres.toStringAsFixed(1);
    });
  }

  int _suggestedMaturityMonths(
    LivestockSpecies species,
    LivestockPurpose purpose,
    int ageMonths,
    AnimalGrowthStage stage,
  ) {
    final int base = switch (species) {
      LivestockSpecies.chicken => switch (purpose) {
          LivestockPurpose.eggs => 5,
          LivestockPurpose.meat => 2,
          LivestockPurpose.breeding => 6,
          LivestockPurpose.milk => 3,
        },
      LivestockSpecies.goat => switch (purpose) {
          LivestockPurpose.milk => 18,
          LivestockPurpose.breeding => 24,
          LivestockPurpose.meat => 12,
          LivestockPurpose.eggs => 12,
        },
      LivestockSpecies.pig => switch (purpose) {
          LivestockPurpose.breeding => 10,
          LivestockPurpose.meat => 7,
          LivestockPurpose.milk => 7,
          LivestockPurpose.eggs => 7,
        },
      LivestockSpecies.cattle => switch (purpose) {
          LivestockPurpose.milk => 24,
          LivestockPurpose.breeding => 30,
          LivestockPurpose.meat => 24,
          LivestockPurpose.eggs => 24,
        },
      LivestockSpecies.sheep => switch (purpose) {
          LivestockPurpose.meat => 12,
          LivestockPurpose.milk => 18,
          LivestockPurpose.breeding => 18,
          LivestockPurpose.eggs => 12,
        },
    };
    final int stageAdjustment = switch (stage) {
      AnimalGrowthStage.starter => -1,
      AnimalGrowthStage.grower => 0,
      AnimalGrowthStage.mature => 2,
      AnimalGrowthStage.breeding => 4,
      AnimalGrowthStage.finishing => 1,
    };
    final int ageAdjustment = ageMonths >= base ? 0 : -1;
    return (base + stageAdjustment + ageAdjustment).clamp(1, 120);
  }

  double _feedPerAnimalKg(
    LivestockSpecies species,
    AnimalGrowthStage stage,
    int ageMonths,
    LivestockPurpose purpose,
  ) {
    final double ageFactor = ageMonths < 4 ? 0.85 : ageMonths < 12 ? 1.0 : 1.15;
    final double purposeFactor = purpose == LivestockPurpose.breeding ? 1.05 : 1.0;
    final double base = switch (species) {
      LivestockSpecies.chicken => switch (stage) {
          AnimalGrowthStage.starter => 0.05,
          AnimalGrowthStage.grower => 0.09,
          AnimalGrowthStage.mature => 0.12,
          AnimalGrowthStage.breeding => 0.13,
          AnimalGrowthStage.finishing => 0.10,
        },
      LivestockSpecies.goat => switch (stage) {
          AnimalGrowthStage.starter => 0.6,
          AnimalGrowthStage.grower => 0.9,
          AnimalGrowthStage.mature => 1.1,
          AnimalGrowthStage.breeding => 1.2,
          AnimalGrowthStage.finishing => 1.0,
        },
      LivestockSpecies.pig => switch (stage) {
          AnimalGrowthStage.starter => 0.8,
          AnimalGrowthStage.grower => 1.6,
          AnimalGrowthStage.mature => 2.2,
          AnimalGrowthStage.breeding => 2.0,
          AnimalGrowthStage.finishing => 2.3,
        },
      LivestockSpecies.cattle => switch (stage) {
          AnimalGrowthStage.starter => 4.0,
          AnimalGrowthStage.grower => 6.0,
          AnimalGrowthStage.mature => 8.0,
          AnimalGrowthStage.breeding => 9.0,
          AnimalGrowthStage.finishing => 7.0,
        },
      LivestockSpecies.sheep => switch (stage) {
          AnimalGrowthStage.starter => 0.5,
          AnimalGrowthStage.grower => 0.8,
          AnimalGrowthStage.mature => 1.0,
          AnimalGrowthStage.breeding => 1.1,
          AnimalGrowthStage.finishing => 0.9,
        },
    };
    return base * ageFactor * purposeFactor;
  }

  double _waterPerAnimalLitres(
    LivestockSpecies species,
    AnimalGrowthStage stage,
    int ageMonths,
    LivestockPurpose purpose,
  ) {
    final double ageFactor = ageMonths < 4 ? 0.9 : ageMonths < 12 ? 1.0 : 1.1;
    final double stageFactor = switch (stage) {
      AnimalGrowthStage.starter => 0.9,
      AnimalGrowthStage.grower => 1.0,
      AnimalGrowthStage.mature => 1.05,
      AnimalGrowthStage.breeding => 1.1,
      AnimalGrowthStage.finishing => 1.0,
    };
    final double purposeFactor = purpose == LivestockPurpose.milk ? 1.1 : 1.0;
    final double base = switch (species) {
      LivestockSpecies.chicken => 0.25,
      LivestockSpecies.goat => 4.0,
      LivestockSpecies.pig => 6.0,
      LivestockSpecies.cattle => 25.0,
      LivestockSpecies.sheep => 2.5,
    };
    return base * ageFactor * stageFactor * purposeFactor;
  }

  void _submit() {
    final String? breedError = Validators.required(_breedController.text, fieldName: 'Breed');
    final String? countError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Count'),
        Validators.livestockCount,
      ],
      _countController.text,
    );
    final String? maleError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Male count'),
        Validators.livestockCount,
      ],
      _maleCountController.text,
    );
    final String? femaleError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Female count'),
        Validators.livestockCount,
      ],
      _femaleCountController.text,
    );
    final String? valueError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Estimated value'),
        Validators.amount,
      ],
      _estimatedValueController.text,
    );

    if (breedError != null) {
      context.showSnackBar(breedError, isError: true);
      return;
    }
    if (countError != null) {
      context.showSnackBar(countError, isError: true);
      return;
    }
    if (maleError != null) {
      context.showSnackBar(maleError, isError: true);
      return;
    }
    if (femaleError != null) {
      context.showSnackBar(femaleError, isError: true);
      return;
    }
    if (valueError != null) {
      context.showSnackBar(valueError, isError: true);
      return;
    }

    final int count = int.parse(_countController.text.trim());
    final int maleCount = int.parse(_maleCountController.text.trim());
    final int femaleCount = int.parse(_femaleCountController.text.trim());
    final int vaccination = int.tryParse(_vaccinationController.text.trim()) ?? 0;
    final int healthScore = int.tryParse(_healthScoreController.text.trim()) ?? 0;
    final int ageMonths = int.tryParse(_ageMonthsController.text.trim()) ?? -1;
    final int targetMaturityMonths = int.tryParse(_targetMaturityController.text.trim()) ?? -1;
    final int mortalityCount = int.tryParse(_mortalityController.text.trim()) ?? -1;
    final double weightKg = double.tryParse(_weightController.text.trim()) ?? -1;
    final double feedKg = double.tryParse(_feedController.text.trim()) ?? -1;
    final double waterLitres = double.tryParse(_waterController.text.trim()) ?? -1;

    if (maleCount + femaleCount > count) {
      context.showSnackBar('Male and female totals cannot exceed total count', isError: true);
      return;
    }
    if (vaccination < 0 || vaccination > 100 || healthScore < 0 || healthScore > 100) {
      context.showSnackBar('Vaccination and health scores must be between 0 and 100', isError: true);
      return;
    }
    if (ageMonths < 0 || targetMaturityMonths <= 0 || mortalityCount < 0) {
      context.showSnackBar('Age, maturity target, and mortality must be valid numbers', isError: true);
      return;
    }
    if (weightKg < 0 || feedKg < 0 || waterLitres < 0) {
      context.showSnackBar('Weight, feed, and water values must be valid numbers', isError: true);
      return;
    }

    Navigator.of(context).pop(
      LivestockDraft(
        farmId: _farmId,
        species: _species,
        breed: _breedController.text.trim(),
        count: count,
        maleCount: maleCount,
        femaleCount: femaleCount,
        purpose: _purpose,
        housingLocation: _housingType,
        acquisitionDate: _acquisitionDate,
        estimatedValue: double.parse(_estimatedValueController.text.trim()),
        vaccinationStatus: vaccination,
        healthScore: healthScore,
        growthStage: _growthStage,
        averageAgeMonths: ageMonths,
        targetMaturityMonths: targetMaturityMonths,
        mortalityCount: mortalityCount,
        emoji: _emojiController.text.trim().isEmpty ? _emojiForSpecies(_species) : _emojiController.text.trim(),
        coverImageBase64: _coverImageBase64,
        coverImageName: _coverImageName,
        averageWeightKg: weightKg,
        dailyFeedKg: feedKg,
        dailyWaterLitres: waterLitres,
      ),
    );
  }

  String _speciesLabel(LivestockSpecies species) => _labelForSpecies(species);

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
}

class _AnimalGroupCard extends StatelessWidget {
  const _AnimalGroupCard({
    required this.livestock,
    required this.farmName,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onAddTask,
    required this.onAddInput,
    required this.onAdjustStock,
    required this.onRecordEggCollection,
    required this.onToggleTask,
  });

  final Livestock livestock;
  final String farmName;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddTask;
  final VoidCallback onAddInput;
  final VoidCallback onAdjustStock;
  final VoidCallback? onRecordEggCollection;
  final ValueChanged<FarmTodoItem> onToggleTask;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = _accentForSpecies(livestock.species);

    return AppCard(
      onTap: onOpen,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(20),
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
                      child: Text(
                        livestock.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _speciesLabel(livestock.species),
                          style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (String value) {
                          if (value == 'edit') {
                            onEdit();
                            return;
                          }
                          if (value == 'task') {
                            onAddTask();
                            return;
                          }
                          if (value == 'input') {
                            onAddInput();
                            return;
                          }
                          if (value == 'stock') {
                            onAdjustStock();
                            return;
                          }
                          if (value == 'eggs') {
                            onRecordEggCollection?.call();
                            return;
                          }
                          onDelete();
                        },
                        itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(value: 'edit', child: Text('Edit group')),
                          PopupMenuItem<String>(value: 'task', child: Text('Add todo/reminder')),
                          PopupMenuItem<String>(value: 'input', child: Text('Record input stock')),
                          PopupMenuItem<String>(value: 'stock', child: Text('Adjust stock count')),
                          PopupMenuItem<String>(value: 'eggs', child: Text('Record egg collection')),
                          PopupMenuItem<String>(value: 'delete', child: Text('Delete group')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${livestock.count} heads linked to $farmName.',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${livestock.breed} for ${_purposeLabel(livestock.purpose).toLowerCase()} in ${_housingLabel(livestock.housingLocation).toLowerCase()}.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Avg weight ${livestock.averageWeightKg.toStringAsFixed(1)} kg · Feed ${livestock.dailyFeedKg.toStringAsFixed(1)} kg/day · Water ${livestock.dailyWaterLitres.toStringAsFixed(1)} L/day',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MiniTag(text: farmName, color: const Color(0xFFDFF1FF)),
                      _MiniTag(text: '${livestock.vaccinationStatus}% vaccinated', color: const Color(0xFFE9F4DB)),
                      _MiniTag(text: CurrencyUtils.formatCurrency(livestock.estimatedValue), color: const Color(0xFFFFE9D0)),
                      _MiniTag(text: '${(livestock.growthProgress * 100).round()}% maturity', color: const Color(0xFFEDE8FF)),
                      _MiniTag(text: '${livestock.openTaskCount} open tasks', color: const Color(0xFFFFF2C7)),
                      _MiniTag(text: '${livestock.inputRecords.length} inputs', color: const Color(0xFFEDE8FF)),
                      _MiniTag(text: '${livestock.productionLogs.length} records', color: const Color(0xFFDDF2C9)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SmartAnimalStrip(
                    title: livestock.intelligenceNotes.isEmpty
                        ? _livestockIntelligenceSummary(
                            livestock.species,
                            livestock.healthScore,
                            livestock.vaccinationStatus,
                            livestock.averageAgeMonths,
                            livestock.averageWeightKg,
                            livestock.purpose,
                          )
                        : livestock.intelligenceNotes,
                    stockNotes: livestock.stockNotes.isEmpty
                        ? _stockSummary(livestock.count, livestock.maleCount, livestock.femaleCount)
                        : livestock.stockNotes,
                    tasks: livestock.todoItems,
                    inputs: livestock.inputRecords,
                    onAddTask: onAddTask,
                    onAddInput: onAddInput,
                    onAdjustStock: onAdjustStock,
                    onRecordEggCollection: onRecordEggCollection,
                    onToggleTask: onToggleTask,
                  ),
                ],
              ),
            ),
          ],
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

class _LivestockPlanningSummary {
  const _LivestockPlanningSummary({
    required this.maturityMonths,
    required this.maturityProgress,
    required this.feedPerAnimal,
    required this.waterPerAnimal,
    required this.groupFeedKg,
    required this.groupWaterLitres,
    required this.stageNote,
    required this.purposeNote,
    required this.speciesNote,
    required this.ageNote,
    required this.eggNote,
    required this.vaccinationNote,
  });

  final int maturityMonths;
  final double maturityProgress;
  final double feedPerAnimal;
  final double waterPerAnimal;
  final double groupFeedKg;
  final double groupWaterLitres;
  final String stageNote;
  final String purposeNote;
  final String speciesNote;
  final String ageNote;
  final String eggNote;
  final String vaccinationNote;
}

class _LivestockPlanningCard extends StatelessWidget {
  const _LivestockPlanningCard({
    required this.summary,
    required this.onApply,
  });

  final _LivestockPlanningSummary summary;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF1FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.insights_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Production estimate',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Feed, water, and maturity are estimated from the selected species, purpose, age, and stage.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onApply,
                  child: const Text('Use suggestion'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MiniTag(text: '${summary.maturityMonths} month maturity', color: const Color(0xFFE8F4D8)),
                _MiniTag(text: '${(summary.maturityProgress * 100).round()}% of target', color: const Color(0xFFDFF1FF)),
                _MiniTag(text: '${summary.groupFeedKg.toStringAsFixed(1)} kg feed/day', color: const Color(0xFFFFEBD0)),
                _MiniTag(text: '${summary.groupWaterLitres.toStringAsFixed(1)} L water/day', color: const Color(0xFFEDE8FF)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: summary.maturityProgress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 12),
            Text(
              'Formula: age compared to target maturity gives maturity progress.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Feed formula: feed per animal x animal count = group feed requirement.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(summary.stageNote, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
            const SizedBox(height: 8),
            Text(summary.purposeNote, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
            const SizedBox(height: 8),
            Text(summary.speciesNote, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
            const SizedBox(height: 8),
            Text(summary.ageNote, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(summary.eggNote, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
            const SizedBox(height: 8),
            Text(summary.vaccinationNote, style: theme.textTheme.bodySmall),
          ],
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

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.label,
    required this.message,
    required this.tint,
  });

  final String label;
  final String message;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.agriculture_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const FarmSceneArtwork(
              height: 180,
              variant: FarmArtworkVariant.field,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton.primary(
              onPressed: onPressed,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.text,
    required this.color,
  });

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

class _SmartAnimalStrip extends StatelessWidget {
  const _SmartAnimalStrip({
    required this.title,
    required this.stockNotes,
    required this.tasks,
    required this.inputs,
    required this.onAddTask,
    required this.onAddInput,
    required this.onAdjustStock,
    required this.onRecordEggCollection,
    required this.onToggleTask,
  });

  final String title;
  final String stockNotes;
  final List<FarmTodoItem> tasks;
  final List<FarmInputRecord> inputs;
  final VoidCallback onAddTask;
  final VoidCallback onAddInput;
  final VoidCallback onAdjustStock;
  final VoidCallback? onRecordEggCollection;
  final ValueChanged<FarmTodoItem> onToggleTask;

  @override
  Widget build(BuildContext context) {
    final Iterable<FarmTodoItem> openTasks = tasks.where((FarmTodoItem item) => !item.isCompleted).take(2);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45)),
          const SizedBox(height: 6),
          Text(stockNotes, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (openTasks.isEmpty)
            Text('No open animal reminders. Add feeding, vaccination, cleaning, or inspection tasks.', style: Theme.of(context).textTheme.bodySmall)
          else
            ...openTasks.map(
              (FarmTodoItem task) => CheckboxListTile(
                value: task.isCompleted,
                onChanged: (_) => onToggleTask(task),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(task.title),
                subtitle: Text(task.dailyReminder ? 'Daily reminder enabled' : _dateLabel(task.dueDate)),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onAddTask,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Todo'),
              ),
              OutlinedButton.icon(
                onPressed: onAddInput,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: Text(inputs.isEmpty ? 'Input' : '${inputs.length} inputs'),
              ),
              OutlinedButton.icon(
                onPressed: onAdjustStock,
                icon: const Icon(Icons.add_chart_rounded, size: 18),
                label: const Text('Stock'),
              ),
              if (onRecordEggCollection != null)
                OutlinedButton.icon(
                  onPressed: onRecordEggCollection,
                  icon: const Icon(Icons.egg_alt_outlined, size: 18),
                  label: const Text('Eggs'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodoFormSheet extends StatefulWidget {
  const _TodoFormSheet({required this.entityName});

  final String entityName;

  @override
  State<_TodoFormSheet> createState() => _TodoFormSheetState();
}

class _TodoFormSheetState extends State<_TodoFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  FarmTodoPriority _priority = FarmTodoPriority.normal;
  bool _dailyReminder = true;
  bool _pushEnabled = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Check ${widget.entityName}');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Animal todo and reminder',
      subtitle: 'Create a daily care action for feeding, cleaning, vaccination, treatment, or inspection.',
      children: <Widget>[
        AppTextField(controller: _titleController, label: 'Task title', hint: 'Feed and inspect'),
        const SizedBox(height: 12),
        _DropdownField<FarmTodoPriority>(
          label: 'Priority',
          value: _priority,
          items: FarmTodoPriority.values,
          itemLabel: _priorityLabel,
          onChanged: (FarmTodoPriority? value) {
            if (value != null) {
              setState(() => _priority = value);
            }
          },
        ),
        const SizedBox(height: 12),
        _DateTile(
          label: 'Due date',
          value: _dueDate,
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _dueDate,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              setState(() => _dueDate = picked);
            }
          },
        ),
        SwitchListTile(
          value: _dailyReminder,
          onChanged: (bool value) => setState(() => _dailyReminder = value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Daily reminder'),
        ),
        SwitchListTile(
          value: _pushEnabled,
          onChanged: (bool value) => setState(() => _pushEnabled = value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Push notification ready'),
        ),
        AppTextField(controller: _notesController, label: 'Notes', maxLines: 3),
        const SizedBox(height: 18),
        AppButton.primary(onPressed: _submit, child: const Text('Save reminder')),
      ],
    );
  }

  void _submit() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      context.showSnackBar('Task title is required', isError: true);
      return;
    }
    final DateTime now = DateTime.now();
    Navigator.of(context).pop(
      FarmTodoItem(
        id: const Uuid().v4(),
        title: title,
        notes: _notesController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        dailyReminder: _dailyReminder,
        pushNotificationEnabled: _pushEnabled,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

class _InputFormSheet extends StatefulWidget {
  const _InputFormSheet({required this.entityName});

  final String entityName;

  @override
  State<_InputFormSheet> createState() => _InputFormSheetState();
}

class _InputFormSheetState extends State<_InputFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _unitCostController;
  late final TextEditingController _supplierController;
  late final TextEditingController _notesController;
  FarmInputCategory _category = FarmInputCategory.feed;
  DateTime _recordedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Feed');
    _quantityController = TextEditingController(text: '1');
    _unitController = TextEditingController(text: 'bag');
    _unitCostController = TextEditingController(text: '0');
    _supplierController = TextEditingController();
    _notesController = TextEditingController(text: 'Used for ${widget.entityName}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _unitCostController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Animal input stock',
      subtitle: 'Track feed, medicine, bedding, labour, and sync costs to finance records.',
      children: <Widget>[
        AppTextField(controller: _nameController, label: 'Input name', hint: 'Grower feed'),
        const SizedBox(height: 12),
        _DropdownField<FarmInputCategory>(
          label: 'Category',
          value: _category,
          items: FarmInputCategory.values,
          itemLabel: _inputCategoryLabel,
          onChanged: (FarmInputCategory? value) {
            if (value != null) {
              setState(() => _category = value);
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(child: AppTextField(controller: _quantityController, label: 'Quantity', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 10),
            Expanded(child: AppTextField(controller: _unitController, label: 'Unit', hint: 'bag')),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(controller: _unitCostController, label: 'Unit cost', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 12),
        AppTextField(controller: _supplierController, label: 'Supplier/provider', hint: 'Feed mill'),
        const SizedBox(height: 12),
        _DateTile(
          label: 'Record date',
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
        AppButton.primary(onPressed: _submit, child: const Text('Save and sync finance')),
      ],
    );
  }

  void _submit() {
    final String name = _nameController.text.trim();
    final double quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    final double unitCost = double.tryParse(_unitCostController.text.trim()) ?? 0;
    if (name.isEmpty || quantity <= 0 || _unitController.text.trim().isEmpty) {
      context.showSnackBar('Input name, quantity, and unit are required', isError: true);
      return;
    }
    final DateTime now = DateTime.now();
    Navigator.of(context).pop(
      FarmInputRecord(
        id: const Uuid().v4(),
        name: name,
        category: _category,
        quantity: quantity,
        unit: _unitController.text.trim(),
        unitCost: unitCost,
        supplier: _supplierController.text.trim(),
        notes: _notesController.text.trim(),
        recordedAt: _recordedAt,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

class _StockCountSheet extends StatefulWidget {
  const _StockCountSheet({required this.livestock});

  final Livestock livestock;

  @override
  State<_StockCountSheet> createState() => _StockCountSheetState();
}

class _StockCountSheetState extends State<_StockCountSheet> {
  late final TextEditingController _countController;
  late final TextEditingController _maleController;
  late final TextEditingController _femaleController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _countController = TextEditingController(text: widget.livestock.count.toString());
    _maleController = TextEditingController(text: widget.livestock.maleCount.toString());
    _femaleController = TextEditingController(text: widget.livestock.femaleCount.toString());
    _notesController = TextEditingController(text: widget.livestock.stockNotes);
  }

  @override
  void dispose() {
    _countController.dispose();
    _maleController.dispose();
    _femaleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Update stock count',
      subtitle: 'Record births, mortality, purchases, sales, or transfers so animal counts stay finance-ready.',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: AppTextField(controller: _countController, label: 'Total count', keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: AppTextField(controller: _maleController, label: 'Male', keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: AppTextField(controller: _femaleController, label: 'Female', keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(controller: _notesController, label: 'Stock notes', hint: '2 births, 1 sale, 0 mortality', maxLines: 3),
        const SizedBox(height: 18),
        AppButton.primary(onPressed: _submit, child: const Text('Update stock')),
      ],
    );
  }

  void _submit() {
    final int count = int.tryParse(_countController.text.trim()) ?? -1;
    final int male = int.tryParse(_maleController.text.trim()) ?? -1;
    final int female = int.tryParse(_femaleController.text.trim()) ?? -1;
    if (count < 0 || male < 0 || female < 0 || male + female > count) {
      context.showSnackBar('Enter valid stock counts. Male and female cannot exceed total.', isError: true);
      return;
    }
    Navigator.of(context).pop(
      _StockCountDraft(
        count: count,
        maleCount: male,
        femaleCount: female,
        notes: _notesController.text.trim().isEmpty ? _stockSummary(count, male, female) : _notesController.text.trim(),
      ),
    );
  }
}

enum EggSaleUnit {
  number,
  crate,
}

class _EggCollectionSheet extends StatefulWidget {
  const _EggCollectionSheet({required this.livestock});

  final Livestock livestock;

  @override
  State<_EggCollectionSheet> createState() => _EggCollectionSheetState();
}

class _EggCollectionSheetState extends State<_EggCollectionSheet> {
  late final TextEditingController _countController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _notesController;
  DateTime _recordedAt = DateTime.now();
  LivestockRecordPeriod _period = LivestockRecordPeriod.daily;
  EggSaleUnit _unit = EggSaleUnit.number;

  @override
  void initState() {
    super.initState();
    _countController = TextEditingController(text: '0');
    _unitPriceController = TextEditingController(text: '0');
    _costPriceController = TextEditingController(text: '0');
    _notesController = TextEditingController(text: '${_speciesLabel(widget.livestock.species)} egg collection');
  }

  @override
  void dispose() {
    _countController.dispose();
    _unitPriceController.dispose();
    _costPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Record egg collection',
      subtitle: 'Add eggs to inventory and keep a production log for layers or poultry sales.',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppTextField(
                controller: _countController,
                label: 'Egg count',
                hint: '120',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DropdownField<EggSaleUnit>(
                label: 'Unit',
                value: _unit,
                items: EggSaleUnit.values,
                itemLabel: (EggSaleUnit value) => value == EggSaleUnit.number ? 'Number' : 'Crate',
                onChanged: (EggSaleUnit? value) {
                  if (value != null) {
                    setState(() => _unit = value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: AppTextField(
                controller: _unitPriceController,
                label: 'Sale price',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _costPriceController,
                label: 'Cost price',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DropdownField<LivestockRecordPeriod>(
          label: 'Record period',
          value: _period,
          items: LivestockRecordPeriod.values,
          itemLabel: (LivestockRecordPeriod value) => value.name[0].toUpperCase() + value.name.substring(1),
          onChanged: (LivestockRecordPeriod? value) {
            if (value != null) {
              setState(() => _period = value);
            }
          },
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
        AppButton.primary(onPressed: _submit, child: const Text('Save egg collection')),
      ],
    );
  }

  void _submit() {
    final int count = int.tryParse(_countController.text.trim()) ?? 0;
    if (count <= 0) {
      context.showSnackBar('Enter a valid egg count', isError: true);
      return;
    }
    Navigator.of(context).pop(
      _EggCollectionDraft(
        count: count,
        unit: _unit,
        unitPrice: double.tryParse(_unitPriceController.text.trim()) ?? 0,
        costPrice: double.tryParse(_costPriceController.text.trim()) ?? 0,
        recordedAt: _recordedAt,
        notes: _notesController.text.trim(),
        period: _period,
      ),
    );
  }
}

class _EggCollectionDraft {
  const _EggCollectionDraft({
    required this.count,
    required this.unit,
    required this.unitPrice,
    required this.costPrice,
    required this.recordedAt,
    required this.notes,
    required this.period,
  });

  final int count;
  final EggSaleUnit unit;
  final double unitPrice;
  final double costPrice;
  final DateTime recordedAt;
  final String notes;
  final LivestockRecordPeriod period;
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

class _StockCountDraft {
  const _StockCountDraft({
    required this.count,
    required this.maleCount,
    required this.femaleCount,
    required this.notes,
  });

  final int count;
  final int maleCount;
  final int femaleCount;
  final String notes;
}

Color _accentForSpecies(LivestockSpecies species) {
  switch (species) {
    case LivestockSpecies.goat:
      return const Color(0xFFE9F4DB);
    case LivestockSpecies.chicken:
      return const Color(0xFFDFF1FF);
    case LivestockSpecies.pig:
      return const Color(0xFFFFE9D0);
    case LivestockSpecies.cattle:
      return const Color(0xFFEDE8FF);
    case LivestockSpecies.sheep:
      return const Color(0xFFE8F4D8);
  }
}

String _speciesLabel(LivestockSpecies species) => _labelForSpecies(species);

String _labelForSpecies(LivestockSpecies species) {
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

String _emojiForSpecies(LivestockSpecies species) {
  switch (species) {
    case LivestockSpecies.goat:
      return '🐐';
    case LivestockSpecies.chicken:
      return '🐔';
    case LivestockSpecies.pig:
      return '🐖';
    case LivestockSpecies.cattle:
      return '🐄';
    case LivestockSpecies.sheep:
      return '🐑';
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

String _livestockIntelligenceSummary(
  LivestockSpecies species,
  int healthScore,
  int vaccinationStatus,
  int ageMonths,
  double weightKg,
  LivestockPurpose purpose,
) {
  final String animal = _speciesLabel(species).toLowerCase();
  final String ageBand = ageMonths < 3
      ? 'young'
      : ageMonths < 9
          ? 'growing'
          : 'mature';
  final String productionHint = purpose == LivestockPurpose.eggs
      ? 'Focus on layer feed, clean water, and daily egg collection.'
      : purpose == LivestockPurpose.meat
          ? 'Use strong feed conversion, weight tracking, and hygiene checks.'
          : purpose == LivestockPurpose.milk
              ? 'Maintain body condition, water access, and regular milking records.'
              : 'Keep breeding condition, body weight, and separation notes updated.';
  if (healthScore < 60) {
    return 'Animal intelligence: $animal need urgent health checks, treatment notes, and closer daily inspection. $productionHint';
  }
  if (vaccinationStatus < 70) {
    return 'Animal intelligence: $animal vaccination coverage is low. Plan a vet visit and mark the reminder for push notification. $productionHint';
  }
  return 'Animal intelligence: $animal are $ageBand and stable at ${weightKg.toStringAsFixed(1)} kg. Keep feed, water, housing hygiene, and stock-count records updated. $productionHint';
}

String _stockSummary(int count, int maleCount, int femaleCount) =>
    'Stock sync: $count animals recorded, $maleCount male, $femaleCount female, ${count - maleCount - femaleCount} unclassified.';

String _priorityLabel(FarmTodoPriority priority) {
  switch (priority) {
    case FarmTodoPriority.low:
      return 'Low';
    case FarmTodoPriority.normal:
      return 'Normal';
    case FarmTodoPriority.high:
      return 'High';
    case FarmTodoPriority.urgent:
      return 'Urgent';
  }
}

String _inputCategoryLabel(FarmInputCategory category) {
  switch (category) {
    case FarmInputCategory.seed:
      return 'Seed';
    case FarmInputCategory.fertiliser:
      return 'Fertiliser';
    case FarmInputCategory.feed:
      return 'Feed';
    case FarmInputCategory.veterinary:
      return 'Veterinary';
    case FarmInputCategory.labour:
      return 'Labour';
    case FarmInputCategory.equipment:
      return 'Equipment';
    case FarmInputCategory.other:
      return 'Other';
  }
}

TransactionCategory _transactionCategoryForInput(FarmInputCategory category) {
  switch (category) {
    case FarmInputCategory.feed:
      return TransactionCategory.feed;
    case FarmInputCategory.veterinary:
      return TransactionCategory.veterinary;
    case FarmInputCategory.labour:
      return TransactionCategory.labour;
    case FarmInputCategory.seed:
    case FarmInputCategory.fertiliser:
      return TransactionCategory.fertiliser;
    case FarmInputCategory.equipment:
    case FarmInputCategory.other:
      return TransactionCategory.other;
  }
}

String _dateLabel(DateTime value) => '${value.day}/${value.month}/${value.year}';

class LivestockDraft {
  const LivestockDraft({
    required this.farmId,
    required this.species,
    required this.breed,
    required this.count,
    required this.maleCount,
    required this.femaleCount,
    required this.purpose,
    required this.housingLocation,
    required this.acquisitionDate,
    required this.estimatedValue,
    required this.vaccinationStatus,
    required this.healthScore,
    required this.growthStage,
    required this.averageAgeMonths,
    required this.targetMaturityMonths,
    required this.mortalityCount,
    required this.emoji,
    required this.coverImageBase64,
    required this.coverImageName,
    required this.averageWeightKg,
    required this.dailyFeedKg,
    required this.dailyWaterLitres,
  });

  final String farmId;
  final LivestockSpecies species;
  final String breed;
  final int count;
  final int maleCount;
  final int femaleCount;
  final LivestockPurpose purpose;
  final HousingType housingLocation;
  final DateTime acquisitionDate;
  final double estimatedValue;
  final int vaccinationStatus;
  final int healthScore;
  final AnimalGrowthStage growthStage;
  final int averageAgeMonths;
  final int targetMaturityMonths;
  final int mortalityCount;
  final String emoji;
  final String coverImageBase64;
  final String coverImageName;
  final double averageWeightKg;
  final double dailyFeedKg;
  final double dailyWaterLitres;
}
