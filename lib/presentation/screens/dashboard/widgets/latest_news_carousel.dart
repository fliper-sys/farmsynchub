import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/news_post.dart';
import '../../../../providers/app_preferences_provider.dart';
import '../../../../providers/news_feed_provider.dart';

/// The newest posts worth showing on Home: public (or admin) posts only,
/// original posts before reposts, newest first, at most [limit].
///
/// Followers-only posts from other people are left out so Home never shows
/// something the General feed would hide.
List<NewsPost> latestNewsHighlights(List<NewsPost> posts, {int limit = 5}) {
  final List<NewsPost> visible = posts
      .where((NewsPost post) =>
          post.isAdminPost || post.visibility == NewsPostVisibility.public)
      .where((NewsPost post) => post.title.trim().isNotEmpty)
      .toList()
    ..sort((NewsPost a, NewsPost b) => b.createdAt.compareTo(a.createdAt));

  final List<NewsPost> originals =
      visible.where((NewsPost post) => !post.isRepost).toList();
  final List<NewsPost> reposts =
      visible.where((NewsPost post) => post.isRepost).toList();
  return <NewsPost>[...originals, ...reposts].take(limit).toList();
}

/// Sliding, animated cards for the five latest news updates.
///
/// Sits on Home under today's tasks. Swipe to browse; it also glides to the
/// next card every few seconds (paused while touched, and off entirely when
/// the device asks for reduced motion). Hides itself when there is no news.
class LatestNewsCarousel extends ConsumerStatefulWidget {
  /// Creates the carousel.
  const LatestNewsCarousel({super.key});

  @override
  ConsumerState<LatestNewsCarousel> createState() => _LatestNewsCarouselState();
}

class _LatestNewsCarouselState extends ConsumerState<LatestNewsCarousel> {
  static const Duration _autoAdvance = Duration(seconds: 5);
  static const double _cardHeight = 204;

