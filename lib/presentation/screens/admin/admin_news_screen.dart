import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../domain/models/news_post.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/news_feed_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import 'admin_locked_view.dart';

class AdminNewsScreen extends ConsumerStatefulWidget {
  const AdminNewsScreen({super.key});

  @override
  ConsumerState<AdminNewsScreen> createState() => _AdminNewsScreenState();
}

class _AdminNewsScreenState extends ConsumerState<AdminNewsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(text: 'Innovation');
  bool _isPublishing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    _whatsappController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdminWorkspaceState> adminAsync = ref.watch(adminWorkspaceProvider);
    final AdminWorkspaceState? adminState = adminAsync.valueOrNull;
    if (adminAsync.isLoading || adminState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (adminState.currentAdmin == null) {
      return const AdminLockedView(
        message: 'Use the hidden admin login to publish feed updates and announcements.',
      );
    }

    final AsyncValue<NewsFeedState> feedAsync = ref.watch(newsFeedProvider);
    final List<NewsPost> adminPosts = feedAsync.valueOrNull?.posts.where((NewsPost post) => post.isAdminPost).toList(growable: false) ?? <NewsPost>[];
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin news'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.read(newsFeedProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          AppCard(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Publish a feed update', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  AppTextField(controller: _titleController, label: 'Headline', hint: 'New irrigation update'),
                  const SizedBox(height: 12),
                  AppTextField(controller: _bodyController, label: 'Body', hint: 'Share the full update', maxLines: 5),
                  const SizedBox(height: 12),
                  AppTextField(controller: _categoryController, label: 'Category', hint: 'Innovation'),
                  const SizedBox(height: 12),
                  AppTextField(controller: _tagsController, label: 'Tags', hint: 'seed, fertilizer, market'),
                  const SizedBox(height: 12),
                  AppTextField(controller: _whatsappController, label: 'WhatsApp handle', hint: '+2348012345678'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isPublishing ? null : () => _publish(context),
                    child: Text(_isPublishing ? 'Publishing...' : 'Publish to news feed'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Recent admin posts', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (adminPosts.isEmpty)
            const Text('No admin posts yet.')
          else
            ...adminPosts.map(
              (NewsPost post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    title: Text(post.title),
                    subtitle: Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.newspaper_rounded),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _publish(BuildContext context) async {
    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      context.showSnackBar('Headline and body are required.', isError: true);
      return;
    }
    setState(() => _isPublishing = true);
    try {
      await ref.read(adminWorkspaceProvider.notifier).createAdminNews(
            title: title,
            body: body,
            category: _categoryController.text.trim().isEmpty ? 'Innovation' : _categoryController.text.trim(),
            tags: _tagsController.text
                .split(',')
                .map((String value) => value.trim())
                .where((String value) => value.isNotEmpty)
                .toList(growable: false),
            whatsappHandle: _whatsappController.text.trim(),
          );
      await ref.read(newsFeedProvider.notifier).refresh();
      if (!mounted) return;
      context.showSnackBar('News update published.');
      _titleController.clear();
      _bodyController.clear();
      _tagsController.clear();
    } catch (error) {
      if (!mounted) return;
      context.showSnackBar('Could not publish news update.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }
}
