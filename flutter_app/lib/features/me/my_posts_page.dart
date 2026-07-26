import 'package:flutter/material.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/post_item.dart';
import '../../repositories/app_repositories.dart';
import '../../widgets/post_card.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  List<PostItem> _posts = const <PostItem>[];
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageTopActions(leading: BackButton()),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.readingMaxWidth,
          ),
          child: _loading
              ? const AppStatePanel(
                  icon: Icons.article_outlined,
                  title: '正在加载我的帖子',
                  message: '正在同步发布记录和审核状态。',
                )
              : ListView(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xs,
                    bottom: AppSpacing.xl,
                  ),
                  children: <Widget>[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: AppInlineMessage(
                          title: '帖子加载失败',
                          message: _error!,
                          tone: AppMessageTone.error,
                          action: TextButton(
                            onPressed: _actionBusy ? null : _loadData,
                            child: const Text('重试'),
                          ),
                        ),
                      ),
                    ..._posts.map(
                      (PostItem post) => Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.xs,
                              AppSpacing.md,
                              0,
                            ),
                            child: PostCard(
                              post: post,
                              onTap: () async {
                                final PostItem? updated =
                                    await openPostDetailPage(
                                      context,
                                      post: post,
                                    );
                                if (updated == null || !mounted) {
                                  return;
                                }
                                setState(() {
                                  _posts = _posts
                                      .map(
                                        (PostItem item) => item.id == updated.id
                                            ? updated
                                            : item,
                                      )
                                      .toList(growable: false);
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                OutlinedButton(
                                  onPressed: _actionBusy
                                      ? null
                                      : () => _updateStatus(post),
                                  child: const Text('更新状态'),
                                ),
                                FilledButton.tonal(
                                  onPressed: _actionBusy
                                      ? null
                                      : () => _delete(post),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_posts.isEmpty)
                      const AppStatePanel(
                        key: Key('my-posts-empty-state'),
                        icon: Icons.post_add_outlined,
                        title: '你还没有发布帖子',
                        message: '回到帖子流，使用发布按钮分享第一条内容。',
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<PostItem> posts = await AppRepositories.posts.fetchMyPosts();
      if (!mounted) {
        return;
      }
      setState(() {
        _posts = posts;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(PostItem post) async {
    final PostStatus next = switch (post.status) {
      PostStatus.ongoing => PostStatus.resolved,
      PostStatus.resolved => PostStatus.closed,
      PostStatus.closed => PostStatus.ongoing,
    };

    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.posts.updateMyPostStatus(
        postId: post.id,
        status: next,
      );
      if (!mounted) {
        return;
      }
      _toast('帖子状态已更新为 ${next.label}');
      await _loadData();
    } catch (error) {
      _toast('更新失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _delete(PostItem post) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除这条帖子？'),
          content: const Text('删除后无法恢复，相关内容将不再展示。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.posts.deleteMyPost(post.id);
      if (!mounted) {
        return;
      }
      _toast('帖子已删除');
      await _loadData();
    } catch (error) {
      _toast('删除失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
