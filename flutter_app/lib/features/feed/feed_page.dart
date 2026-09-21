import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../core/l10n/ui_text.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import 'feed_controller.dart';
import 'discussion_feed_view.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  static void openFilterSheet(BuildContext context, WidgetRef ref) {
    final FeedState state = ref.read(feedControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext context) {
        return _FeedFilterSheet(initialState: state);
      },
    );
  }

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}
class _FeedPageState extends ConsumerState<FeedPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      final FeedState state = ref.read(feedControllerProvider);
      if (!state.loading || state.posts.isNotEmpty) {
        return Future<void>.value();
      }
      return ref.read(feedControllerProvider.notifier).loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final FeedState state = ref.watch(feedControllerProvider);
    return DiscussionFeedView(
      state: state,
      onRefresh: () =>
          ref.read(feedControllerProvider.notifier).refreshPosts(),
      onLoadMore: () =>
          ref.read(feedControllerProvider.notifier).loadMoreIfNeeded(),
      onRetry: () => ref.read(feedControllerProvider.notifier).loadInitial(),
      onFilter: () => FeedPage.openFilterSheet(context, ref),
      onSortChanged: (PostSort sort) =>
          ref.read(feedControllerProvider.notifier).switchSort(sort),
      onPostOpen: _openPost,
      onLike: _toggleLike,
      onFavorite: _toggleFavorite,
    );
  }

  Future<void> _toggleLike(PostItem post) async {
    try {
      await ref.read(feedControllerProvider.notifier).toggleLike(post);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(context, zh: '操作失败：$error', en: 'Action failed: $error'),
          ),
        ),
      );
    }
  }

  Future<void> _openPost(PostItem post) async {
    final PostItem? updated = await openPostDetailPage(context, post: post);
    if (updated == null || !mounted) {
      return;
    }
    ref.read(feedControllerProvider.notifier).replacePost(updated);
  }

  Future<void> _toggleFavorite(PostItem post) async {
    try {
      await ref.read(feedControllerProvider.notifier).toggleFavorite(post);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(context, zh: '操作失败：$error', en: 'Action failed: $error'),
          ),
        ),
      );
    }
  }
}

class _FeedFilterSheet extends ConsumerWidget {
  const _FeedFilterSheet({required this.initialState});

  final FeedState initialState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FeedState state = ref.watch(feedControllerProvider);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        _FilterSectionTitle(uiText(context, zh: '排序', en: 'Sort')),
        _FilterItem(
          label: l10n.latest,
          selected: state.sort == PostSort.latest,
          onTap: () {
            ref
                .read(feedControllerProvider.notifier)
                .switchSort(PostSort.latest);
            Navigator.of(context).pop();
          },
        ),
        _FilterItem(
          label: l10n.popular,
          selected: state.sort == PostSort.hot,
          onTap: () {
            ref.read(feedControllerProvider.notifier).switchSort(PostSort.hot);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 8),
        _FilterSectionTitle(uiText(context, zh: '分区', en: 'Channel')),
        for (final String channel in state.channels)
          _FilterItem(
            label: channel,
            selected: state.selectedChannel == channel,
            onTap: () {
              ref.read(feedControllerProvider.notifier).switchChannel(channel);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.56),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  const _FilterItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(label),
      trailing: selected
          ? Icon(
              Icons.check_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}
