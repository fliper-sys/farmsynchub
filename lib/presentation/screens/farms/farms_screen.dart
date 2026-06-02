import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../core/utils/validators.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/livestock.dart';
import '../../../domain/models/transaction.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';
import 'farm_detail_screen.dart';

class FarmsScreen extends ConsumerWidget {
  const FarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final currentUser = ref.watch(firebaseServiceProvider).currentUser;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final AsyncValue<List<Farm>> farmsAsync = ref.watch(farmsProvider);
    final List<Farm> farms = farmsAsync.maybeWhen(
      data: (List<Farm> items) => items,
      orElse: () => <Farm>[],
    );
    final List<Farm> visibleFarms = _visibleFarms(
      farms,
      currentUser: currentUser,
      profile: profile,
    );
    final Set<String> visibleFarmIds = visibleFarms.map((Farm farm) => farm.id).toSet();
    final List<Crop> crops = ref.watch(cropsProvider).maybeWhen(
      data: (List<Crop> items) => items.where((Crop item) => visibleFarmIds.contains(item.farmId)).toList(growable: false),
      orElse: () => <Crop>[],
    );
    final List<Livestock> livestock = ref.watch(livestockProvider).maybeWhen(
      data: (List<Livestock> items) =>
          items.where((Livestock item) => visibleFarmIds.contains(item.farmId)).toList(growable: false),
      orElse: () => <Livestock>[],
    );
    final List<Transaction> transactions = ref.watch(transactionsProvider).maybeWhen(
      data: (List<Transaction> items) =>
          items.where((Transaction item) => visibleFarmIds.contains(item.farmId)).toList(growable: false),
      orElse: () => <Transaction>[],
    );

    final double totalHectares = visibleFarms.fold(0, (double sum, Farm farm) => sum + farm.sizeHa);
    final int pendingSync = visibleFarms.where((Farm farm) => !farm.isSynced).length;
    final double inventoryValue = livestock.fold(
          0.0,
          (double sum, Livestock item) => sum + item.estimatedValue,
        ) +
        crops.fold<double>(0.0, (double sum, Crop item) => sum + item.totalInputCost);
    final double totalOperatingCost = transactions
        .where((Transaction item) => item.type == TransactionType.expense)
        .fold<double>(0.0, (double sum, Transaction item) => sum + item.amount);

