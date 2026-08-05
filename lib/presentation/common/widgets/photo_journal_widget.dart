import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/livestock.dart';
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

  /// Collect all photo entries from the crop or livestock records.
  List<_PhotoEntry> _collectPhotos() {
    final List<_PhotoEntry> entries = <_PhotoEntry>[];

    if (widget.crop != null) {
      // From crop profile image
      if (widget.crop!.profileImageBase64.isNotEmpty) {
        entries.add(_PhotoEntry(
          id: '${widget.crop!.id}_profile',
          base64: widget.crop!.profileImageBase64,
          date: widget.crop!.updatedAt,
          caption: '${widget.crop!.name} profile',
        ));
      }

      // From crop input records (if there are any associated photos)
      // From crop intelligence notes - check if it contains photo references
      // For MVP, we treat recent entries in intelligence notes as photo references
    }

    if (widget.livestock != null) {
      // From livestock profile/cover images
      if (widget.livestock!.profileImageBase64.isNotEmpty) {
        entries.add(_PhotoEntry(
          id: '${widget.livestock!.id}_profile',
          base64: widget.livestock!.profileImageBase64,
          date: widget.livestock!.updatedAt,
          caption:
              '${_livestockLabel(widget.livestock!.species)} profile photo',
        ));
      }
      if (widget.livestock!.coverImageBase64.isNotEmpty &&
          widget.livestock!.coverImageBase64 !=
              widget.livestock!.profileImageBase64) {
        entries.add(_PhotoEntry(
          id: '${widget.livestock!.id}_cover',
          base64: widget.livestock!.coverImageBase64,
          date: widget.livestock!.updatedAt,
          caption:
              '${_livestockLabel(widget.livestock!.species)} cover image',
        ));
      }
    }

    // Sort by date descending (newest first)
    entries.sort((_PhotoEntry a, _PhotoEntry b) => b.date.compareTo(a.date));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_PhotoEntry> photos = _collectPhotos();

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
              final _PhotoEntry entry = photos[index];
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

      if (widget.crop != null) {
        // Save photo as a note in crop intelligence
        await ref.read(cropsProvider.notifier).updateCrop(
              widget.crop!.copyWith(
                profileImageBase64: widget.crop!.profileImageBase64.isEmpty
                    ? base64
                    : widget.crop!.profileImageBase64,
                intelligenceNotes:
                    '[${DateTime.now().day}/${DateTime.now().month}] 📸 Photo added\n${widget.crop!.intelligenceNotes}',
                updatedAt: DateTime.now(),
                isSynced: false,
              ),
            );
      } else if (widget.livestock != null) {
        // Save photo to livestock profile or cover
        await ref.read(livestockProvider.notifier).updateLivestock(
              widget.livestock!.copyWith(
                coverImageBase64: widget.livestock!.coverImageBase64.isEmpty
                    ? base64
                    : widget.livestock!.coverImageBase64,
                stockNotes:
                    '[${DateTime.now().day}/${DateTime.now().month}] 📸 Photo added\n${widget.livestock!.stockNotes}',
                updatedAt: DateTime.now(),
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

  void _viewPhoto(BuildContext context, _PhotoEntry entry) {
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
    }
  }
}

class _PhotoEntry {
  const _PhotoEntry({
    required this.id,
    required this.base64,
    required this.date,
    required this.caption,
  });

  final String id;
  final String base64;
  final DateTime date;
  final String caption;
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.entry,
    required this.onTap,
  });

  final _PhotoEntry entry;
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