  final PageController _controller = PageController(viewportFraction: 0.88);
  final Map<String, Uint8List?> _imageCache = <String, Uint8List?>{};
  Timer? _timer;
  int _page = 0;
  int _count = 0;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_reduceMotion) {
      return;
    }
    _timer = Timer.periodic(_autoAdvance, (Timer timer) {
      if (!mounted || _count < 2 || !_controller.hasClients) {
        return;
      }
      final int next = (_page + 1) % _count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Uint8List? _imageFor(NewsPost post) {
    if (!post.hasImage) {
      return null;
    }
    return _imageCache.putIfAbsent(post.id, () {
      try {
        return base64Decode(post.coverImageBase64);
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final NewsFeedState? feed = ref.watch(newsFeedProvider).valueOrNull;
    final List<NewsPost> posts =
        feed == null ? <NewsPost>[] : latestNewsHighlights(feed.posts);
    _count = posts.length;
    if (_page >= _count && _count > 0) {
      _page = 0;
    }

    if (feed == null || posts.isEmpty) {
      // Nothing to show yet (loading, offline with no cache, or no posts).
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                Icon(Icons.newspaper_rounded,
                    size: 20,
                    color: AppColors.primaryForeground(theme.brightness)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    language.tr(
                      en: 'Latest news',
                      ha: 'Sababbin labarai',
                      fr: 'Dernières actualités',
                    ),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/news'),
                  child: Text(
                    language.tr(en: 'See all', ha: 'Duba duka', fr: 'Voir tout'),
                  ),
                ),
              ],
            ),
          ),
          // Each page is 88% of the width, so the next card peeks in at the
          // edge, which tells people the row slides.
          SizedBox(
            height: _cardHeight,
            child: Listener(
              onPointerDown: (_) => _timer?.cancel(),
              onPointerUp: (_) => _restartTimer(),
              onPointerCancel: (_) => _restartTimer(),
              child: PageView.builder(
                controller: _controller,
                itemCount: posts.length,
                padEnds: false,
                onPageChanged: (int index) => setState(() => _page = index),
                itemBuilder: (BuildContext context, int index) {
                  final NewsPost post = posts[index];
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) {
                      final double current = _controller.hasClients &&
                              _controller.position.haveDimensions
                          ? (_controller.page ?? _page.toDouble())
                          : _page.toDouble();
                      final double offset =
                          (current - index).clamp(-1.0, 1.0).toDouble();
                      final double distance = offset.abs();
                      return Opacity(
                        opacity: 1 - 0.40 * distance,
                        child: Transform.scale(
                          scale: 1 - 0.06 * distance,
                          alignment: Alignment.center,
                          child: _NewsCard(
                            post: post,
                            image: _imageFor(post),
                            language: language,
                            parallax: offset,
                            onTap: () => context.go('/news'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PageDots(count: posts.length, active: _page),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.post,
    required this.image,
    required this.language,
    required this.parallax,
    required this.onTap,
  });

  final NewsPost post;
  final Uint8List? image;
  final AppLanguage language;

  /// -1..1: how far this card is from the centre, used to drift the photo
  /// slightly against the swipe for depth.
  final double parallax;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String snippet = post.body.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String category = post.category.trim();

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Semantics(
        button: true,
        label: '${post.title}. ${_timeAgo(post.createdAt, language)}',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                // Deep brand green: white text on it is always readable, in
                // light and dark mode, with or without a photo.
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF0E5A41), Color(0xFF0B3D2D)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF0B3D2D).withOpacity(0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (image != null)
                    Image.memory(
                      image!,
                      fit: BoxFit.cover,
                      alignment: Alignment(parallax * 0.6, 0),
                      gaplessPlayback: true,
                      errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                          const SizedBox.shrink(),
                    ),
                  // Darkens the bottom so the headline is readable on any photo.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withOpacity(image != null ? 0.10 : 0.0),
                          Colors.black.withOpacity(image != null ? 0.78 : 0.30),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            if (category.isNotEmpty)
                              _Pill(
                                label: category,
                                background: AppColors.primary,
                                foreground: AppColors.onPrimaryBrand,
                              ),
                            if (post.isAdminPost) ...<Widget>[
                              if (category.isNotEmpty) const SizedBox(width: 8),
                              _Pill(
                                label: language.tr(
                                    en: 'Official',
                                    ha: 'Na hukuma',
                                    fr: 'Officiel'),
                                background: Colors.white.withOpacity(0.22),
                                foreground: Colors.white,
                              ),
                            ],
                          ],
                        ),
                        const Spacer(),
                        Text(
                          post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1.2,
                          ),
                        ),
                        if (snippet.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.86),
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Icon(Icons.schedule_rounded,
                                size: 14, color: Colors.white.withOpacity(0.8)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${post.authorName.trim().isEmpty ? 'FarmSync' : post.authorName.trim()} · ${_timeAgo(post.createdAt, language)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 18, color: Colors.white),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

/// Dots under the carousel; the active one stretches into a pill.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color on = AppColors.primaryForeground(theme.brightness);
    final Color off = theme.colorScheme.outlineVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (int index) {
        final bool selected = index == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: selected ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: selected ? on : off,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

String _timeAgo(DateTime time, AppLanguage language) {
  final Duration diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) {
    return language.tr(en: 'Just now', ha: 'Yanzu', fr: "À l'instant");
  }
  if (diff.inMinutes < 60) {
    return language.tr(
      en: '${diff.inMinutes}m ago',
      ha: 'mintuna ${diff.inMinutes} da suka wuce',
      fr: 'il y a ${diff.inMinutes} min',
    );
  }
  if (diff.inHours < 24) {
    return language.tr(
      en: '${diff.inHours}h ago',
      ha: 'awa ${diff.inHours} da suka wuce',
      fr: 'il y a ${diff.inHours} h',
    );
  }
  if (diff.inDays < 7) {
    return language.tr(
      en: '${diff.inDays}d ago',
      ha: 'kwana ${diff.inDays} da suka wuce',
      fr: 'il y a ${diff.inDays} j',
    );
  }
  return DateFormat('d MMM').format(time);
}
