import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../core/widgets/async_page_state.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import 'search_controller.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const List<PostSort> _webSorts = <PostSort>[
    PostSort.latest,
    PostSort.hot,
  ];

  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(searchControllerProvider.notifier).loadInitial(),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SearchState state = ref.watch(searchControllerProvider);
    return AsyncPageState(
      loading: state.loading,
      error: state.error,
      onRetry: () => ref.read(searchControllerProvider.notifier).loadInitial(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          TextField(
            controller: _queryController,
            decoration: const InputDecoration(
              hintText: '输入关键词搜索：标题/正文/标签/频道',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => _submitSearch(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  initialValue: state.selectedChannel,
                  decoration: const InputDecoration(
                    labelText: '频道',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: state.channels
                      .map(
                        (String c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(c),
                        ),
                      )
                      .toList(),
                  onChanged: state.searching
                      ? null
                      : (String? value) {
                          if (value == null) {
                            return;
                          }
                          ref
                              .read(searchControllerProvider.notifier)
                              .updateChannel(value);
                        },
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<PostStatus?>(
                  initialValue: state.status,
                  decoration: const InputDecoration(
                    labelText: '状态',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: <DropdownMenuItem<PostStatus?>>[
                    const DropdownMenuItem<PostStatus?>(
                      value: null,
                      child: Text('全部状态'),
                    ),
                    ...PostStatus.values.map(
                      (PostStatus status) => DropdownMenuItem<PostStatus?>(
                        value: status,
                        child: Text(status.label),
                      ),
                    ),
                  ],
                  onChanged: state.searching
                      ? null
                      : (PostStatus? value) {
                          ref
                              .read(searchControllerProvider.notifier)
                              .updateStatus(value);
                        },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<PostSort>(
                  initialValue: state.sort,
                  decoration: const InputDecoration(
                    labelText: '排序',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: _webSorts
                      .map(
                        (PostSort value) => DropdownMenuItem<PostSort>(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: state.searching
                      ? null
                      : (PostSort? value) {
                          if (value == null) {
                            return;
                          }
                          ref
                              .read(searchControllerProvider.notifier)
                              .updateSort(value);
                        },
                ),
              ),
              FilterChip(
                label: const Text('仅看有图'),
                selected: state.imageOnly,
                onSelected: state.searching
                    ? null
                    : (bool selected) {
                        ref
                            .read(searchControllerProvider.notifier)
                            .updateImageOnly(selected);
                      },
              ),
              FilterChip(
                label: const Text('仅看可私信'),
                selected: state.dmOnly,
                onSelected: state.searching
                    ? null
                    : (bool selected) {
                        ref
                            .read(searchControllerProvider.notifier)
                            .updateDmOnly(selected);
                      },
              ),
              FilledButton.icon(
                onPressed: state.searching ? null : _submitSearch,
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
              ),
            ],
          ),
          if (state.searching)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 10),
          Text('共找到 ${state.results.length} 条结果'),
          const SizedBox(height: 6),
          ...state.results.map(
            (PostItem post) => PostCard(
              post: post,
              onTap: () async {
                final PostItem? updated =
                    await openPostDetailPage(context, post: post);
                if (updated == null || !mounted) {
                  return;
                }
                ref.read(searchControllerProvider.notifier).replaceResult(
                      updated,
                    );
              },
            ),
          ),
          if (state.results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('没有匹配内容，换个关键词试试。')),
            ),
        ],
      ),
    );
  }

  Future<void> _submitSearch() {
    ref
        .read(searchControllerProvider.notifier)
        .setKeyword(_queryController.text.trim());
    return ref.read(searchControllerProvider.notifier).search();
  }
}
