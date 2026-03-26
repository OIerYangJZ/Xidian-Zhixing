import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import '../home/post_card.dart';

/// 搜索页
/// 支持搜索历史、热门搜索、搜索结果列表、筛选功能
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isSearching = false;
  List<PostItem> _searchResults = [];

  // 筛选状态
  String _selectedChannel = '全部';
  PostStatus? _selectedStatus;
  bool? _hasImageFilter;

  final List<String> _channels = [
    '全部',
    '学习',
    '吐槽日常',
    '失物招领',
    '二手交易',
    '找搭子',
  ];

  final List<String> _hotSearchKeywords = [
    '期末考试',
    '二手交易',
    '找搭子',
    '租房',
    '学习资料',
    '考研',
    '保研',
    '组队',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSearch({bool saveHistory = true}) async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty &&
        _selectedChannel == '全部' &&
        _selectedStatus == null &&
        _hasImageFilter == null) {
      return;
    }

    setState(() {
      _isSearching = true;
    });

    if (keyword.isNotEmpty && saveHistory) {
      ref.read(searchHistoryProvider.notifier).add(keyword);
    }

    try {
      final postRepo = ref.read(postRepositoryProvider);
      final results = await postRepo.fetchPosts(
        keyword: keyword.isEmpty ? null : keyword,
        channel: _selectedChannel == '全部' ? null : _selectedChannel,
        status: _selectedStatus,
        hasImage: _hasImageFilter,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  void _handleKeywordTap(String keyword) {
    _searchController.text = keyword;
    _handleSearch();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MobileTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _FilterSheet(
        selectedChannel: _selectedChannel,
        selectedStatus: _selectedStatus,
        hasImageFilter: _hasImageFilter,
        channels: _channels,
        onApply: (channel, status, hasImage) {
          setState(() {
            _selectedChannel = channel;
            _selectedStatus = status;
            _hasImageFilter = hasImage;
          });
          Navigator.pop(context);
          _handleSearch(saveHistory: false);
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedChannel = '全部';
      _selectedStatus = null;
      _hasImageFilter = null;
    });
    _handleSearch(saveHistory: false);
  }

  bool get _hasActiveFilters =>
      _selectedChannel != '全部' ||
      _selectedStatus != null ||
      _hasImageFilter != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MobileTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏
            _buildSearchBar(),

            // 内容
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isNotEmpty
                      ? _buildSearchResults()
                      : _buildSearchContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: MobileTheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _handleSearch(),
                    decoration: InputDecoration(
                      hintText: '搜索帖子...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: MobileTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterButton(),
              ],
            ),
          ),

          // 筛选标签
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  _buildFilterChip('频道: $_selectedChannel', () {
                    setState(() => _selectedChannel = '全部');
                    _handleSearch(saveHistory: false);
                  }),
                  if (_selectedStatus != null)
                    _buildFilterChip('状态: ${_selectedStatus!.label}', () {
                      setState(() => _selectedStatus = null);
                      _handleSearch(saveHistory: false);
                    }),
                  if (_hasImageFilter == true)
                    _buildFilterChip('有图', () {
                      setState(() => _hasImageFilter = null);
                      _handleSearch(saveHistory: false);
                    }),
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearFilters,
                    child: const Text(
                      '清除筛选',
                      style: TextStyle(
                        fontSize: 13,
                        color: MobileTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return GestureDetector(
      onTap: _showFilterSheet,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _hasActiveFilters
              ? MobileTheme.primary.withValues(alpha: 0.1)
              : MobileTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                _hasActiveFilters ? MobileTheme.primary : MobileTheme.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune,
              size: 20,
              color: _hasActiveFilters
                  ? MobileTheme.primary
                  : MobileTheme.textSecondary,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: MobileTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _getActiveFilterCount().toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedChannel != '全部') count++;
    if (_selectedStatus != null) count++;
    if (_hasImageFilter != null) count++;
    return count;
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MobileTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: MobileTheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: MobileTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return PostCard(
          post: post,
          onTap: () => context.push('/post/${post.id}'),
        );
      },
    );
  }

  Widget _buildSearchContent() {
    final searchHistory = ref.watch(searchHistoryProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索历史
          if (searchHistory.isNotEmpty) ...[
            const _SectionHeader(title: '搜索历史', showClear: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: searchHistory.map((keyword) {
                  return GestureDetector(
                    onTap: () => _handleKeywordTap(keyword),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: MobileTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: MobileTheme.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history,
                            size: 14,
                            color: MobileTheme.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            keyword,
                            style: const TextStyle(
                              fontSize: 13,
                              color: MobileTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(searchHistoryProvider.notifier)
                                  .remove(keyword);
                            },
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: MobileTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
          ],

          // 热门搜索
          const _SectionHeader(title: '热门搜索'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hotSearchKeywords.asMap().entries.map((entry) {
                final index = entry.key;
                final keyword = entry.value;
                return GestureDetector(
                  onTap: () => _handleKeywordTap(keyword),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: index < 3
                          ? MobileTheme.accent.withValues(alpha: 0.1)
                          : MobileTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            index < 3 ? MobileTheme.accent : MobileTheme.divider,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (index < 3)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: MobileTheme.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Text(
                          keyword,
                          style: TextStyle(
                            fontSize: 13,
                            color: index < 3
                                ? MobileTheme.accent
                                : MobileTheme.textSecondary,
                            fontWeight:
                                index < 3 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // 搜索提示
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: MobileTheme.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '搜索技巧',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MobileTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '• 输入关键词搜索帖子标题和内容\n'
                  '• 使用筛选功能过滤频道、状态\n'
                  '• 点击热门搜索快速查找',
                  style: TextStyle(
                    fontSize: 12,
                    color: MobileTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 区块头部（标题 + 可选清空）
class _SectionHeader extends ConsumerWidget {
  final String title;
  final bool showClear;

  const _SectionHeader({required this.title, this.showClear = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MobileTheme.textPrimary,
            ),
          ),
          if (showClear)
            GestureDetector(
              onTap: () {
                ref.read(searchHistoryProvider.notifier).clear();
              },
              child: const Text(
                '清空',
                style: TextStyle(
                  fontSize: 13,
                  color: MobileTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 筛选面板
class _FilterSheet extends StatefulWidget {
  final String selectedChannel;
  final PostStatus? selectedStatus;
  final bool? hasImageFilter;
  final List<String> channels;
  final Function(String, PostStatus?, bool?) onApply;

  const _FilterSheet({
    required this.selectedChannel,
    required this.selectedStatus,
    required this.hasImageFilter,
    required this.channels,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _channel;
  late PostStatus? _status;
  late bool? _hasImage;

  @override
  void initState() {
    super.initState();
    _channel = widget.selectedChannel;
    _status = widget.selectedStatus;
    _hasImage = widget.hasImageFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '筛选',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MobileTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _channel = '全部';
                    _status = null;
                    _hasImage = null;
                  });
                },
                child: const Text(
                  '重置',
                  style: TextStyle(
                    fontSize: 14,
                    color: MobileTheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 频道筛选
          const Text(
            '频道',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MobileTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.channels.map((channel) {
              final isSelected = channel == _channel;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _channel = channel;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MobileTheme.primary
                        : MobileTheme.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? MobileTheme.primary
                          : MobileTheme.divider,
                    ),
                  ),
                  child: Text(
                    channel,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          isSelected ? Colors.white : MobileTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // 状态筛选
          const Text(
            '状态',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MobileTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...PostStatus.values.map((status) {
                final isSelected = status == _status;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _status = isSelected ? null : status;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MobileTheme.primary
                          : MobileTheme.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? MobileTheme.primary
                            : MobileTheme.divider,
                      ),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                            ? Colors.white
                            : MobileTheme.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 20),

          // 图片筛选
          Row(
            children: [
              const Text(
                '仅显示有图片',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MobileTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: _hasImage ?? false,
                onChanged: (value) {
                  setState(() {
                    _hasImage = value ? true : null;
                  });
                },
                activeThumbColor: MobileTheme.primary,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 确认按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_channel, _status, _hasImage);
              },
              child: const Text('应用筛选'),
            ),
          ),
        ],
      ),
    );
  }
}
