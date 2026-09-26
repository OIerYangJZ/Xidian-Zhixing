import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../design_system/design_system.dart';
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

  /// A section name; 全部 shows every favorite.
  String _selectedSection = '全部';
  FavoriteSortMode _sortMode = FavoriteSortMode.latest;
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
    if (_loading && _favorites.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final List<PostItem> filtered = _buildFilteredFavorites();

    return ZxPaper(
      child: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      key: const Key('favorites-search'),
                      controller: _keywordController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: uiText(
                          context,
                          zh: '搜索收藏（标题、正文、标签）',
                          en: 'Search saved posts (title, body, tags)',
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _keywordController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: uiText(context, zh: '清除', en: 'Clear'),
                                onPressed: () {
                                  _keywordController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: <Widget>[
                                for (final String section in _sections)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      showCheckmark: false,
                                      label: Text(
                                        localizedChannel(locale, section),
                                      ),
                                      selected: _selectedSection == section,
                                      onSelected: (_) => setState(
                                        () => _selectedSection = section,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SegmentedButton<FavoriteSortMode>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: <ButtonSegment<FavoriteSortMode>>[
                            for (final FavoriteSortMode mode
                                in FavoriteSortMode.values)
                              ButtonSegment<FavoriteSortMode>(
                                value: mode,
                                label: Text(mode.labelFor(locale)),
                              ),
                          ],
                          selected: <FavoriteSortMode>{_sortMode},
                          onSelectionChanged: (Set<FavoriteSortMode> v) =>
                              setState(() => _sortMode = v.first),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
                      child: Text(
                        filtered.length == _favorites.length
                            ? uiText(
                                context,
                                zh: '共 ${_favorites.length} 条收藏',
                                en: '${_favorites.length} saved',
                              )
                            : uiText(
                                context,
                                zh: '共 ${_favorites.length} 条收藏 · 显示 ${filtered.length} 条',
                                en: '${_favorites.length} saved · ${filtered.length} shown',
                              ),
                        style: ZxType.caption.copyWith(color: t.text3),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ZxInlineMessage(
                          message: _error!,
                          tone: ZxMessageTone.danger,
                          actionLabel: uiText(context, zh: '重试', en: 'Retry'),
                          onAction: _loadFavorites,
                        ),
                      ),
                    for (final PostItem post in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildFavoriteCard(post),
                      ),
                    if (filtered.isEmpty && _error == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: ZxStatePanel(
                          icon: Icons.star_outline_rounded,
                          title: _favorites.isEmpty
                              ? uiText(
                                  context,
                                  zh: '你还没有收藏帖子',
                                  en: 'You have not saved any posts yet',
                                )
                              : uiText(
                                  context,
                                  zh: '没有符合条件的收藏',
                                  en: 'No saved posts match these filters',
                                ),
                          message: _favorites.isEmpty
                              ? uiText(
                                  context,
                                  zh: '在帖子上点星标即可收藏',
                                  en: 'Tap the star on a post to save it.',
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(PostItem post) {
    // The card's own star removes it, with 撤销 in the toast.
    return PostCard(
      post: post,
      onFavorite: _updatingPostIds.contains(post.id)
          ? null
          : () => _unfavorite(post),
      onTap: () async {
        final PostItem? updated = await openPostDetailPage(context, post: post);
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
              .map((PostItem item) => item.id == updated.id ? updated : item)
              .toList(growable: false);
        });
      },
    );
  }

  /// 全部, then each section the favorites are filed under.
  List<String> get _sections => <String>[
    '全部',
    ..._favorites
        .map((PostItem post) => post.sectionName)
        .where((String name) => name.isNotEmpty)
        .toSet(),
  ];

  List<PostItem> _buildFilteredFavorites() {
    final String keyword = _keywordController.text.trim().toLowerCase();

    final List<PostItem> rows = _favorites.where((PostItem post) {
      final bool matchSection =
          _selectedSection == '全部' || post.sectionName == _selectedSection;
      if (!matchSection) {
        return false;
      }
      if (keyword.isEmpty) {
        return true;
      }
      final String text =
          '${post.title} ${post.content} ${post.sectionName} ${post.tags.join(' ')}'
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
        zxShowToast(
          context,
          uiText(
            context,
            zh: '取消收藏失败，请稍后重试。',
            en: 'Could not remove the favorite. Please try again later.',
          ),
        );
        return;
      }

      setState(() {
        _favorites = _favorites
            .where((PostItem item) => item.id != post.id)
            .toList(growable: false);
      });

      zxShowToast(
        context,
        uiText(
          context,
          zh: '已取消收藏：${post.title}',
          en: 'Removed from favorites: ${post.title}',
        ),
        actionLabel: uiText(context, zh: '撤销', en: 'Undo'),
        onAction: () => _restoreFavorite(post),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      zxShowToast(
        context,
        uiText(
          context,
          zh: '取消收藏失败：$error',
          en: 'Could not remove the favorite: $error',
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
        favoriteCount: result.favoriteCount,
      );

      setState(() {
        _favorites = <PostItem>[restored, ..._favorites];
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
      final List<PostItem> posts = await AppRepositories.posts
          .fetchFavoritePosts();

      if (!mounted) {
        return;
      }

      setState(() {
        _favorites = posts;
        if (!_sections.contains(_selectedSection)) _selectedSection = '全部';
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