    return SoftScreenScaffold(
      heroTitle: 'Farm operations',
      heroSubtitle: 'Create farm records, update land profiles, and keep crop, livestock, and finance activity linked to the right place.',
      heroIcon: Icons.agriculture_rounded,
      heroVariant: FarmArtworkVariant.field,
      heroBadge: '${visibleFarms.length} managed farms',
      trailing: _HeroActionButton(
        icon: Icons.add_rounded,
        onTap: () => _openFarmSheet(context, ref),
      ),
      sections: <Widget>[
        if (farmsAsync.hasError) ...<Widget>[
          const _InlineNotice(
            message: 'Could not load farms right now. Please try again.',
            color: Color(0xFFFFEBD3),
            icon: Icons.error_outline_rounded,
          ),
          const SizedBox(height: 18),
        ],
        const SoftSectionTitle(title: 'Structure overview'),
        Row(
          children: <Widget>[
            Expanded(
              child: SoftInfoChip(
                label: 'Managed land',
                value: '${totalHectares.toStringAsFixed(1)} ha',
                color: const Color(0xFFE5F5D8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: 'Inventory value',
                value: CurrencyUtils.formatCompactCurrency(inventoryValue),
                color: const Color(0xFFDFF1FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: 'Pending sync',
                value: '$pendingSync',
                color: const Color(0xFFFFEBD2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(
          title: 'Farm management board',
          action: TextButton.icon(
            onPressed: () => _openFarmSheet(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add farm'),
          ),
        ),
        if (farmsAsync.isLoading && visibleFarms.isEmpty)
          const _FarmLoadingCard()
        else if (visibleFarms.isEmpty)
          _EmptyFarmState(
            onCreate: () => _openFarmSheet(context, ref),
          )
        else
          ...visibleFarms.map(
            (Farm farm) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _FarmManagementCard(
                farm: farm,
                crops: crops.where((Crop crop) => crop.farmId == farm.id).toList(),
                livestock: livestock.where((Livestock animal) => animal.farmId == farm.id).toList(),
                transactions: transactions.where((Transaction item) => item.farmId == farm.id).toList(),
                onOpen: () async {
                  await ref.read(activeFarmProvider.notifier).setActiveFarm(farm.id);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FarmDetailScreen(farmId: farm.id),
                      ),
                    );
                  }
                },
                onEdit: () => _openFarmSheet(context, ref, farm: farm),
                onDelete: () => _confirmDelete(context, ref, farm),
              ),
            ),
          ),
        const SizedBox(height: 18),
        const SoftSectionTitle(title: 'Farm processes'),
        const Row(
          children: <Widget>[
            Expanded(
              child: _ProcessCard(
                title: 'Land preparation',
                detail: 'Bed shaping, soil checks, and water access planning.',
                status: 'Active',
                color: Color(0xFFE9F4DB),
                icon: Icons.construction_rounded,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ProcessCard(
                title: 'Planting cycle',
                detail: 'Seed scheduling, spacing, and expected harvest windows.',
                status: 'Tracked',
                color: Color(0xFFDFF1FF),
                icon: Icons.event_note_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: <Widget>[
            Expanded(
              child: _ProcessCard(
                title: 'Input management',
                detail: 'Fertiliser, feed, tools, and usage planning.',
                status: 'Monitored',
                color: Color(0xFFFFEBD0),
                icon: Icons.inventory_2_rounded,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ProcessCard(
                title: 'Harvest and sales',
                detail: 'Output records, market timing, and delivery notes.',
                status: 'Ready',
                color: Color(0xFFE8F0D9),
                icon: Icons.local_shipping_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SoftSectionTitle(title: 'Documentation support'),
        AppCard(
          color: scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                _DocumentationRow(
                  title: 'Field notes',
                  subtitle: 'Daily observations, irrigation changes, and crop issues.',
                  trailing: '${crops.length} linked entries',
                  icon: Icons.sticky_note_2_rounded,
                  color: const Color(0xFFDFF1FF),
                ),
                const SizedBox(height: 12),
                _DocumentationRow(
                  title: 'Input logs',
                  subtitle: 'Track feed, fertiliser, labour, and tool usage by farm.',
                  trailing: CurrencyUtils.formatCompactCurrency(totalOperatingCost),
                  icon: Icons.playlist_add_check_circle_rounded,
                  color: const Color(0xFFE9F4DB),
                ),
                const SizedBox(height: 12),
                _DocumentationRow(
                  title: 'Compliance records',
                  subtitle: 'Farmer category, water source, and farm condition snapshots.',
                  trailing: '${visibleFarms.length} profiles',
                  icon: Icons.verified_user_rounded,
                  color: const Color(0xFFFFEBD0),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SoftSectionTitle(title: 'Inventory and management'),
        Row(
          children: <Widget>[
            Expanded(
              child: _InventoryPanel(
                title: 'Crop inventory',
                count: '${crops.length} active records',
                detail: '${crops.where((Crop crop) => crop.status == CropStatus.ready).length} ready for harvest',
                color: const Color(0xFFE7F4D8),
                icon: Icons.spa_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InventoryPanel(
                title: 'Livestock inventory',
                count: '${livestock.fold(0, (int sum, Livestock item) => sum + item.count)} animals',
                detail: '${livestock.length} managed groups',
                color: const Color(0xFFDDEEFF),
                icon: Icons.pets_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          color: scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Use this workspace to create farm profiles first, then connect crops, livestock, and records to the correct farm.',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton.primary(
                    onPressed: () => _openFarmSheet(context, ref),
                    child: const Text('Add new farm'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openFarmSheet(
    BuildContext context,
    WidgetRef ref, {
    Farm? farm,
  }) async {
    final FarmDraft? draft = await showModalBottomSheet<FarmDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _FarmFormSheet(initialFarm: farm),
    );

    if (draft == null) {
      return;
    }

    final FarmsNotifier notifier = ref.read(farmsProvider.notifier);
    final DateTime now = DateTime.now();
    final currentUser = ref.read(firebaseServiceProvider).currentUser;
    final Farm nextFarm = Farm(
      id: farm?.id ?? const Uuid().v4(),
      name: draft.name,
      ward: draft.ward,
      sizeHa: draft.sizeHa,
      farmType: draft.farmType,
      farmerCategory: draft.farmerCategory,
      soilType: draft.soilType,
      waterSource: draft.waterSource,
      createdAt: farm?.createdAt ?? now,
      updatedAt: now,
      isSynced: farm?.isSynced ?? false,
      ownerUid: farm?.ownerUid ?? currentUser?.uid ?? '',
      ownerEmail: farm?.ownerEmail ?? currentUser?.email ?? '',
      ownerName: farm?.ownerName ?? currentUser?.displayName ?? '',
      coverImageBase64: farm?.coverImageBase64 ?? '',
      notes: farm?.notes ?? '',
      temperatureCelsius: farm?.temperatureCelsius ?? 24,
      humidityPercent: farm?.humidityPercent ?? 60,
      soilMoisturePercent: farm?.soilMoisturePercent ?? 52,
      precipitationMm: farm?.precipitationMm ?? 6,
      greenhouseCount: draft.greenhouseCount,
      greenhouseAreaHa: draft.greenhouseAreaHa,
      cropCapacityHa: draft.cropCapacityHa,
      livestockCapacity: draft.livestockCapacity,
      documents: farm?.documents ?? const <FarmDocumentRecord>[],
    );

    try {
      if (farm == null) {
        await notifier.addFarm(nextFarm);
        if (context.mounted) {
          context.showSnackBar('Farm created successfully');
        }
      } else {
        await notifier.updateFarm(nextFarm);
        if (context.mounted) {
          context.showSnackBar('Farm updated successfully');
        }
      }
    } catch (error) {
      if (context.mounted) {
        context.showSnackBar(_friendlyErrorMessage(error), isError: true);
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Farm farm,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete farm'),
          content: Text('Remove "${farm.name}" from your farm records?'),
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
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(farmsProvider.notifier).deleteFarm(farm.id);
      if (context.mounted) {
        context.showSnackBar('Farm deleted');
      }
    } catch (error) {
      if (context.mounted) {
        context.showSnackBar(_friendlyErrorMessage(error), isError: true);
      }
    }
  }

  String _friendlyErrorMessage(Object error) {
    final String message = error.toString();
    if (message.contains('User not authenticated')) {
      return 'Farm saved on this device, but cloud sync needs a signed-in account.';
    }
    return 'Could not save farm changes right now. Please try again.';
  }
}

class _FarmManagementCard extends StatelessWidget {
  const _FarmManagementCard({
    required this.farm,
    required this.crops,
    required this.livestock,
    required this.transactions,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Farm farm;
  final List<Crop> crops;
  final List<Livestock> livestock;
  final List<Transaction> transactions;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double income = transactions
        .where((Transaction item) => item.type == TransactionType.income)
        .fold(0, (double sum, Transaction item) => sum + item.amount);
    final double expenses = transactions
        .where((Transaction item) => item.type == TransactionType.expense)
        .fold(0, (double sum, Transaction item) => sum + item.amount);

    return AppCard(
      onTap: onOpen,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              FarmSceneArtwork(
                height: 170,
                variant: crops.isEmpty ? FarmArtworkVariant.field : FarmArtworkVariant.crops,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: PopupMenuButton<String>(
                  color: theme.colorScheme.surface,
                  onSelected: (String value) {
                    if (value == 'edit') {
                      onEdit();
                      return;
                    }
                    onDelete();
                  },
                  itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit farm'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete farm'),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: const Icon(Icons.more_horiz_rounded),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        farm.name,
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 28),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: farm.isSynced ? const Color(0xFFE9F4DB) : const Color(0xFFFFEBD0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(farm.isSynced ? 'Synced' : 'Pending'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${farm.ward} ward | ${_farmTypeLabel(farm.farmType)} | ${farm.sizeHa.toStringAsFixed(1)} ha',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _MiniTag(text: _categoryLabel(farm.farmerCategory), color: const Color(0xFFEAF0DE)),
                    _MiniTag(text: _soilLabel(farm.soilType), color: const Color(0xFFFFEBD0)),
                    _MiniTag(text: _waterLabel(farm.waterSource), color: const Color(0xFFDFF1FF)),
                    if (farm.supportsCrops) _MiniTag(text: '${crops.length} crop records', color: const Color(0xFFE8F4D8)),
                    if (farm.supportsLivestock)
                      _MiniTag(
                        text: '${livestock.fold(0, (int sum, Livestock item) => sum + item.count)} livestock',
                        color: const Color(0xFFEAF0DE),
                      ),
                    if (farm.supportsGreenhouse)
                      _MiniTag(
                        text: '${farm.greenhouseCount} greenhouse${farm.greenhouseCount == 1 ? '' : 's'}',
                        color: const Color(0xFFEDE8FF),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _FarmStatTile(
                        label: 'Documentation',
                        value: '${crops.length + livestock.length + farm.documents.length} entries',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FarmStatTile(
                        label: 'Income',
                        value: CurrencyUtils.formatCompactCurrency(income),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FarmStatTile(
                        label: 'Climate',
                        value: '${farm.temperatureCelsius.toStringAsFixed(0)} C',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.fact_check_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Last farm update ${app_date.DateUtils.formatDate(farm.updatedAt)}. Keep structure, notes, inventory, and processes refreshed from this space.',
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _soilLabel(SoilType soilType) {
    switch (soilType) {
      case SoilType.clay:
        return 'Clay soil';
      case SoilType.sandy:
        return 'Sandy soil';
      case SoilType.loamy:
        return 'Loamy soil';
      case SoilType.silt:
        return 'Silt soil';
    }
  }

  String _waterLabel(WaterSource waterSource) {
    switch (waterSource) {
      case WaterSource.rainfall:
        return 'Rainfall';
      case WaterSource.borehole:
        return 'Borehole';
      case WaterSource.river:
        return 'River';
      case WaterSource.dam:
        return 'Dam';
      case WaterSource.irrigation:
        return 'Irrigation';
    }
  }

  String _categoryLabel(FarmerCategory category) {
    switch (category) {
      case FarmerCategory.subsistence:
        return 'Subsistence';
      case FarmerCategory.semiCommercial:
        return 'Semi-commercial';
      case FarmerCategory.marketOriented:
        return 'Market-oriented';
    }
  }

  String _farmTypeLabel(FarmType type) {
    switch (type) {
      case FarmType.crop:
        return 'Crop farm';
      case FarmType.livestock:
        return 'Livestock farm';
      case FarmType.greenhouse:
        return 'Greenhouse farm';
      case FarmType.combined:
        return 'Combined farm';
    }
  }
}

class _FarmFormSheet extends StatefulWidget {
  const _FarmFormSheet({
    this.initialFarm,
  });

  final Farm? initialFarm;

  @override
  State<_FarmFormSheet> createState() => _FarmFormSheetState();
}

class _FarmFormSheetState extends State<_FarmFormSheet> {
  late final VoidCallback _formListener;
  late final TextEditingController _nameController;
  late final TextEditingController _wardController;
  late final TextEditingController _sizeController;
  late final TextEditingController _cropCapacityController;
  late final TextEditingController _livestockCapacityController;
  late final TextEditingController _greenhouseCountController;
  late final TextEditingController _greenhouseAreaController;

  late FarmType _farmType;
  late FarmerCategory _farmerCategory;
  late SoilType _soilType;
  late WaterSource _waterSource;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final Farm? farm = widget.initialFarm;
    _nameController = TextEditingController(text: farm?.name ?? '');
    _wardController = TextEditingController(text: farm?.ward ?? '');
    _sizeController = TextEditingController(
      text: farm == null ? '' : farm.sizeHa.toStringAsFixed(1),
    );
    _cropCapacityController = TextEditingController(
      text: farm == null ? '' : farm.cropCapacityHa.toStringAsFixed(1),
    );
    _livestockCapacityController = TextEditingController(
      text: farm?.livestockCapacity.toString() ?? '',
    );
    _greenhouseCountController = TextEditingController(
      text: farm?.greenhouseCount.toString() ?? '',
    );
    _greenhouseAreaController = TextEditingController(
      text: farm == null ? '' : farm.greenhouseAreaHa.toStringAsFixed(1),
    );
    _farmType = farm?.farmType ?? FarmType.combined;
    _farmerCategory = farm?.farmerCategory ?? FarmerCategory.subsistence;
    _soilType = farm?.soilType ?? SoilType.loamy;
    _waterSource = farm?.waterSource ?? WaterSource.rainfall;
    _formListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _nameController.addListener(_formListener);
    _wardController.addListener(_formListener);
    _sizeController.addListener(_formListener);
    _cropCapacityController.addListener(_formListener);
    _livestockCapacityController.addListener(_formListener);
    _greenhouseCountController.addListener(_formListener);
    _greenhouseAreaController.addListener(_formListener);
  }

  @override
  void dispose() {
    _nameController.removeListener(_formListener);
    _wardController.removeListener(_formListener);
    _sizeController.removeListener(_formListener);
    _cropCapacityController.removeListener(_formListener);
    _livestockCapacityController.removeListener(_formListener);
    _greenhouseCountController.removeListener(_formListener);
    _greenhouseAreaController.removeListener(_formListener);
    _nameController.dispose();
    _wardController.dispose();
    _sizeController.dispose();
    _cropCapacityController.dispose();
    _livestockCapacityController.dispose();
    _greenhouseCountController.dispose();
    _greenhouseAreaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initialFarm != null;

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
                  isEditing ? 'Edit farm' : 'Create farm',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  isEditing
                      ? 'Update the core details for this farm profile.'
                      : 'Add a new farm so crops, animals, and records can be linked correctly.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _nameController,
                  label: 'Farm name',
                  hint: 'Pisang King Farms',
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _wardController,
                  label: 'Ward',
                  hint: 'Vwang',
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _sizeController,
                  label: 'Farm size (ha)',
                  hint: '1.2',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                _DropdownField<FarmType>(
                  label: 'Farm type',
                  value: _farmType,
                  items: FarmType.values,
                  itemLabel: _farmTypeLabel,
                  onChanged: (FarmType? value) {
                    if (value != null) {
                      setState(() => _farmType = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _DropdownField<FarmerCategory>(
                  label: 'Farmer category',
                  value: _farmerCategory,
                  items: FarmerCategory.values,
                  itemLabel: _farmerCategoryLabel,
                  onChanged: (FarmerCategory? value) {
                    if (value != null) {
                      setState(() => _farmerCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _DropdownField<SoilType>(
                  label: 'Soil type',
                  value: _soilType,
                  items: SoilType.values,
                  itemLabel: _soilTypeLabel,
                  onChanged: (SoilType? value) {
                    if (value != null) {
                      setState(() => _soilType = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _DropdownField<WaterSource>(
                  label: 'Water source',
                  value: _waterSource,
                  items: WaterSource.values,
                  itemLabel: _waterSourceLabel,
                  onChanged: (WaterSource? value) {
                    if (value != null) {
                      setState(() => _waterSource = value);
                    }
                  },
                ),
                if (_farmType == FarmType.crop || _farmType == FarmType.combined || _farmType == FarmType.greenhouse) ...<Widget>[
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _cropCapacityController,
                    label: 'Crop capacity (ha)',
                    hint: '0.8',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
                if (_farmType == FarmType.livestock || _farmType == FarmType.combined) ...<Widget>[
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _livestockCapacityController,
                    label: 'Livestock capacity',
                    hint: '120',
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (_farmType == FarmType.greenhouse || _farmType == FarmType.combined) ...<Widget>[
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppTextField(
                          controller: _greenhouseCountController,
                          label: 'Greenhouse units',
                          hint: '2',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _greenhouseAreaController,
                          label: 'Greenhouse area (ha)',
                          hint: '0.2',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                _FarmPlanningCard(summary: _farmPlanningSummary()),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton.secondary(
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton.primary(
                        onPressed: _isSaving ? null : _submit,
                        child: Text(isEditing ? 'Save changes' : 'Create farm'),
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

  _FarmPlanningSummary _farmPlanningSummary() {
    final double sizeHa = double.tryParse(_sizeController.text.trim()) ?? 0;
    final double cropCapacity = _suggestedCropCapacity(sizeHa, _farmType);
    final int livestockCapacity = _suggestedLivestockCapacity(sizeHa, _farmType);
    final double greenhouseArea = _suggestedGreenhouseArea(sizeHa, _farmType);
    final int greenhouseUnits = _suggestedGreenhouseUnits(sizeHa, _farmType);
    final String note = switch (_farmType) {
      FarmType.crop => 'Crop farms usually reserve most of the land for planting, then leave room for paths and water access.',
      FarmType.livestock => 'Livestock farms should keep capacity conservative so housing, hygiene, and feed handling stay manageable.',
      FarmType.greenhouse => 'Greenhouses work best when area is used intensively and the shelter plan stays compact.',
      FarmType.combined => 'Combined farms should split space between crops, stock, and movement corridors to keep the workflow calm.',
    };

    return _FarmPlanningSummary(
      cropCapacityHa: cropCapacity,
      livestockCapacity: livestockCapacity,
      greenhouseAreaHa: greenhouseArea,
      greenhouseUnits: greenhouseUnits,
      landUseNote: note,
      formulaNote: 'Formulas use farm size as the starting point, then adjust by the selected farm type.',
    );
  }

  double _suggestedCropCapacity(double sizeHa, FarmType farmType) {
    if (sizeHa <= 0) {
      return 0;
    }
    final double factor = switch (farmType) {
      FarmType.crop => 0.8,
      FarmType.livestock => 0.0,
      FarmType.greenhouse => 0.25,
      FarmType.combined => 0.55,
    };
    return sizeHa * factor;
  }

  int _suggestedLivestockCapacity(double sizeHa, FarmType farmType) {
    if (sizeHa <= 0) {
      return 0;
    }
    final double factor = switch (farmType) {
      FarmType.crop => 0.0,
      FarmType.livestock => 18,
      FarmType.greenhouse => 0.0,
      FarmType.combined => 10,
    };
    return (sizeHa * factor).round();
  }

  double _suggestedGreenhouseArea(double sizeHa, FarmType farmType) {
    if (sizeHa <= 0) {
      return 0;
    }
    final double factor = switch (farmType) {
      FarmType.crop => 0.0,
      FarmType.livestock => 0.0,
      FarmType.greenhouse => 0.18,
      FarmType.combined => 0.12,
    };
    return sizeHa * factor;
  }

  int _suggestedGreenhouseUnits(double sizeHa, FarmType farmType) {
    if (sizeHa <= 0) {
      return 0;
    }
    return switch (farmType) {
      FarmType.crop => 0,
      FarmType.livestock => 0,
      FarmType.greenhouse => math.max(1, (sizeHa / 0.2).floor()),
      FarmType.combined => math.max(1, (sizeHa / 0.35).floor()),
    };
  }

  void _submit() {
    final String? nameError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Farm name'),
        (String? value) => Validators.maxLength(value, 40, fieldName: 'Farm name'),
      ],
      _nameController.text,
    );
    final String? wardError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Ward'),
        (String? value) => Validators.maxLength(value, 30, fieldName: 'Ward'),
      ],
      _wardController.text,
    );
    final String? sizeError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Farm size'),
        Validators.farmSize,
      ],
      _sizeController.text,
    );

    if (nameError != null) {
      context.showSnackBar(nameError, isError: true);
      return;
    }
    if (wardError != null) {
      context.showSnackBar(wardError, isError: true);
      return;
    }
    if (sizeError != null) {
      context.showSnackBar(sizeError, isError: true);
      return;
    }

    final double? sizeHa = double.tryParse(_sizeController.text.trim());
    if (sizeHa == null) {
      context.showSnackBar('Farm size must be a valid number', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    Navigator.of(context).pop(
      FarmDraft(
        name: _nameController.text.trim(),
        ward: _wardController.text.trim(),
        sizeHa: sizeHa,
        farmType: _farmType,
        farmerCategory: _farmerCategory,
        soilType: _soilType,
        waterSource: _waterSource,
        cropCapacityHa: double.tryParse(_cropCapacityController.text.trim()) ?? 0,
        livestockCapacity: int.tryParse(_livestockCapacityController.text.trim()) ?? 0,
        greenhouseCount: int.tryParse(_greenhouseCountController.text.trim()) ?? 0,
        greenhouseAreaHa: double.tryParse(_greenhouseAreaController.text.trim()) ?? 0,
      ),
    );
  }

  String _farmTypeLabel(FarmType value) {
    switch (value) {
      case FarmType.crop:
        return 'Crop farm';
      case FarmType.livestock:
        return 'Livestock farm';
      case FarmType.greenhouse:
        return 'Greenhouse farm';
      case FarmType.combined:
        return 'Combined farm';
    }
  }

  String _farmerCategoryLabel(FarmerCategory value) {
    switch (value) {
      case FarmerCategory.subsistence:
        return 'Subsistence';
      case FarmerCategory.semiCommercial:
        return 'Semi-commercial';
      case FarmerCategory.marketOriented:
        return 'Market-oriented';
    }
  }

  String _soilTypeLabel(SoilType value) {
    switch (value) {
      case SoilType.clay:
        return 'Clay';
      case SoilType.sandy:
        return 'Sandy';
      case SoilType.loamy:
        return 'Loamy';
      case SoilType.silt:
        return 'Silt';
    }
  }

  String _waterSourceLabel(WaterSource value) {
    switch (value) {
      case WaterSource.rainfall:
        return 'Rainfall';
      case WaterSource.borehole:
        return 'Borehole';
      case WaterSource.river:
        return 'River';
      case WaterSource.dam:
        return 'Dam';
      case WaterSource.irrigation:
        return 'Irrigation';
    }
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

class _FarmPlanningSummary {
  const _FarmPlanningSummary({
    required this.cropCapacityHa,
    required this.livestockCapacity,
    required this.greenhouseAreaHa,
    required this.greenhouseUnits,
    required this.landUseNote,
    required this.formulaNote,
  });

  final double cropCapacityHa;
  final int livestockCapacity;
  final double greenhouseAreaHa;
  final int greenhouseUnits;
  final String landUseNote;
  final String formulaNote;
}

class _FarmPlanningCard extends StatelessWidget {
  const _FarmPlanningCard({
    required this.summary,
  });

  final _FarmPlanningSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    color: const Color(0xFFE8F4D8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.insights_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Farm planning estimate',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MiniTag(text: '${summary.cropCapacityHa.toStringAsFixed(1)} ha crop space', color: const Color(0xFFE8F4D8)),
                _MiniTag(text: '${summary.livestockCapacity} livestock units', color: const Color(0xFFDFF1FF)),
                _MiniTag(text: '${summary.greenhouseUnits} greenhouse unit${summary.greenhouseUnits == 1 ? '' : 's'}', color: const Color(0xFFFFEBD0)),
                _MiniTag(text: '${summary.greenhouseAreaHa.toStringAsFixed(1)} ha greenhouse area', color: const Color(0xFFEDE8FF)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Formula: farm size × type factor = planning estimate.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              summary.landUseNote,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              summary.formulaNote,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            if (summary.greenhouseUnits > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Greenhouse values are starter estimates only. Experienced growers can use tighter spacing, different media, or a custom irrigation layout and continue with their own plan.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _EmptyFarmState extends StatelessWidget {
  const _EmptyFarmState({
    required this.onCreate,
  });

  final VoidCallback onCreate;

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
            Text(
              'No farms added yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first farm profile to start linking crops, livestock, and financial activity.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton.primary(
              onPressed: onCreate,
              child: const Text('Create first farm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FarmLoadingCard extends StatelessWidget {
  const _FarmLoadingCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text('Loading farms and linked records...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _FarmStatTile extends StatelessWidget {
  const _FarmStatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({
    required this.title,
    required this.detail,
    required this.status,
    required this.color,
    required this.icon,
  });

  final String title;
  final String detail;
  final String status;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon),
            ),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(detail, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
            const SizedBox(height: 12),
            Text(status, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _DocumentationRow extends StatelessWidget {
  const _DocumentationRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(trailing, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({
    required this.title,
    required this.count,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String title;
  final String count;
  final String detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon),
            ),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(count, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(detail, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
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

List<Farm> _visibleFarms(
  List<Farm> farms, {
  required User? currentUser,
  required UserProfile? profile,
}) {
  if (currentUser == null) {
    return farms;
  }

  final List<Farm> accessibleFarms = farms
      .where(
        (Farm farm) =>
            farm.ownerUid == currentUser.uid ||
            farm.ownerEmail == currentUser.email ||
            farm.workspaceMembers.any(
              (FarmWorkspaceMember member) =>
                  member.email == currentUser.email ||
                  member.id == currentUser.uid ||
                  member.allowedFarmIds.contains(farm.id),
            ),
      )
      .toList(growable: false);

  if (accessibleFarms.isNotEmpty) {
    return accessibleFarms;
  }

  if (profile?.accountRole != null && profile!.accountRole != UserAccountRole.owner) {
    return <Farm>[];
  }

  return farms;
}

class FarmDraft {
  const FarmDraft({
    required this.name,
    required this.ward,
    required this.sizeHa,
    required this.farmType,
    required this.farmerCategory,
    required this.soilType,
    required this.waterSource,
    required this.cropCapacityHa,
    required this.livestockCapacity,
    required this.greenhouseCount,
    required this.greenhouseAreaHa,
  });

  final String name;
  final String ward;
  final double sizeHa;
  final FarmType farmType;
  final FarmerCategory farmerCategory;
  final SoilType soilType;
  final WaterSource waterSource;
  final double cropCapacityHa;
  final int livestockCapacity;
  final int greenhouseCount;
  final double greenhouseAreaHa;
}
