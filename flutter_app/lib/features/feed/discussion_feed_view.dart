import 'package:flutter/material.dart';

import '../../core/auth/auth_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import '../post/create_post_page.dart';
import 'feed_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    return AppPageFrame(
      maxWidth: AppBreakpoints.isDesktop(context)
          ? AppLayout.referenceFeed *
                AppLayout.shellScale(MediaQuery.sizeOf(context).width)
          : double.infinity,
      padding: EdgeInsets.zero,
      child: _DiscussionTimeline(
        state: state,
        onRefresh: onRefresh,
        onLoadMore: onLoadMore,
        onRetry: onRetry,
        onFilter: onFilter,
        onSortChanged: onSortChanged,
        onPostOpen: onPostOpen,
        onLike: onLike,
        onFavorite: onFavorite,
      ),
    );
  }
}

class _DiscussionTimeline extends StatelessWidget {
  const _DiscussionTimeline({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.onFilter,
    required this.onSortChanged,
    required this.onPostOpen,
    required this.onLike,
    required this.onFavorite,
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

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final bool desktop = AppBreakpoints.isDesktop(context);
    final double scale = desktop
        ? AppLayout.shellScale(MediaQuery.sizeOf(context).width)
        : 1;
    final BorderRadius radius = desktop
        ? BorderRadius.vertical(top: Radius.circular(34 * scale))
        : BorderRadius.zero;
    final Widget panel = Container(
      key: const Key('discussion-feed-panel'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: radius,
      ),
      child: Column(
        children: <Widget>[
          if (desktop) _DesktopComposer(onRefresh: onRefresh, scale: scale),
          Expanded(
            child: _DiscussionFeedBody(
              state: state,
              onRefresh: onRefresh,
              onLoadMore: onLoadMore,
              onRetry: onRetry,
              onPostOpen: onPostOpen,
              onLike: onLike,
              onFavorite: onFavorite,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: <Widget>[
        if (desktop) SizedBox(height: 100 * scale),
        Expanded(child: panel),
      ],
    );
  }
}

class _DesktopComposer extends StatelessWidget {
  const _DesktopComposer({required this.onRefresh, required this.scale});

  final Future<void> Function() onRefresh;
  final double scale;

  Future<void> _create(BuildContext context) async {
    // Use the authenticated app's existing editor and current section navigator.
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const CreatePostPage()),
    );
    if (created == true) await onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final colors = EditorialColors.of(context);
    return Container(
      key: const Key('desktop-feed-composer'),
      constraints: BoxConstraints(minHeight: (105 * scale).clamp(72, 105)),
      padding: EdgeInsets.symmetric(
        horizontal: 33 * scale,
        vertical: 16 * scale,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: <Widget>[
          ListenableBuilder(
            listenable: AuthStore.instance,
            builder: (context, _) {
              final user = AuthStore.instance.currentUser;
              final avatar = user?.avatarUrl.trim() ?? '';
              final name = user?.nickname.trim() ?? '';
              return CircleAvatar(
                radius: 25 * scale,
                backgroundColor: colors.primarySubtle,
                foregroundColor: colors.ink,
                backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                child: avatar.isNotEmpty
                    ? null
                    : Text(
                        name.isEmpty
                            ? uiText(context, zh: '匿', en: 'A')
                            : name.characters.first,
                      ),
              );
            },
          ),
          SizedBox(width: 17 * scale),
          Expanded(
            child: TextButton(
              key: const Key('desktop-feed-compose-prompt'),
              onPressed: () => _create(context),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                foregroundColor: colors.mutedInk,
                textStyle: Theme.of(context).textTheme.bodyLarge,
              ),
              child: Text(uiText(context, zh: '有什么新鲜事？', en: "What's new?")),
            ),
          ),
          SizedBox(width: 17 * scale),
          OutlinedButton(
            key: const Key('desktop-feed-compose-post'),
            onPressed: () => _create(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 40),
              padding: EdgeInsets.symmetric(horizontal: 22 * scale),
              side: BorderSide(color: colors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15 * scale),
              ),
            ),
            child: Text(
              l10n.createPost,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscussionFeedBody extends StatelessWidget {
  const _DiscussionFeedBody({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.onPostOpen,
    required this.onLike,
    required this.onFavorite,
  });

  final FeedState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final ValueChanged<PostItem> onPostOpen;
  final ValueChanged<PostItem> onLike;
  final ValueChanged<PostItem> onFavorite;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.posts.isEmpty) {
      return AppStatePanel(
        icon: Icons.cloud_off_outlined,
        title: uiText(context, zh: '内容加载失败', en: 'Could not load content'),
        message: state.error!,
        action: TextButton(
          onPressed: onRetry,
          child: Text(uiText(context, zh: '重试', en: 'Retry')),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.extentAfter < 420) {
            onLoadMore();
          }
          return false;
        },
        child: ListView.separated(
          key: const Key('discussion-feed-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: state.posts.isEmpty
              ? 1
              : state.posts.length + (state.loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox.shrink(),
          itemBuilder: (BuildContext context, int index) {
            if (state.posts.isEmpty) {
              return SizedBox(
                height: 320,
                child: AppStatePanel(
                  icon: Icons.forum_outlined,
                  title: uiText(context, zh: '这里还没有帖子', en: 'No posts yet'),
                  message: uiText(
                    context,
                    zh: '成为第一位分享校园日常的人。',
                    en: 'Be the first to share something from campus.',
                  ),
                ),
              );
            }
            if (index == state.posts.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final PostItem post = state.posts[index];
            return PostCard(
              post: post,
              onTap: () => onPostOpen(post),
              onLike: () => onLike(post),
              onFavorite: () => onFavorite(post),
            );
          },
        ),
      ),
    );
  }
}
