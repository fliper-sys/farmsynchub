import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../core/services/farm_notification_service.dart';
import '../../../data/services/crop_advice_catalog.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/farm_activity.dart';
import '../../../domain/models/notification.dart' as farm_notification;
import '../../../domain/models/transaction.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';
import 'crop_detail_screen.dart';

class CropsScreen extends ConsumerWidget {
  const CropsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLanguage language = ref.watch(appLanguageProvider);
    final AsyncValue<List<Crop>> cropsAsync = ref.watch(cropsProvider);
    final AsyncValue<List<Farm>> farmsAsync = ref.watch(farmsProvider);
    final List<Crop> crops = cropsAsync.maybeWhen(
      data: (List<Crop> items) => items,
      orElse: () => <Crop>[],
    );
    final List<Farm> farms = farmsAsync.maybeWhen(
      data: (List<Farm> items) => items,
      orElse: () => <Farm>[],
    );
    final Map<String, CropAdviceSummary> adviceByCrop =
        <String, CropAdviceSummary>{};
    final Map<String, Farm> farmById = <String, Farm>{
      for (final Farm farm in farms) farm.id: farm,
    };
    final List<Farm> eligibleFarms =
        farms.where((Farm farm) => farm.supportsCrops).toList(growable: false);

    final int seedingCount = crops
        .where((Crop crop) => crop.currentStage == CropStage.seeding)
        .length;
    final int growingCount = crops
        .where((Crop crop) => <CropStage>[
              CropStage.germination,
              CropStage.vegetative,
            ].contains(crop.currentStage))
        .length;
    final int floweringCount = crops
        .where((Crop crop) => crop.currentStage == CropStage.flowering)
        .length;
    final int readyCount =
        crops.where((Crop crop) => crop.status == CropStatus.ready).length;
    final int openTaskCount =
        crops.fold<int>(0, (int sum, Crop crop) => sum + crop.openTaskCount);
    final double inputSpend = crops.fold<double>(
        0, (double sum, Crop crop) => sum + crop.syncedInputCost);
    for (final Crop crop in crops) {
      adviceByCrop[crop.id] = CropAdviceCatalog.summarize(crop);
    }

