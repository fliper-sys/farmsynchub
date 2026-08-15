import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/services/farm_email_service.dart';
import '../data/remote/firebase_service.dart';
import '../domain/models/notification.dart';
import '../domain/models/news_post.dart';
import '../domain/models/user_profile.dart';
import 'auth_provider.dart';
import 'email_notification_provider.dart';
import 'notification_provider.dart';
import 'user_profile_provider.dart';

final newsFeedProvider =
    StateNotifierProvider<NewsFeedController, AsyncValue<NewsFeedState>>((ref) {
  return NewsFeedController(ref);
});

class NewsFeedState {
  const NewsFeedState({
    required this.posts,
    required this.followedAuthorIds,
    required this.users,
    required this.isLoading,
    required this.lastUpdatedAt,
  });

  final List<NewsPost> posts;
  final List<String> followedAuthorIds;
  final List<UserProfile> users;
  final bool isLoading;
  final DateTime? lastUpdatedAt;

  NewsFeedState copyWith({
    List<NewsPost>? posts,
    List<String>? followedAuthorIds,
    List<UserProfile>? users,
    bool? isLoading,
    DateTime? lastUpdatedAt,
  }) {
    return NewsFeedState(
      posts: posts ?? this.posts,
      followedAuthorIds: followedAuthorIds ?? this.followedAuthorIds,
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

class NewsFeedController extends StateNotifier<AsyncValue<NewsFeedState>> {
  NewsFeedController(this._ref)
      : _firebaseService = _ref.read(firebaseServiceProvider),
        _emailService = _ref.read(farmEmailServiceProvider),
        super(const AsyncValue.loading()) {
    loadFeed();
  }

  final Ref _ref;
  final FirebaseService _firebaseService;
  final FarmEmailService _emailService;
  static const String _followKey = 'news_followed_authors';
  static const String _followCollection = 'news_following';
  static const String _followDocId = 'current';
  static const String _collection = 'news_posts';
  final Uuid _uuid = const Uuid();

  Future<void> loadFeed() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    try {
      final List<NewsPost> remotePosts = await _loadRemotePosts();
      final List<String> followed = await _loadFollowedAuthors();
      final List<UserProfile> users = await _loadUsers();
      // Starter posts only fill the feed while there's no real content yet -
      // otherwise their hardcoded "now.subtract(...)" timestamps would make
      // them look freshly posted forever, permanently crowding out real posts.
      final List<NewsPost> posts =
          remotePosts.isEmpty ? _seedPosts() : remotePosts;
      posts.sort((NewsPost a, NewsPost b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      state = AsyncValue.data(
        NewsFeedState(
          posts: posts,
          followedAuthorIds: followed,
          users: users,
          isLoading: false,
          lastUpdatedAt: DateTime.now(),
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => loadFeed();

  List<NewsPost> _currentPosts() => state.valueOrNull?.posts ?? <NewsPost>[];

  List<String> _currentFollowedAuthors() => state.valueOrNull?.followedAuthorIds ?? <String>[];

  List<UserProfile> _currentUsers() => state.valueOrNull?.users ?? <UserProfile>[];

  Future<List<NewsPost>> _loadRemotePosts() async {
    if (_firebaseService.currentUser == null) {
      return <NewsPost>[];
    }
    final List<Map<String, dynamic>> records = await _firebaseService.getGlobalFromFirestore(_collection);
    return records
        .map(NewsPost.fromJson)
        .where((NewsPost post) => post.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<UserProfile>> _loadUsers() async {
    if (_firebaseService.currentUser == null) {
      return <UserProfile>[];
    }
    try {
      final List<UserProfile> users = await _firebaseService.getAllUserProfiles();
      users.sort((UserProfile a, UserProfile b) => b.updatedAt.compareTo(a.updatedAt));
      return users;
    } catch (_) {
      return <UserProfile>[];
    }
  }

  Future<List<String>> _loadFollowedAuthors() async {
    if (_firebaseService.currentUser != null) {
      try {
        final List<Map<String, dynamic>> records = await _firebaseService.getFromFirestore(_followCollection);
        if (records.isNotEmpty) {
          final List<String> remoteFollowed = (records.first['authorIds'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList(growable: false) ??
              <String>[];
          await _saveFollowedAuthors(remoteFollowed);
          return remoteFollowed;
        }
      } catch (_) {
        // Fall back to local cache when cloud follow sync is unavailable.
      }
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_followKey) ?? <String>[];
  }

  Future<void> _saveFollowedAuthors(List<String> followed) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> unique = followed.toSet().toList(growable: false);
    await prefs.setStringList(_followKey, unique);
    if (_firebaseService.currentUser != null) {
      try {
        await _firebaseService.syncToFirestore(_followCollection, <String, dynamic>{
          'id': _followDocId,
          'authorIds': unique,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Keep the local cache if remote sync fails.
      }
    }
  }

  List<NewsPost> _seedPosts() {
    final DateTime now = DateTime.now();
    return <NewsPost>[
      _seedPost(
        id: 'admin-innovation-1',
        title: 'New irrigation idea for dry spells',
        body: 'Try simple moisture scheduling and drip line checks before the field begins to stress. Small water adjustments often save a crop in the hot season.',
        category: 'Innovation',
        authorName: 'FarmSync Admin',
        createdAt: now.subtract(const Duration(hours: 5)),
        tags: <String>['irrigation', 'innovation', 'water'],
      ),
      _seedPost(
        id: 'admin-product-1',
        title: 'Product spotlight: improved seed and input packs',
        body: 'Share trusted seed sources, fertilizer blends, and local supply updates so nearby farmers can make faster decisions without leaving the app.',
        category: 'Product',
        authorName: 'FarmSync Admin',
        createdAt: now.subtract(const Duration(days: 1)),
        tags: <String>['product', 'inputs', 'market'],
      ),
      _seedPost(
        id: 'admin-market-1',
        title: 'Market tip: post harvest quickly and sort by grade',
        body: 'Good grading, clean packaging, and quick listing can lift farm income. Use the feed to share local buyers, prices, and transport updates.',
        category: 'Market',
        authorName: 'FarmSync Admin',
        createdAt: now.subtract(const Duration(days: 2)),
        tags: <String>['market', 'sales', 'harvest'],
      ),
      _seedPost(
        id: 'admin-training-1',
        title: 'Training note: keep farm records daily',
        body: 'A few minutes of daily logging improves reports, reminders, and profit analysis. Record inputs, labour, and field events while they are fresh.',
        category: 'Training',
        authorName: 'FarmSync Admin',
        createdAt: now.subtract(const Duration(days: 3)),
        tags: <String>['training', 'records', 'finance'],
      ),
    ]..shuffle(Random(now.day));
  }

  NewsPost _seedPost({
    required String id,
    required String title,
    required String body,
    required String category,
    required String authorName,
    required DateTime createdAt,
    required List<String> tags,
  }) {
    return NewsPost(
      id: id,
      authorId: 'admin',
      authorName: authorName,
      authorWhatsapp: '',
      title: title,
      body: body,
      category: category,
      createdAt: createdAt,
      updatedAt: createdAt,
      isAdminPost: true,
      repostCount: 0,
      commentCount: 0,
      likeCount: 0,
      visibility: NewsPostVisibility.public,
      tags: tags,
    );
  }

  Future<void> toggleFollow(String authorId) async {
    final List<String> followed = _currentFollowedAuthors().toList(growable: true);
    if (followed.contains(authorId)) {
      followed.remove(authorId);
    } else {
      followed.add(authorId);
    }
    await _saveFollowedAuthors(followed);
    if (!mounted) return;
    final NewsFeedState? current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(followedAuthorIds: followed));
    }
  }

  Future<void> createPost({
    required String title,
    required String body,
    required String category,
    required List<String> tags,
    required String whatsappHandle,
    bool isAdminPost = false,
    String coverImageBase64 = '',
    String coverImageName = '',
    String location = '',
    String linkUrl = '',
    NewsPostVisibility visibility = NewsPostVisibility.public,
  }) async {
    final UserProfile? profile = _ref.read(userProfileProvider).valueOrNull;
    final FirebaseService firebaseService = _ref.read(firebaseServiceProvider);
    final DateTime now = DateTime.now();
    final NewsPost post = NewsPost(
      id: _uuid.v4(),
      authorId: isAdminPost ? 'admin' : (firebaseService.currentUser?.uid ?? profile?.uid ?? 'local-user'),
      authorName: isAdminPost
          ? 'FarmSync Admin'
          : (profile?.fullName.isNotEmpty == true
              ? profile!.fullName
              : (firebaseService.currentUser?.displayName ?? 'Farmer')),
      authorWhatsapp: whatsappHandle,
      authorAvatar: profile?.profileImageBase64 ?? '',
      title: title,
      body: body,
      category: category,
      coverImageBase64: coverImageBase64,
      coverImageName: coverImageName,
      tags: tags,
      location: location,
      linkUrl: linkUrl,
      createdAt: now,
      updatedAt: now,
      isAdminPost: isAdminPost,
      repostCount: 0,
      commentCount: 0,
      likeCount: 0,
      visibility: visibility,
    );

    await _firebaseService.syncGlobalToFirestore(_collection, post.toJson());
    await _insertLocalPost(post);
    await _ref.read(notificationsProvider.notifier).publishNotification(
          title: isAdminPost ? 'Admin news update' : 'New farmer update',
          message: title,
          type: NotificationType.info,
          actionUrl: '/news',
          audience: 'all',
          metadata: <String, dynamic>{
            'source': 'news',
            'postId': post.id,
            'category': category,
            'authorId': post.authorId,
          },
        );
    await _sendNewsEmail(
      title: title,
      category: category,
      summary: body.length > 160 ? '${body.substring(0, 160)}...' : body,
      isPost: true,
    );
  }

  Future<void> updatePost(NewsPost post) async {
    final DateTime now = DateTime.now();
    final NewsPost updated = post.copyWith(updatedAt: now, isEdited: true);
    await _firebaseService.syncGlobalToFirestore(_collection, updated.toJson());
    await _replaceLocalPost(updated);
    await _sendNewsEmail(
      title: post.title,
      category: post.category,
      summary: 'A new comment was added to your post.',
      isPost: false,
    );
  }

  Future<void> deletePost(String postId) async {
    await _firebaseService.deleteGlobalFromFirestore(_collection, postId);
    final List<NewsPost> posts = _currentPosts().where((NewsPost item) => item.id != postId).toList(growable: false);
    if (!mounted) return;
    final NewsFeedState? current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(posts: posts));
    }
  }

  Future<void> repostPost(NewsPost post) async {
    final UserProfile? profile = _ref.read(userProfileProvider).valueOrNull;
    final FirebaseService firebaseService = _ref.read(firebaseServiceProvider);
    final DateTime now = DateTime.now();
    final NewsPost repost = NewsPost(
      id: _uuid.v4(),
      authorId: firebaseService.currentUser?.uid ?? profile?.uid ?? 'local-user',
      authorName: profile?.fullName.isNotEmpty == true ? profile!.fullName : (firebaseService.currentUser?.displayName ?? 'Farmer'),
      authorWhatsapp: profile?.phoneNumber ?? '',
      authorAvatar: profile?.profileImageBase64 ?? '',
      title: post.title,
      body: 'Reposted: ${post.body}',
      category: post.category,
      coverImageBase64: post.coverImageBase64,
      coverImageName: post.coverImageName,
      sourcePostId: post.id,
      repostedById: firebaseService.currentUser?.uid ?? profile?.uid ?? '',
      tags: post.tags,
      location: post.location,
      linkUrl: post.linkUrl,
      createdAt: now,
      updatedAt: now,
      isAdminPost: false,
      repostCount: 0,
      commentCount: 0,
      likeCount: 0,
      visibility: post.visibility,
    );
    await _firebaseService.syncGlobalToFirestore(_collection, repost.toJson());
    await _insertLocalPost(repost);
    await _ref.read(notificationsProvider.notifier).publishNotification(
          title: 'News reposted',
          message: '${repost.authorName} reposted: ${post.title}',
          type: NotificationType.info,
          actionUrl: '/news',
          audience: 'all',
          metadata: <String, dynamic>{
            'source': 'news',
            'postId': repost.id,
            'sourcePostId': post.id,
            'authorId': repost.authorId,
          },
        );

    final List<NewsPost> current = _currentPosts();
    final int sourceIndex = current.indexWhere((NewsPost item) => item.id == post.id);
    if (sourceIndex != -1) {
      final NewsPost updatedSource = current[sourceIndex].copyWith(
        repostCount: current[sourceIndex].repostCount + 1,
        updatedAt: now,
      );
      await _firebaseService.syncGlobalToFirestore(_collection, updatedSource.toJson());
      await _replaceLocalPost(updatedSource);
    }
  }

  Future<void> addComment(String postId, String message) async {
    final UserProfile? profile = _ref.read(userProfileProvider).valueOrNull;
    final FirebaseService firebaseService = _ref.read(firebaseServiceProvider);
    final List<NewsPost> current = _currentPosts();
    final int index = current.indexWhere((NewsPost item) => item.id == postId);
    if (index == -1) return;
    final DateTime now = DateTime.now();
    final NewsPost post = current[index];
    final NewsComment comment = NewsComment(
      id: _uuid.v4(),
      authorId: firebaseService.currentUser?.uid ?? profile?.uid ?? 'local-user',
      authorName: profile?.fullName.isNotEmpty == true ? profile!.fullName : (firebaseService.currentUser?.displayName ?? 'Farmer'),
      authorWhatsapp: profile?.phoneNumber ?? '',
      message: message.trim(),
      createdAt: now,
    );
    final NewsPost updated = post.copyWith(
      comments: <NewsComment>[comment, ...post.comments],
      commentCount: post.commentCount + 1,
      updatedAt: now,
    );
    await _firebaseService.syncGlobalToFirestore(_collection, updated.toJson());
    await _replaceLocalPost(updated);
    await _ref.read(notificationsProvider.notifier).publishNotification(
          title: 'New comment on news',
          message: '${comment.authorName}: ${comment.message}',
          type: NotificationType.info,
          actionUrl: '/news',
          audience: 'single',
          targetUserId: post.authorId,
          metadata: <String, dynamic>{
            'source': 'news',
            'postId': post.id,
            'commentId': comment.id,
            'authorId': comment.authorId,
          },
        );
  }

  bool canEditPost(NewsPost post) {
    final String? uid = _firebaseService.currentUser?.uid;
    return uid != null && post.authorId == uid;
  }

  List<NewsPost> generalFeed() {
    final List<NewsPost> posts = List<NewsPost>.from(_currentPosts())
      ..removeWhere((NewsPost post) => !post.isAdminPost && post.visibility == NewsPostVisibility.followersOnly)
      ..shuffle(Random(DateTime.now().day + DateTime.now().month));
    return posts;
  }

  List<NewsPost> forYouFeed() {
    final Set<String> followed = _currentFollowedAuthors().toSet();
    return _currentPosts()
        .where((NewsPost post) => post.isAdminPost || followed.contains(post.authorId))
        .toList(growable: false)
      ..sort((NewsPost a, NewsPost b) => b.createdAt.compareTo(a.createdAt));
  }

  List<NewsPost> myPosts() {
    final String? uid = _firebaseService.currentUser?.uid;
    if (uid == null) return <NewsPost>[];
    return _currentPosts()
        .where((NewsPost post) => post.authorId == uid)
        .toList(growable: false)
      ..sort((NewsPost a, NewsPost b) => b.createdAt.compareTo(a.createdAt));
  }

  List<NewsPost> followingPosts() {
    final Set<String> followed = _currentFollowedAuthors().toSet();
    return _currentPosts()
        .where((NewsPost post) => post.isAdminPost || followed.contains(post.authorId))
        .toList(growable: false)
      ..sort((NewsPost a, NewsPost b) => b.createdAt.compareTo(a.createdAt));
  }

  UserProfile? userForAuthor(String authorId) {
    for (final UserProfile profile in _currentUsers()) {
      if (profile.uid == authorId) {
        return profile;
      }
    }
    return null;
  }

  List<UserProfile> suggestedPeople({String query = ''}) {
    final String normalizedQuery = query.trim().toLowerCase();
    final Set<String> followed = _currentFollowedAuthors().toSet();
    final String? currentUserId = _firebaseService.currentUser?.uid;
    final List<UserProfile> users = _currentUsers()
        .where((UserProfile profile) => profile.uid.isNotEmpty && profile.uid != currentUserId)
        .where((UserProfile profile) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          final String haystack =
              '${profile.fullName} ${profile.email} ${profile.phoneNumber} ${profile.ward} ${profile.primaryFocus} ${profile.bio}'
                  .toLowerCase();
          return haystack.contains(normalizedQuery);
        })
        .toList(growable: false);

    users.sort((UserProfile a, UserProfile b) {
      final bool aFollowed = followed.contains(a.uid);
      final bool bFollowed = followed.contains(b.uid);
      if (aFollowed != bFollowed) {
        return aFollowed ? 1 : -1;
      }
      if (a.isVerified != b.isVerified) {
        return a.isVerified ? -1 : 1;
      }
      if (a.isComplete != b.isComplete) {
        return a.isComplete ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return users.take(12).toList(growable: false);
  }

  Future<void> _insertLocalPost(NewsPost post) async {
    final List<NewsPost> next = <NewsPost>[post, ..._currentPosts()];
    if (!mounted) return;
    final NewsFeedState? current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(posts: next, lastUpdatedAt: DateTime.now()));
    }
  }

  Future<void> _replaceLocalPost(NewsPost post) async {
    final List<NewsPost> next = _currentPosts()
        .map((NewsPost item) => item.id == post.id ? post : item)
        .toList(growable: false);
    if (!mounted) return;
    final NewsFeedState? current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(posts: next, lastUpdatedAt: DateTime.now()));
    }
  }

  Future<void> _sendNewsEmail({
    required String title,
    required String category,
    required String summary,
    required bool isPost,
  }) async {
    final String email = _firebaseService.currentUser?.email ?? '';
    if (email.isEmpty) {
      return;
    }
    final String displayName = _firebaseService.currentUser?.displayName?.trim() ?? '';
    final String recipientName = displayName.isNotEmpty ? displayName : email.split('@').first;
    await _emailService.sendNewsUpdateNotification(
      toEmail: email,
      recipientName: recipientName,
      title: title,
      category: isPost ? 'News update' : 'Community response',
      summary: summary,
    );
  }
}
