import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../data/mock_data.dart';
import '../models/comment_item.dart';
import '../models/post_item.dart';
import '../models/uploaded_image_item.dart';

enum PostSort {
  latest,
  likes,
}

extension PostSortCodec on PostSort {
  String get apiValue {
    switch (this) {
      case PostSort.latest:
        return 'latest';
      case PostSort.likes:
        return 'likes';
    }
  }

  String get label {
    switch (this) {
      case PostSort.latest:
        return '按发布时间';
      case PostSort.likes:
        return '按点赞量';
    }
  }
}

class CreatePostInput {
  CreatePostInput({
    required this.title,
    required this.content,
    required this.channel,
    required this.tags,
    required this.allowComment,
    required this.allowDm,
    required this.status,
    required this.hasImage,
    this.imageUploadIds = const <String>[],
    this.useAnonymousAlias = false,
    this.anonymousAlias,
  });

  final String title;
  final String content;
  final String channel;
  final List<String> tags;
  final bool allowComment;
  final bool allowDm;
  final PostStatus status;
  final bool hasImage;
  final List<String> imageUploadIds;
  final bool useAnonymousAlias;
  final String? anonymousAlias;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'content': content,
      'channel': channel,
      'tags': tags,
      'allowComment': allowComment,
      'allowDm': allowDm,
      'status': status.apiValue,
      'hasImage': hasImage || imageUploadIds.isNotEmpty,
      'imageUploadIds': imageUploadIds,
      'useAnonymousAlias': useAnonymousAlias,
      if (anonymousAlias != null && anonymousAlias!.trim().isNotEmpty)
        'anonymousAlias': anonymousAlias!.trim(),
    };
  }
}

class FavoriteActionResult {
  FavoriteActionResult({
    required this.favorited,
    this.favoriteCount,
  });

  final bool favorited;
  final int? favoriteCount;
}

