import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/date_utils.dart' as app_date;
import '../../../domain/models/news_post.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/news_feed_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<NewsFeedState> feedAsync = ref.watch(newsFeedProvider);
    final UserProfile? profile = ref.watch(userProfileProvider).valueOrNull;
    final NewsFeedState? feed = feedAsync.valueOrNull;
    final Set<String> followedAuthorIds = feed?.followedAuthorIds.toSet() ?? <String>{};
    final List<NewsPost> general = feed == null ? <NewsPost>[] : ref.read(newsFeedProvider.notifier).generalFeed();
    final List<NewsPost> forYou = feed == null ? <NewsPost>[] : ref.read(newsFeedProvider.notifier).forYouFeed();
    final List<NewsPost> mine = feed == null ? <NewsPost>[] : ref.read(newsFeedProvider.notifier).myPosts();
    final List<NewsPost> following = feed == null ? <NewsPost>[] : ref.read(newsFeedProvider.notifier).followingPosts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('News'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh feed',
            onPressed: () => ref.read(newsFeedProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const <Tab>[
            Tab(text: 'For You'),
            Tab(text: 'General'),
            Tab(text: 'Following'),
            Tab(text: 'My Posts'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposeSheet(context, ref, profile: profile),
        icon: const Icon(Icons.edit_square),
        label: const Text('Post'),
      ),
      body: Column(
        children: <Widget>[
          _NewsHeader(
            followedCount: feed?.followedAuthorIds.length ?? 0,
            postCount: feed?.posts.length ?? 0,
            onCompose: () => _openComposeSheet(context, ref, profile: profile),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _NewsFeedList(
                  emptyMessage: 'No followed updates yet. Follow farmers and admin posts to build your feed.',
                  posts: forYou,
                  ref: ref,
                  followedAuthorIds: followedAuthorIds,
                  mineOnly: false,
                ),
                _NewsFeedList(
                  emptyMessage: 'No general posts yet. Start a conversation by sharing an update.',
                  posts: general,
                  ref: ref,
                  followedAuthorIds: followedAuthorIds,
                  mineOnly: false,
                ),
                _NewsFeedList(
                  emptyMessage: 'You are not following anyone yet.',
                  posts: following,
                  ref: ref,
                  followedAuthorIds: followedAuthorIds,
                  mineOnly: false,
                ),
                _NewsFeedList(
                  emptyMessage: 'You have not posted any updates yet.',
                  posts: mine,
                  ref: ref,
                  followedAuthorIds: followedAuthorIds,
                  mineOnly: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openComposeSheet(
    BuildContext context,
    WidgetRef ref, {
    required UserProfile? profile,
    NewsPost? initialPost,
  }) async {
    final NewsComposeDraft? draft = await showModalBottomSheet<NewsComposeDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewsComposeSheet(
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
    required this.followedCount,
    required this.postCount,
    required this.onCompose,
  });

  final int followedCount;
  final int postCount;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: AppCard(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Daily news', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Share innovations, products, market updates, and farm stories. Follow other farmers for curated updates.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _MetricChip(label: 'Posts', value: '$postCount'),
                        _MetricChip(label: 'Following', value: '$followedCount'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onCompose,
                child: const Text('Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _NewsFeedList extends StatelessWidget {
  const _NewsFeedList({
    required this.posts,
    required this.ref,
    required this.followedAuthorIds,
    required this.emptyMessage,
    required this.mineOnly,
  });

  final List<NewsPost> posts;
  final WidgetRef ref;
  final Set<String> followedAuthorIds;
  final String emptyMessage;
  final bool mineOnly;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final NewsPost post = posts[index];
        return _NewsPostCard(
          post: post,
          ref: ref,
          followedAuthorIds: followedAuthorIds,
          mineOnly: mineOnly,
        );
      },
    );
  }
}

class _NewsPostCard extends StatelessWidget {
  const _NewsPostCard({
    required this.post,
    required this.ref,
    required this.followedAuthorIds,
    required this.mineOnly,
  });

  final NewsPost post;
  final WidgetRef ref;
  final Set<String> followedAuthorIds;
  final bool mineOnly;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canEdit = ref.read(newsFeedProvider.notifier).canEditPost(post);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => _openComments(context, ref, post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (post.hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: Image.memory(
                  base64Decode(post.coverImageBase64),
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 190,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.tertiaryContainer,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(18),
                alignment: Alignment.bottomLeft,
                child: Text(
                  post.title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      _Tag(text: post.category, color: const Color(0xFFE8F4D8)),
                      if (post.isAdminPost) const _Tag(text: 'Admin', color: Color(0xFFFFEBD0)),
                      if (post.isRepost) const _Tag(text: 'Repost', color: Color(0xFFDFF1FF)),
                      if (post.visibility == NewsPostVisibility.followersOnly) const _Tag(text: 'Followers only', color: Color(0xFFEDE8FF)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(post.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(post.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'F'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(post.authorName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                              '${app_date.DateUtils.formatDate(post.createdAt)} ${post.authorWhatsapp.isNotEmpty ? ' | WhatsApp ${post.authorWhatsapp}' : ''}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (!mineOnly && !post.isAdminPost)
                        IconButton(
                          tooltip: followedAuthorIds.contains(post.authorId) ? 'Unfollow' : 'Follow',
                          onPressed: () => ref.read(newsFeedProvider.notifier).toggleFollow(post.authorId),
                          icon: Icon(
                            followedAuthorIds.contains(post.authorId)
                                ? Icons.person_remove_alt_1_outlined
                                : Icons.person_add_alt_1_outlined,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _ActionChip(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '${post.commentCount}',
                        onTap: () => _openComments(context, ref, post),
                      ),
                      _ActionChip(
                        icon: Icons.repeat_rounded,
                        label: '${post.repostCount}',
                        onTap: () => ref.read(newsFeedProvider.notifier).repostPost(post),
                      ),
                      _ActionChip(
                        icon: Icons.message_rounded,
                        label: 'Chat',
                        onTap: post.authorWhatsapp.isEmpty ? null : () => _launchWhatsApp(post.authorWhatsapp, post.title),
                      ),
                      if (canEdit)
                        _ActionChip(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          onTap: () => _editPost(context, ref, post),
                        ),
                      if (canEdit)
                        _ActionChip(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          onTap: () => _deletePost(context, ref, post),
                        ),
                    ],
                  ),
                  if (post.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: post.tags.map((String tag) => _Tag(text: '#$tag', color: const Color(0xFFF3F3F3))).toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPost(BuildContext context, WidgetRef ref, NewsPost post) async {
    final NewsComposeDraft? draft = await showModalBottomSheet<NewsComposeDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewsComposeSheet(initialPost: post),
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

  Future<void> _deletePost(BuildContext context, WidgetRef ref, NewsPost post) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will remove the feed update from all feeds.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(newsFeedProvider.notifier).deletePost(post.id);
    }
  }

  Future<void> _openComments(BuildContext context, WidgetRef ref, NewsPost post) async {
    final TextEditingController controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final List<NewsComment> comments = ref.read(newsFeedProvider).valueOrNull?.posts
                .firstWhere((NewsPost item) => item.id == post.id, orElse: () => post)
                .comments ??
            post.comments;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Comments', style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text('No comments yet.'),
                    )
                  else
                    ...comments.map(
                      (NewsComment comment) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text(comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : 'F')),
                        title: Text(comment.authorName),
                        subtitle: Text(comment.message),
                        trailing: comment.authorWhatsapp.isNotEmpty
                            ? IconButton(
                                tooltip: 'WhatsApp',
                                icon: const Icon(Icons.message_rounded),
                                onPressed: () => _launchWhatsApp(comment.authorWhatsapp, comment.message),
                              )
                            : null,
                      ),
                    ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: controller,
                    label: 'Write a comment',
                    hint: 'Share a message or ask a question',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppButton.secondary(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton.primary(
                          onPressed: () async {
                            final String message = controller.text.trim();
                            if (message.isEmpty) return;
                            await ref.read(newsFeedProvider.notifier).addComment(post.id, message);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          child: const Text('Send'),
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
    this.profile,
    this.initialPost,
  });

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
    _whatsappController = TextEditingController(text: post?.authorWhatsapp ?? widget.profile?.phoneNumber ?? '');
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              Text(widget.initialPost == null ? 'Create post' : 'Edit post', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              AppTextField(controller: _titleController, label: 'Headline', hint: 'Share a farm innovation'),
              const SizedBox(height: 12),
              AppTextField(controller: _bodyController, label: 'Post body', hint: 'Describe what changed, what is available, or what farmers should know.', maxLines: 5),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                items: _categories.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(growable: false),
                onChanged: (String? value) {
                  if (value != null) setState(() => _category = value);
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _whatsappController,
                      label: 'WhatsApp handle',
                      hint: '+2348012345678',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<NewsPostVisibility>(
                      value: _visibility,
                      items: NewsPostVisibility.values
                          .map((NewsPostVisibility value) => DropdownMenuItem<NewsPostVisibility>(value: value, child: Text(value.name)))
                          .toList(growable: false),
                      onChanged: (NewsPostVisibility? value) {
                        if (value != null) setState(() => _visibility = value);
                      },
                      decoration: const InputDecoration(labelText: 'Visibility'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(controller: _locationController, label: 'Location', hint: 'Jos South'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(controller: _linkController, label: 'Link', hint: 'Product page or article'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _tagsController, label: 'Tags', hint: 'seed, maize, innovation'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: _pickImage,
                      child: Text(_coverImageBase64.isEmpty ? 'Add image' : 'Replace image'),
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
                      child: const Text('Clear image'),
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
                child: Text(widget.initialPost == null ? 'Publish' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 82);
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
        const SnackBar(content: Text('Headline and body are required.')),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
