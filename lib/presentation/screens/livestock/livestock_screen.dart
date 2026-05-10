import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

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

    final int animalCount = livestock.fold(0, (int sum, Livestock item) => sum + item.count);
    final int vaccinatedAverage = livestock.isEmpty
        ? 0
        : (livestock.fold(0, (int sum, Livestock item) => sum + item.vaccinationStatus) / livestock.length).round();
    final int healthAverage = livestock.isEmpty
        ? 0
        : (livestock.fold(0, (int sum, Livestock item) => sum + item.healthScore) / livestock.length).round();

    return SoftScreenScaffold(
      heroTitle: 'Livestock care',
      heroSubtitle: 'Assign each herd or flock to a specific farm so housing, welfare, and value records stay in the right place.',
      heroIcon: Icons.pets_rounded,
      heroVariant: FarmArtworkVariant.field,
      heroBadge: '${livestock.length} linked groups',
      trailing: IconButton(
        onPressed: farms.isEmpty ? null : () => _openLivestockSheet(context, ref, farms: farms),
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
      sections: <Widget>[
        if (farms.isEmpty) ...<Widget>[
          _InlineNotice(
            label: 'Farm link required',
            message: 'Create a farm first before adding livestock groups so each record belongs to a real farm.',
            tint: const Color(0xFFFFE9D0),
          ),
          const SizedBox(height: 18),
        ],
        const SoftSectionTitle(title: 'Herd health'),
        Row(
          children: <Widget>[
            Expanded(
              child: SoftInfoChip(
                label: 'Animals',
                value: '$animalCount',
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
        const SizedBox(height: 18),
        SoftSectionTitle(
          title: 'Groups',
          action: TextButton.icon(
            onPressed: farms.isEmpty ? null : () => _openLivestockSheet(context, ref, farms: farms),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add group'),
          ),
        ),
        if (livestockAsync.isLoading && livestock.isEmpty)
          const _LoadingCard(message: 'Loading livestock records...')
        else if (livestock.isEmpty)
          _EmptyState(
            title: 'No livestock groups yet',
            message: farms.isEmpty
                ? 'Create a farm first, then come back to add livestock groups.'
                : 'Add your first livestock group and link it to a specific farm.',
            actionLabel: 'Add first group',
            onPressed: farms.isEmpty ? null : () => _openLivestockSheet(context, ref, farms: farms),
          )
        else
          ...livestock.map(
            (Livestock item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AnimalGroupCard(
                livestock: item,
                farmName: farmById[item.farmId]?.name ?? 'Unknown farm',
                onEdit: () => _openLivestockSheet(context, ref, farms: farms, livestock: item),
                onDelete: () => _confirmDelete(context, ref, item),
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
      createdAt: livestock?.createdAt ?? now,
      updatedAt: now,
      isSynced: livestock?.isSynced ?? false,
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
  late final TextEditingController _breedController;
  late final TextEditingController _countController;
  late final TextEditingController _maleCountController;
  late final TextEditingController _femaleCountController;
  late final TextEditingController _estimatedValueController;
  late final TextEditingController _vaccinationController;
  late final TextEditingController _healthScoreController;

  late String _farmId;
  late LivestockSpecies _species;
  late LivestockPurpose _purpose;
  late HousingType _housingType;
  late DateTime _acquisitionDate;

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
    _farmId = livestock?.farmId ?? widget.farms.first.id;
    _species = livestock?.species ?? LivestockSpecies.goat;
    _purpose = livestock?.purpose ?? LivestockPurpose.meat;
    _housingType = livestock?.housingLocation ?? HousingType.shed;
    _acquisitionDate = livestock?.acquisitionDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _breedController.dispose();
    _countController.dispose();
    _maleCountController.dispose();
    _femaleCountController.dispose();
    _estimatedValueController.dispose();
    _vaccinationController.dispose();
    _healthScoreController.dispose();
    super.dispose();
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

    if (maleCount + femaleCount > count) {
      context.showSnackBar('Male and female totals cannot exceed total count', isError: true);
      return;
    }
    if (vaccination < 0 || vaccination > 100 || healthScore < 0 || healthScore > 100) {
      context.showSnackBar('Vaccination and health scores must be between 0 and 100', isError: true);
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
}

class _AnimalGroupCard extends StatelessWidget {
  const _AnimalGroupCard({
    required this.livestock,
    required this.farmName,
    required this.onEdit,
    required this.onDelete,
  });

  final Livestock livestock;
  final String farmName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = _accentForSpecies(livestock.species);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.pets_rounded),
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
                          onDelete();
                        },
                        itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(value: 'edit', child: Text('Edit group')),
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MiniTag(text: farmName, color: const Color(0xFFDFF1FF)),
                      _MiniTag(text: '${livestock.vaccinationStatus}% vaccinated', color: const Color(0xFFE9F4DB)),
                      _MiniTag(text: CurrencyUtils.formatCurrency(livestock.estimatedValue), color: const Color(0xFFFFE9D0)),
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
}
