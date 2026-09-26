import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';
import '../../models/post_item.dart';
import '../../models/section_item.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/discussion_home_scaffold.dart';
import '../../widgets/post_card.dart';
import '../download/android_release_page.dart';
import '../legal/community_guidelines_page.dart';
import 'feed_controller.dart';

/// 树洞 feed (handoff W1 / W4 / W5).
///
/// With the sidebar (≥ 960): hero header with 推荐 / 最新 and 选择分区,
/// section chips, the posts in one panel, and from 1200 an aside with
/// 正在讨论, the community principles and the Android download. Narrower,
/// the top bar carries the title, so the feed starts with the sort switch
/// and the active section.
///
/// Posts are built lazily as they scroll into view: the feed pages in 20 at
/// a time, but a long session accumulates many, and building every card
/// (text layout, images) up front is what made the old home slow.
class DiscussionFeedView extends StatelessWidget {
  const DiscussionFeedView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.onFilter,
    required this.onSortChanged,
    required this.onPostOpen,
    required this.onLike,
    required this.onFavorite,
    this.onSectionSelected,
    this.onCreate,
  });

  final FeedState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final VoidCallback onFilter;
  final ValueChanged<PostSort> onSortChanged;
  final ValueChanged<PostItem> onPostOpen;
  final ValueChanged<PostItem> onLike;
  final ValueChanged<PostItem> onFavorite;

  /// A section's key, or empty for 全部.
  final ValueChanged<String>? onSectionSelected;

  /// 发布帖子 on the empty state.
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final double screen = MediaQuery.sizeOf(context).width;
    final bool wide = screen >= DiscussionHomeScaffold.sidebarBreakpoint;
    final bool withAside = screen >= DiscussionHomeScaffold.expandedBreakpoint;

    final Widget timeline = RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.extentAfter < 420) {
            onLoadMore();
          }
          return false;
        },
        child: CustomScrollView(
          key: const Key('discussion-feed-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.only(top: wide ? 24 : 8),
              sliver: SliverToBoxAdapter(
                child: wide
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _Hero(
                            sort: state.sort,
                            onSortChanged: onSortChanged,
                            onFilter: onFilter,
                          ),
                          const SizedBox(height: 14),
                          _SectionChips(
                            sections: state.sections,
                            selectedKey: state.selectedSectionKey,
                            onSelected: onSectionSelected,
                          ),
                          const SizedBox(height: 14),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CompactHeader(
                          sort: state.sort,
                          section: state.selectedSection,
                          onSortChanged: onSortChanged,
                          onClearSection: onSectionSelected == null
                              ? null
                              : () => onSectionSelected!(''),
                        ),
                      ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 120),
              sliver: _PostsPanel(
                wide: wide,
                state: state,
                onRetry: onRetry,
                onCreate: onCreate,
                onPostOpen: onPostOpen,
                onLike: onLike,
                onFavorite: onFavorite,
              ),
            ),
          ],
        ),
      ),
    );

    if (!wide) {
      return timeline;
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: timeline),
              if (withAside) ...<Widget>[
                const SizedBox(width: 24),
                SizedBox(
                  width: 300,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: _Aside(posts: state.posts, onPostOpen: onPostOpen),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SortSwitch extends StatelessWidget {
  const _SortSwitch({required this.sort, required this.onChanged});

  final PostSort sort;
  final ValueChanged<PostSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PostSort>(
      key: const Key('feed-sort'),
      showSelectedIcon: false,
      segments: <ButtonSegment<PostSort>>[
        ButtonSegment<PostSort>(
          value: PostSort.hot,
          icon: const Icon(Icons.local_fire_department_outlined, size: 16),
          label: Text(uiText(context, zh: '推荐', en: 'For you')),
        ),
        ButtonSegment<PostSort>(
          value: PostSort.latest,
          icon: const Icon(Icons.schedule_rounded, size: 16),
          label: Text(uiText(context, zh: '最新', en: 'Latest')),
        ),
      ],
      selected: <PostSort>{sort},
      onSelectionChanged: (Set<PostSort> value) => onChanged(value.first),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.sort,
    required this.onSortChanged,
    required this.onFilter,
  });

  final PostSort sort;
  final ValueChanged<PostSort> onSortChanged;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return ClipRRect(
      borderRadius: ZxRadius.sheetAll,
      child: ZxHeroWash(
        borderRadius: ZxRadius.sheetAll,
        child: Stack(
          children: <Widget>[
            // The brand character as a faint watermark, as in the handoff.
            Positioned(
              right: -8,
              top: -34,
              child: ExcludeSemantics(
                child: Text(
                  '知',
                  style: ZxType.display.copyWith(
                    fontSize: 168,
                    height: 1,
                    color: t.primary.withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    uiText(context, zh: '树洞', en: 'Treehole'),
                    style: ZxType.display.copyWith(color: t.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    uiText(
                      context,
                      zh: '让校园里的真实声音被听见',
                      en: 'Where real campus voices are heard',
                    ),
                    style: ZxType.body.copyWith(color: t.text2),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      _SortSwitch(sort: sort, onChanged: onSortChanged),
                      const Spacer(),
                      ZxButton(
                        label: uiText(context, zh: '选择分区', en: 'Channels'),
                        icon: Icons.filter_list_rounded,
                        variant: ZxButtonVariant.outline,
                        small: true,
                        onPressed: onFilter,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.sort,
    required this.section,
    required this.onSortChanged,
    required this.onClearSection,
  });

  final PostSort sort;
  final SectionItem? section;
  final ValueChanged<PostSort> onSortChanged;
  final VoidCallback? onClearSection;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final SectionItem? filter = section;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          _SortSwitch(sort: sort, onChanged: onSortChanged),
          const Spacer(),
          if (filter != null)
            InputChip(
              avatar: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: t.channelFor(filter.sectionName),
                  shape: BoxShape.circle,
                ),
              ),
              label: Text(filter.sectionName),
              onDeleted: onClearSection,
              deleteButtonTooltipMessage: uiText(
                context,
                zh: '清除筛选',
                en: 'Clear filter',
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionChips extends StatelessWidget {
  const _SectionChips({
    required this.sections,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<SectionItem> sections;
  final String selectedKey;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _ChannelChip(
          label: uiText(context, zh: '全部', en: 'All'),
          dot: null,
          selected: selectedKey.isEmpty,
          onTap: onSelected == null ? null : () => onSelected!(''),
        ),
        for (final SectionItem section in sections)
          _ChannelChip(
            label: section.sectionName,
            dot: t.channelFor(section.sectionName),
            selected: selectedKey == section.key,
            onTap: onSelected == null ? null : () => onSelected!(section.key),
          ),
      ],
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({
    required this.label,
    required this.dot,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? dot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Material(
      color: selected ? t.text : t.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? t.text : t.line)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (dot != null) ...<Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: ZxType.caption.copyWith(
                  color: selected ? t.surface : t.text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostsPanel extends StatelessWidget {
  const _PostsPanel({
    required this.wide,
    required this.state,
    required this.onRetry,
    required this.onCreate,
    required this.onPostOpen,
    required this.onLike,
    required this.onFavorite,
  });

  final bool wide;
  final FeedState state;
  final VoidCallback onRetry;
  final VoidCallback? onCreate;
  final ValueChanged<PostItem> onPostOpen;
  final ValueChanged<PostItem> onLike;
  final ValueChanged<PostItem> onFavorite;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Widget? message;
    if (state.loading) {
      message = Column(
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: t.line),
            const _PostSkeleton(),
          ],
        ],
      );
    } else if (state.error != null && state.posts.isEmpty) {
      message = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: ZxStatePanel(
          icon: Icons.cloud_off_rounded,
          title: uiText(context, zh: '内容加载失败', en: 'Could not load content'),
          message: state.error,
          actionLabel: uiText(context, zh: '重试', en: 'Retry'),
          onAction: onRetry,
          error: true,
        ),
      );
    } else if (state.posts.isEmpty) {
      message = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: ZxStatePanel(
          title: uiText(context, zh: '这里还没有帖子', en: 'No posts yet'),
          message: uiText(
            context,
            zh: '成为第一位分享校园日常的人',
            en: 'Be the first to share something from campus.',
          ),
          actionLabel: onCreate == null
              ? null
              : uiText(context, zh: '发布帖子', en: 'Create post'),
          onAction: onCreate,
        ),
      );
    } else {
      message = null;
    }

    final int count = state.posts.length;
    // The footer row: a spinner while the next page loads.
    final bool footer = message == null && state.loadingMore;
    final Widget list = message != null
        ? SliverToBoxAdapter(child: message)
        : SliverList.builder(
            itemCount: count + (footer ? 1 : 0),
            itemBuilder: (BuildContext context, int i) {
              if (i == count) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final PostItem post = state.posts[i];
              final Widget card = PostCard(
                key: ValueKey<String>(post.id),
                post: post,
                onTap: () => onPostOpen(post),
                onLike: () => onLike(post),
                onFavorite: () => onFavorite(post),
              );
              final Widget row = i == 0
                  ? card
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Divider(height: 1, color: t.line),
                        card,
                      ],
                    );
              if (!wide) return row;
              // Keep the hover ink inside the panel's rounded corners.
              final bool first = i == 0;
              final bool last = i == count - 1 && !footer;
              if (!first && !last) return row;
              return ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: first ? ZxRadius.sheetAll.topLeft : Radius.zero,
                  bottom: last ? ZxRadius.sheetAll.bottomLeft : Radius.zero,
                ),
                child: row,
              );
            },
          );
    if (!wide) {
      return DecoratedSliver(
        decoration: BoxDecoration(color: t.surface),
        sliver: list,
      );
    }
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: ZxRadius.sheetAll,
        border: Border.all(color: t.line),
        boxShadow: t.shadow1,
      ),
      sliver: SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        sliver: list,
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ZxSkeleton(
            width: 40,
            height: 40,
            borderRadius: ZxRadius.smallButtonAll,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ZxSkeleton(width: 140),
                SizedBox(height: 12),
                ZxSkeleton(height: 16),
                SizedBox(height: 8),
                ZxSkeleton(width: 260),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Aside extends StatelessWidget {
  const _Aside({required this.posts, required this.onPostOpen});

  final List<PostItem> posts;
  final ValueChanged<PostItem> onPostOpen;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    // The loaded posts with the most replies.
    final List<PostItem> discussed = List<PostItem>.of(posts)
      ..sort(
        (PostItem a, PostItem b) => b.commentCount.compareTo(a.commentCount),
      );
    final List<PostItem> top = discussed
        .where((PostItem p) => p.commentCount > 0)
        .take(5)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ZxCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.local_fire_department_outlined,
                    size: 18,
                    color: t.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    uiText(context, zh: '正在讨论', en: 'In discussion'),
                    style: ZxType.label.copyWith(color: t.text),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (top.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    uiText(context, zh: '暂时没有讨论', en: 'No discussions yet'),
                    style: ZxType.caption.copyWith(color: t.text3),
                  ),
                )
              else
                for (int i = 0; i < top.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, color: t.line),
                  InkWell(
                    onTap: () => onPostOpen(top[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${i + 1}',
                              style: ZxType.headline.copyWith(
                                fontSize: 18,
                                height: 1.2,
                                color: t.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  top[i].title.trim().isEmpty
                                      ? top[i].content.trim()
                                      : top[i].title.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: ZxType.caption.copyWith(
                                    color: t.text,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  uiText(
                                    context,
                                    zh: '${top[i].commentCount} 条回复',
                                    en: '${top[i].commentCount} replies',
                                  ),
                                  style: ZxType.micro.copyWith(
                                    color: t.text3,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Principles(t: t),
        const SizedBox(height: 14),
        ZxCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: ZxListItem(
            icon: Icons.download_rounded,
            iconColor: t.success,
            title: uiText(context, zh: 'Android 客户端', en: 'Android app'),
            subtitle: uiText(context, zh: '下载安装包', en: 'Download the APK'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AndroidReleasePage(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Principles extends StatelessWidget {
  const _Principles({required this.t});

  final ZxTokens t;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: t.accentSoft,
      borderRadius: ZxRadius.cardAll,
      child: InkWell(
        borderRadius: ZxRadius.cardAll,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CommunityGuidelinesPage(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '“',
                style: ZxType.display.copyWith(
                  fontSize: 30,
                  height: 1,
                  color: t.accentInk,
                ),
              ),
              Text(
                uiText(
                  context,
                  zh: '尊重每一次认真表达。\n匿名不等于无边界。',
                  en: 'Respect every sincere voice.\nAnonymity still has limits.',
                ),
                style: ZxType.headline.copyWith(
                  fontSize: 16,
                  height: 1.7,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Text(
                    uiText(context, zh: '社区规范', en: 'Guidelines'),
                    style: ZxType.caption.copyWith(
                      color: t.accentInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: t.accentInk,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
