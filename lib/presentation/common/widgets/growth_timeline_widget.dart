import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/growth_timeline_entry.dart';
import '../../../providers/crop_provider.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_text_field.dart';
import 'loading_shimmer.dart';

/// Displays a visual growth timeline for a crop with stage markers,
/// photos, height/leaf measurements, and notes.
class GrowthTimelineWidget extends ConsumerWidget {
  const GrowthTimelineWidget({
    super.key,
    required this.crop,
  });

  final Crop crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    // In a full implementation, timeline entries would be fetched from provider.
    // For now, we use the crop's intelligence notes and input records as backdrop.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.timeline_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              'Growth Timeline',
              style: theme.textTheme.titleLarge,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openAddEntrySheet(context, ref, crop),
              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
              label: const Text('Add entry'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Stage cards — visual timeline of growth stages
        ..._buildStageCards(context, theme, crop),
        const SizedBox(height: 12),
        // Quick-guide note
        AppCard(
          color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Icon(Icons.photo_camera_rounded,
                    size: 20, color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add weekly photos and measurements to track your ${crop.name}\'s growth visually across stages.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStageCards(
      BuildContext context, ThemeData theme, Crop crop) {
    final List<CropStage> stages = CropStage.values;
    final int currentIndex = stages.indexOf(crop.currentStage);

    return stages.asMap().entries.map((MapEntry<int, CropStage> entry) {
      final int index = entry.key;
      final CropStage stage = entry.value;
      final bool isPast = index < currentIndex;
      final bool isCurrent = index == currentIndex;
      final bool isFuture = index > currentIndex;

      final Color dotColor = isCurrent
          ? theme.colorScheme.primary
          : isPast
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.outlineVariant;

      final Color cardColor = isCurrent
          ? theme.colorScheme.primaryContainer.withOpacity(0.4)
          : theme.colorScheme.surfaceContainerHighest;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Column(
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(
                            color: theme.colorScheme.onPrimary, width: 2.5)
                        : null,
                  ),
                ),
                if (index < stages.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: isFuture
                        ? theme.colorScheme.outlineVariant
                        : theme.colorScheme.primary.withOpacity(0.3),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppCard(
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            _stageLabel(stage),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight:
                                  isCurrent ? FontWeight.w800 : FontWeight.w600,
                              color: isFuture
                                  ? theme.colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                          const Spacer(),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Current',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (isPast)
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: Colors.green),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stageAdvice(stage),
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: crop.growthProgress,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(crop.growthProgress * 100).round()}% through cycle',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList(growable: false);
  }

  Future<void> _openAddEntrySheet(
      BuildContext context, WidgetRef ref, Crop crop) async {
    final GrowthTimelineEntry? entry = await showModalBottomSheet<
        GrowthTimelineEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _GrowthTimelineFormSheet(crop: crop),
    );

    if (entry == null || !context.mounted) return;

    // Add entry to crop's timeline — for MVP we append to intelligence notes
    // In production, this would be saved to the Crop model's growthTimeline list
    final String note = 'Day ${crop.daysSincePlanting}: ${entry.notes.isEmpty ? _stageLabel(entry.stage) : entry.notes}'
        '${entry.heightCm > 0 ? ' | Height: ${entry.heightCm.toStringAsFixed(1)} cm' : ''}'
        '${entry.leafCount > 0 ? ' | Leaves: ${entry.leafCount}' : ''}';

    await ref.read(cropsProvider.notifier).updateCrop(
          crop.copyWith(
            intelligenceNotes:
                '[${DateTime.now().day}/${DateTime.now().month}] $note\n${crop.intelligenceNotes}',
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );

    if (context.mounted) {
      context.showSnackBar('Growth entry recorded!');
    }
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
}

/// Bottom sheet form to add a growth timeline entry with photo and measurements.
class _GrowthTimelineFormSheet extends StatefulWidget {
  const _GrowthTimelineFormSheet({required this.crop});

  final Crop crop;

  @override
  State<_GrowthTimelineFormSheet> createState() =>
      _GrowthTimelineFormSheetState();
}

class _GrowthTimelineFormSheetState extends State<_GrowthTimelineFormSheet> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _leafCountController = TextEditingController();
  String _photoBase64 = '';
  CropStage _stage = CropStage.seeding;

  @override
  void initState() {
    super.initState();
    _stage = widget.crop.currentStage;
    _heightController.text =
        widget.crop.inputRecords.isEmpty
            ? '0'
            : '${(widget.crop.inputRecords.length * 2.5).toStringAsFixed(1)}';
  }

  @override
  void dispose() {
    _notesController.dispose();
    _heightController.dispose();
    _leafCountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? file =
        await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBase64 = base64Encode(bytes));
  }

  Future<void> _takePhoto() async {
    final XFile? file =
        await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBase64 = base64Encode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  'Add growth entry',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Record photo, height, and leaf count for your ${widget.crop.name}.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                // Photo section
                Row(
                  children: <Widget>[
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: _photoBase64.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.memory(
                                  base64Decode(_photoBase64),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.add_a_photo_rounded, size: 30),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          AppButton.secondary(
                            onPressed: _pickImage,
                            child: const Text('Gallery'),
                          ),
                          const SizedBox(height: 8),
                          AppButton.secondary(
                            onPressed: _takePhoto,
                            child: const Text('Camera'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Stage dropdown
                DropdownButtonFormField<CropStage>(
                  value: _stage,
                  decoration: const InputDecoration(
                    labelText: 'Current stage',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  items: CropStage.values
                      .map((CropStage s) => DropdownMenuItem<CropStage>(
                            value: s,
                            child: Text(_stageLabel(s)),
                          ))
                      .toList(),
                  onChanged: (CropStage? value) {
                    if (value != null) setState(() => _stage = value);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _heightController,
                        label: 'Height (cm)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _leafCountController,
                        label: 'Leaf count',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _notesController,
                  label: 'Notes',
                  hint: 'Good growth, no pest signs...',
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
                      flex: 2,
                      child: AppButton.primary(
                        onPressed: _submit,
                        child: const Text('Save entry'),
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
    final double heightCm = double.tryParse(_heightController.text.trim()) ?? 0;
    final int leafCount = int.tryParse(_leafCountController.text.trim()) ?? 0;

    Navigator.of(context).pop(
      GrowthTimelineEntry(
        id: const Uuid().v4(),
        cropId: widget.crop.id,
        stage: _stage,
        recordedAt: DateTime.now(),
        photoBase64: _photoBase64,
        notes: _notesController.text.trim(),
        heightCm: heightCm,
        leafCount: leafCount,
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
}
