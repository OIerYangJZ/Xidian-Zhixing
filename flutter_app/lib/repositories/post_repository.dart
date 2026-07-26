import 'dart:math' as math;

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../models/comment_item.dart';
import '../models/post_item.dart';
import '../models/uploaded_image_item.dart';

enum PostSort { latest, hot, likes }

enum CommentSort { latest, hot }

extension PostSortCodec on PostSort {
  String get apiValue {
    switch (this) {
      case PostSort.latest:
        return 'latest';
      case PostSort.hot:
        return 'hot';
      case PostSort.likes:
        return 'likes';
    }
  }

  String get label {
    switch (this) {
      case PostSort.latest:
        return '按发布时间';
      case PostSort.hot:
        return '热度排序';
      case PostSort.likes:
        return '按点赞量';
    }
  }
}

extension CommentSortCodec on CommentSort {
  String get apiValue {
    switch (this) {
      case CommentSort.latest:
        return 'latest';
      case CommentSort.hot:
        return 'hot';
    }
  }
}

List<PostItem> sortPostsForView(
  Iterable<PostItem> posts, {
  PostSort sort = PostSort.latest,
  DateTime? now,
}) {
  final DateTime anchor = now ?? DateTime.now();
  final List<PostItem> activePinned = <PostItem>[];
  final List<PostItem> normalPosts = <PostItem>[];

  for (final PostItem post in posts) {
    if (_isActivePinned(post, anchor)) {
      activePinned.add(post);
    } else {
      normalPosts.add(post);
    }
  }

  activePinned.sort((PostItem a, PostItem b) {
    final int byPinStart = _safeDate(
      b.pinStartedAt ?? b.createdAt,
    ).compareTo(_safeDate(a.pinStartedAt ?? a.createdAt));
    if (byPinStart != 0) {
      return byPinStart;
    }
    return _compareByLatest(a, b);
  });

  switch (sort) {
    case PostSort.hot:
      normalPosts.sort((PostItem a, PostItem b) {
        final int byHot = _hotScore(b, anchor).compareTo(_hotScore(a, anchor));
        if (byHot != 0) {
          return byHot;
        }
        final int byEngagement = _engagementScore(
          b,
        ).compareTo(_engagementScore(a));
        if (byEngagement != 0) {
          return byEngagement;
        }
        return _compareByLatest(a, b);
      });
      break;
    case PostSort.likes:
      normalPosts.sort((PostItem a, PostItem b) {
        final int byLikes = b.likeCount.compareTo(a.likeCount);
        if (byLikes != 0) {
          return byLikes;
        }
        return _compareByLatest(a, b);
      });
      break;
    case PostSort.latest:
      normalPosts.sort(_compareByLatest);
      break;
  }

  return <PostItem>[...activePinned, ...normalPosts];
}

bool _isActivePinned(PostItem post, DateTime now) {
  if (!post.isPinned) {
    return false;
  }
  if (post.pinStartedAt != null && post.pinStartedAt!.isAfter(now)) {
    return false;
  }
  if (post.pinExpiresAt != null && !post.pinExpiresAt!.isAfter(now)) {
    return false;
  }
  return true;
}

int _compareByLatest(PostItem a, PostItem b) {
  final int byCreated = b.createdAt.compareTo(a.createdAt);
  if (byCreated != 0) {
    return byCreated;
  }
  return b.id.compareTo(a.id);
}

int _engagementScore(PostItem post) {
  final int cappedViews = math.min(post.viewCount, 500);
  return (post.likeCount * 3) +
      (post.commentCount * 5) +
      (post.favoriteCount * 2) +
      cappedViews;
}

double _hotScore(PostItem post, DateTime now) {
  final double ageHours = math.max(
    1,
    now.difference(post.createdAt).inMinutes.abs() / 60.0,
  );
  final double engagement = _engagementScore(post).toDouble();
  final double decay = math.pow(ageHours + 2, 0.85).toDouble();
  final double recencyTieBreaker =
      post.createdAt.millisecondsSinceEpoch / 1000000000000000.0;
  return (engagement / decay) + recencyTieBreaker;
}

DateTime _safeDate(DateTime value) => value.toUtc();

