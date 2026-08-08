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

const List<String> _kMonthNames = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatShortDate(DateTime date) => '${date.day} ${_kMonthNames[date.month - 1]}';

String _formatFullDate(DateTime date) {
  final String hh = date.hour.toString().padLeft(2, '0');
  final String mm = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_kMonthNames[date.month - 1]} ${date.year} · $hh:$mm';
}

/// Displays a photo journal for a crop or livestock, showing base64 photos
/// in a chronological grid with dates and captions. Photos can be marked
/// as favorites, filtered to favorites-only, and opened in a full-screen
/// sliding carousel viewer.
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
  bool _favoritesOnly = false;

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
    final List<PhotoJournalEntry> allPhotos = _collectPhotos();
    final int favoriteCount =
        allPhotos.where((PhotoJournalEntry p) => p.isFavorite).length;
    final List<PhotoJournalEntry> visiblePhotos = _favoritesOnly
        ? allPhotos.where((PhotoJournalEntry p) => p.isFavorite).toList()
        : allPhotos;

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
          allPhotos.isEmpty
              ? 'No photos yet. Add photos to track visual progress.'
              : '${allPhotos.length} photo${allPhotos.length == 1 ? '' : 's'} recorded',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (allPhotos.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              ChoiceChip(
                label: Text('All (${allPhotos.length})'),
                selected: !_favoritesOnly,
                onSelected: (_) => setState(() => _favoritesOnly = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const Icon(Icons.favorite_rounded, size: 16),
                label: Text('Favorites ($favoriteCount)'),
                selected: _favoritesOnly,
                onSelected: favoriteCount == 0
                    ? null
                    : (_) => setState(() => _favoritesOnly = true),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),

        if (visiblePhotos.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  Icon(
                    _favoritesOnly
                        ? Icons.favorite_border_rounded
                        : Icons.photo_camera_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _favoritesOnly
                        ? 'No favorites yet. Tap the heart on a photo to save it here.'
                        : widget.crop != null
                            ? 'Add photos to document your ${widget.crop!.name} growth journey.'
                            : 'Add photos to document your livestock visual records.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  if (!_favoritesOnly) ...<Widget>[
                    const SizedBox(height: 16),
                    AppButton.secondary(
                      onPressed: _addPhoto,
                      child: const Text('Take a photo'),
                    ),
                  ],
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
            itemCount: visiblePhotos.length,
            itemBuilder: (BuildContext context, int index) {
              final PhotoJournalEntry entry = visiblePhotos[index];
              return _PhotoTile(
                entry: entry,
                onTap: () => _viewPhoto(context, visiblePhotos, index),
                onToggleFavorite: () => _toggleFavorite(entry),
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

  Future<void> _toggleFavorite(PhotoJournalEntry entry) async {
    final DateTime now = DateTime.now();
    final PhotoJournalEntry updated =
        entry.copyWith(isFavorite: !entry.isFavorite);

    if (widget.crop != null) {
      await ref.read(cropsProvider.notifier).updateCrop(
            widget.crop!.copyWith(
              photoJournal: widget.crop!.photoJournal
                  .map((PhotoJournalEntry item) =>
                      item.id == entry.id ? updated : item)
                  .toList(),
              updatedAt: now,
              isSynced: false,
            ),
          );
    } else if (widget.livestock != null) {
      await ref.read(livestockProvider.notifier).updateLivestock(
            widget.livestock!.copyWith(
              photoJournal: widget.livestock!.photoJournal
                  .map((PhotoJournalEntry item) =>
                      item.id == entry.id ? updated : item)
                  .toList(),
              updatedAt: now,
              isSynced: false,
            ),
          );
    }
  }

  void _viewPhoto(
      BuildContext context, List<PhotoJournalEntry> photos, int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (BuildContext context, __, ___) => _PhotoViewerScreen(
          photos: photos,
          initialIndex: index,
          onToggleFavorite: _toggleFavorite,
        ),
        transitionsBuilder: (BuildContext context, Animation<double> animation,
                __, Widget child) =>
            FadeTransition(opacity: animation, child: child),
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
    required this.onToggleFavorite,
  });

  final PhotoJournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

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
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.memory(
                    base64Decode(entry.base64),
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object error,
                            StackTrace? stackTrace) =>
                        Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 24,
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onToggleFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          entry.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 14,
                          color: entry.isFavorite ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _formatShortDate(entry.date),
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

/// Full-screen photo viewer using Material 3's [CarouselView] to slide
/// between every visible journal photo with a native carousel animation.
class _PhotoViewerScreen extends StatefulWidget {
  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
    required this.onToggleFavorite,
  });

  final List<PhotoJournalEntry> photos;
  final int initialIndex;
  final Future<void> Function(PhotoJournalEntry entry) onToggleFavorite;

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final CarouselController _controller;
  late int _currentIndex;
  late List<PhotoJournalEntry> _photos;
  double? _itemExtent;

  @override
  void initState() {
    super.initState();
    _photos = widget.photos;
    _currentIndex = widget.initialIndex;
    _controller = CarouselController(initialItem: widget.initialIndex);
    _controller.addListener(_handleScroll);
  }

  void _handleScroll() {
    final double? extent = _itemExtent;
    if (extent == null || extent <= 0 || !_controller.hasClients) return;
    final int newIndex =
        (_controller.offset / extent).round().clamp(0, _photos.length - 1);
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleCurrentFavorite() async {
    final PhotoJournalEntry current = _photos[_currentIndex];
    await widget.onToggleFavorite(current);
    setState(() {
      _photos[_currentIndex] = current.copyWith(isFavorite: !current.isFavorite);
    });
  }

  @override
  Widget build(BuildContext context) {
    final PhotoJournalEntry current = _photos[_currentIndex];
    final double width = MediaQuery.sizeOf(context).width;
    _itemExtent = width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentIndex + 1} / ${_photos.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      current.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: current.isFavorite ? Colors.redAccent : Colors.white,
                    ),
                    onPressed: _toggleCurrentFavorite,
                  ),
                ],
              ),
            ),
            Expanded(
              child: CarouselView(
                controller: _controller,
                itemExtent: width,
                shrinkExtent: width * 0.94,
                itemSnapping: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                enableSplash: false,
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final PhotoJournalEntry entry in _photos)
                    InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.memory(
                        base64Decode(entry.base64),
                        fit: BoxFit.contain,
                        errorBuilder: (BuildContext context, Object error,
                                StackTrace? stackTrace) =>
                            const Center(
                          child: Icon(Icons.broken_image_rounded,
                              size: 48, color: Colors.white54),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: <Widget>[
                  if (current.caption.isNotEmpty)
                    Text(
                      current.caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatFullDate(current.date),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
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