    return SoftScreenScaffold(
      heroTitle: language.tr(
          en: 'Crop records',
          ha: 'Bayanan amfanin gona',
          fr: 'Fiches de cultures'),
      heroSubtitle: language.tr(
        en: 'Link every crop to the right farm, track its stage, and keep planting plans tied to actual field records.',
        ha: 'Hada kowanne amfanin gona da gonar da ta dace, bin diddigin matakinsa, kuma ka rike shirye-shiryen shuka a hade da ainihin bayanan gona.',
        fr: 'Reliez chaque culture a la bonne ferme, suivez son stade et gardez les plans de plantation lies aux releves reels du champ.',
      ),
      heroIcon: Icons.grass_rounded,
      heroVariant: FarmArtworkVariant.crops,
      heroBadge: '${crops.length} crop records',
      trailing: _HeroActionButton(
        onTap: eligibleFarms.isEmpty
            ? null
            : () => _openCropSheet(context, ref, farms: eligibleFarms),
        icon: Icons.add_circle_outline_rounded,
      ),
      sections: <Widget>[
        if (eligibleFarms.isEmpty) ...<Widget>[
          _InlineNotice(
            icon: Icons.agriculture_rounded,
            color: const Color(0xFFFFEBD0),
            message: language.tr(
              en: 'Create a farm first before adding crops so each record can be linked to a real field.',
              ha: 'Kirkiri gona tukun kafin kara amfanin gona domin kowanne bayani ya hade da ainihin fili.',
              fr: 'Creez d\'abord une ferme avant d\'ajouter des cultures afin que chaque fiche soit liee a un champ reel.',
            ),
          ),
          const SizedBox(height: 18),
        ],
        SoftSectionTitle(
          title: language.tr(
              en: 'Growth board',
              ha: 'Allon girma',
              fr: 'Tableau de croissance'),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          childAspectRatio: 1.05,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: <Widget>[
            _StageCard(
                label: language.tr(en: 'Seeding', ha: 'Shuki', fr: 'Semis'),
                value: '$seedingCount crops',
                color: const Color(0xFFE8F4D8)),
            _StageCard(
                label:
                    language.tr(en: 'Growing', ha: 'Girma', fr: 'Croissance'),
                value: '$growingCount crops',
                color: const Color(0xFFDDF0E4)),
            _StageCard(
                label: language.tr(
                    en: 'Flowering', ha: 'Furanni', fr: 'Floraison'),
                value: '$floweringCount crops',
                color: const Color(0xFFFFEBD0)),
            _StageCard(
                label: language.tr(en: 'Ready', ha: 'A shirye', fr: 'Pret'),
                value: '$readyCount crops',
                color: const Color(0xFFDCEEFF)),
            _StageCard(
                label: language.tr(
                    en: 'Open tasks',
                    ha: 'Ayyukan da suka rage',
                    fr: 'Taches ouvertes'),
                value: '$openTaskCount todos',
                color: const Color(0xFFEDE8FF)),
            _StageCard(
                label: language.tr(
                    en: 'Inputs synced',
                    ha: 'Kayan da aka sync',
                    fr: 'Intrants synchronises'),
                value: CurrencyUtils.formatCurrency(inputSpend),
                color: const Color(0xFFFFF2C7)),
          ],
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(
          title: language.tr(
              en: 'Current crops',
              ha: 'Amfanin gona na yanzu',
              fr: 'Cultures actuelles'),
          action: TextButton.icon(
            onPressed: eligibleFarms.isEmpty
                ? null
                : () => _openCropSheet(context, ref, farms: eligibleFarms),
            icon: const Icon(Icons.add_rounded),
            label: Text(language.tr(
                en: 'Add crop',
                ha: 'Kara amfanin gona',
                fr: 'Ajouter une culture')),
          ),
        ),
        if (cropsAsync.isLoading && crops.isEmpty)
          _LoadingCard(
            message: language.tr(
              en: 'Loading crop records...',
              ha: 'Ana loda bayanan amfanin gona...',
              fr: 'Chargement des fiches de cultures...',
            ),
          )
        else if (crops.isEmpty)
          _EmptyState(
            title: language.tr(
                en: 'No crops linked yet',
                ha: 'Babu amfanin gona da aka hada har yanzu',
                fr: 'Aucune culture liee pour le moment'),
            message: eligibleFarms.isEmpty
                ? language.tr(
                    en: 'Create a crop, greenhouse, or combined farm first, then come back to add crop records.',
                    ha: 'Kirkiri gonar amfanin gona, gidan kore, ko gonar hade tukun, sannan ka koma domin kara bayanan amfanin gona.',
                    fr: 'Creez d\'abord une ferme de cultures, une serre ou une ferme mixte, puis revenez ajouter des fiches de cultures.',
                  )
                : language.tr(
                    en: 'Add your first crop and assign it to a farm to begin tracking field progress.',
                    ha: 'Kara amfanin gonarka na farko kuma ka ba da shi ga wata gona domin fara bin diddigin ci gaban fili.',
                    fr: 'Ajoutez votre premiere culture et assignez-la a une ferme pour commencer a suivre l\'avancement du champ.',
                  ),
            buttonLabel: language.tr(
                en: 'Add first crop',
                ha: 'Kara amfanin gona na farko',
                fr: 'Ajouter la premiere culture'),
            onPressed: eligibleFarms.isEmpty
                ? null
                : () => _openCropSheet(context, ref, farms: eligibleFarms),
          )
        else
          ...crops.map(
            (Crop crop) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CropCard(
                crop: crop,
                farmName: farmById[crop.farmId]?.name ?? 'Unknown farm',
                advice: adviceByCrop[crop.id],
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CropDetailScreen(cropId: crop.id),
                  ),
                ),
                onEdit: () =>
                    _openCropSheet(context, ref, farms: farms, crop: crop),
                onDelete: () => _confirmDelete(context, ref, crop),
                onAddTask: () => _openCropTaskSheet(context, ref, crop),
                onAddInput: () => _openCropInputSheet(context, ref, crop),
                onToggleTask: (FarmTodoItem task) =>
                    _toggleCropTask(context, ref, crop, task),
              ),
            ),
          ),
        const SizedBox(height: 18),
        AppCard(
          color: scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    farms.isEmpty
                        ? 'Farm records unlock crop linking. Create a crop, greenhouse, or combined farm to begin planting plans.'
                        : 'Review linked crop records by farm and keep planting dates, stages, and input costs updated.',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppButton.secondary(
                    onPressed: eligibleFarms.isEmpty
                        ? null
                        : () =>
                            _openCropSheet(context, ref, farms: eligibleFarms),
                    child: const Text('Open planner'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCropSheet(
    BuildContext context,
    WidgetRef ref, {
    required List<Farm> farms,
    Crop? crop,
  }) async {
    final CropDraft? draft = await showModalBottomSheet<CropDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _CropFormSheet(
        farms: farms,
        initialCrop: crop,
      ),
    );

    if (draft == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final Crop nextCrop = Crop(
      id: crop?.id ?? const Uuid().v4(),
      farmId: draft.farmId,
      name: draft.name,
      variety: draft.variety,
      areaHa: draft.areaHa,
      plantingDate: draft.plantingDate,
      expectedHarvestDate: draft.expectedHarvestDate,
      currentStage: draft.currentStage,
      status: draft.status,
      totalInputCost: draft.totalInputCost,
      cycleLengthDays: draft.cycleLengthDays,
      notes: draft.notes,
      createdAt: crop?.createdAt ?? now,
      updatedAt: now,
      isSynced: crop?.isSynced ?? false,
      profileImageBase64: crop?.profileImageBase64 ?? '',
      landSizeValue: draft.landSizeValue,
      landSizeUnit: draft.landSizeUnit,
      targetYieldKg: draft.targetYieldKg,
      protectedEnvironment: draft.protectedEnvironment,
      todoItems: crop?.todoItems ?? const <FarmTodoItem>[],
      inputRecords: crop?.inputRecords ?? const <FarmInputRecord>[],
      intelligenceNotes: _cropIntelligenceSummary(
          draft.name, draft.currentStage, draft.expectedHarvestDate,
          landSizeText: draft.landSizeLabel),
      lastIntelligenceSyncAt: now,
    );

    if (crop == null) {
      await ref.read(cropsProvider.notifier).addCrop(nextCrop);
      if (context.mounted) {
        context.showSnackBar('Crop linked to farm successfully');
      }
    } else {
      await ref.read(cropsProvider.notifier).updateCrop(nextCrop);
      if (context.mounted) {
        context.showSnackBar('Crop record updated successfully');
      }
    }
  }

  Future<void> _openCropTaskSheet(
      BuildContext context, WidgetRef ref, Crop crop) async {
    final FarmTodoItem? task = await showModalBottomSheet<FarmTodoItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _TodoFormSheet(entityName: crop.name),
    );
    if (task == null) {
      return;
    }

    await ref.read(cropsProvider.notifier).updateCrop(
          crop.copyWith(
            todoItems: <FarmTodoItem>[task, ...crop.todoItems],
            updatedAt: DateTime.now(),
            isSynced: false,
            intelligenceNotes: _cropIntelligenceSummary(
                crop.name, crop.currentStage, crop.expectedHarvestDate,
                landSizeText: crop.landSizeLabel),
            lastIntelligenceSyncAt: DateTime.now(),
          ),
        );
    await _appendFarmActivity(
      ref,
      crop.farmId,
      action: 'Crop reminder added',
      detail: '${crop.name}: ${task.title}',
      audience: FarmActivityAudience.owners,
      relatedTaskId: task.id,
    );
    if (task.pushNotificationEnabled) {
      final DateTime scheduledAt = task.dueDate.isBefore(DateTime.now())
          ? DateTime.now().add(const Duration(minutes: 1))
          : task.dueDate;
      await FarmNotificationService.instance.scheduleAt(
        id: task.id.hashCode,
        title: 'Crop reminder: ${task.title}',
        body: '${crop.name} is due on ${_dateLabel(task.dueDate)}.',
        scheduledAt: scheduledAt,
        payload: '/crops',
      );
    }
    if (task.pushNotificationEnabled) {
      ref.read(notificationsProvider.notifier).addNotification(
        title: 'Crop reminder: ${task.title}',
        message:
            '${crop.name} reminder due ${_dateLabel(task.dueDate)}.${task.dailyReminder ? ' Repeats daily.' : ''}',
        type: farm_notification.NotificationType.info,
        actionUrl: '/crops',
        metadata: <String, dynamic>{
          'entityType': 'crop',
          'entityId': crop.id,
          'priority': task.priority.name,
        },
      );
    }
    if (context.mounted) {
      context.showSnackBar(task.pushNotificationEnabled
          ? 'Crop reminder saved. It will appear in farm sync and notification planning.'
          : 'Crop task saved.');
    }
  }

  Future<void> _openCropInputSheet(
      BuildContext context, WidgetRef ref, Crop crop) async {
    final FarmInputRecord? input = await showModalBottomSheet<FarmInputRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _InputFormSheet(entityName: crop.name),
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
              farmId: crop.farmId,
              type: TransactionType.expense,
              category: _transactionCategoryForInput(input.category),
              amount: input.totalCost,
              description: '${input.name} input for ${crop.name}',
              transactionDate: input.recordedAt,
              linkedEntityId: crop.id,
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

    await ref.read(cropsProvider.notifier).updateCrop(
          crop.copyWith(
            totalInputCost: crop.totalInputCost + input.totalCost,
            inputRecords: <FarmInputRecord>[syncedInput, ...crop.inputRecords],
            updatedAt: DateTime.now(),
            isSynced: false,
            intelligenceNotes: _cropIntelligenceSummary(
                crop.name, crop.currentStage, crop.expectedHarvestDate,
                landSizeText: crop.landSizeLabel),
            lastIntelligenceSyncAt: DateTime.now(),
          ),
        );
    await _appendFarmActivity(
      ref,
      crop.farmId,
      action: 'Crop input logged',
      detail: '${input.name} added to ${crop.name}',
      audience: FarmActivityAudience.workspace,
    );
    if (context.mounted) {
      context.showSnackBar(input.totalCost > 0
          ? 'Input saved and synced to finance.'
          : 'Input stock record saved.');
    }
  }

  Future<void> _toggleCropTask(
      BuildContext context, WidgetRef ref, Crop crop, FarmTodoItem task) async {
    final DateTime now = DateTime.now();
    final bool nowCompleted = !task.isCompleted;
    final List<FarmTodoItem> tasks = crop.todoItems
        .map(
          (FarmTodoItem item) => item.id == task.id
              ? item.copyWith(
                  isCompleted: nowCompleted,
                  completedAt: nowCompleted ? now : null,
                  clearCompletedAt: !nowCompleted,
                  updatedAt: now,
                )
              : item,
        )
        .toList();
    await ref.read(cropsProvider.notifier).updateCrop(
          crop.copyWith(todoItems: tasks, updatedAt: now, isSynced: false),
        );
    if (nowCompleted) {
      await FarmNotificationService.instance.cancel(task.id.hashCode);
      await _appendFarmActivity(
        ref,
        crop.farmId,
        action: 'Crop reminder completed',
        detail: '${crop.name}: ${task.title}',
        audience: FarmActivityAudience.owners,
        relatedTaskId: task.id,
      );
    }
    if (context.mounted) {
      context.showSnackBar('Crop task updated.');
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Crop crop) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete crop'),
        content: Text('Remove "${crop.name}" from your crop records?'),
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

    await ref.read(cropsProvider.notifier).deleteCrop(crop.id);
    if (context.mounted) {
      context.showSnackBar('Crop deleted');
    }
  }

  Future<void> _appendFarmActivity(
    WidgetRef ref,
    String farmId, {
    required String action,
    required String detail,
    required FarmActivityAudience audience,
    String relatedTaskId = '',
    String relatedMemberId = '',
  }) async {
    final List<Farm> farms = ref.read(farmsProvider).valueOrNull ?? <Farm>[];
    final int index = farms.indexWhere((Farm farm) => farm.id == farmId);
    if (index == -1) {
      return;
    }
    final Farm farm = farms[index];
    final UserProfile? profile = ref.read(userProfileProvider).valueOrNull;
    final DateTime now = DateTime.now();
    final FarmActivityRecord activity = FarmActivityRecord(
      id: const Uuid().v4(),
      actorName: profile?.fullName ?? 'You',
      actorRole: _workspaceRoleForAccount(profile?.accountRole),
      action: action,
      detail: detail,
      audience: audience,
      relatedTaskId: relatedTaskId,
      relatedMemberId: relatedMemberId,
      sentToOwners: audience == FarmActivityAudience.owners,
      createdAt: now,
    );
    await ref.read(farmsProvider.notifier).updateFarm(
          farm.copyWith(
            activityLog: <FarmActivityRecord>[activity, ...farm.activityLog],
            updatedAt: now,
            isSynced: false,
          ),
        );
  }
}

FarmWorkspaceRole _workspaceRoleForAccount(UserAccountRole? role) {
  switch (role) {
    case UserAccountRole.worker:
      return FarmWorkspaceRole.worker;
    case UserAccountRole.partner:
      return FarmWorkspaceRole.partner;
    case UserAccountRole.viewer:
      return FarmWorkspaceRole.viewer;
    case UserAccountRole.owner:
    case null:
      return FarmWorkspaceRole.owner;
  }
}

class _CropFormSheet extends StatefulWidget {
  const _CropFormSheet({
    required this.farms,
    this.initialCrop,
  });

  final List<Farm> farms;
  final Crop? initialCrop;

  @override
  State<_CropFormSheet> createState() => _CropFormSheetState();
}

class _CropFormSheetState extends State<_CropFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _varietyController;
  late final TextEditingController _landSizeController;
  late final TextEditingController _costController;
  late final TextEditingController _cycleController;
  late final TextEditingController _targetYieldController;
  late final TextEditingController _notesController;

  late String _farmId;
  late LandSizeUnit _landSizeUnit;
  late CropStage _stage;
  late CropStatus _status;
  late DateTime _plantingDate;
  late DateTime _expectedHarvestDate;
  late bool _protectedEnvironment;
  late final VoidCallback _formListener;

  @override
  void initState() {
    super.initState();
    final Crop? crop = widget.initialCrop;
    _nameController = TextEditingController(text: crop?.name ?? '');
    _varietyController = TextEditingController(text: crop?.variety ?? '');
    _landSizeUnit = crop?.landSizeUnit ?? LandSizeUnit.hectares;
    _landSizeController = TextEditingController(
      text: crop == null
          ? ''
          : (_landSizeUnit == LandSizeUnit.plots
                  ? crop.landSizeValue
                  : crop.areaHa)
              .toStringAsFixed(_landSizeUnit == LandSizeUnit.plots ? 1 : 2),
    );
    _costController = TextEditingController(
        text: crop == null ? '' : crop.totalInputCost.toStringAsFixed(0));
    _cycleController =
        TextEditingController(text: crop?.cycleLengthDays.toString() ?? '90');
    _targetYieldController = TextEditingController(
        text: crop == null ? '' : crop.targetYieldKg.toStringAsFixed(0));
    _notesController = TextEditingController(text: crop?.notes ?? '');
    _farmId = crop?.farmId ?? widget.farms.first.id;
    _stage = crop?.currentStage ?? CropStage.seeding;
    _status = crop?.status ?? CropStatus.planted;
    _plantingDate = crop?.plantingDate ?? DateTime.now();
    _expectedHarvestDate = crop?.expectedHarvestDate ??
        DateTime.now().add(const Duration(days: 90));
    _protectedEnvironment =
        crop?.protectedEnvironment ?? widget.farms.first.supportsGreenhouse;
    _formListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _nameController.addListener(_formListener);
    _varietyController.addListener(_formListener);
    _landSizeController.addListener(_formListener);
    _cycleController.addListener(_formListener);
    _targetYieldController.addListener(_formListener);
  }

  @override
  void dispose() {
    _nameController.removeListener(_formListener);
    _varietyController.removeListener(_formListener);
    _landSizeController.removeListener(_formListener);
    _cycleController.removeListener(_formListener);
    _targetYieldController.removeListener(_formListener);
    _nameController.dispose();
    _varietyController.dispose();
    _landSizeController.dispose();
    _costController.dispose();
    _cycleController.dispose();
    _targetYieldController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initialCrop != null;

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
                Text(
                  isEditing ? 'Edit crop record' : 'Add crop record',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Link this crop to a specific farm so its records show up in the right field workspace.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                _DropdownField<String>(
                  label: 'Farm',
                  value: _farmId,
                  items: widget.farms.map((Farm farm) => farm.id).toList(),
                  itemLabel: (String farmId) => widget.farms
                      .firstWhere((Farm farm) => farm.id == farmId)
                      .name,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _farmId = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _nameController,
                  label: 'Crop name',
                  hint: 'Tomato',
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _varietyController,
                  label: 'Variety',
                  hint: 'Roma',
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _landSizeController,
                  label: 'Land size',
                  hint: _landSizeUnit == LandSizeUnit.plots ? '4.0' : '0.3',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                _DropdownField<LandSizeUnit>(
                  label: 'Land size unit',
                  value: _landSizeUnit,
                  items: LandSizeUnit.values,
                  itemLabel: (LandSizeUnit value) => value.label,
                  onChanged: (LandSizeUnit? value) {
                    if (value == null) return;
                    setState(() {
                      final double entered =
                          double.tryParse(_landSizeController.text.trim()) ?? 0;
                      if (_landSizeUnit == LandSizeUnit.hectares &&
                          value == LandSizeUnit.plots) {
                        _landSizeController.text =
                            (entered / CropAdviceCatalog.plotToHa)
                                .toStringAsFixed(1);
                      } else if (_landSizeUnit == LandSizeUnit.plots &&
                          value == LandSizeUnit.hectares) {
                        _landSizeController.text =
                            (entered * CropAdviceCatalog.plotToHa)
                                .toStringAsFixed(2);
                      }
                      _landSizeUnit = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _costController,
                  label: 'Total input cost',
                  hint: '78000',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _cycleController,
                        label: 'Cycle length (days)',
                        hint: '90',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _targetYieldController,
                        label: 'Target yield (kg)',
                        hint: '3500',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _CropPlanningCard(
                  summary: _cropPlanningSummary(),
                  onApply: _applyCropSuggestions,
                ),
                const SizedBox(height: 14),
                _DropdownField<CropStage>(
                  label: 'Growth stage',
                  value: _stage,
                  items: CropStage.values,
                  itemLabel: _stageLabel,
                  onChanged: (CropStage? value) {
                    if (value != null) {
                      setState(() => _stage = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _DropdownField<CropStatus>(
                  label: 'Status',
                  value: _status,
                  items: CropStatus.values,
                  itemLabel: _statusLabel,
                  onChanged: (CropStatus? value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _DateTile(
                  label: 'Planting date',
                  value: _plantingDate,
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _plantingDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _plantingDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _DateTile(
                  label: 'Expected harvest date',
                  value: _expectedHarvestDate,
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _expectedHarvestDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _expectedHarvestDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  value: _protectedEnvironment,
                  onChanged: (bool value) =>
                      setState(() => _protectedEnvironment = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Protected environment'),
                  subtitle: Text(
                    widget.farms
                            .firstWhere((Farm farm) => farm.id == _farmId)
                            .supportsGreenhouse
                        ? 'This farm supports greenhouse work. Keep this on for enclosed production.'
                        : 'Use this when the crop is being managed in protected conditions.',
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _notesController,
                  label: 'Notes',
                  hint: 'Irrigation adjusted after heat wave.',
                  maxLines: 3,
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
                        child: Text(isEditing ? 'Save changes' : 'Add crop'),
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

  _CropPlanningSummary _cropPlanningSummary() {
    final double enteredLand =
        double.tryParse(_landSizeController.text.trim()) ?? 0;
    final double areaHa = _landSizeUnit == LandSizeUnit.plots
        ? enteredLand * CropAdviceCatalog.plotToHa
        : enteredLand;
    final CropAdviceProfile? profile =
        CropAdviceCatalog.detect(_nameController.text);
    final int suggestedCycleDays =
        _suggestedCycleDays(profile, _stage, _protectedEnvironment);
    final int stageOffset = _stageOffsetDays(_stage);
    final int remainingDays = (suggestedCycleDays - stageOffset).clamp(0, 3650);
    final DateTime suggestedHarvestDate =
        _plantingDate.add(Duration(days: suggestedCycleDays));
    final double suggestedYield =
        _suggestedYieldKg(profile, areaHa, _stage, _protectedEnvironment);
    final String stageNote = switch (_stage) {
      CropStage.seeding =>
        'Cycle is at the start; keep moisture steady and confirm stand establishment.',
      CropStage.germination =>
        'Stand establishment is underway, so the app shortens the remaining window slightly.',
      CropStage.vegetative =>
        'Vegetative growth is active; nutrition and weed control protect the cycle now.',
      CropStage.flowering =>
        'Flowering means the crop is entering a yield-critical window and harvest prep should start earlier.',
      CropStage.fruiting =>
        'Fruiting suggests the crop is close to harvest, so the remaining window is short.',
    };

    final Crop tempCrop = Crop(
      id: widget.initialCrop?.id ?? 'preview',
      farmId: _farmId,
      name: _nameController.text.trim().isEmpty
          ? 'Crop'
          : _nameController.text.trim(),
      variety: _varietyController.text.trim().isEmpty
          ? 'Variety'
          : _varietyController.text.trim(),
      areaHa: areaHa,
      plantingDate: _plantingDate,
      expectedHarvestDate: suggestedHarvestDate,
      currentStage: _stage,
      status: _status,
      totalInputCost: double.tryParse(_costController.text.trim()) ?? 0,
      cycleLengthDays: suggestedCycleDays,
      notes: _notesController.text.trim(),
      createdAt: widget.initialCrop?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      isSynced: false,
      landSizeValue: enteredLand,
      landSizeUnit: _landSizeUnit,
      targetYieldKg: suggestedYield,
      protectedEnvironment: _protectedEnvironment,
    );
    final CropAdviceSummary advice = CropAdviceCatalog.summarize(tempCrop);

    return _CropPlanningSummary(
      profileName: advice.profile.name,
      seedRequirementLabel: advice.seedRequirementLabel,
      fertiliserSummary: advice.fertiliserSummary,
      otherInputs: advice.otherInputs,
      cycleDays: suggestedCycleDays,
      remainingDays: remainingDays,
      suggestedHarvestDate: suggestedHarvestDate,
      suggestedYieldKg: suggestedYield,
      stageNote: stageNote,
      referenceNote: advice.referenceNote,
      matchConfidence: advice.matchConfidence,
      areaLabel: tempCrop.landSizeLabel,
      reminders: advice.reminders.length,
    );
  }

  void _applyCropSuggestions() {
    final _CropPlanningSummary summary = _cropPlanningSummary();
    setState(() {
      _cycleController.text = summary.cycleDays.toString();
      _targetYieldController.text = summary.suggestedYieldKg.toStringAsFixed(0);
      _expectedHarvestDate = summary.suggestedHarvestDate;
    });
  }

  int _suggestedCycleDays(
    CropAdviceProfile? profile,
    CropStage stage,
    bool protectedEnvironment,
  ) {
    final String key = profile?.name.toLowerCase().trim() ?? '';
    final Map<String, int> baseCycleDays = <String, int>{
      'maize': 110,
      'rice': 120,
      'sorghum': 110,
      'millet': 90,
      'wheat': 125,
      'cassava': 360,
      'yam': 270,
      'sweet potato': 120,
      'potato': 100,
      'bean': 70,
      'cowpea': 75,
      'groundnut': 110,
      'soybean': 100,
      'tomato': 110,
      'pepper': 150,
      'onion': 150,
      'okra': 65,
      'cabbage': 90,
    };
    final int base = baseCycleDays[key] ?? 90;
    final int protectedBonus = protectedEnvironment ? -7 : 0;
    return (base + protectedBonus).clamp(45, 540);
  }

  int _stageOffsetDays(CropStage stage) {
    switch (stage) {
      case CropStage.seeding:
        return 0;
      case CropStage.germination:
        return 10;
      case CropStage.vegetative:
        return 25;
      case CropStage.flowering:
        return 45;
      case CropStage.fruiting:
        return 60;
    }
  }

  double _suggestedYieldKg(
    CropAdviceProfile? profile,
    double areaHa,
    CropStage stage,
    bool protectedEnvironment,
  ) {
    final String key = profile?.name.toLowerCase().trim() ?? '';
    final Map<String, double> yieldPerHa = <String, double>{
      'maize': 4200,
      'rice': 5200,
      'sorghum': 2600,
      'millet': 1800,
      'wheat': 3500,
      'cassava': 24000,
      'yam': 12000,
      'sweet potato': 15000,
      'potato': 17000,
      'bean': 1200,
      'cowpea': 1000,
      'groundnut': 1700,
      'soybean': 2400,
      'tomato': 22000,
      'pepper': 13000,
      'onion': 20000,
      'okra': 8500,
      'cabbage': 28000,
    };
    final double base = yieldPerHa[key] ?? 2500;
    final double stageFactor = switch (stage) {
      CropStage.seeding => 1.0,
      CropStage.germination => 0.98,
      CropStage.vegetative => 1.0,
      CropStage.flowering => 0.96,
      CropStage.fruiting => 0.92,
    };
    final double environmentFactor = protectedEnvironment ? 1.1 : 1.0;
    return areaHa * base * stageFactor * environmentFactor;
  }

  void _submit() {
    final String? nameError =
        Validators.required(_nameController.text, fieldName: 'Crop name');
    final String? varietyError =
        Validators.required(_varietyController.text, fieldName: 'Variety');
    final String? areaError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Land size'),
        Validators.cropArea,
      ],
      _landSizeController.text,
    );
    final String? costError = Validators.combine(
      <String? Function(String?)>[
        (String? value) =>
            Validators.required(value, fieldName: 'Total input cost'),
        Validators.amount,
      ],
      _costController.text,
    );
    final String? cycleError =
        Validators.required(_cycleController.text, fieldName: 'Cycle length');

    if (nameError != null) {
      context.showSnackBar(nameError, isError: true);
      return;
    }
    if (varietyError != null) {
      context.showSnackBar(varietyError, isError: true);
      return;
    }
    if (areaError != null) {
      context.showSnackBar(areaError, isError: true);
      return;
    }
    if (costError != null) {
      context.showSnackBar(costError, isError: true);
      return;
    }
    if (cycleError != null) {
      context.showSnackBar(cycleError, isError: true);
      return;
    }
    if (_expectedHarvestDate.isBefore(_plantingDate)) {
      context.showSnackBar('Expected harvest date must be after planting date',
          isError: true);
      return;
    }
    final int? cycleLengthDays = int.tryParse(_cycleController.text.trim());
    if (cycleLengthDays == null || cycleLengthDays <= 0) {
      context.showSnackBar('Cycle length must be a valid number of days',
          isError: true);
      return;
    }

    Navigator.of(context).pop(
      CropDraft(
        farmId: _farmId,
        name: _nameController.text.trim(),
        variety: _varietyController.text.trim(),
        areaHa: _landSizeUnit == LandSizeUnit.plots
            ? double.parse(_landSizeController.text.trim()) *
                CropAdviceCatalog.plotToHa
            : double.parse(_landSizeController.text.trim()),
        landSizeValue: double.parse(_landSizeController.text.trim()),
        landSizeUnit: _landSizeUnit,
        plantingDate: _plantingDate,
        expectedHarvestDate: _expectedHarvestDate,
        currentStage: _stage,
        status: _status,
        totalInputCost: double.parse(_costController.text.trim()),
        cycleLengthDays: cycleLengthDays,
        targetYieldKg: double.tryParse(_targetYieldController.text.trim()) ?? 0,
        protectedEnvironment: _protectedEnvironment,
        notes: _notesController.text.trim(),
      ),
    );
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

  String _statusLabel(CropStatus status) {
    switch (status) {
      case CropStatus.planted:
        return 'Planted';
      case CropStatus.growing:
        return 'Growing';
      case CropStatus.ready:
        return 'Ready';
      case CropStatus.harvested:
        return 'Harvested';
    }
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color iconBackground = isDark
        ? Color.alphaBlend(color.withOpacity(0.22), theme.colorScheme.surface)
        : color;
    final Color iconForeground =
        isDark ? theme.colorScheme.onSurface : const Color(0xFF44624E);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color:
                        isDark ? color.withOpacity(0.42) : Colors.transparent),
              ),
              child: Icon(Icons.spa_rounded, color: iconForeground),
            ),
            const Spacer(),
            Text(value, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  const _CropCard({
    required this.crop,
    required this.farmName,
    required this.advice,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onAddTask,
    required this.onAddInput,
    required this.onToggleTask,
  });

  final Crop crop;
  final String farmName;
  final CropAdviceSummary? advice;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddTask;
  final VoidCallback onAddInput;
  final ValueChanged<FarmTodoItem> onToggleTask;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int daysToHarvest =
        crop.expectedHarvestDate.difference(DateTime.now()).inDays;

    return AppCard(
      onTap: onOpen,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 92,
              child: FarmSceneArtwork(
                height: 92,
                variant: FarmArtworkVariant.crops,
                borderRadius: BorderRadius.all(Radius.circular(22)),
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
                        child: Text(crop.name,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontSize: 24)),
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
                          onDelete();
                        },
                        itemBuilder: (BuildContext context) =>
                            const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                              value: 'edit', child: Text('Edit crop')),
                          PopupMenuItem<String>(
                              value: 'task', child: Text('Add todo/reminder')),
                          PopupMenuItem<String>(
                              value: 'input',
                              child: Text('Record input stock')),
                          PopupMenuItem<String>(
                              value: 'delete', child: Text('Delete crop')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${crop.variety} variety linked to $farmName.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MiniTag(
                          text: _stageTag(crop.currentStage),
                          color: const Color(0xFFE8F4D8)),
                      _MiniTag(
                          text: crop.landSizeLabel,
                          color: const Color(0xFFDFF1FF)),
                      _MiniTag(
                        text: '${(crop.growthProgress * 100).round()}% cycle',
                        color: const Color(0xFFDCEEFF),
                      ),
                      _MiniTag(
                        text: CurrencyUtils.formatCurrency(crop.totalInputCost),
                        color: const Color(0xFFFFEBD0),
                      ),
                      _MiniTag(text: farmName, color: const Color(0xFFEDE8FF)),
                      _MiniTag(
                          text: '${crop.openTaskCount} open tasks',
                          color: const Color(0xFFFFF2C7)),
                      _MiniTag(
                          text: '${crop.inputRecords.length} input records',
                          color: const Color(0xFFDDF0E4)),
                      if (crop.targetYieldKg > 0)
                        _MiniTag(
                            text:
                                '${crop.targetYieldKg.toStringAsFixed(0)} kg target',
                            color: const Color(0xFFFFF2C7)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SmartRecordStrip(
                    title: crop.intelligenceNotes.isEmpty
                        ? _cropIntelligenceSummary(crop.name, crop.currentStage,
                            crop.expectedHarvestDate,
                            landSizeText: crop.landSizeLabel)
                        : crop.intelligenceNotes,
                    tasks: crop.todoItems,
                    inputs: crop.inputRecords,
                    advice: advice,
                    onAddTask: onAddTask,
                    onAddInput: onAddInput,
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

  String _stageTag(CropStage stage) {
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
}

class _SmartRecordStrip extends StatelessWidget {
  const _SmartRecordStrip({
    required this.title,
    required this.tasks,
    required this.inputs,
    required this.advice,
    required this.onAddTask,
    required this.onAddInput,
    required this.onToggleTask,
  });

  final String title;
  final List<FarmTodoItem> tasks;
  final List<FarmInputRecord> inputs;
  final CropAdviceSummary? advice;
  final VoidCallback onAddTask;
  final VoidCallback onAddInput;
  final ValueChanged<FarmTodoItem> onToggleTask;

  @override
  Widget build(BuildContext context) {
    final Iterable<FarmTodoItem> openTasks =
        tasks.where((FarmTodoItem item) => !item.isCompleted).take(2);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.45)),
          if (advice != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Seed need: ${advice!.seedRequirementLabel} | ${advice!.fertiliserSummary}',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ],
          const SizedBox(height: 10),
          if (openTasks.isEmpty)
            Text(
                'No open crop reminders. Add irrigation, scouting, harvest, or input tasks.',
                style: Theme.of(context).textTheme.bodySmall)
          else
            ...openTasks.map(
              (FarmTodoItem task) => CheckboxListTile(
                value: task.isCompleted,
                onChanged: (_) => onToggleTask(task),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(task.title),
                subtitle: Text(task.dailyReminder
                    ? 'Daily reminder enabled'
                    : _dateLabel(task.dueDate)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddTask,
                  icon:
                      const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Todo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddInput,
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text(
                      inputs.isEmpty ? 'Input' : '${inputs.length} inputs'),
                ),
              ),
            ],
          ),
        ],
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

class _CropPlanningSummary {
  const _CropPlanningSummary({
    required this.profileName,
    required this.seedRequirementLabel,
    required this.fertiliserSummary,
    required this.otherInputs,
    required this.cycleDays,
    required this.remainingDays,
    required this.suggestedHarvestDate,
    required this.suggestedYieldKg,
    required this.stageNote,
    required this.referenceNote,
    required this.matchConfidence,
    required this.areaLabel,
    required this.reminders,
  });

  final String profileName;
  final String seedRequirementLabel;
  final String fertiliserSummary;
  final List<String> otherInputs;
  final int cycleDays;
  final int remainingDays;
  final DateTime suggestedHarvestDate;
  final double suggestedYieldKg;
  final String stageNote;
  final String referenceNote;
  final double matchConfidence;
  final String areaLabel;
  final int reminders;
}

class _CropPlanningCard extends StatelessWidget {
  const _CropPlanningCard({
    required this.summary,
    required this.onApply,
  });

  final _CropPlanningSummary summary;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const Color tint = Color(0xFFE8F4D8);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark
                            ? tint.withOpacity(0.42)
                            : Colors.transparent),
                  ),
                  child: Icon(Icons.insights_rounded, color: iconForeground),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Planning estimate',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.profileName,
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
                _MiniTag(
                    text: '${summary.cycleDays} day cycle',
                    color: const Color(0xFFE8F4D8)),
                _MiniTag(
                    text: '${summary.remainingDays} days left',
                    color: const Color(0xFFDFF1FF)),
                _MiniTag(
                    text:
                        '${summary.suggestedYieldKg.toStringAsFixed(0)} kg target',
                    color: const Color(0xFFFFEBD0)),
                _MiniTag(
                    text: summary.areaLabel, color: const Color(0xFFEDE8FF)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Formula: planting date + cycle length = expected harvest date.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Suggested harvest date: ${MaterialLocalizations.of(context).formatFullDate(summary.suggestedHarvestDate)}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Seed need: ${summary.seedRequirementLabel}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Fertiliser: ${summary.fertiliserSummary}',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              summary.stageNote,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Reminder plan: ${summary.reminders} checkpoints built from the selected crop profile.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              summary.referenceNote,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.onTap,
    required this.icon,
  });

  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color iconBackground = isDark
        ? Color.alphaBlend(color.withOpacity(0.22), theme.colorScheme.surface)
        : color;
    final Color iconForeground =
        isDark ? theme.colorScheme.onSurface : const Color(0xFF44624E);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color:
                        isDark ? color.withOpacity(0.42) : Colors.transparent),
              ),
              child: Icon(icon, color: iconForeground),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
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
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
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
              variant: FarmArtworkVariant.crops,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton.primary(
              onPressed: onPressed,
              child: Text(buttonLabel),
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = isDark
        ? Color.alphaBlend(color.withOpacity(0.22), theme.colorScheme.surface)
        : color;
    final Color foreground =
        isDark ? theme.colorScheme.onSurface : const Color(0xFF284231);

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
    _titleController =
        TextEditingController(text: 'Check ${widget.entityName}');
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
      title: 'Todo and reminder',
      subtitle:
          'Create a daily action that can be used by sync and notification planning.',
      children: <Widget>[
        AppTextField(
            controller: _titleController,
            label: 'Task title',
            hint: 'Scout for pests'),
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
          subtitle:
              const Text('Shows this action as a repeating farm reminder.'),
        ),
        SwitchListTile(
          value: _pushEnabled,
          onChanged: (bool value) => setState(() => _pushEnabled = value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Push notification ready'),
          subtitle: const Text('Marks this task for notification scheduling.'),
        ),
        AppTextField(
            controller: _notesController,
            label: 'Notes',
            hint: 'What should be checked?',
            maxLines: 3),
        const SizedBox(height: 18),
        AppButton.primary(
            onPressed: _submit, child: const Text('Save reminder')),
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
  FarmInputCategory _category = FarmInputCategory.fertiliser;
  DateTime _recordedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _unitController = TextEditingController(text: 'bag');
    _unitCostController = TextEditingController(text: '0');
    _supplierController = TextEditingController();
    _notesController =
        TextEditingController(text: 'Used for ${widget.entityName}');
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
      title: 'Input stock record',
      subtitle:
          'Track seeds, fertiliser, labour, or supplies and sync the cost to finance.',
      children: <Widget>[
        AppTextField(
            controller: _nameController,
            label: 'Input name',
            hint: 'NPK fertiliser'),
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
            Expanded(
                child: AppTextField(
                    controller: _quantityController,
                    label: 'Quantity',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 10),
            Expanded(
                child: AppTextField(
                    controller: _unitController, label: 'Unit', hint: 'bag')),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
            controller: _unitCostController,
            label: 'Unit cost',
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 12),
        AppTextField(
            controller: _supplierController,
            label: 'Supplier/provider',
            hint: 'Agro dealer'),
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
        AppButton.primary(
            onPressed: _submit, child: const Text('Save and sync finance')),
      ],
    );
  }

  void _submit() {
    final String name = _nameController.text.trim();
    final double quantity =
        double.tryParse(_quantityController.text.trim()) ?? 0;
    final double unitCost =
        double.tryParse(_unitCostController.text.trim()) ?? 0;
    if (name.isEmpty || quantity <= 0 || _unitController.text.trim().isEmpty) {
      context.showSnackBar('Input name, quantity, and unit are required',
          isError: true);
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

String _cropIntelligenceSummary(
  String name,
  CropStage stage,
  DateTime harvestDate, {
  String landSizeText = '',
}) {
  final int days = harvestDate.difference(DateTime.now()).inDays;
  final String stageLabel = switch (stage) {
    CropStage.seeding => 'protect seedlings from heat and birds',
    CropStage.germination => 'check germination gaps and soil moisture',
    CropStage.vegetative => 'prioritise weeding, nutrition, and irrigation',
    CropStage.flowering => 'avoid moisture stress during flowering',
    CropStage.fruiting => 'watch harvest quality, pests, and market timing',
  };
  final String areaSnippet =
      landSizeText.isEmpty ? '' : ' Current land size is $landSizeText.';
  return '$name intelligence: $stageLabel.$areaSnippet ${days >= 0 ? 'Harvest window in $days days.' : 'Harvest is due; update sale or storage records.'}';
}

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
    case FarmInputCategory.fertiliser:
    case FarmInputCategory.seed:
      return TransactionCategory.fertiliser;
    case FarmInputCategory.feed:
      return TransactionCategory.feed;
    case FarmInputCategory.veterinary:
      return TransactionCategory.veterinary;
    case FarmInputCategory.labour:
      return TransactionCategory.labour;
    case FarmInputCategory.equipment:
    case FarmInputCategory.other:
      return TransactionCategory.other;
  }
}

String _dateLabel(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';

class CropDraft {
  const CropDraft({
    required this.farmId,
    required this.name,
    required this.variety,
    required this.areaHa,
    required this.landSizeValue,
    required this.landSizeUnit,
    required this.plantingDate,
    required this.expectedHarvestDate,
    required this.currentStage,
    required this.status,
    required this.totalInputCost,
    required this.cycleLengthDays,
    required this.targetYieldKg,
    required this.protectedEnvironment,
    required this.notes,
  });

  final String farmId;
  final String name;
  final String variety;
  final double areaHa;
  final double landSizeValue;
  final LandSizeUnit landSizeUnit;
  final DateTime plantingDate;
  final DateTime expectedHarvestDate;
  final CropStage currentStage;
  final CropStatus status;
  final double totalInputCost;
  final int cycleLengthDays;
  final double targetYieldKg;
  final bool protectedEnvironment;
  final String notes;

  String get landSizeLabel => landSizeUnit == LandSizeUnit.plots
      ? '${landSizeValue.toStringAsFixed(1)} plots'
      : '${landSizeValue.toStringAsFixed(2)} ha';
}