List<CommentItem> sortCommentsForView(
  Iterable<CommentItem> comments, {
  CommentSort sort = CommentSort.latest,
}) {
  final List<CommentItem> rows = comments.toList();
  switch (sort) {
    case CommentSort.hot:
      rows.sort((CommentItem a, CommentItem b) {
        final int byLikes = b.likeCount.compareTo(a.likeCount);
        if (byLikes != 0) {
          return byLikes;
        }
        final int byCreated = b.createdAt.compareTo(a.createdAt);
        if (byCreated != 0) {
          return byCreated;
        }
        return b.id.compareTo(a.id);
      });
      break;
    case CommentSort.latest:
      rows.sort((CommentItem a, CommentItem b) {
        final int byCreated = b.createdAt.compareTo(a.createdAt);
        if (byCreated != 0) {
          return byCreated;
        }
        return b.id.compareTo(a.id);
      });
      break;
  }
  return rows;
}

class CreatePostInput {
  CreatePostInput({
    required this.title,
    required this.content,
    this.contentFormat = 'plain',
    this.markdownSource,
    required this.channel,
    required this.tags,
    required this.allowComment,
    required this.allowDm,
    required this.privateOnly,
    required this.status,
    required this.hasImage,
    this.pinDurationMinutes,
    this.imageUploadIds = const <String>[],
    this.useAnonymousAlias = false,
    this.anonymousAlias,
  });

  final String title;
  final String content;
  final String contentFormat;
  final String? markdownSource;
  final String channel;
  final List<String> tags;
  final bool allowComment;
  final bool allowDm;
  final bool privateOnly;
  final PostStatus status;
  final bool hasImage;
  final int? pinDurationMinutes;
  final List<String> imageUploadIds;
  final bool useAnonymousAlias;
  final String? anonymousAlias;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'content': content,
      'contentFormat': contentFormat.trim().toLowerCase() == 'markdown'
          ? 'markdown'
          : 'plain',
      if ((markdownSource ?? '').trim().isNotEmpty)
        'markdownSource': markdownSource!.trim(),
      'channel': channel,
      'tags': tags,
      'allowComment': allowComment,
      'allowDm': allowDm,
      'visibility': privateOnly ? 'private' : 'public',
      'status': status.apiValue,
      'hasImage': hasImage || imageUploadIds.isNotEmpty,
      if (pinDurationMinutes != null && pinDurationMinutes! > 0)
        'pinDurationMinutes': pinDurationMinutes,
      'imageUploadIds': imageUploadIds,
      'useAnonymousAlias': useAnonymousAlias,
      if (anonymousAlias != null && anonymousAlias!.trim().isNotEmpty)
        'anonymousAlias': anonymousAlias!.trim(),
    };
  }
}

class FavoriteActionResult {
  FavoriteActionResult({required this.favorited, this.favoriteCount});

  final bool favorited;
  final int? favoriteCount;
}

class PinPostActionResult {
  PinPostActionResult({required this.mode, this.post});

  final String mode;
  final PostItem? post;

  bool get isDirect => mode == 'direct';
}

class ForumSection {
  const ForumSection({
    required this.id,
    required this.name,
    required this.type,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String type;
  final int sortOrder;

  factory ForumSection.fromJson(Map<String, dynamic> json) {
    final String? id = readString(json, <String>['sectionId', 'id']);
    final String? name = readString(json, <String>['sectionName', 'name']);
    final String? type = readString(json, <String>['sectionType']);
    final int? sortOrder = readInt(json, <String>['sortOrder']);
    if (id == null || name == null || type == null || sortOrder == null) {
      throw const FormatException('分区记录缺少必要字段');
    }
    return ForumSection(id: id, name: name, type: type, sortOrder: sortOrder);
  }
}

class PostRepository {
  PostRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<String>> fetchChannels() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.channels);
    final List<dynamic> list = extractList(response);
    final List<String> channels = list.map((dynamic item) {
      if (item is String) {
        return item.trim();
      }
      final Map<String, dynamic> map = asMap(item);
      return readString(map, <String>['name', 'title', 'channelName']) ?? '';
    }).toList();
    if (channels.any((String name) => name.isEmpty)) {
      throw const FormatException('频道列表包含无效记录');
    }
    return channels.toSet().toList();
  }

