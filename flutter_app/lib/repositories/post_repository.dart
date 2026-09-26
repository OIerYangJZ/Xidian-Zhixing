import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../models/comment_item.dart';
import '../models/post_item.dart';
import '../models/section_item.dart';
import '../models/uploaded_image_item.dart';
import '../core/l10n/ui_text.dart';

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

  String labelFor(Locale locale) {
    switch (this) {
      case PostSort.latest:
        return uiTextFor(locale, zh: '按发布时间', en: 'By date');
      case PostSort.hot:
        return uiTextFor(locale, zh: '热度排序', en: 'By activity');
      case PostSort.likes:
        return uiTextFor(locale, zh: '按点赞量', en: 'By likes');
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
    required this.section,
    this.publisherClub,
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
  final SectionItem section;

  /// Posts to a club section are published as that club.
  final ClubItem? publisherClub;
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
      'sectionType': section.sectionType,
      'sectionId': section.key,
      'sectionName': section.sectionName,
      if (publisherClub != null) ...<String, dynamic>{
        'publisherType': 'club',
        'publisherClubId': publisherClub!.id,
      },
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

/// Posts per feed page.
const int postPageSize = 20;

/// What the server accepts for a post (backend/handlers/_post_handler.py).
abstract final class PostLimits {
  static const int title = 200;

  /// Plain-text body; for Markdown the server checks the rendered text too.
  static const int plainContent = 10000;
  static const int markdownSource = 20000;

  /// Explicit tags plus the #tags written in the title and body.
  static const int tags = 10;
  static const int tagLength = 40;

  /// The server's inline-tag pattern: # then 1–30 letters, digits, _ or -.
  // The server's _extract_inline_tags: Python's Unicode \w (letters, digits,
  // marks, underscore) plus '-'.
  static final RegExp _inlineTag = RegExp(
    r'#([\p{L}\p{N}\p{M}_-]{1,30})',
    unicode: true,
  );

  /// The tags the server will store: [explicit] first, then each new inline
  /// #tag from [title] and [content], as _post_handler.handle_create_post
  /// merges them.
  static List<String> mergedTags(
    List<String> explicit,
    String title,
    String content,
  ) {
    final List<String> merged = <String>[...explicit];
    for (final String text in <String>[title, content]) {
      for (final RegExpMatch match in _inlineTag.allMatches(text)) {
        final String tag = match.group(1)!.trim();
        if (tag.isNotEmpty && !merged.contains(tag)) merged.add(tag);
      }
    }
    return merged;
  }

  /// Why the server would refuse these tags, or null.
  static String? tagProblem(
    List<String> explicit,
    String title,
    String content,
  ) {
    final List<String> merged = mergedTags(explicit, title, content);
    final String? tooLong = merged
        .where((String tag) => tag.runes.length > tagLength)
        .firstOrNull;
    if (tooLong != null) {
      return uiTextGlobal(
        zh: '标签「$tooLong」超过 $tagLength 个字',
        en: 'The tag "$tooLong" is longer than $tagLength characters',
      );
    }
    if (merged.length > tags) {
      return uiTextGlobal(
        zh: '标签最多 $tags 个（含标题和正文里的 #话题），当前 ${merged.length} 个',
        en: 'At most $tags tags, counting #topics in the title and body; this post has ${merged.length}',
      );
    }
    return null;
  }
}

class PostPage {
  const PostPage({required this.items, required this.hasMore});

  final List<PostItem> items;
  final bool hasMore;
}

class FavoriteActionResult {
  FavoriteActionResult({required this.favorited, required this.favoriteCount});

  final bool favorited;
  final int favoriteCount;
}

/// POST /posts/<id>/like answers the state and the post's like count.
class LikeActionResult {
  LikeActionResult({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;
}

class PinPostActionResult {
  PinPostActionResult({required this.mode, this.post});

  final String mode;
  final PostItem? post;

  bool get isDirect => mode == 'direct';
}

class PostRepository {
  PostRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Every enabled 分区 (综合, colleges, clubs), in the server's order.
  Future<List<SectionItem>> fetchSections() async {
    final dynamic response = await _apiClient.get('/sections/tree');
    final Map<String, dynamic> tree = extractMap(response);
    final dynamic rows = tree['sections'];
    if (rows is! List) {
      throw FormatException(
        uiTextGlobal(
          zh: '分区响应缺少 sections',
          en: 'The section response is missing sections',
        ),
      );
    }
    return rows
        .map((dynamic row) => SectionItem.fromJson(asMap(row)))
        .toSet()
        .toList(growable: false);
  }

  /// Active clubs, each saying whether the viewer may post as it.
  Future<List<ClubItem>> fetchClubs() async {
    final dynamic response = await _apiClient.get('/clubs');
    return extractList(response)
        .map((dynamic row) => ClubItem.fromJson(asMap(row)))
        .toList(growable: false);
  }

  /// One page of the feed, in the server's order (pinned first, then [sort]).
  Future<PostPage> fetchPostPage({
    SectionItem? section,
    PostSort sort = PostSort.latest,
    required int page,
    int limit = postPageSize,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.posts,
      queryParameters: <String, dynamic>{
        ..._postQuery(section: section, sort: sort),
        'page': page,
        'limit': limit,
      },
    );
    final Map<String, dynamic> data = extractMap(response);
    final dynamic rows = data['items'];
    final bool? hasMore = readBool(data, <String>['hasMore']);
    if (rows is! List || hasMore == null) {
      throw FormatException(
        uiTextGlobal(zh: '帖子分页响应格式无效', en: 'The post page response is invalid'),
      );
    }
    return PostPage(items: _parsePosts(rows), hasMore: hasMore);
  }

  /// Every matching post (search filters and sorts the whole result).
  Future<List<PostItem>> fetchPosts({
    SectionItem? section,
    String? keyword,
    bool? hasImage,
    bool? allowDm,
    PostStatus? status,
    PostSort sort = PostSort.latest,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.posts,
      queryParameters: <String, dynamic>{
        ..._postQuery(section: section, sort: sort),
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        if (hasImage != null) 'hasImage': hasImage,
        if (allowDm != null) 'allowDm': allowDm,
        if (status != null) 'status': status.apiValue,
      },
    );
    return sortPostsForView(_parsePosts(extractList(response)), sort: sort);
  }

  Map<String, dynamic> _postQuery({
    SectionItem? section,
    required PostSort sort,
  }) {
    return <String, dynamic>{
      if (section != null) ...<String, dynamic>{
        'sectionType': section.sectionType,
        'sectionId': section.key,
      },
      'sort': sort.apiValue,
    };
  }

  List<PostItem> _parsePosts(List<dynamic> rows) {
    final List<PostItem> posts = rows
        .map((dynamic item) => PostItem.fromJson(asMap(item)))
        .toList();
    if (posts.any((PostItem post) => post.id.isEmpty)) {
      throw FormatException(
        uiTextGlobal(
          zh: '帖子列表包含无效记录',
          en: 'The post list contains invalid records',
        ),
      );
    }
    return posts;
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
    throw FormatException(
      uiTextGlobal(
        zh: '帖子详情响应缺少有效帖子数据',
        en: 'The post detail response is missing valid post data',
      ),
    );
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

    throw FormatException(
      uiTextGlobal(
        zh: '创建帖子响应缺少帖子数据',
        en: 'The create-post response is missing post data',
      ),
    );
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
    throw FormatException(
      uiTextGlobal(
        zh: '图片上传响应缺少有效图片数据',
        en: 'The image upload response is missing valid image data',
      ),
    );
  }

  Future<List<UploadedImageItem>> fetchMyUploads() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myUploads);
    final List<dynamic> rows = extractList(response);
    final List<UploadedImageItem> items = rows
        .map((dynamic item) => UploadedImageItem.fromJson(asMap(item)))
        .toList();
    if (items.any((UploadedImageItem item) => item.id.isEmpty)) {
      throw FormatException(
        uiTextGlobal(
          zh: '上传图片列表包含无效记录',
          en: 'The uploaded image list contains invalid records',
        ),
      );
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
      throw FormatException(
        uiTextGlobal(
          zh: '评论列表包含无效记录',
          en: 'The comment list contains invalid records',
        ),
      );
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

  // Like and favorite send the state wanted: without it the server toggles,
  // which undoes the action whenever this client's copy of the state is stale.
  Future<LikeActionResult> likePost(String postId) =>
      _setPostLiked(postId, true);

  Future<LikeActionResult> unlikePost(String postId) =>
      _setPostLiked(postId, false);

  Future<LikeActionResult> _setPostLiked(String postId, bool liked) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.postLike(postId),
      body: <String, dynamic>{'liked': liked},
    );
    final Map<String, dynamic> map = extractMap(response);
    final bool? resultLiked = readBool(map, <String>['liked']);
    final int? likeCount = readInt(map, <String>['likeCount']);
    if (resultLiked == null || likeCount == null) {
      throw FormatException(
        uiTextGlobal(
          zh: '点赞响应缺少 liked / likeCount',
          en: 'The like response is missing liked / likeCount',
        ),
      );
    }
    return LikeActionResult(liked: resultLiked, likeCount: likeCount);
  }

  Future<void> likeComment(String commentId) {
    return _apiClient.post(
      ApiEndpoints.commentLike(commentId),
      body: const <String, dynamic>{'liked': true},
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
      body: const <String, dynamic>{'favorited': true},
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
      throw FormatException(
        uiTextGlobal(
          zh: '收藏帖子列表包含无效记录',
          en: 'The saved post list contains invalid records',
        ),
      );
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
      throw FormatException(
        uiTextGlobal(
          zh: '用户帖子列表包含无效记录',
          en: 'The user post list contains invalid records',
        ),
      );
    }
    return posts;
  }

  /// A random anonymous nickname for 随机, from the server's word list.
  Future<String> fetchRandomAnonymousAlias() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.anonymousAlias);
    final String alias = (extractMap(response)['alias'] ?? '')
        .toString()
        .trim();
    if (alias.isEmpty) {
      throw FormatException(
        uiTextGlobal(zh: '没有取到随机昵称', en: 'No random nickname was returned'),
      );
    }
    return alias;
  }

  Future<List<PostItem>> fetchMyPosts() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myPosts);
    final List<dynamic> list = extractList(response);
    final List<PostItem> posts = list
        .map((dynamic item) => PostItem.fromJson(asMap(item)))
        .toList();
    if (posts.any((PostItem post) => post.id.isEmpty)) {
      throw FormatException(
        uiTextGlobal(
          zh: '我的帖子列表包含无效记录',
          en: 'My post list contains invalid records',
        ),
      );
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

  Future<int> incrementView(String postId) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.postView(postId),
      body: const <String, dynamic>{},
    );
    final Map<String, dynamic> map = extractMap(response);
    final int? viewCount = readInt(map, <String>['viewCount']);
    if (viewCount == null) {
      throw FormatException(
        uiTextGlobal(
          zh: '阅读量响应缺少 viewCount',
          en: 'The view-count response is missing viewCount',
        ),
      );
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
      throw FormatException(
        uiTextGlobal(
          zh: '置顶申请响应包含无效 mode',
          en: 'The pin request response contains an invalid mode',
        ),
      );
    }
    final Map<String, dynamic> postMap = asMap(map['post']);
    if (mode == 'direct' && postMap.isEmpty) {
      throw FormatException(
        uiTextGlobal(
          zh: '直接置顶响应缺少帖子数据',
          en: 'The direct pin response is missing post data',
        ),
      );
    }
    return PinPostActionResult(
      mode: mode,
      post: postMap.isEmpty ? null : PostItem.fromJson(postMap),
    );
  }

  FavoriteActionResult _parseFavoriteActionResult(dynamic response) {
    final Map<String, dynamic> map = extractMap(response);
    if (map.isEmpty) {
      throw FormatException(
        uiTextGlobal(
          zh: '收藏操作响应缺少数据',
          en: 'The favorite response is missing data',
        ),
      );
    }
    final bool? favorited = readBool(map, <String>['favorited', 'isFavorited']);
    if (favorited == null) {
      throw FormatException(
        uiTextGlobal(
          zh: '收藏操作响应缺少 favorited 状态',
          en: 'The favorite response is missing the favorited flag',
        ),
      );
    }
    final int? favoriteCount = readInt(map, <String>['favoriteCount']);
    if (favoriteCount == null) {
      throw FormatException(
        uiTextGlobal(
          zh: '收藏操作响应缺少 favoriteCount',
          en: 'The favorite response is missing favoriteCount',
        ),
      );
    }
    return FavoriteActionResult(
      favorited: favorited,
      favoriteCount: favoriteCount,
    );
  }
}
