import 'package:flutter/material.dart';

import '../../models/my_comment_item.dart';
import '../../repositories/app_repositories.dart';
import '../../core/l10n/ui_text.dart';

class MyCommentsPage extends StatefulWidget {
  const MyCommentsPage({super.key});

  @override
  State<MyCommentsPage> createState() => _MyCommentsPageState();
}

class _MyCommentsPageState extends State<MyCommentsPage> {
  List<MyCommentItem> _items = const <MyCommentItem>[];
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '我的评论', en: 'My comments')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _items.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (BuildContext context, int index) {
                final MyCommentItem row = _items[index];
                return Card(
                  child: ListTile(
                    title: Text(row.postTitle),
                    subtitle: Text('${row.content}\n${row.timeText}'),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  uiText(
                                    context,
                                    zh: '原帖跳转下一步接入。',
                                    en:
                                        'Opening the original post is coming soon.',
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            uiText(context, zh: '原帖', en: 'Original post'),
                          ),
                        ),
                        TextButton(
                          onPressed: _actionBusy ? null : () => _delete(row.id),
                          child: Text(
                            uiText(context, zh: '删除', en: 'Delete'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: _error == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<MyCommentItem> items = await AppRepositories.users.fetchMyComments();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = uiTextGlobal(zh: '加载失败：$error', en: 'Load failed: $error');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _delete(String commentId) async {
    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.users.deleteMyComment(commentId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, zh: '评论删除成功。', en: 'Comment deleted.')),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(context, zh: '删除失败：$error', en: 'Delete failed: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }
}
