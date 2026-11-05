import 'package:farmsynchub/domain/models/news_post.dart';
import 'package:farmsynchub/presentation/screens/dashboard/widgets/latest_news_carousel.dart';
import 'package:flutter_test/flutter_test.dart';

NewsPost _post(
  String id, {
  required DateTime at,
  String title = 'Title',
  bool admin = false,
  NewsPostVisibility visibility = NewsPostVisibility.public,
  String sourcePostId = '',
}) {
  return NewsPost(
    id: id,
    authorId: 'author-$id',
    authorName: 'Author',
    authorWhatsapp: '',
    title: title,
    body: 'Body',
    category: 'General',
    createdAt: at,
    updatedAt: at,
    isAdminPost: admin,
    repostCount: 0,
    commentCount: 0,
    likeCount: 0,
    visibility: visibility,
    sourcePostId: sourcePostId,
  );
}

void main() {
  final DateTime base = DateTime(2026, 11, 1);

  group('latestNewsHighlights', () {
    test('returns at most five, newest first', () {
      final List<NewsPost> posts = <NewsPost>[
        for (int i = 0; i < 8; i++) _post('p$i', at: base.add(Duration(days: i))),
      ];
      final List<NewsPost> result = latestNewsHighlights(posts);
      expect(result.length, 5);
      expect(result.first.id, 'p7');
      expect(result.last.id, 'p3');
    });

    test('hides followers-only posts from non-admins but keeps admin ones', () {
      final List<NewsPost> result = latestNewsHighlights(<NewsPost>[
        _post('private',
            at: base.add(const Duration(days: 3)),
            visibility: NewsPostVisibility.followersOnly),
        _post('official',
            at: base.add(const Duration(days: 2)),
            admin: true,
            visibility: NewsPostVisibility.followersOnly),
        _post('public', at: base.add(const Duration(days: 1))),
      ]);
      expect(result.map((NewsPost p) => p.id), <String>['official', 'public']);
    });

    test('puts original posts before reposts', () {
      final List<NewsPost> result = latestNewsHighlights(<NewsPost>[
        _post('repost',
            at: base.add(const Duration(days: 5)), sourcePostId: 'orig'),
        _post('original', at: base.add(const Duration(days: 1))),
      ]);
      expect(result.map((NewsPost p) => p.id), <String>['original', 'repost']);
    });

    test('skips posts without a title and handles an empty feed', () {
      expect(latestNewsHighlights(<NewsPost>[]), isEmpty);
      expect(
        latestNewsHighlights(<NewsPost>[_post('blank', at: base, title: '  ')]),
        isEmpty,
      );
    });
  });
}
