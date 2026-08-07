import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/livestock.dart';
import '../../../domain/models/photo_journal_entry.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/livestock_provider.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Displays a photo journal for a crop or livestock, showing
/// base64 photos in a chronological grid with dates and captions.
class PhotoJournalWidget extends ConsumerStatefulWidget {
  const PhotoJournalWidget({
    super.key,
    this.crop,
    this.livestock,
  });

  final Crop? crop;
  final Livestock? livestock;

  @override
  ConsumerState<PhotoJournalWidget> createState() => _PhotoJournalWidgetState();
}

class _PhotoJournalWidgetState extends ConsumerState<PhotoJournalWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isAddingPhoto = false;

  /// Collect all photo entries from the crop or livestock journal, newest first.
  List<PhotoJournalEntry> _collectPhotos() {
    final List<PhotoJournalEntry> entries = <PhotoJournalEntry>[
      ...?widget.crop?.photoJournal,
      ...?widget.livestock?.photoJournal,
    ];
    entries.sort(
        (PhotoJournalEntry a, PhotoJournalEntry b) => b.date.compareTo(a.date));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<PhotoJournalEntry> photos = _collectPhotos();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.photo_library_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              'Photo Journal',
              style: theme.textTheme.titleLarge,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _isAddingPhoto ? null : _addPhoto,
              icon: _isAddingPhoto
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.add_a_photo_rounded, size: 18),
              label:
                  Text(_isAddingPhoto ? 'Adding...' : 'Add photo'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          photos.isEmpty
              ? 'No photos yet. Add photos to track visual progress.'
              : '${photos.length} photo${photos.length == 1 ? '' : 's'} recorded',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        if (photos.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.photo_camera_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.crop != null
                        ? 'Add photos to document your ${widget.crop!.name} growth journey.'
                        : 'Add photos to document your livestock visual records.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  AppButton.secondary(
                    onPressed: _addPhoto,
                    child: const Text('Take a photo'),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: photos.length,
            itemBuilder: (BuildContext context, int index) {
              final PhotoJournalEntry entry = photos[index];
              return _PhotoTile(
                entry: entry,
                onTap: () => _viewPhoto(context, entry),
              );
            },
          ),
      ],
    );
  }

  Future<void> _addPhoto() async {
    setState(() => _isAddingPhoto = true);

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (file == null) {
        if (mounted) setState(() => _isAddingPhoto = false);
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      final String base64 = base64Encode(bytes);
      final DateTime now = DateTime.now();
      final PhotoJournalEntry entry = PhotoJournalEntry(
        id: const Uuid().v4(),
        base64: base64,
        date: now,
        caption: widget.crop != null
            ? '${widget.crop!.name} photo update'
            : '${_livestockLabel(widget.livestock!.species)} photo update',
      );

      if (widget.crop != null) {
        await ref.read(cropsProvider.notifier).updateCrop(
              widget.crop!.copyWith(
                photoJournal: <PhotoJournalEntry>[
                  entry,
                  ...widget.crop!.photoJournal,
                ],
                updatedAt: now,
                isSynced: false,
              ),
            );
      } else if (widget.livestock != null) {
        await ref.read(livestockProvider.notifier).updateLivestock(
              widget.livestock!.copyWith(
                photoJournal: <PhotoJournalEntry>[
                  entry,
                  ...widget.livestock!.photoJournal,
                ],
                updatedAt: now,
                isSynced: false,
              ),
            );
      }

      if (mounted) {
        context.showSnackBar('Photo added to journal!');
        setState(() => _isAddingPhoto = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAddingPhoto = false);
        context.showSnackBar('Failed to add photo: $e');
      }
    }
  }

  void _viewPhoto(BuildContext context, PhotoJournalEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(
                base64Decode(entry.base64),
                fit: BoxFit.contain,
                errorBuilder: (BuildContext context, Object error,
                        StackTrace? stackTrace) =>
                    Container(
                  height: 300,
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: Colors.white54),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.caption,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.date.day}/${entry.date.month}/${entry.date.year}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _livestockLabel(LivestockSpecies species) {
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
      case LivestockSpecies.rabbit:
        return 'Rabbits';
      case LivestockSpecies.duck:
        return 'Ducks';
      case LivestockSpecies.fish:
        return 'Fish';
      case LivestockSpecies.snail:
        return 'Snails';
    }
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.entry,
    required this.onTap,
  });

  final PhotoJournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Image.memory(
                base64Decode(entry.base64),
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stackTrace) =>
                        Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 24,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${entry.date.day}/${entry.date.month}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

