enum NewsPostVisibility {
  public,
  followersOnly,
}

class NewsComment {
  const NewsComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorWhatsapp,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorWhatsapp;
  final String message;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorWhatsapp': authorWhatsapp,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
      };

  factory NewsComment.fromJson(Map<String, dynamic> json) {
    return NewsComment(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorWhatsapp: json['authorWhatsapp'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class NewsPost {
  const NewsPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorWhatsapp,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    required this.isAdminPost,
    required this.repostCount,
    required this.commentCount,
    required this.likeCount,
    required this.visibility,
    this.authorAvatar = '',
    this.coverImageBase64 = '',
    this.coverImageName = '',
    this.sourcePostId = '',
    this.repostedById = '',
    this.comments = const <NewsComment>[],
    this.tags = const <String>[],
    this.location = '',
    this.linkUrl = '',
    this.isEdited = false,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorWhatsapp;
  final String authorAvatar;
  final String title;
  final String body;
  final String category;
  final String coverImageBase64;
  final String coverImageName;
  final String sourcePostId;
  final String repostedById;
  final List<NewsComment> comments;
  final List<String> tags;
  final String location;
  final String linkUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isAdminPost;
  final int repostCount;
  final int commentCount;
  final int likeCount;
  final bool isEdited;
  final NewsPostVisibility visibility;

  bool get hasImage => coverImageBase64.isNotEmpty;
  bool get isRepost => sourcePostId.isNotEmpty;

  NewsPost copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorWhatsapp,
    String? authorAvatar,
    String? title,
    String? body,
    String? category,
    String? coverImageBase64,
    String? coverImageName,
    String? sourcePostId,
    String? repostedById,
    List<NewsComment>? comments,
    List<String>? tags,
    String? location,
    String? linkUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAdminPost,
    int? repostCount,
    int? commentCount,
    int? likeCount,
    bool? isEdited,
    NewsPostVisibility? visibility,
  }) {
    return NewsPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorWhatsapp: authorWhatsapp ?? this.authorWhatsapp,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
      coverImageName: coverImageName ?? this.coverImageName,
      sourcePostId: sourcePostId ?? this.sourcePostId,
      repostedById: repostedById ?? this.repostedById,
      comments: comments ?? this.comments,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      linkUrl: linkUrl ?? this.linkUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAdminPost: isAdminPost ?? this.isAdminPost,
      repostCount: repostCount ?? this.repostCount,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      isEdited: isEdited ?? this.isEdited,
      visibility: visibility ?? this.visibility,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorWhatsapp': authorWhatsapp,
        'authorAvatar': authorAvatar,
        'title': title,
        'body': body,
        'category': category,
        'coverImageBase64': coverImageBase64,
        'coverImageName': coverImageName,
        'sourcePostId': sourcePostId,
        'repostedById': repostedById,
        'comments': comments.map((NewsComment comment) => comment.toJson()).toList(growable: false),
        'tags': tags,
        'location': location,
        'linkUrl': linkUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isAdminPost': isAdminPost,
        'repostCount': repostCount,
        'commentCount': commentCount,
        'likeCount': likeCount,
        'isEdited': isEdited,
        'visibility': visibility.name,
      };

  factory NewsPost.fromJson(Map<String, dynamic> json) {
    return NewsPost(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorWhatsapp: json['authorWhatsapp'] as String? ?? '',
      authorAvatar: json['authorAvatar'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      coverImageBase64: json['coverImageBase64'] as String? ?? '',
      coverImageName: json['coverImageName'] as String? ?? '',
      sourcePostId: json['sourcePostId'] as String? ?? '',
      repostedById: json['repostedById'] as String? ?? '',
      comments: _jsonList(json['comments']).map(NewsComment.fromJson).toList(growable: false),
      tags: (json['tags'] as List<dynamic>?)?.whereType<String>().toList(growable: false) ?? <String>[],
      location: json['location'] as String? ?? '',
      linkUrl: json['linkUrl'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      isAdminPost: json['isAdminPost'] as bool? ?? false,
      repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isEdited: json['isEdited'] as bool? ?? false,
      visibility: NewsPostVisibility.values.firstWhere(
        (NewsPostVisibility value) => value.name == json['visibility'],
        orElse: () => NewsPostVisibility.public,
      ),
    );
  }
}

List<Map<String, dynamic>> _jsonList(Object? value) {
  if (value is! Iterable) {
    return <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((Map item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
