import 'package:flutter/material.dart';

import '../../core/navigation/post_detail_nav.dart';
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
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的帖子')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: <Widget>[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ..._posts.map(
                  (PostItem post) => Column(
                    children: <Widget>[
                      PostCard(
                        post: post,
                        onTap: () {
                          openPostDetailPage(context, post: post);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            OutlinedButton(
                              onPressed: _actionBusy ? null : () => _edit(post),
                              child: const Text('编辑'),
                            ),
                            OutlinedButton(
                              onPressed: _actionBusy ? null : () => _updateStatus(post),
                              child: const Text('更新状态'),
                            ),
                            FilledButton.tonal(
                              onPressed: _actionBusy ? null : () => _delete(post),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('你还没有发布帖子。')),
                  ),
              ],
            ),
    );
  }

  Future<void> _loadPosts() async {
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

  Future<void> _edit(PostItem post) async {
    _toast('编辑接口待后端提供（当前仅保留入口）。');
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
      await AppRepositories.posts.updateMyPostStatus(postId: post.id, status: next);
      if (!mounted) {
        return;
      }
      _toast('帖子状态已更新为 ${next.label}');
      await _loadPosts();
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
    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.posts.deleteMyPost(post.id);
      if (!mounted) {
        return;
      }
      _toast('帖子已删除');
      await _loadPosts();
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