class PostRepository {
  PostRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<String>> fetchChannels() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.channels);
      final List<dynamic> list = extractList(response);
      final List<String> channels = list
          .map((dynamic item) {
            if (item is String) {
              return item.trim();
            }
            final Map<String, dynamic> map = asMap(item);
            return readString(map, <String>['name', 'title', 'channelName']) ??
                '';
          })
          .where((String name) => name.isNotEmpty)
          .toSet()
          .toList();

      if (channels.isNotEmpty) {
        return channels;
      }
    } catch (_) {
      // ignore and fallback
    }

    return kChannels;
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

    try {
      final dynamic response = await _apiClient.get(
        ApiEndpoints.posts,
        queryParameters: query,
      );
      final List<dynamic> list = extractList(response);
      final List<PostItem> posts = list
          .map((dynamic item) => PostItem.fromJson(asMap(item)))
          .where((PostItem post) => post.id.isNotEmpty || post.title.isNotEmpty)
          .toList();
      if (posts.isNotEmpty || !AppConfig.enableMockFallback) {
        return posts;
      }
    } catch (_) {
      // ignore and fallback
    }

    return _filterMockPosts(
      channel: channel,
      keyword: keyword,
      hasImage: hasImage,
      allowDm: allowDm,
      status: status,
      sort: sort,
    );
  }

  Future<PostItem> fetchPostDetail(String postId) async {
    try {
      final dynamic response =
          await _apiClient.get(ApiEndpoints.postById(postId));
      final Map<String, dynamic> map = extractMap(response);
      if (map.isNotEmpty) {
        return PostItem.fromJson(map);
      }
    } catch (_) {
      // ignore and fallback
    }

    return mockPosts.firstWhere(
      (PostItem post) => post.id == postId,
      orElse: () => PostItem(
        id: postId,
        title: '帖子不存在',
        content: '该帖子可能被删除。',
        channel: '未知',
        tags: const <String>[],
        authorAlias: '系统',
        createdAt: DateTime.now(),
        hasImage: false,
        commentCount: 0,
        likeCount: 0,
        favoriteCount: 0,
        status: PostStatus.closed,
        allowComment: false,
        allowDm: false,
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
      return PostItem.fromJson(map);
    }

    return PostItem(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      title: input.title,
      content: input.content,
      channel: input.channel,
      tags: input.tags,
      authorAlias: input.useAnonymousAlias
          ? ((input.anonymousAlias ?? '').trim().isNotEmpty
              ? input.anonymousAlias!.trim()
              : '匿名同学')
          : '我的昵称',
      createdAt: DateTime.now(),
      hasImage: input.hasImage || input.imageUploadIds.isNotEmpty,
      commentCount: 0,
      likeCount: 0,
      favoriteCount: 0,
      status: input.status,
      allowComment: input.allowComment,
      allowDm: input.allowDm,
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
      return UploadedImageItem.fromJson(data);
    }
    throw Exception('图片上传失败：服务端未返回有效数据');
  }

  Future<List<UploadedImageItem>> fetchMyUploads() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myUploads);
    final List<dynamic> rows = extractList(response);
    return rows
        .map((dynamic item) => UploadedImageItem.fromJson(asMap(item)))
        .where((UploadedImageItem item) => item.id.isNotEmpty)
        .toList();
  }

  Future<List<CommentItem>> fetchComments(String postId) async {
    try {
      final dynamic response =
          await _apiClient.get(ApiEndpoints.postComments(postId));
      final List<dynamic> list = extractList(response);
      final List<CommentItem> comments = list
          .map((dynamic item) => CommentItem.fromJson(asMap(item)))
          .where((CommentItem item) => item.content.isNotEmpty)
          .toList();
      if (comments.isNotEmpty || !AppConfig.enableMockFallback) {
        return comments;
      }
    } catch (_) {
      // ignore and fallback
    }

    final List<String> fallback =
        mockCommentsByPostId[postId] ?? const <String>[];
    return fallback
        .asMap()
        .entries
        .map(
          (MapEntry<int, String> entry) => CommentItem(
            id: 'mock-${entry.key + 1}',
            authorAlias: '匿名同学-${entry.key + 1}',
            content: entry.value,
            createdAt:
                DateTime.now().subtract(Duration(minutes: 5 * (entry.key + 1))),
            likeCount: 0,
          ),
        )
        .toList();
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
    return _apiClient
        .post(ApiEndpoints.postLike(postId), body: const <String, dynamic>{});
  }

  Future<FavoriteActionResult> favoritePost(String postId) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.postFavorite(postId),
      body: const <String, dynamic>{},
    );
    return _parseFavoriteActionResult(response, fallbackFavorited: true);
  }

  Future<FavoriteActionResult> unfavoritePost(String postId) async {
    final dynamic response = await _apiClient.delete(
      ApiEndpoints.postUnfavorite(postId),
      body: const <String, dynamic>{},
    );
    return _parseFavoriteActionResult(response, fallbackFavorited: false);
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
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.favoritePosts);
      final List<dynamic> list = extractList(response);
      final List<PostItem> posts = list
          .map((dynamic item) => PostItem.fromJson(asMap(item)))
          .where((PostItem post) => post.id.isNotEmpty || post.title.isNotEmpty)
          .toList();
      if (posts.isNotEmpty || !AppConfig.enableMockFallback) {
        return posts;
      }
    } catch (_) {
      // ignore and fallback
    }

    return mockPosts.where((PostItem post) => post.favoriteCount > 15).toList();
  }

  Future<List<PostItem>> fetchMyPosts() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.myPosts);
      final List<dynamic> list = extractList(response);
      final List<PostItem> posts = list
          .map((dynamic item) => PostItem.fromJson(asMap(item)))
          .where((PostItem post) => post.id.isNotEmpty || post.title.isNotEmpty)
          .toList();
      if (posts.isNotEmpty || !AppConfig.enableMockFallback) {
        return posts;
      }
    } catch (_) {
      // ignore and fallback
    }

    return mockPosts.take(3).toList();
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

  List<PostItem> _filterMockPosts({
    String? channel,
    String? keyword,
    bool? hasImage,
    bool? allowDm,
    PostStatus? status,
    PostSort sort = PostSort.latest,
  }) {
    final String normalizedKeyword = keyword?.trim().toLowerCase() ?? '';

    final List<PostItem> rows = mockPosts.where((PostItem post) {
      final bool matchChannel =
          channel == null || channel == '全部' || post.channel == channel;
      final bool matchKeyword = normalizedKeyword.isEmpty ||
          post.title.toLowerCase().contains(normalizedKeyword) ||
          post.content.toLowerCase().contains(normalizedKeyword) ||
          post.channel.toLowerCase().contains(normalizedKeyword) ||
          post.tags.join(' ').toLowerCase().contains(normalizedKeyword);
      final bool matchImage = hasImage == null || post.hasImage == hasImage;
      final bool matchDm = allowDm == null || post.allowDm == allowDm;
      final bool matchStatus = status == null || post.status == status;
      return matchChannel &&
          matchKeyword &&
          matchImage &&
          matchDm &&
          matchStatus;
    }).toList();

    rows.sort((PostItem a, PostItem b) {
      if (sort == PostSort.likes) {
        final int byLikes = b.likeCount.compareTo(a.likeCount);
        if (byLikes != 0) {
          return byLikes;
        }
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return rows;
  }

  FavoriteActionResult _parseFavoriteActionResult(
    dynamic response, {
    required bool fallbackFavorited,
  }) {
    final Map<String, dynamic> map = extractMap(response);
    if (map.isEmpty) {
      return FavoriteActionResult(favorited: fallbackFavorited);
    }
    return FavoriteActionResult(
      favorited: readBool(map, <String>['favorited', 'isFavorited']) ??
          fallbackFavorited,
      favoriteCount: readInt(map, <String>['favoriteCount', 'collectCount']),
    );
  }
}
