import 'package:flutter/material.dart';
import '../../core/widgets/app_surfaces.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../models/post_item.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';

enum FavoriteSortMode { latest, hot }

extension FavoriteSortModeLabel on FavoriteSortMode {
  String labelFor(Locale locale) {
    switch (this) {
      case FavoriteSortMode.latest:
        return uiTextFor(locale, zh: '按时间', en: 'By date');
      case FavoriteSortMode.hot:
        return uiTextFor(locale, zh: '按热度', en: 'By activity');
    }
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => FavoritesPageState();
}

class FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _keywordController = TextEditingController();

  String _selectedChannel = '全部';
  FavoriteSortMode _sortMode = FavoriteSortMode.latest;
  List<String> _channels = const <String>['全部'];
  List<PostItem> _favorites = const <PostItem>[];
  Set<String> _updatingPostIds = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> refreshFavorites() => _loadFavorites();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<PostItem> filtered = _buildFilteredFavorites();

    return AppPageFrame(
      maxWidth: 720,
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: <Widget>[
            _buildHero(context, filtered.length),
            const SizedBox(height: 10),
            _buildToolbar(context),
            const SizedBox(height: 10),
            _buildChannelBar(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 4),
            ...filtered.map(_buildFavoriteCard),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    _favorites.isEmpty
                        ? uiText(
                            context,
                            zh: '你还没有收藏帖子。',
                            en: 'You have not favorited any posts yet.',
                          )
                        : uiText(
                            context,
                            zh: '暂无符合条件的收藏内容。',
                            en: 'No favorites match the current filters.',
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, int filteredCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  uiText(context, zh: '收藏内容', en: 'Saved posts'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  uiText(
                    context,
                    zh: '总收藏 ${_favorites.length} 条 · 当前显示 $filteredCount 条',
                    en: '${_favorites.length} saved · $filteredCount shown',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _loadFavorites,
            icon: const Icon(Icons.refresh),
            label: Text(uiText(context, zh: '刷新', en: 'Refresh')),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _keywordController,
            decoration: InputDecoration(
              hintText: uiText(
                context,
                zh: '搜索收藏帖子（标题/正文/标签）',
                en: 'Search favorites (title / body / tags)',
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _keywordController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _keywordController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(Icons.sort_rounded, size: 18),
              const SizedBox(width: 6),
              Text(
                uiText(context, zh: '排序', en: 'Sort'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              ...FavoriteSortMode.values.map(
                (FavoriteSortMode mode) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(mode.labelFor(Localizations.localeOf(context))),
                    selected: _sortMode == mode,
                    onSelected: (_) {
                      setState(() {
                        _sortMode = mode;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelBar() {
    final Locale locale = Localizations.localeOf(context);
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _channels
            .map(
              (String channel) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(localizedChannel(locale, channel)),
                  selected: _selectedChannel == channel,
                  onSelected: (_) {
                    setState(() {
                      _selectedChannel = channel;
                    });
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFavoriteCard(PostItem post) {
    final bool busy = _updatingPostIds.contains(post.id);
    return Column(
      children: <Widget>[
        PostCard(
          post: post,
          onTap: () async {
            final PostItem? updated = await openPostDetailPage(
              context,
              post: post,
            );
            if (!mounted || updated == null) {
              return;
            }
            setState(() {
              if (!updated.isFavorited) {
                _favorites = _favorites
                    .where((PostItem item) => item.id != updated.id)
                    .toList(growable: false);
                return;
              }
              _favorites = _favorites
                  .map(
                    (PostItem item) => item.id == updated.id ? updated : item,
                  )
                  .toList(growable: false);
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20, bottom: 6),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: busy ? null : () => _unfavorite(post),
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_remove_outlined),
              label: Text(
                busy
                    ? uiText(context, zh: '处理中...', en: 'Working...')
                    : uiText(context, zh: '取消收藏', en: 'Remove'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<PostItem> _buildFilteredFavorites() {
    final String keyword = _keywordController.text.trim().toLowerCase();

    final List<PostItem> rows = _favorites.where((PostItem post) {
      final bool matchChannel =
          _selectedChannel == '全部' || post.channel == _selectedChannel;
      if (!matchChannel) {
        return false;
      }
      if (keyword.isEmpty) {
        return true;
      }
      final String text =
          '${post.title} ${post.content} ${post.channel} ${post.tags.join(' ')}'
              .toLowerCase();
      return text.contains(keyword);
    }).toList();

    return sortPostsForView(
      rows,
      sort: _sortMode == FavoriteSortMode.hot ? PostSort.hot : PostSort.latest,
    );
  }

  Future<void> _unfavorite(PostItem post) async {
    setState(() {
      _updatingPostIds = <String>{..._updatingPostIds, post.id};
    });

    try {
      final FavoriteActionResult result = await AppRepositories.posts
          .unfavoritePost(post.id);
      if (!mounted) {
        return;
      }

      if (result.favorited) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                zh: '取消收藏失败，请稍后重试。',
                en: 'Could not remove the favorite. Please try again later.',
              ),
            ),
          ),
        );
        return;
      }

      setState(() {
        _favorites = _favorites
            .where((PostItem item) => item.id != post.id)
            .toList(growable: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(
              context,
              zh: '已取消收藏：${post.title}',
              en: 'Removed from favorites: ${post.title}',
            ),
          ),
          action: SnackBarAction(
            label: uiText(context, zh: '撤销', en: 'Undo'),
            onPressed: () {
              _restoreFavorite(post);
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(
              context,
              zh: '取消收藏失败：$error',
              en: 'Could not remove the favorite: $error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPostIds = <String>{..._updatingPostIds}..remove(post.id);
        });
      }
    }
  }

  Future<void> _restoreFavorite(PostItem post) async {
    try {
      final FavoriteActionResult result = await AppRepositories.posts
          .favoritePost(post.id);
      if (!mounted) {
        return;
      }
      final bool exists = _favorites.any((PostItem item) => item.id == post.id);
      if (exists) {
        return;
      }

      final PostItem restored = post.copyWith(
        isFavorited: true,
        favoriteCount: result.favoriteCount ?? post.favoriteCount,
      );

      setState(() {
        _favorites = <PostItem>[restored, ..._favorites];
        if (!_channels.contains(restored.channel)) {
          _channels = <String>[..._channels, restored.channel];
        }
      });
    } catch (_) {
      // ignore undo failure
    }
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<String> channels = await AppRepositories.posts.fetchChannels();
      final List<PostItem> posts = await AppRepositories.posts
          .fetchFavoritePosts();

      if (!mounted) {
        return;
      }

      setState(() {
        _channels = <String>['全部', ...channels.toSet()];
        _favorites = posts;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = uiTextGlobal(
          zh: '收藏加载失败：$error',
          en: 'Could not load favorites: $error',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}
