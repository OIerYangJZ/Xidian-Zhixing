import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/discussion_home_scaffold.dart';
import '../../widgets/post_card.dart';
import '../download/android_release_page.dart';
import '../legal/community_guidelines_page.dart';
import 'feed_controller.dart';

/// 树洞 feed (handoff W1 / W4 / W5).
///
/// With the sidebar (≥ 960): hero header with 推荐 / 最新 and 选择分区,
/// channel chips, the posts in one panel, and from 1200 an aside with
/// 正在讨论, the community principles and the Android download. Narrower,
/// the top bar carries the title, so the feed starts with the sort switch
/// and the active channel.
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
    this.onChannelSelected,
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
  final ValueChanged<String>? onChannelSelected;

  /// 发布帖子 on the empty state.
  final VoidCallback? onCreate;

  static const String _allChannels = '全部';

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
        child: ListView(
          key: const Key('discussion-feed-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, wide ? 24 : 8, 0, 120),
          children: <Widget>[
            if (wide) ...<Widget>[
              _Hero(
                sort: state.sort,
                onSortChanged: onSortChanged,
                onFilter: onFilter,
              ),
              const SizedBox(height: 14),
              _ChannelChips(
                channels: state.channels,
                selected: state.selectedChannel,
                onSelected: onChannelSelected,
              ),
              const SizedBox(height: 14),
            ] else ...<Widget>[
              _CompactHeader(
                sort: state.sort,
                channel: state.selectedChannel,
                onSortChanged: onSortChanged,
                onClearChannel: onChannelSelected == null
                    ? null
                    : () => onChannelSelected!(_allChannels),
              ),
              const SizedBox(height: 8),
            ],
            _PostsPanel(
              wide: wide,
              state: state,
              onRetry: onRetry,
              onCreate: onCreate,
              onPostOpen: onPostOpen,
              onLike: onLike,
              onFavorite: onFavorite,
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
    required this.channel,
    required this.onSortChanged,
    required this.onClearChannel,
  });

  final PostSort sort;
  final String channel;
  final ValueChanged<PostSort> onSortChanged;
  final VoidCallback? onClearChannel;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final bool filtered = channel.isNotEmpty && channel != '全部';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          _SortSwitch(sort: sort, onChanged: onSortChanged),
          const Spacer(),
          if (filtered)
            InputChip(
              avatar: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: t.channelFor(channel),
                  shape: BoxShape.circle,
                ),
              ),
              label: Text(
                localizedChannel(Localizations.localeOf(context), channel),
              ),
              onDeleted: onClearChannel,
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

class _ChannelChips extends StatelessWidget {
  const _ChannelChips({
    required this.channels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> channels;
  final String selected;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final List<String> all = <String>[
      DiscussionFeedView._allChannels,
      ...channels.where((String c) => c != DiscussionFeedView._allChannels),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String channel in all)
          _ChannelChip(
            label: channel == DiscussionFeedView._allChannels
                ? uiText(context, zh: '全部', en: 'All')
                : localizedChannel(locale, channel),
            dot: channel == DiscussionFeedView._allChannels
                ? null
                : t.channelFor(channel),
            selected: selected == channel,
            onTap: onSelected == null ? null : () => onSelected!(channel),
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
    final Widget body;
    if (state.loading) {
      body = Column(
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: t.line),
            const _PostSkeleton(),
          ],
        ],
      );
    } else if (state.error != null && state.posts.isEmpty) {
      body = Padding(
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
      body = Padding(
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
      body = Column(
        children: <Widget>[
          for (int i = 0; i < state.posts.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: t.line),
            PostCard(
              post: state.posts[i],
              onTap: () => onPostOpen(state.posts[i]),
              onLike: () => onLike(state.posts[i]),
              onFavorite: () => onFavorite(state.posts[i]),
            ),
          ],
          if (state.loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }
    if (!wide) {
      return ColoredBox(color: t.surface, child: body);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: ZxRadius.sheetAll,
        border: Border.all(color: t.line),
        boxShadow: t.shadow1,
      ),
      child: ClipRRect(borderRadius: ZxRadius.sheetAll, child: body),
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
          ZxSkeleton(width: 40, height: 40, borderRadius: ZxRadius.pillAll),
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
