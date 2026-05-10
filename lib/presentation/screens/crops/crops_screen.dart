import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class CropsScreen extends ConsumerWidget {
  const CropsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
    final Map<String, Farm> farmById = <String, Farm>{
      for (final Farm farm in farms) farm.id: farm,
    };

    final int seedingCount = crops.where((Crop crop) => crop.currentStage == CropStage.seeding).length;
    final int growingCount = crops
        .where((Crop crop) => <CropStage>[
              CropStage.germination,
              CropStage.vegetative,
            ].contains(crop.currentStage))
        .length;
    final int floweringCount = crops.where((Crop crop) => crop.currentStage == CropStage.flowering).length;
    final int readyCount = crops.where((Crop crop) => crop.status == CropStatus.ready).length;

    return SoftScreenScaffold(
      heroTitle: 'Crop records',
      heroSubtitle: 'Link every crop to the right farm, track its stage, and keep planting plans tied to actual field records.',
      heroIcon: Icons.grass_rounded,
      heroVariant: FarmArtworkVariant.crops,
      heroBadge: '${crops.length} crop records',
      trailing: _HeroActionButton(
        onTap: farms.isEmpty ? null : () => _openCropSheet(context, ref, farms: farms),
        icon: Icons.add_circle_outline_rounded,
      ),
      sections: <Widget>[
        if (farms.isEmpty) ...<Widget>[
          _InlineNotice(
            icon: Icons.agriculture_rounded,
            color: const Color(0xFFFFEBD0),
            message: 'Create a farm first before adding crops so each record can be linked to a real field.',
          ),
          const SizedBox(height: 18),
        ],
        const SoftSectionTitle(title: 'Growth board'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          childAspectRatio: 1.05,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: <Widget>[
            _StageCard(label: 'Seeding', value: '$seedingCount crops', color: const Color(0xFFE8F4D8)),
            _StageCard(label: 'Growing', value: '$growingCount crops', color: const Color(0xFFDDF0E4)),
            _StageCard(label: 'Flowering', value: '$floweringCount crops', color: const Color(0xFFFFEBD0)),
            _StageCard(label: 'Ready', value: '$readyCount crops', color: const Color(0xFFDCEEFF)),
          ],
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(
          title: 'Current crops',
          action: TextButton.icon(
            onPressed: farms.isEmpty ? null : () => _openCropSheet(context, ref, farms: farms),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add crop'),
          ),
        ),
        if (cropsAsync.isLoading && crops.isEmpty)
          const _LoadingCard(message: 'Loading crop records...')
        else if (crops.isEmpty)
          _EmptyState(
            title: 'No crops linked yet',
            message: farms.isEmpty
                ? 'Create a farm first, then come back to add crop records.'
                : 'Add your first crop and assign it to a farm to begin tracking field progress.',
            buttonLabel: 'Add first crop',
            onPressed: farms.isEmpty ? null : () => _openCropSheet(context, ref, farms: farms),
          )
        else
          ...crops.map(
            (Crop crop) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CropCard(
                crop: crop,
                farmName: farmById[crop.farmId]?.name ?? 'Unknown farm',
                onEdit: () => _openCropSheet(context, ref, farms: farms, crop: crop),
                onDelete: () => _confirmDelete(context, ref, crop),
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
                        ? 'Farm records unlock crop linking. Create one farm to begin planting plans.'
                        : 'Review linked crop records by farm and keep planting dates, stages, and input costs updated.',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppButton.secondary(
                    onPressed: farms.isEmpty ? null : () => _openCropSheet(context, ref, farms: farms),
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
      notes: draft.notes,
      createdAt: crop?.createdAt ?? now,
      updatedAt: now,
      isSynced: crop?.isSynced ?? false,
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Crop crop) async {
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
  late final TextEditingController _areaController;
  late final TextEditingController _costController;
  late final TextEditingController _notesController;

  late String _farmId;
  late CropStage _stage;
  late CropStatus _status;
  late DateTime _plantingDate;
  late DateTime _expectedHarvestDate;

  @override
  void initState() {
    super.initState();
    final Crop? crop = widget.initialCrop;
    _nameController = TextEditingController(text: crop?.name ?? '');
    _varietyController = TextEditingController(text: crop?.variety ?? '');
    _areaController = TextEditingController(text: crop == null ? '' : crop.areaHa.toStringAsFixed(1));
    _costController = TextEditingController(text: crop == null ? '' : crop.totalInputCost.toStringAsFixed(0));
    _notesController = TextEditingController(text: crop?.notes ?? '');
    _farmId = crop?.farmId ?? widget.farms.first.id;
    _stage = crop?.currentStage ?? CropStage.seeding;
    _status = crop?.status ?? CropStatus.planted;
    _plantingDate = crop?.plantingDate ?? DateTime.now();
    _expectedHarvestDate = crop?.expectedHarvestDate ?? DateTime.now().add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _varietyController.dispose();
    _areaController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initialCrop != null;

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
                  isEditing ? 'Edit crop record' : 'Add crop record',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Link this crop to a specific farm so its records show up in the right field workspace.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
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
                  controller: _areaController,
                  label: 'Area planted (ha)',
                  hint: '0.3',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _costController,
                  label: 'Total input cost',
                  hint: '78000',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

  void _submit() {
    final String? nameError = Validators.required(_nameController.text, fieldName: 'Crop name');
    final String? varietyError = Validators.required(_varietyController.text, fieldName: 'Variety');
    final String? areaError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Area'),
        Validators.cropArea,
      ],
      _areaController.text,
    );
    final String? costError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Total input cost'),
        Validators.amount,
      ],
      _costController.text,
    );

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
    if (_expectedHarvestDate.isBefore(_plantingDate)) {
      context.showSnackBar('Expected harvest date must be after planting date', isError: true);
      return;
    }

    Navigator.of(context).pop(
      CropDraft(
        farmId: _farmId,
        name: _nameController.text.trim(),
        variety: _varietyController.text.trim(),
        areaHa: double.parse(_areaController.text.trim()),
        plantingDate: _plantingDate,
        expectedHarvestDate: _expectedHarvestDate,
        currentStage: _stage,
        status: _status,
        totalInputCost: double.parse(_costController.text.trim()),
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

    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.spa_rounded),
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
    required this.onEdit,
    required this.onDelete,
  });

  final Crop crop;
  final String farmName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int daysToHarvest = crop.expectedHarvestDate.difference(DateTime.now()).inDays;

    return AppCard(
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
                        child: Text(crop.name, style: theme.textTheme.titleLarge?.copyWith(fontSize: 24)),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (String value) {
                          if (value == 'edit') {
                            onEdit();
                            return;
                          }
                          onDelete();
                        },
                        itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(value: 'edit', child: Text('Edit crop')),
                          PopupMenuItem<String>(value: 'delete', child: Text('Delete crop')),
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
                      _MiniTag(text: _stageTag(crop.currentStage), color: const Color(0xFFE8F4D8)),
                      _MiniTag(
                        text: daysToHarvest >= 0 ? 'Harvest in $daysToHarvest days' : 'Harvest due',
                        color: const Color(0xFFDCEEFF),
                      ),
                      _MiniTag(
                        text: CurrencyUtils.formatCurrency(crop.totalInputCost),
                        color: const Color(0xFFFFEBD0),
                      ),
                      _MiniTag(text: farmName, color: const Color(0xFFEDE8FF)),
                    ],
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
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

class CropDraft {
  const CropDraft({
    required this.farmId,
    required this.name,
    required this.variety,
    required this.areaHa,
    required this.plantingDate,
    required this.expectedHarvestDate,
    required this.currentStage,
    required this.status,
    required this.totalInputCost,
    required this.notes,
  });

  final String farmId;
  final String name;
  final String variety;
  final double areaHa;
  final DateTime plantingDate;
  final DateTime expectedHarvestDate;
  final CropStage currentStage;
  final CropStatus status;
  final double totalInputCost;
  final String notes;
}
