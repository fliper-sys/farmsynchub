import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/date_utils.dart' as app_date;
import '../../../domain/models/news_post.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/news_feed_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/detail_ui.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _peopleSearchController = TextEditingController();
  bool _showHeader = true;
  bool _showDiscoverySection = true;
  bool _discoveryCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _peopleSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final AsyncValue<NewsFeedState> feedAsync = ref.watch(newsFeedProvider);
    final UserProfile? profile = ref.watch(userProfileProvider).valueOrNull;
    final NewsFeedState? feed = feedAsync.valueOrNull;
    final Set<String> followedAuthorIds =
        feed?.followedAuthorIds.toSet() ?? <String>{};
    final String peopleQuery = _peopleSearchController.text.trim();
    final List<UserProfile> people = feed == null
        ? <UserProfile>[]
        : ref
            .read(newsFeedProvider.notifier)
            .suggestedPeople(query: peopleQuery);
    final List<NewsPost> general = feed == null
        ? <NewsPost>[]
        : ref.read(newsFeedProvider.notifier).generalFeed();
    final List<NewsPost> forYou = feed == null
        ? <NewsPost>[]
        : ref.read(newsFeedProvider.notifier).forYouFeed();
    final List<NewsPost> mine = feed == null
        ? <NewsPost>[]
        : ref.read(newsFeedProvider.notifier).myPosts();
    final List<NewsPost> following = feed == null
        ? <NewsPost>[]
        : ref.read(newsFeedProvider.notifier).followingPosts();
    final Object? feedError = feedAsync.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(language.tr(en: 'News', ha: 'Labarai', fr: 'Actualites')),
        actions: <Widget>[
          IconButton(
            tooltip: language.tr(
                en: 'Refresh feed',
                ha: 'Sabunta Bayanai',
                fr: 'Actualiser le fil'),
            onPressed: () => ref.read(newsFeedProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: <Tab>[
            Tab(
                text: language.tr(
                    en: 'For You', ha: 'A gare ka', fr: 'Pour vous')),
            Tab(
                text:
                    language.tr(en: 'General', ha: 'Gama gari', fr: 'General')),
            Tab(
                text: language.tr(
                    en: 'Following', ha: 'Ana Bi', fr: 'Abonnements')),
            Tab(
                text: language.tr(
                    en: 'My Posts', ha: 'Sakonnina', fr: 'Mes publications')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposeSheet(context, ref, profile: profile),
        icon: const Icon(Icons.edit_square),
        label: Text(language.tr(en: 'Post', ha: 'Aika', fr: 'Publier')),
      ),
      // A single NestedScrollView drives the header, the people-discovery
      // strip, and the feed as one continuous scroll gesture instead of two
      // independently-scrolling regions stacked on top of each other.
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            <Widget>[
          SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: _showHeader
                  ? _NewsHeader(
                      language: language,
                      followedCount: feed?.followedAuthorIds.length ?? 0,
                      postCount: feed?.posts.length ?? 0,
                      onCompose: () =>
                          _openComposeSheet(context, ref, profile: profile),
                      onCollapse: () => setState(() => _showHeader = false),
                    )
                  : _CollapsedNewsHeader(
                      language: language,
                      onExpand: () => setState(() => _showHeader = true),
                    ),
            ),
          ),
          if (feed != null)
            SliverToBoxAdapter(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: _showDiscoverySection
                    ? _PeopleDiscoverySection(
                        language: language,
                        queryController: _peopleSearchController,
                        people: people,
                        followedAuthorIds: followedAuthorIds,
                        isCollapsed: _discoveryCollapsed,
                        onToggleCollapsed: () => setState(() =>
                            _discoveryCollapsed = !_discoveryCollapsed),
                        onClose: () => setState(() {
                          _showDiscoverySection = false;
                          _discoveryCollapsed = false;
                        }),
                        onFollowToggle: (String authorId) => ref
                            .read(newsFeedProvider.notifier)
                            .toggleFollow(authorId),
                        onSearchChanged: () => setState(() {}),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
        body: feedError != null
            ? _NewsFeedError(
                language: language,
                error: feedError,
                onRetry: () => ref.read(newsFeedProvider.notifier).refresh(),
              )
            : TabBarView(
                controller: _tabController,
                children: <Widget>[
                  _NewsFeedList(
                    language: language,
                    emptyMessage: language.tr(
                      en: 'No followed updates yet. Follow farmers and admin posts to build your feed.',
                      ha: 'Babu sabuntawar da ake bi tukuna. Bi manoma da sakonnin admin domin gina bayaninka.',
                      fr: 'Aucune mise a jour suivie pour le moment. Suivez des agriculteurs et des publications admin pour construire votre fil.',
                    ),
                    posts: forYou,
                    ref: ref,
                    followedAuthorIds: followedAuthorIds,
                    mineOnly: false,
                  ),
                  _NewsFeedList(
                    language: language,
                    emptyMessage: language.tr(
                      en: 'No general posts yet. Start a conversation by sharing an update.',
                      ha: 'Babu sako gama gari tukuna. Fara tattaunawa ta hanyar raba sabuntawa.',
                      fr: 'Aucune publication generale pour le moment. Demarrez une conversation en partageant une mise a jour.',
                    ),
                    posts: general,
                    ref: ref,
                    followedAuthorIds: followedAuthorIds,
                    mineOnly: false,
                  ),
                  _NewsFeedList(
                    language: language,
                    emptyMessage: language.tr(
                        en: 'You are not following anyone yet.',
                        ha: 'Ba ka bin kowa tukuna ba.',
                        fr: 'Vous ne suivez personne pour le moment.'),
                    posts: following,
                    ref: ref,
                    followedAuthorIds: followedAuthorIds,
                    mineOnly: false,
                  ),
                  _NewsFeedList(
                    language: language,
                    emptyMessage: language.tr(
                        en: 'You have not posted any updates yet.',
                        ha: 'Ba ka aika wata sabuntawa tukuna ba.',
                        fr: 'Vous n\'avez publie aucune mise a jour pour le moment.'),
                    posts: mine,
                    ref: ref,
                    followedAuthorIds: followedAuthorIds,
                    mineOnly: true,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _openComposeSheet(
    BuildContext context,
    WidgetRef ref, {
    required UserProfile? profile,
    NewsPost? initialPost,
  }) async {
    final AppLanguage sheetLanguage = ref.read(appLanguageProvider);
    final NewsComposeDraft? draft =
        await showModalBottomSheet<NewsComposeDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewsComposeSheet(
        language: sheetLanguage,
        profile: profile,
        initialPost: initialPost,
      ),
    );
    if (draft == null) return;

    final NewsFeedController controller = ref.read(newsFeedProvider.notifier);
    if (initialPost == null) {
      await controller.createPost(
        title: draft.title,
        body: draft.body,
        category: draft.category,
        tags: draft.tags,
        whatsappHandle: draft.whatsappHandle,
        coverImageBase64: draft.coverImageBase64,
        coverImageName: draft.coverImageName,
        location: draft.location,
        linkUrl: draft.linkUrl,
        visibility: draft.visibility,
      );
    } else {
      await controller.updatePost(
        initialPost.copyWith(
          title: draft.title,
          body: draft.body,
          category: draft.category,
          tags: draft.tags,
          authorWhatsapp: draft.whatsappHandle,
          coverImageBase64: draft.coverImageBase64,
          coverImageName: draft.coverImageName,
          location: draft.location,
          linkUrl: draft.linkUrl,
          visibility: draft.visibility,
        ),
      );
    }
  }
}

class _NewsHeader extends StatelessWidget {
  const _NewsHeader({
    required this.language,
    required this.followedCount,
    required this.postCount,
    required this.onCompose,
    required this.onCollapse,
  });

  final AppLanguage language;
  final int followedCount;
  final int postCount;
  final VoidCallback onCompose;
  final VoidCallback onCollapse;

  Widget _stat(int value, String label) => Padding(
        padding: const EdgeInsets.only(right: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double v, Widget? c) => Text(
                '${v.round()}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900),
              ),
            ),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 12)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF0E5A41), Color(0xFF2E9E5B)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.newspaper_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    language.tr(
                        en: 'Daily news',
                        ha: 'Labaran Yau da Kullum',
                        fr: 'Actualites quotidiennes'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: language.tr(
                      en: 'Hide summary',
                      ha: 'Boye Takaitawa',
                      fr: 'Masquer le resume'),
                  onPressed: onCollapse,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded,
                      color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                language.tr(
                  en: 'Share innovations, products, market updates, and farm stories. Follow other farmers for curated updates.',
                  ha: 'Raba sabbin dabaru, kayayyaki, sabuntawar kasuwa, da labaran gona. Bi wasu manoma domin samun sabuntawa masu tsari.',
                  fr: 'Partagez des innovations, des produits, des mises a jour du marche et des recits agricoles. Suivez d\'autres agriculteurs pour des mises a jour selectionnees.',
                ),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                _stat(postCount,
                    language.tr(en: 'Posts', ha: 'Sakonni', fr: 'Publications')),
                _stat(
                    followedCount,
                    language.tr(
                        en: 'Following', ha: 'Ana Bi', fr: 'Abonnements')),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0E5A41),
                    ),
                    onPressed: onCompose,
                    icon: const Icon(Icons.edit_square, size: 18),
                    label: Text(
                        language.tr(en: 'Post', ha: 'Aika', fr: 'Publier')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedNewsHeader extends StatelessWidget {
  const _CollapsedNewsHeader({
    required this.language,
    required this.onExpand,
  });

  final AppLanguage language;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: InkWell(
        onTap: onExpand,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.newspaper_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  language.tr(
                      en: 'Daily news summary',
                      ha: 'Takaitaccen Labarai na Yau da Kullum',
                      fr: 'Resume des actualites quotidiennes'),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleDiscoverySection extends StatelessWidget {
  const _PeopleDiscoverySection({
    required this.language,
    required this.queryController,
    required this.people,
    required this.followedAuthorIds,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.onClose,
    required this.onFollowToggle,
    required this.onSearchChanged,
  });

  final AppLanguage language;
  final TextEditingController queryController;
  final List<UserProfile> people;
  final Set<String> followedAuthorIds;
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onClose;
  final ValueChanged<String> onFollowToggle;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: AppCard(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                        language.tr(
                            en: 'Find farmers to follow',
                            ha: 'Nemi Manoma da za a Bi',
                            fr: 'Trouver des agriculteurs a suivre'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Text(
                      language.tr(
                          en: '${people.length} suggested',
                          ha: '${people.length} da aka shawarta',
                          fr: '${people.length} suggeres'),
                      style: theme.textTheme.labelLarge),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: isCollapsed
                        ? language.tr(
                            en: 'Expand discovery',
                            ha: 'Fadada Bincike',
                            fr: 'Developper la decouverte')
                        : language.tr(
                            en: 'Collapse discovery',
                            ha: 'Rufe Bincike',
                            fr: 'Reduire la decouverte'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onToggleCollapsed,
                    icon: Icon(isCollapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded),
                  ),
                  IconButton(
                    tooltip: language.tr(
                        en: 'Hide discovery',
                        ha: 'Boye Bincike',
                        fr: 'Masquer la decouverte'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (!isCollapsed) ...<Widget>[
                const SizedBox(height: 10),
                TextField(
                  controller: queryController,
                  onChanged: (_) => onSearchChanged(),
                  decoration: InputDecoration(
                    hintText: language.tr(
                        en: 'Search by name, ward, focus, phone, or bio',
                        ha: 'Nemi ta suna, unguwa, manufa, waya, ko bayani',
                        fr: 'Rechercher par nom, quartier, specialite, telephone ou bio'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide:
                          BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide:
                          BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                          color: theme.colorScheme.primary, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (people.isEmpty)
                  Text(
                    language.tr(
                      en: 'No matching farmers found. Try a different name, ward, or production focus.',
                      ha: 'Ba a sami manoma masu dacewa ba. Gwada wani suna, unguwa, ko manufar samarwa.',
                      fr: 'Aucun agriculteur correspondant trouve. Essayez un autre nom, quartier ou specialite de production.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  )
                else
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: people
                              .map(
                                (UserProfile person) => Padding(
                                  padding: const EdgeInsets.only(
                                      right: 10, bottom: 10),
                                  child: _PeopleSuggestionTile(
                                    language: language,
                                    profile: person,
                                    isFollowed:
                                        followedAuthorIds.contains(person.uid),
                                    onFollowToggle: () =>
                                        onFollowToggle(person.uid),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleSuggestionTile extends StatefulWidget {
  const _PeopleSuggestionTile({
    required this.language,
    required this.profile,
    required this.isFollowed,
    required this.onFollowToggle,
  });

  final AppLanguage language;
  final UserProfile profile;
  final bool isFollowed;
  final VoidCallback onFollowToggle;

  @override
  State<_PeopleSuggestionTile> createState() => _PeopleSuggestionTileState();
}

class _PeopleSuggestionTileState extends State<_PeopleSuggestionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Uint8List? avatarBytes = widget.profile.profileImageBase64.isEmpty
        ? null
        : base64Decode(widget.profile.profileImageBase64);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage:
                    avatarBytes == null ? null : MemoryImage(avatarBytes),
                child: avatarBytes == null
                    ? Text(
                        widget.profile.fullName.isNotEmpty
                            ? widget.profile.fullName[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.labelLarge,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            widget.profile.fullName.isNotEmpty
                                ? widget.profile.fullName
                                : widget.profile.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (widget.profile.isVerified) ...<Widget>[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 15, color: Colors.green),
                        ],
                      ],
                    ),
                    Text(
                      widget.profile.ward.isNotEmpty
                          ? widget.profile.ward
                          : widget.profile.primaryFocus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _isExpanded
                    ? widget.language
                        .tr(en: 'Collapse', ha: 'Rufe', fr: 'Reduire')
                    : widget.language
                        .tr(en: 'Expand', ha: 'Fadada', fr: 'Developper'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                icon: Icon(_isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.profile.primaryFocus.isNotEmpty
                ? widget.profile.primaryFocus
                : widget.language.tr(
                    en: 'Farmer profile',
                    ha: 'Bayanin Manomi',
                    fr: 'Profil d\'agriculteur'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
          if (_isExpanded) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              widget.profile.email,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: widget.onFollowToggle,
              icon: Icon(
                  widget.isFollowed
                      ? Icons.check_rounded
                      : Icons.person_add_alt_1_rounded,
                  size: 18),
              label: Text(widget.isFollowed
                  ? widget.language
                      .tr(en: 'Following', ha: 'Ana Bi', fr: 'Suivi')
                  : widget.language.tr(en: 'Follow', ha: 'Bi', fr: 'Suivre')),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsFeedList extends StatelessWidget {
  const _NewsFeedList({
    required this.language,
    required this.posts,
    required this.ref,
    required this.followedAuthorIds,
    required this.emptyMessage,
    required this.mineOnly,
  });

  final AppLanguage language;
  final List<NewsPost> posts;
  final WidgetRef ref;
  final Set<String> followedAuthorIds;
  final String emptyMessage;
  final bool mineOnly;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (posts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: <Widget>[
          const SizedBox(height: 40),
          FadeInUp(
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.forum_outlined,
                      size: 42, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 18),
                Text(emptyMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (BuildContext context, int index) {
        final NewsPost post = posts[index];
        return FadeInUp(
          index: index.clamp(0, 5),
          child: _NewsPostCard(
            language: language,
            post: post,
            ref: ref,
            followedAuthorIds: followedAuthorIds,
            mineOnly: mineOnly,
          ),
        );
      },
    );
  }
}

class _NewsFeedError extends StatelessWidget {
  const _NewsFeedError({
    required this.language,
    required this.error,
    required this.onRetry,
  });

  final AppLanguage language;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AppCard(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.cloud_off_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        language.tr(
                            en: 'News sync failed',
                            ha: 'Sync na Labarai ya Kasa',
                            fr: 'Echec de synchronisation des actualites'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  language.tr(
                    en: 'Could not load news posts from Firestore. Check your connection or Firestore rules for the global news_posts collection.',
                    ha: 'An kasa loda sakonnin labarai daga Firestore. Duba hanyar sadarwar ka ko dokokin Firestore na tarin news_posts na duniya.',
                    fr: 'Impossible de charger les publications d\'actualites depuis Firestore. Verifiez votre connexion ou les regles Firestore pour la collection news_posts globale.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 10),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                AppButton.secondary(
                  onPressed: onRetry,
                  child: Text(language.tr(
                      en: 'Retry sync',
                      ha: 'Sake Gwada Sync',
                      fr: 'Reessayer la synchronisation')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NewsPostCard extends StatelessWidget {
  const _NewsPostCard({
    required this.language,
    required this.post,
    required this.ref,
    required this.followedAuthorIds,
    required this.mineOnly,
  });

  final AppLanguage language;
  final NewsPost post;
  final WidgetRef ref;
  final Set<String> followedAuthorIds;
  final bool mineOnly;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canEdit = ref.read(newsFeedProvider.notifier).canEditPost(post);
    final UserProfile? authorProfile =
        ref.read(newsFeedProvider.notifier).userForAuthor(post.authorId);
    final bool authorVerified = authorProfile?.isVerified == true;

    final bool following = followedAuthorIds.contains(post.authorId);
    final Color accent = post.isAdminPost
        ? const Color(0xFFE08A1E)
        : theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openComments(context, ref, post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: <Color>[
                          accent,
                          accent.withOpacity(0.6),
                        ],
                      ),
                    ),
                    child: Text(
                      post.authorName.isNotEmpty
                          ? post.authorName[0].toUpperCase()
                          : 'F',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(post.authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800)),
                            ),
                            if (authorVerified) ...<Widget>[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified_rounded,
                                  size: 16, color: Color(0xFF2E9E5B)),
                            ],
                            if (post.isAdminPost) ...<Widget>[
                              const SizedBox(width: 6),
                              _Tag(
                                  text: language.tr(
                                      en: 'Admin', ha: 'Admin', fr: 'Admin'),
                                  color: const Color(0xFFFFEBD0)),
                            ],
                          ],
                        ),
                        Text(
                          '${_timeAgo(post.createdAt)}'
                          '${post.location.isNotEmpty ? '  ·  ${post.location}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (!mineOnly && !post.isAdminPost)
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () => ref
                          .read(newsFeedProvider.notifier)
                          .toggleFollow(post.authorId),
                      child: Text(following
                          ? language.tr(
                              en: 'Following', ha: 'Ana Bi', fr: 'Suivi')
                          : language.tr(en: 'Follow', ha: 'Bi', fr: 'Suivre')),
                    ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      tooltip: language.tr(
                          en: 'More', ha: 'Kari', fr: 'Plus'),
                      onSelected: (String v) {
                        if (v == 'edit') _editPost(context, ref, post);
                        if (v == 'delete') _deletePost(context, ref, post);
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text(language.tr(
                              en: 'Edit', ha: 'Gyara', fr: 'Modifier')),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(language.tr(
                              en: 'Delete', ha: 'Share', fr: 'Supprimer')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (post.hasImage)
              Stack(
                children: <Widget>[
                  Image.memory(
                    base64Decode(post.coverImageBase64),
                    width: double.infinity,
                    height: 210,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _CategoryBadge(post.category),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      if (!post.hasImage) _CategoryBadge(post.category),
                      if (post.isRepost)
                        _Tag(
                            text: language.tr(
                                en: 'Repost',
                                ha: 'Sake Aikawa',
                                fr: 'Republication'),
                            color: const Color(0xFFDFF1FF)),
                      if (post.visibility == NewsPostVisibility.followersOnly)
                        _Tag(
                            text: language.tr(
                                en: 'Followers only',
                                ha: 'Masu Bi Kadai',
                                fr: 'Abonnes uniquement'),
                            color: const Color(0xFFEDE8FF)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(post.title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 6),
                  Text(post.body,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                  if (post.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: post.tags
                          .map((String tag) => Text('#$tag',
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700)))
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
            Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: <Widget>[
                  _PostAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '${post.commentCount}',
                    onTap: () => _openComments(context, ref, post),
                  ),
                  _PostAction(
                    icon: Icons.repeat_rounded,
                    label: '${post.repostCount}',
                    onTap: () =>
                        ref.read(newsFeedProvider.notifier).repostPost(post),
                  ),
                  const Spacer(),
                  if (post.authorWhatsapp.isNotEmpty)
                    _PostAction(
                      icon: Icons.message_rounded,
                      label: language.tr(
                          en: 'Chat', ha: 'Tattaunawa', fr: 'Discuter'),
                      onTap: () =>
                          _launchWhatsApp(post.authorWhatsapp, post.title),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(DateTime t) {
    final Duration d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return app_date.DateUtils.formatDate(t);
  }

  Future<void> _editPost(
      BuildContext context, WidgetRef ref, NewsPost post) async {
    final NewsComposeDraft? draft =
        await showModalBottomSheet<NewsComposeDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewsComposeSheet(language: language, initialPost: post),
    );
    if (draft == null) return;
    await ref.read(newsFeedProvider.notifier).updatePost(
          post.copyWith(
            title: draft.title,
            body: draft.body,
            category: draft.category,
            tags: draft.tags,
            authorWhatsapp: draft.whatsappHandle,
            coverImageBase64: draft.coverImageBase64,
            coverImageName: draft.coverImageName,
            location: draft.location,
            linkUrl: draft.linkUrl,
            visibility: draft.visibility,
          ),
        );
  }

  Future<void> _deletePost(
      BuildContext context, WidgetRef ref, NewsPost post) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(language.tr(
            en: 'Delete post?',
            ha: 'Share sako?',
            fr: 'Supprimer la publication ?')),
        content: Text(language.tr(
            en: 'This will remove the feed update from all feeds.',
            ha: 'Wannan zai cire sabuntawar daga dukkan bayanai.',
            fr: 'Cela supprimera la mise a jour de tous les fils.')),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  Text(language.tr(en: 'Cancel', ha: 'Soke', fr: 'Annuler'))),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                  language.tr(en: 'Delete', ha: 'Share', fr: 'Supprimer'))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(newsFeedProvider.notifier).deletePost(post.id);
    }
  }

  Future<void> _openComments(
      BuildContext context, WidgetRef ref, NewsPost post) async {
    final TextEditingController controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final List<NewsComment> comments = ref
                .read(newsFeedProvider)
                .valueOrNull
                ?.posts
                .firstWhere((NewsPost item) => item.id == post.id,
                    orElse: () => post)
                .comments ??
            post.comments;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Text(
                      '${language.tr(en: 'Comments', ha: 'Sharhi', fr: 'Commentaires')} (${comments.length})',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(language.tr(
                          en: 'No comments yet.',
                          ha: 'Babu sharhi tukuna.',
                          fr: 'Aucun commentaire pour le moment.')),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.of(sheetContext).size.height * 0.4),
                      child: ListView(
                        shrinkWrap: true,
                        children: comments.map(
                      (NewsComment comment) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                            child: Text(comment.authorName.isNotEmpty
                                ? comment.authorName[0].toUpperCase()
                                : 'F')),
                        title: Text(comment.authorName),
                        subtitle: Text(comment.message),
                        trailing: comment.authorWhatsapp.isNotEmpty
                            ? IconButton(
                                tooltip: language.tr(
                                    en: 'WhatsApp',
                                    ha: 'WhatsApp',
                                    fr: 'WhatsApp'),
                                icon: const Icon(Icons.message_rounded),
                                onPressed: () => _launchWhatsApp(
                                    comment.authorWhatsapp, comment.message),
                              )
                            : null,
                      ),
                    ).toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: controller,
                    label: language.tr(
                        en: 'Write a comment',
                        ha: 'Rubuta Sharhi',
                        fr: 'Ecrire un commentaire'),
                    hint: language.tr(
                        en: 'Share a message or ask a question',
                        ha: 'Raba sako ko yi tambaya',
                        fr: 'Partagez un message ou posez une question'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppButton.secondary(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: Text(language.tr(
                              en: 'Close', ha: 'Rufe', fr: 'Fermer')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton.primary(
                          onPressed: () async {
                            final String message = controller.text.trim();
                            if (message.isEmpty) return;
                            await ref
                                .read(newsFeedProvider.notifier)
                                .addComment(post.id, message);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          child: Text(language.tr(
                              en: 'Send', ha: 'Aika', fr: 'Envoyer')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchWhatsApp(String handle, String text) async {
    final String sanitized = handle.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri uri = Uri.parse(
      'https://wa.me/${sanitized.replaceAll('+', '')}?text=${Uri.encodeComponent(text)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class NewsComposeSheet extends StatefulWidget {
  const NewsComposeSheet({
    super.key,
    required this.language,
    this.profile,
    this.initialPost,
  });

  final AppLanguage language;
  final UserProfile? profile;
  final NewsPost? initialPost;

  @override
  State<NewsComposeSheet> createState() => _NewsComposeSheetState();
}

class _NewsComposeSheetState extends State<NewsComposeSheet> {
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _tagsController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _locationController;
  late final TextEditingController _linkController;
  String _category = 'Innovation';
  NewsPostVisibility _visibility = NewsPostVisibility.public;
  String _coverImageBase64 = '';
  String _coverImageName = '';

  static const List<String> _categories = <String>[
    'Innovation',
    'Product',
    'Market',
    'Training',
    'Alert',
    'Event',
  ];

  @override
  void initState() {
    super.initState();
    final NewsPost? post = widget.initialPost;
    _titleController = TextEditingController(text: post?.title ?? '');
    _bodyController = TextEditingController(text: post?.body ?? '');
    _tagsController = TextEditingController(text: post?.tags.join(', ') ?? '');
    _whatsappController = TextEditingController(
        text: post?.authorWhatsapp ?? widget.profile?.phoneNumber ?? '');
    _locationController = TextEditingController(text: post?.location ?? '');
    _linkController = TextEditingController(text: post?.linkUrl ?? '');
    _category = post?.category ?? 'Innovation';
    _visibility = post?.visibility ?? NewsPostVisibility.public;
    _coverImageBase64 = post?.coverImageBase64 ?? '';
    _coverImageName = post?.coverImageName ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    _whatsappController.dispose();
    _locationController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                  widget.initialPost == null
                      ? widget.language.tr(
                          en: 'Create post',
                          ha: 'Kirkiri Sako',
                          fr: 'Creer une publication')
                      : widget.language.tr(
                          en: 'Edit post',
                          ha: 'Gyara Sako',
                          fr: 'Modifier la publication'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              AppTextField(
                  controller: _titleController,
                  label: widget.language
                      .tr(en: 'Headline', ha: 'Take', fr: 'Titre'),
                  hint: widget.language.tr(
                      en: 'Share a farm innovation',
                      ha: 'Raba sabon abu na gona',
                      fr: 'Partagez une innovation agricole')),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _bodyController,
                  label: widget.language.tr(
                      en: 'Post body',
                      ha: 'Cikin Sako',
                      fr: 'Corps de la publication'),
                  hint: widget.language.tr(
                      en: 'Describe what changed, what is available, or what farmers should know.',
                      ha: 'Bayyana abin da ya canza, abin da ke samuwa, ko abin da ya kamata manoma su sani.',
                      fr: 'Decrivez ce qui a change, ce qui est disponible ou ce que les agriculteurs devraient savoir.'),
                  maxLines: 5),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                items: _categories
                    .map((String item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(_categoryLabel(widget.language, item))))
                    .toList(growable: false),
                onChanged: (String? value) {
                  if (value != null) setState(() => _category = value);
                },
                decoration: InputDecoration(
                    labelText: widget.language
                        .tr(en: 'Category', ha: 'Rukuni', fr: 'Categorie')),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _whatsappController,
                      label: widget.language.tr(
                          en: 'WhatsApp handle',
                          ha: 'Lambar WhatsApp',
                          fr: 'Contact WhatsApp'),
                      hint: '+2348012345678',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<NewsPostVisibility>(
                      value: _visibility,
                      items: NewsPostVisibility.values
                          .map((NewsPostVisibility value) =>
                              DropdownMenuItem<NewsPostVisibility>(
                                  value: value, child: Text(value.name)))
                          .toList(growable: false),
                      onChanged: (NewsPostVisibility? value) {
                        if (value != null) setState(() => _visibility = value);
                      },
                      decoration: InputDecoration(
                          labelText: widget.language.tr(
                              en: 'Visibility',
                              ha: 'Ganuwa',
                              fr: 'Visibilite')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                        controller: _locationController,
                        label: widget.language
                            .tr(en: 'Location', ha: 'Wuri', fr: 'Emplacement'),
                        hint: 'Jos South'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                        controller: _linkController,
                        label: widget.language.tr(
                            en: 'Link', ha: 'Hanyar Yanar Gizo', fr: 'Lien'),
                        hint: widget.language.tr(
                            en: 'Product page or article',
                            ha: 'Shafin kaya ko labari',
                            fr: 'Page produit ou article')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _tagsController,
                  label: widget.language
                      .tr(en: 'Tags', ha: 'Alamomi', fr: 'Mots-cles'),
                  hint: 'seed, maize, innovation'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: _pickImage,
                      child: Text(_coverImageBase64.isEmpty
                          ? widget.language.tr(
                              en: 'Add image',
                              ha: 'Kara Hoto',
                              fr: 'Ajouter une image')
                          : widget.language.tr(
                              en: 'Replace image',
                              ha: 'Musanya Hoto',
                              fr: 'Remplacer l\'image')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: _coverImageBase64.isEmpty
                          ? null
                          : () => setState(() {
                                _coverImageBase64 = '';
                                _coverImageName = '';
                              }),
                      child: Text(widget.language.tr(
                          en: 'Clear image',
                          ha: 'Share Hoto',
                          fr: 'Effacer l\'image')),
                    ),
                  ),
                ],
              ),
              if (_coverImageBase64.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                    base64Decode(_coverImageBase64),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              AppButton.primary(
                onPressed: _submit,
                child: Text(widget.initialPost == null
                    ? widget.language
                        .tr(en: 'Publish', ha: 'Wallafa', fr: 'Publier')
                    : widget.language.tr(
                        en: 'Save changes',
                        ha: 'Ajiye Canje-canje',
                        fr: 'Enregistrer les modifications')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 82);
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    setState(() {
      _coverImageBase64 = base64Encode(bytes);
      _coverImageName = file.name;
    });
  }

  void _submit() {
    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.language.tr(
                en: 'Headline and body are required.',
                ha: 'Ana bukatar take da cikin sako.',
                fr: 'Le titre et le corps sont requis.'))),
      );
      return;
    }
    Navigator.of(context).pop(
      NewsComposeDraft(
        title: title,
        body: body,
        category: _category,
        tags: _tagsController.text
            .split(',')
            .map((String item) => item.trim())
            .where((String item) => item.isNotEmpty)
            .toList(growable: false),
        whatsappHandle: _whatsappController.text.trim(),
        coverImageBase64: _coverImageBase64,
        coverImageName: _coverImageName,
        location: _locationController.text.trim(),
        linkUrl: _linkController.text.trim(),
        visibility: _visibility,
      ),
    );
  }
}

String _categoryLabel(AppLanguage language, String category) {
  switch (category) {
    case 'Innovation':
      return language.tr(en: 'Innovation', ha: 'Sabon Abu', fr: 'Innovation');
    case 'Product':
      return language.tr(en: 'Product', ha: 'Kaya', fr: 'Produit');
    case 'Market':
      return language.tr(en: 'Market', ha: 'Kasuwa', fr: 'Marche');
    case 'Training':
      return language.tr(en: 'Training', ha: 'Horo', fr: 'Formation');
    case 'Alert':
      return language.tr(en: 'Alert', ha: 'Gargadi', fr: 'Alerte');
    case 'Event':
      return language.tr(en: 'Event', ha: 'Taro', fr: 'Evenement');
    default:
      return category;
  }
}

class NewsComposeDraft {
  const NewsComposeDraft({
    required this.title,
    required this.body,
    required this.category,
    required this.tags,
    required this.whatsappHandle,
    required this.coverImageBase64,
    required this.coverImageName,
    required this.location,
    required this.linkUrl,
    required this.visibility,
  });

  final String title;
  final String body;
  final String category;
  final List<String> tags;
  final String whatsappHandle;
  final String coverImageBase64;
  final String coverImageName;
  final String location;
  final String linkUrl;
  final NewsPostVisibility visibility;
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0E5A41),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3)),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant),
      icon: Icon(icon, size: 19),
      label: Text(label),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: isDark ? color.withOpacity(0.44) : color.withOpacity(0.85)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

