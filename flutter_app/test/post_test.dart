import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/models/comment_item.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/section_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'api_mocks.dart';

void main() {
  group('CommentItem', () {
    test('匿名评论忽略旧接口残留的用户标识和头像', () {
      final CommentItem comment = CommentItem.fromJson(<String, dynamic>{
        'id': 'c1',
        'authorAlias': '匿名同学',
        'isAnonymous': true,
        'authorUserId': 'stable-user-id',
        'authorId': 'stable-user-id',
        'userId': 'stable-user-id',
        'authorAvatarUrl': '/api/storage/avatar/private.png',
      });

      expect(comment.authorUserId, isEmpty);
      expect(comment.authorAvatar, isNull);
    });
  });

  group('PostRepository', () {
    late MockClient mockClient;
    late PostRepository postRepository;
    Map<String, String> lastPostQuery = const <String, String>{};
    Map<String, dynamic> lastCreateBody = const <String, dynamic>{};
    const SectionItem general = SectionItem(
      sectionType: 'general',
      sectionId: 'general',
      sectionName: '综合',
    );

    setUp(() {
      mockClient = MockClient((http.Request request) async {
        final String path = request.url.path;
        final String method = request.method;

        // 分区树
        if (path.endsWith('/sections/tree') && method == 'GET') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'sections': <Map<String, dynamic>>[
                  _section('general', 'general', '综合'),
                  _section('college', 'cs', '计算机科学与技术学院'),
                  _section('club', 'club-robot', '机器人社'),
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 一页帖子
        if (path.endsWith('/posts') &&
            method == 'GET' &&
            request.url.queryParameters.containsKey('page')) {
          lastPostQuery = request.url.queryParameters;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'items': MockApiResponses.postsSuccess()['data'],
                'page': 1,
                'limit': 20,
                'total': 21,
                'hasMore': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 获取帖子列表
        if (path.endsWith('/posts') && method == 'GET') {
          lastPostQuery = request.url.queryParameters;
          return http.Response(
            jsonEncode(MockApiResponses.postsSuccess()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 获取单个帖子详情
        final postDetailPattern = RegExp(r'/posts/(p\d+|new_post_id)$');
        if (postDetailPattern.hasMatch(path) && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.postDetailSuccess()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 创建帖子
        if (path.endsWith('/posts') && method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          lastCreateBody = body;
          final title = body['title'] as String?;

          if (title != null && title.isNotEmpty) {
            return http.Response(
              jsonEncode(MockApiResponses.createPostSuccess()),
              201,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{'message': '标题不能为空'}),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 获取评论
        final commentsPattern = RegExp(r'/posts/.+/comments');
        if (commentsPattern.hasMatch(path) && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.commentsSuccess()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (commentsPattern.hasMatch(path) && method == 'POST') {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': '评论已发布'}),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 点赞帖子
        final likePattern = RegExp(r'/posts/.+/like');
        if (likePattern.hasMatch(path) && method == 'POST') {
          // What handle_toggle_like answers.
          return http.Response(
            jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{'liked': true, 'likeCount': 26},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 收藏帖子
        final favoritePattern = RegExp(r'/posts/.+/favorite');
        if (favoritePattern.hasMatch(path) && method == 'POST') {
          return http.Response(
            jsonEncode(MockApiResponses.favoriteSuccess()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 搜索帖子
        if (path.endsWith('/posts/search') && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.searchPostsSuccess()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        if (path.endsWith('/reports') && method == 'POST') {
          return http.Response(
            jsonEncode(MockApiResponses.reportSuccess()),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        return http.Response(
          jsonEncode(MockApiResponses.notFound()),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      postRepository = PostRepository(ApiClient(httpClient: mockClient));
    });

    group('fetchSections', () {
      test('分区树的 sections 依服务器顺序返回', () async {
        final sections = await postRepository.fetchSections();

        expect(
          sections.map((SectionItem s) => s.sectionName),
          <String>['综合', '计算机科学与技术学院', '机器人社'],
        );
        expect(sections.first.isGeneral, isTrue);
      });
    });

    group('fetchPostPage', () {
      test('按分区和页码请求，读取 items 与 hasMore', () async {
        const SectionItem college = SectionItem(
          sectionType: 'college',
          sectionId: 'cs',
          sectionName: '计算机科学与技术学院',
        );
        final PostPage page = await postRepository.fetchPostPage(
          section: college,
          page: 2,
        );

        expect(page.items, isNotEmpty);
        expect(page.hasMore, isTrue);
        expect(lastPostQuery['sectionType'], 'college');
        expect(lastPostQuery['sectionId'], 'cs');
        expect(lastPostQuery['page'], '2');
        expect(lastPostQuery['limit'], '20');
        expect(lastPostQuery.containsKey('channel'), isFalse);
      });
    });

    group('fetchPosts', () {
      test('获取帖子列表成功', () async {
        final posts = await postRepository.fetchPosts();

        expect(posts, isNotEmpty);
        expect(posts.first, isA<PostItem>());
      });

      test('按分区筛选帖子', () async {
        final posts = await postRepository.fetchPosts(section: general);

        expect(posts, isA<List<PostItem>>());
        expect(lastPostQuery['sectionType'], 'general');
        expect(lastPostQuery['sectionId'], 'general');
      });

      test('按关键词搜索帖子', () async {
        final posts = await postRepository.fetchPosts(keyword: '测试');

        expect(posts, isA<List<PostItem>>());
      });

      test('按点赞量排序', () async {
        final posts = await postRepository.fetchPosts(sort: PostSort.likes);

        expect(posts, isA<List<PostItem>>());
      });
    });

    group('fetchPostDetail', () {
      test('获取帖子详情成功', () async {
        final post = await postRepository.fetchPostDetail('p1');

        expect(post.id, equals('p1'));
        expect(post.title, isNotEmpty);
        expect(post.content, isNotEmpty);
      });
    });

    group('createPost', () {
      test('创建帖子成功', () async {
        final input = CreatePostInput(
          title: '新帖子标题',
          content: '新帖子内容',
          section: general,
          tags: <String>['测试'],
          allowComment: true,
          allowDm: false,
          privateOnly: false,
          status: PostStatus.ongoing,
          hasImage: false,
        );

        final post = await postRepository.createPost(input);

        expect(post.title, equals('新帖子标题'));
        expect(post.content, equals('新帖子内容'));
        expect(lastCreateBody['sectionType'], 'general');
        expect(lastCreateBody['sectionId'], 'general');
        expect(lastCreateBody['sectionName'], '综合');
        expect(lastCreateBody.containsKey('channel'), isFalse);
      });

      test('社团分区以社团身份发布', () {
        const SectionItem clubSection = SectionItem(
          sectionType: 'club',
          sectionId: 'club-robot',
          sectionName: '机器人社',
        );
        const ClubItem club = ClubItem(
          id: 'c1',
          name: '机器人社',
          sectionId: 'club-robot',
          canPublishAs: true,
        );
        final json = CreatePostInput(
          title: '招新',
          content: '欢迎',
          section: clubSection,
          publisherClub: publisherClubFor(clubSection, const <ClubItem>[club]),
          tags: <String>[],
          allowComment: true,
          allowDm: true,
          privateOnly: false,
          status: PostStatus.ongoing,
          hasImage: false,
        ).toJson();

        expect(json['publisherType'], 'club');
        expect(json['publisherClubId'], 'c1');
      });

      test('创建帖子时 hasImage 由 imageUploadIds 决定', () async {
        final inputWithImages = CreatePostInput(
          title: '带图帖子',
          content: '内容',
          section: general,
          tags: <String>[],
          allowComment: true,
          allowDm: false,
          privateOnly: false,
          status: PostStatus.ongoing,
          hasImage: false,
          imageUploadIds: <String>['img1', 'img2'],
        );

        expect(inputWithImages.toJson()['hasImage'], isTrue);
        expect(inputWithImages.toJson()['imageUploadIds'], hasLength(2));
      });

      test('CreatePostInput.toJson 正确序列化', () {
        final input = CreatePostInput(
          title: '测试标题',
          content: '测试内容',
          section: general,
          tags: <String>['标签1', '标签2'],
          allowComment: true,
          allowDm: true,
          privateOnly: false,
          status: PostStatus.resolved,
          hasImage: true,
          useAnonymousAlias: true,
          anonymousAlias: '匿名用户',
        );

        final json = input.toJson();

        expect(json['title'], equals('测试标题'));
        expect(json['content'], equals('测试内容'));
        expect(json['sectionId'], equals('general'));
        expect(json['tags'], equals(<String>['标签1', '标签2']));
        expect(json['allowComment'], isTrue);
        expect(json['allowDm'], isTrue);
        expect(json['status'], equals('resolved'));
        expect(json['hasImage'], isTrue);
        expect(json['useAnonymousAlias'], isTrue);
        expect(json['anonymousAlias'], equals('匿名用户'));
      });
    });

    group('PostLimits', () {
      test('#话题 计入标签数，与服务器合并方式一致', () {
        final List<String> merged = PostLimits.mergedTags(
          <String>['学习'],
          '求助 #考研',
          '#学习 还有 #保研-经验',
        );
        expect(merged, <String>['学习', '考研', '保研-经验']);
      });

      test('超过 10 个标签或单个超过 40 字时给出原因', () {
        final List<String> eleven = List<String>.generate(11, (int i) => 't$i');
        expect(PostLimits.tagProblem(eleven, '', ''), contains('10'));
        expect(
          PostLimits.tagProblem(<String>['字' * 41], '', ''),
          contains('40'),
        );
        expect(PostLimits.tagProblem(<String>['字' * 40], '', ''), isNull);
      });
    });

    group('fetchComments', () {
      test('获取评论列表成功', () async {
        final comments = await postRepository.fetchComments('p1');

        expect(comments, isNotEmpty);
        expect(comments.first.content, isNotEmpty);
      });
    });

    group('createComment', () {
      test('创建评论成功不抛出异常', () async {
        await expectLater(
          postRepository.createComment(postId: 'p1', content: '这是一条测试评论'),
          completes,
        );
      });

      test('创建带父评论的回复成功', () async {
        await expectLater(
          postRepository.createComment(
            postId: 'p1',
            content: '这是回复',
            parentId: 'c1',
          ),
          completes,
        );
      });
    });

    group('likePost', () {
      test('点赞帖子成功', () async {
        final LikeActionResult result = await postRepository.likePost('p1');
        expect(result.liked, isTrue);
        expect(result.likeCount, 26);
      });
    });

    group('favoritePost', () {
      test('收藏帖子成功返回结果', () async {
        final result = await postRepository.favoritePost('p1');

        expect(result.favorited, isTrue);
        expect(result.favoriteCount, equals(4));
      });
    });

    group('report', () {
      test('举报帖子成功', () async {
        await expectLater(
          postRepository.report(
            targetType: 'post',
            targetId: 'p1',
            reason: '垃圾广告',
            description: '包含营销信息',
          ),
          completes,
        );
      });
    });

    group('PostItem', () {
      test('fromJson 正确解析 JSON', () {
        final json = <String, dynamic>{
          'id': 'test_post',
          'title': '测试标题',
          'content': '测试内容',
          'sectionType': 'college',
          'sectionId': 'cs',
          'sectionName': '计算机科学与技术学院',
          'tags': <String>['Flutter', '测试'],
          'authorAlias': '测试用户',
          'createdAt': '2024-01-15T10:30:00Z',
          'hasImage': true,
          'commentCount': 10,
          'likeCount': 25,
          'favoriteCount': 5,
          'status': 'ongoing',
          'allowComment': true,
          'allowDm': false,
        };

        final post = PostItem.fromJson(json);

        expect(post.id, equals('test_post'));
        expect(post.title, equals('测试标题'));
        expect(post.content, equals('测试内容'));
        expect(post.sectionName, equals('计算机科学与技术学院'));
        expect(post.sectionId, equals('cs'));
        expect(post.tags, equals(<String>['Flutter', '测试']));
        expect(post.authorAlias, equals('测试用户'));
        expect(post.hasImage, isTrue);
        expect(post.commentCount, equals(10));
        expect(post.likeCount, equals(25));
        expect(post.favoriteCount, equals(5));
        expect(post.status, equals(PostStatus.ongoing));
        expect(post.allowComment, isTrue);
        expect(post.allowDm, isFalse);
      });

      test('fromJson 处理不同状态值', () {
        expect(
          PostStatusCodec.fromDynamic('ongoing'),
          equals(PostStatus.ongoing),
        );
        expect(
          PostStatusCodec.fromDynamic('resolved'),
          equals(PostStatus.resolved),
        );
        expect(
          PostStatusCodec.fromDynamic('closed'),
          equals(PostStatus.closed),
        );
        expect(
          PostStatusCodec.fromDynamic('solved'),
          equals(PostStatus.resolved),
        );
        // 状态 is optional: none, missing or unknown shows no badge.
        expect(PostStatusCodec.fromDynamic('none'), equals(PostStatus.none));
        expect(
          PostStatusCodec.fromDynamic('unknown'),
          equals(PostStatus.none),
        );
        expect(PostStatus.none.apiValue, equals('none'));
      });

      test('fromJson 处理空数据', () {
        final post = PostItem.fromJson(<String, dynamic>{});

        expect(post.id, isEmpty);
        expect(post.title, isEmpty);
        expect(post.status, equals(PostStatus.none));
      });

      test('copyWith 创建新实例保留原值', () {
        final original = PostItem(
          id: 'p1',
          title: '原始标题',
          content: '原始内容',
          tags: <String>['标签'],
          authorAlias: '作者',
          createdAt: DateTime(2024, 1, 1),
          hasImage: false,
          commentCount: 5,
          likeCount: 10,
          favoriteCount: 2,
          status: PostStatus.ongoing,
          allowComment: true,
          allowDm: false,
        );

        final modified = original.copyWith(title: '修改后的标题', likeCount: 15);

        expect(modified.id, equals('p1'));
        expect(modified.title, equals('修改后的标题'));
        expect(modified.likeCount, equals(15));
        expect(modified.content, equals('原始内容'));
        expect(modified.commentCount, equals(5));
      });
    });

    group('PostSort', () {
      test('PostSort 枚举的 apiValue 正确', () {
        expect(PostSort.latest.apiValue, equals('latest'));
        expect(PostSort.likes.apiValue, equals('likes'));
      });

      test('PostSort 枚举的 label 正确', () {
        expect(PostSort.latest.label, equals('按发布时间'));
        expect(PostSort.likes.label, equals('按点赞量'));
      });
    });
  });
}

Map<String, dynamic> _section(String type, String id, String name) =>
    <String, dynamic>{
      'id': 'section-$id',
      'sectionType': type,
      'sectionId': id,
      'sectionName': name,
    };