  Future<List<ForumSection>> fetchCollegeSections() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.sectionsTree);
    final Map<String, dynamic> tree = extractMap(response);
    final List<dynamic> colleges = asList(tree['colleges']);
    final List<ForumSection> sections = colleges
        .map((dynamic item) => ForumSection.fromJson(asMap(item)))
        .toList();
    if (sections.any((ForumSection section) => section.type != 'college')) {
      throw const FormatException('学院分区接口返回了非学院记录');
    }
    sections.sort(
      (ForumSection left, ForumSection right) =>
          left.sortOrder.compareTo(right.sortOrder),
    );
    return sections;
  }

  Future<List<PostItem>> fetchPosts({
    String? channel,
    String? keyword,
    bool? hasImage,
    bool? allowDm,
    PostStatus? status,
    PostSort sort = PostSort.latest,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      if (channel != null && channel != '全部') 'channel': channel,
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
      if (hasImage != null) 'hasImage': hasImage,
      if (allowDm != null) 'allowDm': allowDm,
      if (status != null) 'status': status.apiValue,
      'sort': sort.apiValue,
    };

    final dynamic response = await _apiClient.get(
      ApiEndpoints.posts,
      queryParameters: query,
    );
    final List<dynamic> list = extractList(response);
    final List<PostItem> posts = list
        .map((dynamic item) => PostItem.fromJson(asMap(item)))
        .toList();
    if (posts.any((PostItem post) => post.id.isEmpty)) {
      throw const FormatException('帖子列表包含无效记录');
    }
    return sortPostsForView(posts, sort: sort);
  }

  Future<List<PostItem>> fetchSectionPosts({
    required String sectionId,
    PostSort sort = PostSort.latest,
  }) async {
    if (sectionId.trim().isEmpty) {
      throw const FormatException('分区标识不能为空');
    }
    final dynamic response = await _apiClient.get(
      ApiEndpoints.sectionPosts(sectionId.trim()),
      queryParameters: <String, dynamic>{'sort': sort.apiValue},
    );
    final List<PostItem> posts = extractList(
      response,
    ).map((dynamic item) => PostItem.fromJson(asMap(item))).toList();
    if (posts.any((PostItem post) => post.id.isEmpty)) {
      throw const FormatException('学院分区帖子列表包含无效记录');
    }
    return sortPostsForView(posts, sort: sort);
  }

  Future<PostItem> fetchPostDetail(String postId) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.postById(postId),
    );
    final Map<String, dynamic> map = extractMap(response);
    if (map.isNotEmpty) {
      final PostItem post = PostItem.fromJson(map);
      if (post.id.isNotEmpty) {
        return post;
      }
    }
    throw const FormatException('帖子详情响应缺少有效帖子数据');
  }

  Future<PostItem> createPost(CreatePostInput input) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.posts,
      body: input.toJson(),
    );

    final Map<String, dynamic> map = extractMap(response);
    if (map.isNotEmpty) {
      final PostItem post = PostItem.fromJson(map);
      if (post.id.isNotEmpty) {
        return post;
      }
    }

    throw const FormatException('创建帖子响应缺少帖子数据');
  }

  Future<UploadedImageItem> uploadImage({
    required String fileName,
    required String contentType,
    required String dataBase64,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.uploadImages,
      body: <String, dynamic>{
        'fileName': fileName,
        'contentType': contentType,
        'dataBase64': dataBase64,
      },
    );
    final Map<String, dynamic> data = extractMap(response);
    if (data.isNotEmpty) {
      final UploadedImageItem item = UploadedImageItem.fromJson(data);
      if (item.id.isNotEmpty) {
        return item;
      }
    }
    throw const FormatException('图片上传响应缺少有效图片数据');
  }

  Future<List<UploadedImageItem>> fetchMyUploads() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myUploads);
    final List<dynamic> rows = extractList(response);
    final List<UploadedImageItem> items = rows
        .map((dynamic item) => UploadedImageItem.fromJson(asMap(item)))
        .toList();
    if (items.any((UploadedImageItem item) => item.id.isEmpty)) {
      throw const FormatException('上传图片列表包含无效记录');
    }
    return items;
  }

  Future<List<CommentItem>> fetchComments(
    String postId, {
    CommentSort sort = CommentSort.latest,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.postComments(postId),
      queryParameters: <String, dynamic>{'sort': sort.apiValue},
    );
    final List<dynamic> list = extractList(response);
    final List<CommentItem> comments = list
        .map((dynamic item) => CommentItem.fromJson(asMap(item)))
        .toList();
    if (comments.any(
      (CommentItem comment) => comment.id.isEmpty || comment.content.isEmpty,
    )) {
      throw const FormatException('评论列表包含无效记录');
    }
    return sortCommentsForView(comments, sort: sort);
  }

  Future<void> createComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    await _apiClient.post(
      ApiEndpoints.postComments(postId),
      body: <String, dynamic>{
        'content': content,
        if (parentId != null) 'parentId': parentId,
      },
    );
  }

  Future<void> likePost(String postId) {
    return _apiClient.post(
      ApiEndpoints.postLike(postId),
      body: const <String, dynamic>{},
    );
  }

  Future<void> unlikePost(String postId) {
    return _apiClient.post(
      ApiEndpoints.postLike(postId),
      body: const <String, dynamic>{},
    );
  }

  Future<void> likeComment(String commentId) {
    return _apiClient.post(
      ApiEndpoints.commentLike(commentId),
      body: const <String, dynamic>{},
    );
  }

  Future<void> unlikeComment(String commentId) {
    return _apiClient.delete(
      ApiEndpoints.commentLike(commentId),
      body: const <String, dynamic>{},
    );
  }

  Future<FavoriteActionResult> favoritePost(String postId) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.postFavorite(postId),
      body: const <String, dynamic>{},
    );
    return _parseFavoriteActionResult(response);
  }

  Future<FavoriteActionResult> unfavoritePost(String postId) async {
    final dynamic response = await _apiClient.delete(
      ApiEndpoints.postUnfavorite(postId),
      body: const <String, dynamic>{},
    );
    return _parseFavoriteActionResult(response);
  }

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) {
    return _apiClient.post(
      ApiEndpoints.reports,
      body: <String, dynamic>{
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
  }

  Future<List<PostItem>> fetchFavoritePosts() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.favoritePosts);
    final List<dynamic> list = extractList(response);
    final List<PostItem> posts = list
        .map((dynamic item) => PostItem.fromJson(asMap(item)))
        .toList();
    if (posts.any((PostItem post) => post.id.isEmpty)) {
      throw const FormatException('收藏帖子列表包含无效记录');
    }
    return posts;
  }

  Future<List<PostItem>> fetchUserPosts(String userId) async {
    final Map<String, dynamic> query = {'authorId': userId};
    final dynamic response = await _apiClient.get(
      ApiEndpoints.posts,
      queryParameters: query,
    );
    final List<dynamic> list = extractList(response);
    final List<PostItem> posts = list
        .map((dynamic item) => PostItem.fromJson(asMap(item)))
        .toList();
    if (posts.any((PostItem post) => post.id.isEmpty)) {
      throw const FormatException('用户帖子列表包含无效记录');
    }
    return posts;
  }

  Future<List<PostItem>> fetchMyPosts() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myPosts);
    final List<dynamic> list = extractList(response);
    final List<PostItem> posts = list
        .map((dynamic item) => PostItem.fromJson(asMap(item)))
        .toList();
    if (posts.any((PostItem post) => post.id.isEmpty)) {
      throw const FormatException('我的帖子列表包含无效记录');
    }
    return posts;
  }

  Future<void> updateMyPostStatus({
    required String postId,
    required PostStatus status,
  }) {
    return _apiClient.patch(
      ApiEndpoints.postById(postId),
      body: <String, dynamic>{'status': status.apiValue},
    );
  }

  Future<void> deleteMyPost(String postId) {
    return _apiClient.delete(ApiEndpoints.postById(postId));
  }

  Future<int?> incrementView(String postId) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.postView(postId),
      body: const <String, dynamic>{},
    );
    final Map<String, dynamic> map = extractMap(response);
    final int? viewCount = readInt(map, <String>['viewCount']);
    if (viewCount == null) {
      throw const FormatException('阅读量响应缺少 viewCount');
    }
    return viewCount;
  }

  Future<PinPostActionResult> submitPinRequest({
    required String postId,
    required int durationMinutes,
    String? reason,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.postPinRequest(postId),
      body: <String, dynamic>{
        'durationMinutes': durationMinutes,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final Map<String, dynamic> map = extractMap(response);
    final String mode = (readString(map, <String>['mode']) ?? '').trim();
    if (mode != 'direct' && mode != 'pending') {
      throw const FormatException('置顶申请响应包含无效 mode');
    }
    final Map<String, dynamic> postMap = asMap(map['post']);
    if (mode == 'direct' && postMap.isEmpty) {
      throw const FormatException('直接置顶响应缺少帖子数据');
    }
    return PinPostActionResult(
      mode: mode,
      post: postMap.isEmpty ? null : PostItem.fromJson(postMap),
    );
  }

  FavoriteActionResult _parseFavoriteActionResult(dynamic response) {
    final Map<String, dynamic> map = extractMap(response);
    if (map.isEmpty) {
      throw const FormatException('收藏操作响应缺少数据');
    }
    final bool? favorited = readBool(map, <String>['favorited', 'isFavorited']);
    if (favorited == null) {
      throw const FormatException('收藏操作响应缺少 favorited 状态');
    }
    return FavoriteActionResult(
      favorited: favorited,
      favoriteCount: readInt(map, <String>['favoriteCount', 'collectCount']),
    );
  }
}
