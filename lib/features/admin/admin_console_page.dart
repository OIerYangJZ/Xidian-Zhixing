import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../models/admin_models.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/admin_repository.dart';

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({
    super.key,
    this.repository,
    this.onLogout,
  });

  final AdminRepository? repository;
  final Future<void> Function()? onLogout;

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  AdminOverview? _overview;
  List<AdminReviewItem> _reviews = const <AdminReviewItem>[];
  List<AdminReportEntry> _reports = const <AdminReportEntry>[];
  List<AdminImageReviewItem> _imageReviews = const <AdminImageReviewItem>[];
  List<AdminUserEntry> _users = const <AdminUserEntry>[];
  AdminChannelTagData _channelTagData =
      AdminChannelTagData(channels: const <String>[], tags: const <String>[]);
  AdminSystemConfig _config = AdminSystemConfig(
    sensitiveWords: const <String>[],
    postRateLimit: 10,
    commentRateLimit: 30,
    messageRateLimit: 40,
    imageMaxMb: 5,
  );

  final TextEditingController _newChannelController = TextEditingController();
  final TextEditingController _newTagController = TextEditingController();
  final TextEditingController _sensitiveController = TextEditingController();
  final TextEditingController _postLimitController = TextEditingController();
  final TextEditingController _commentLimitController = TextEditingController();
  final TextEditingController _messageLimitController = TextEditingController();
  final TextEditingController _imageMaxController = TextEditingController();
  final TextEditingController _reportReasonController = TextEditingController();
  final TextEditingController _reportKeywordController =
      TextEditingController();
  final TextEditingController _userKeywordController = TextEditingController();
  final TextEditingController _imageKeywordController = TextEditingController();

  String _reviewType = 'post';
  String _reviewStatus = 'pending';
  String _reportStatus = 'all';
  String _imageStatus = 'pending';
  String _userFilter = 'all';

  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  AdminRepository get _repo => widget.repository ?? AppRepositories.admin;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _newChannelController.dispose();
    _newTagController.dispose();
    _sensitiveController.dispose();
    _postLimitController.dispose();
    _commentLimitController.dispose();
    _messageLimitController.dispose();
    _imageMaxController.dispose();
    _reportReasonController.dispose();
    _reportKeywordController.dispose();
    _userKeywordController.dispose();
    _imageKeywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理员后台工作台'),
        actions: <Widget>[
          IconButton(
            onPressed: _actionBusy ? null : _loadAll,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新全部',
          ),
          if (widget.onLogout != null)
            IconButton(
              onPressed: _actionBusy
                  ? null
                  : () async {
                      await widget.onLogout!.call();
                    },
              icon: const Icon(Icons.logout),
              tooltip: '退出管理员后台',
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFEAF4FA), Color(0xFFF5F9FC)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : DefaultTabController(
                length: 7,
                child: Column(
                  children: <Widget>[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: _buildDashboardHeader(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(14),
                        child: const TabBar(
                          isScrollable: true,
                          dividerColor: Colors.transparent,
                          tabs: <Tab>[
                            Tab(text: '概览'),
                            Tab(text: '内容审核'),
                            Tab(text: '举报处理'),
                            Tab(text: '图片审核'),
                            Tab(text: '用户管理'),
                            Tab(text: '分类标签'),
                            Tab(text: '系统配置'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: TabBarView(
                        children: <Widget>[
                          _buildOverviewTab(),
                          _buildReviewTab(),
                          _buildReportTab(),
                          _buildImageReviewTab(),
                          _buildUserTab(),
                          _buildChannelTagTab(),
                          _buildConfigTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDashboardHeader() {
    final AdminOverview overview = _overview ??
        AdminOverview(
          todayNewUsers: 0,
          todayPosts: 0,
          todayComments: 0,
          todayReports: 0,
          pendingReviews: 0,
          bannedUsers: 0,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFD5E2)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: <Widget>[
          _compactStatusChip(
              icon: Icons.person_add_alt_1,
              label: '今日新用户 ${overview.todayNewUsers}'),
          _compactStatusChip(
              icon: Icons.article_outlined,
              label: '今日发帖 ${overview.todayPosts}'),
          _compactStatusChip(
              icon: Icons.comment_outlined,
              label: '今日评论 ${overview.todayComments}'),
          _compactStatusChip(
              icon: Icons.flag_outlined,
              label: '今日举报 ${overview.todayReports}'),
          _compactStatusChip(
              icon: Icons.pending_actions_outlined,
              label: '待审核 ${overview.pendingReviews}'),
          _compactStatusChip(
              icon: Icons.gpp_bad_outlined,
              label: '封禁用户 ${overview.bannedUsers}'),
        ],
      ),
    );
  }

  Widget _compactStatusChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF5FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: const Color(0xFF155E75)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final AdminOverview overview = _overview ??
        AdminOverview(
          todayNewUsers: 0,
          todayPosts: 0,
          todayComments: 0,
          todayReports: 0,
          pendingReviews: 0,
          bannedUsers: 0,
        );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _metricCard(
              title: '今日新增用户',
              value: overview.todayNewUsers,
              icon: Icons.person_add_alt_1_rounded,
              color: const Color(0xFF2061A8),
            ),
            _metricCard(
              title: '今日发帖数',
              value: overview.todayPosts,
              icon: Icons.edit_note_rounded,
              color: const Color(0xFF126E5E),
            ),
            _metricCard(
              title: '今日评论数',
              value: overview.todayComments,
              icon: Icons.forum_outlined,
              color: const Color(0xFF5C4DB0),
            ),
            _metricCard(
              title: '今日举报数',
              value: overview.todayReports,
              icon: Icons.flag_circle_outlined,
              color: const Color(0xFFB34B1E),
            ),
            _metricCard(
              title: '待审核内容',
              value: overview.pendingReviews,
              icon: Icons.approval_outlined,
              color: const Color(0xFFA46A00),
            ),
            _metricCard(
              title: '被封禁用户',
              value: overview.bannedUsers,
              icon: Icons.gpp_bad_outlined,
              color: const Color(0xFFAF2333),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadAll,
                  icon: const Icon(Icons.sync),
                  label: const Text('刷新全部模块'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadReviews,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('刷新内容审核'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadReports,
                  icon: const Icon(Icons.rule_outlined),
                  label: const Text('刷新举报列表'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadImageReviews,
                  icon: const Icon(Icons.image_search_outlined),
                  label: const Text('刷新图片审核'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadUsers,
                  icon: const Icon(Icons.groups_2_outlined),
                  label: const Text('刷新用户列表'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: _reviewType,
                    decoration: const InputDecoration(labelText: '审核对象'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'post', child: Text('帖子')),
                      DropdownMenuItem(value: 'comment', child: Text('评论')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _reviewType = value;
                      });
                      _loadReviews();
                    },
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: _reviewStatus,
                    decoration: const InputDecoration(labelText: '审核状态'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'pending', child: Text('待审核')),
                      DropdownMenuItem(value: 'approved', child: Text('已通过')),
                      DropdownMenuItem(value: 'rejected', child: Text('已驳回')),
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _reviewStatus = value;
                      });
                      _loadReviews();
                    },
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadReviews,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
              ],
            ),
          ),
        ),
        ..._reviews.map(
          (AdminReviewItem item) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _statusChip(item.reviewStatus),
                      if (item.riskMarked)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Chip(
                            label: Text('风险'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(item.content,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text('作者：${item.authorAlias} · 时间：${item.createdAt}'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _showSimpleDetail(
                          title: item.title,
                          subtitle: '作者：${item.authorAlias}',
                          content: item.content,
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('详情'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _handleReview(
                                item.targetType, item.id, 'approve'),
                        child: const Text('通过'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _handleReview(
                                item.targetType, item.id, 'reject'),
                        child: const Text('驳回'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () =>
                                _handleReview(item.targetType, item.id, 'risk'),
                        child: const Text('标风险'),
                      ),
                      FilledButton.tonal(
                        onPressed: _actionBusy
                            ? null
                            : () => _handleReview(
                                item.targetType, item.id, 'delete'),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('当前条件下暂无审核内容。')),
          ),
      ],
    );
  }

  Widget _buildReportTab() {
    final String reasonKeyword =
        _reportReasonController.text.trim().toLowerCase();
    final String textKeyword =
        _reportKeywordController.text.trim().toLowerCase();

    final List<AdminReportEntry> rows = _reports.where((AdminReportEntry item) {
      final bool matchReason = reasonKeyword.isEmpty ||
          item.reason.toLowerCase().contains(reasonKeyword);
      final String merged =
          '${item.id} ${item.targetType} ${item.targetId} ${item.reporterAlias} ${item.description} ${item.result}'
              .toLowerCase();
      final bool matchText =
          textKeyword.isEmpty || merged.contains(textKeyword);
      return matchReason && matchText;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _reportStatus,
                    decoration: const InputDecoration(labelText: '举报状态'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(value: 'pending', child: Text('待处理')),
                      DropdownMenuItem(value: 'resolved', child: Text('已处理')),
                      DropdownMenuItem(value: 'closed', child: Text('已关闭')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _reportStatus = value;
                      });
                      _loadReports();
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _reportReasonController,
                    decoration: const InputDecoration(
                      labelText: '原因筛选',
                      hintText: '例如：广告',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _reportKeywordController,
                    decoration: const InputDecoration(
                      labelText: '关键字筛选',
                      hintText: '举报单号 / 用户 / 描述',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadReports,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
              ],
            ),
          ),
        ),
        ...rows.map(
          (AdminReportEntry report) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '举报 ${report.id} · ${report.targetType}:${report.targetId}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _statusChip(report.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('原因：${report.reason}'),
                  if (report.description.isNotEmpty)
                    Text('说明：${report.description}'),
                  Text('举报人：${report.reporterAlias} · ${report.createdAt}'),
                  if (report.result.isNotEmpty) Text('处理结果：${report.result}'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _showSimpleDetail(
                          title: '举报 ${report.id}',
                          subtitle:
                              '目标：${report.targetType}:${report.targetId}',
                          content:
                              '原因：${report.reason}\n\n说明：${report.description}\n\n结果：${report.result}',
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('详情'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _promptAndHandleReport(
                                  reportId: report.id,
                                  action: 'delete_content',
                                  actionLabel: '删除内容',
                                  defaultResult: '内容已删除',
                                ),
                        child: const Text('删除内容'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _promptAndHandleReport(
                                  reportId: report.id,
                                  action: 'warn_user',
                                  actionLabel: '警告用户',
                                  defaultResult: '已警告用户',
                                ),
                        child: const Text('警告用户'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _promptAndHandleReport(
                                  reportId: report.id,
                                  action: 'ban_user',
                                  actionLabel: '封禁用户',
                                  defaultResult: '已封禁用户',
                                ),
                        child: const Text('封禁用户'),
                      ),
                      FilledButton.tonal(
                        onPressed: _actionBusy
                            ? null
                            : () => _promptAndHandleReport(
                                  reportId: report.id,
                                  action: 'mark_misreport',
                                  actionLabel: '标记误报',
                                  defaultResult: '标记为误报',
                                ),
                        child: const Text('标记误报'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('暂无匹配的举报记录。')),
          ),
      ],
    );
  }

  Widget _buildImageReviewTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _imageStatus,
                    decoration: const InputDecoration(labelText: '图片状态'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(value: 'pending', child: Text('待审核')),
                      DropdownMenuItem(value: 'approved', child: Text('已通过')),
                      DropdownMenuItem(value: 'rejected', child: Text('已拒绝')),
                      DropdownMenuItem(value: 'risk', child: Text('风险标记')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _imageStatus = value;
                      });
                      _loadImageReviews();
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _imageKeywordController,
                    decoration: const InputDecoration(
                      labelText: '图片搜索',
                      hintText: '文件名 / 上传者 / 风险原因',
                    ),
                    onSubmitted: (_) => _loadImageReviews(),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadImageReviews,
                  icon: const Icon(Icons.search),
                  label: const Text('查询'),
                ),
              ],
            ),
          ),
        ),
        ..._imageReviews.map(
          (AdminImageReviewItem item) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildImagePreview(item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                item.fileName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            _statusChip(item.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '上传者：${item.uploaderAlias} (${item.uploaderId})',
                        ),
                        Text('上传时间：${item.createdAt}'),
                        Text(
                          '类型：${item.contentType} · 大小：${_formatFileSize(item.sizeBytes)}',
                        ),
                        if (item.postId.trim().isNotEmpty)
                          Text('关联帖子：${item.postId}'),
                        if (item.moderationReason.trim().isNotEmpty)
                          Text('风控说明：${item.moderationReason}'),
                        if (item.reviewNote.trim().isNotEmpty)
                          Text('审核备注：${item.reviewNote}'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: () => _showImageDialog(item),
                              icon: const Icon(Icons.open_in_full_outlined),
                              label: const Text('查看大图'),
                            ),
                            OutlinedButton(
                              onPressed: _actionBusy
                                  ? null
                                  : () => _promptAndHandleImageReview(
                                        uploadId: item.id,
                                        action: 'approve',
                                        actionLabel: '通过图片',
                                        defaultNote: '已通过',
                                      ),
                              child: const Text('通过'),
                            ),
                            OutlinedButton(
                              onPressed: _actionBusy
                                  ? null
                                  : () => _promptAndHandleImageReview(
                                        uploadId: item.id,
                                        action: 'risk',
                                        actionLabel: '标记风险',
                                        defaultNote: '已标记风险',
                                      ),
                              child: const Text('风险'),
                            ),
                            OutlinedButton(
                              onPressed: _actionBusy
                                  ? null
                                  : () => _promptAndHandleImageReview(
                                        uploadId: item.id,
                                        action: 'reject',
                                        actionLabel: '拒绝图片',
                                        defaultNote: '已拒绝',
                                      ),
                              child: const Text('拒绝'),
                            ),
                            FilledButton.tonal(
                              onPressed: _actionBusy
                                  ? null
                                  : () => _promptAndHandleImageReview(
                                        uploadId: item.id,
                                        action: 'delete',
                                        actionLabel: '删除图片',
                                        defaultNote: '已删除图片',
                                      ),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_imageReviews.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('暂无匹配的图片审核记录。')),
          ),
      ],
    );
  }

  Widget _buildImagePreview(AdminImageReviewItem item) {
    final String resolvedUrl = _resolveMediaUrl(item.url);
    if (resolvedUrl.isEmpty) {
      return _imagePlaceholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        resolvedUrl,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }

  Widget _buildUserTab() {
    final String keyword = _userKeywordController.text.trim().toLowerCase();

    final List<AdminUserEntry> rows = _users.where((AdminUserEntry user) {
      final String merged =
          '${user.id} ${user.alias} ${user.email} ${user.createdAt}'
              .toLowerCase();
      final bool matchKeyword = keyword.isEmpty || merged.contains(keyword);

      final bool matchFilter;
      switch (_userFilter) {
        case 'admin':
          matchFilter = user.isAdmin;
          break;
        case 'banned':
          matchFilter = user.banned;
          break;
        case 'muted':
          matchFilter = user.muted;
          break;
        case 'normal':
          matchFilter = !user.banned && !user.muted;
          break;
        default:
          matchFilter = true;
      }

      return matchKeyword && matchFilter;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _userKeywordController,
                    decoration: const InputDecoration(
                      labelText: '用户搜索',
                      hintText: '昵称 / 邮箱 / ID',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _userFilter,
                    decoration: const InputDecoration(labelText: '状态筛选'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(value: 'normal', child: Text('正常')),
                      DropdownMenuItem(value: 'banned', child: Text('封禁中')),
                      DropdownMenuItem(value: 'muted', child: Text('禁言中')),
                      DropdownMenuItem(value: 'admin', child: Text('管理员')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _userFilter = value;
                      });
                    },
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadUsers,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新用户列表'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            '匹配用户 ${rows.length} / 总计 ${_users.length}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
        ),
        ...rows.map(
          (AdminUserEntry user) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${user.alias} (${user.email})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (user.verified)
                        const Chip(
                          label: Text('已认证'),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (user.isAdmin)
                        const Chip(
                          label: Text('管理员'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                          child: Text('ID: ${user.id} · 注册：${user.createdAt}')),
                      IconButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: user.id));
                          _toast('已复制用户ID：${user.id}');
                        },
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: '复制用户ID',
                      ),
                    ],
                  ),
                  Text(
                    '发帖 ${user.postCount} · 评论 ${user.commentCount} · 被举报 ${user.reportCount}',
                  ),
                  Text(
                    '状态：${user.banned ? '封禁' : '正常'} / ${user.muted ? '禁言' : '可发言'}',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _updateUser(user.id, 'mute'),
                        child: const Text('禁言'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _updateUser(user.id, 'unmute'),
                        child: const Text('解禁言'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _updateUser(user.id, 'ban'),
                        child: const Text('封禁'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _updateUser(user.id, 'unban'),
                        child: const Text('解封'),
                      ),
                      FilledButton.tonal(
                        onPressed: _actionBusy
                            ? null
                            : () => _updateUser(
                                user.id, user.isAdmin ? 'demote' : 'promote'),
                        child: Text(user.isAdmin ? '取消管理员' : '设为管理员'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('暂无匹配用户数据。')),
          ),
      ],
    );
  }

  Widget _buildChannelTagTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '频道管理',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _newChannelController,
                        decoration: const InputDecoration(labelText: '新增频道名'),
                      ),
                    ),
                    FilledButton(
                      onPressed: _actionBusy ? null : _addChannel,
                      child: const Text('新增频道'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._channelTagData.channels.map(
                  (String channel) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(channel),
                    trailing: Wrap(
                      spacing: 4,
                      children: <Widget>[
                        IconButton(
                          onPressed: _actionBusy
                              ? null
                              : () => _renameChannel(channel),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: _actionBusy
                              ? null
                              : () => _deleteChannel(channel),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '标签管理',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _newTagController,
                        decoration: const InputDecoration(labelText: '新增标签名'),
                      ),
                    ),
                    FilledButton(
                      onPressed: _actionBusy ? null : _addTag,
                      child: const Text('新增标签'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._channelTagData.tags.map(
                  (String tag) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(tag),
                    trailing: Wrap(
                      spacing: 4,
                      children: <Widget>[
                        IconButton(
                          onPressed: _actionBusy ? null : () => _renameTag(tag),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: _actionBusy ? null : () => _deleteTag(tag),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '系统风控配置',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('敏感词（英文逗号分隔）'),
                const SizedBox(height: 6),
                TextField(
                  controller: _sensitiveController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: '例如：广告,引流,辱骂,诈骗',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _postLimitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '发帖频率限制'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _commentLimitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '评论频率限制'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _messageLimitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '私信频率限制'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _imageMaxController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: '图片上限(MB)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _actionBusy ? null : _saveConfig,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存系统配置'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _actionBusy ? null : _loadConfig,
                      icon: const Icon(Icons.restore),
                      label: const Text('重新读取当前配置'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 188,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(color: Colors.black54)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final String normalized = status.trim().toLowerCase();
    final Map<String, Color> colors = <String, Color>{
      'pending': const Color(0xFFBB6B00),
      'approved': const Color(0xFF126E5E),
      'resolved': const Color(0xFF126E5E),
      'rejected': const Color(0xFFB42318),
      'closed': const Color(0xFF7A5C00),
      'risk': const Color(0xFF8F4B12),
    };
    final Map<String, String> labels = <String, String>{
      'pending': '待处理',
      'approved': '已通过',
      'resolved': '已处理',
      'rejected': '已拒绝',
      'closed': '已关闭',
      'risk': '风险',
    };
    final Color color = colors[normalized] ?? Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        labels[normalized] ?? status,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  String _resolveMediaUrl(String value) {
    final String text = value.trim();
    if (text.isEmpty) {
      return '';
    }
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }
    if (!text.startsWith('/')) {
      return '';
    }
    final Uri base = Uri.parse(AppConfig.apiBaseUrl);
    return '${base.scheme}://${base.authority}$text';
  }

  String _formatFileSize(int sizeBytes) {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    }
    final double kb = sizeBytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final double mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final AdminOverview overview = await _repo.fetchOverview();
      final List<AdminReviewItem> reviews = await _repo.fetchReviews(
        type: _reviewType,
        status: _reviewStatus,
      );
      final List<AdminReportEntry> reports =
          await _repo.fetchReports(status: _reportStatus);
      final List<AdminImageReviewItem> imageReviews =
          await _repo.fetchImageReviews(
        status: _imageStatus,
        keyword: _imageKeywordController.text.trim(),
      );
      final List<AdminUserEntry> users = await _repo.fetchUsers();
      final AdminChannelTagData channelTagData =
          await _repo.fetchChannelTagData();
      final AdminSystemConfig config = await _repo.fetchConfig();

      if (!mounted) {
        return;
      }

      setState(() {
        _overview = overview;
        _reviews = reviews;
        _reports = reports;
        _imageReviews = imageReviews;
        _users = users;
        _channelTagData = channelTagData;
        _config = config;
      });

      _syncConfigControllers();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '后台数据加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadReviews() async {
    try {
      final List<AdminReviewItem> reviews = await _repo.fetchReviews(
        type: _reviewType,
        status: _reviewStatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _reviews = reviews;
      });
    } catch (error) {
      _toast('加载审核列表失败：$error');
    }
  }

  Future<void> _loadReports() async {
    try {
      final List<AdminReportEntry> reports =
          await _repo.fetchReports(status: _reportStatus);
      if (!mounted) {
        return;
      }
      setState(() {
        _reports = reports;
      });
    } catch (error) {
      _toast('加载举报列表失败：$error');
    }
  }

  Future<void> _loadImageReviews() async {
    try {
      final List<AdminImageReviewItem> rows = await _repo.fetchImageReviews(
        status: _imageStatus,
        keyword: _imageKeywordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _imageReviews = rows;
      });
    } catch (error) {
      _toast('加载图片审核列表失败：$error');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final List<AdminUserEntry> users = await _repo.fetchUsers();
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users;
      });
    } catch (error) {
      _toast('加载用户列表失败：$error');
    }
  }

  Future<void> _loadChannelTag() async {
    try {
      final AdminChannelTagData data = await _repo.fetchChannelTagData();
      if (!mounted) {
        return;
      }
      setState(() {
        _channelTagData = data;
      });
    } catch (error) {
      _toast('加载分类标签失败：$error');
    }
  }

  Future<void> _loadConfig() async {
    try {
      final AdminSystemConfig config = await _repo.fetchConfig();
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
      });
      _syncConfigControllers();
    } catch (error) {
      _toast('加载配置失败：$error');
    }
  }

  Future<void> _handleReview(
      String targetType, String targetId, String action) async {
    await _runAction(
      () => _repo.handleReview(
        targetType: targetType,
        targetId: targetId,
        action: action,
      ),
      successText: '审核操作成功',
      onSuccess: () async {
        await _loadReviews();
        await _loadOverview();
      },
    );
  }

  Future<void> _handleReport(
    String reportId,
    String action, {
    String? result,
  }) async {
    await _runAction(
      () => _repo.handleReport(
        reportId: reportId,
        action: action,
        result: result,
      ),
      successText: '举报处理成功',
      onSuccess: () async {
        await _loadReports();
        await _loadOverview();
      },
    );
  }

  Future<void> _handleImageReview(
    String uploadId,
    String action, {
    String? note,
  }) async {
    await _runAction(
      () => _repo.handleImageReview(
        uploadId: uploadId,
        action: action,
        note: note,
      ),
      successText: '图片审核成功',
      onSuccess: () async {
        await _loadImageReviews();
        await _loadOverview();
      },
    );
  }

  Future<void> _updateUser(String userId, String action) async {
    await _runAction(
      () => _repo.updateUserState(userId: userId, action: action),
      successText: '用户状态已更新',
      onSuccess: _loadUsers,
    );
  }

  Future<void> _addChannel() async {
    final String value = _newChannelController.text.trim();
    if (value.isEmpty) {
      _toast('请输入频道名');
      return;
    }
    await _runAction(
      () => _repo.addChannel(value),
      successText: '频道已新增',
      onSuccess: () async {
        _newChannelController.clear();
        await _loadChannelTag();
      },
    );
  }

  Future<void> _renameChannel(String oldName) async {
    final String? next = await _askNewName(title: '重命名频道', initial: oldName);
    if (next == null || next.trim().isEmpty || next.trim() == oldName) {
      return;
    }
    await _runAction(
      () => _repo.renameChannel(oldName: oldName, newName: next.trim()),
      successText: '频道已更新',
      onSuccess: _loadChannelTag,
    );
  }

  Future<void> _deleteChannel(String name) async {
    await _runAction(
      () => _repo.deleteChannel(name),
      successText: '频道已删除',
      onSuccess: _loadChannelTag,
    );
  }

  Future<void> _addTag() async {
    final String value = _newTagController.text.trim();
    if (value.isEmpty) {
      _toast('请输入标签名');
      return;
    }
    await _runAction(
      () => _repo.addTag(value),
      successText: '标签已新增',
      onSuccess: () async {
        _newTagController.clear();
        await _loadChannelTag();
      },
    );
  }

  Future<void> _renameTag(String oldName) async {
    final String? next = await _askNewName(title: '重命名标签', initial: oldName);
    if (next == null || next.trim().isEmpty || next.trim() == oldName) {
      return;
    }
    await _runAction(
      () => _repo.renameTag(oldName: oldName, newName: next.trim()),
      successText: '标签已更新',
      onSuccess: _loadChannelTag,
    );
  }

  Future<void> _deleteTag(String name) async {
    await _runAction(
      () => _repo.deleteTag(name),
      successText: '标签已删除',
      onSuccess: _loadChannelTag,
    );
  }

  Future<void> _saveConfig() async {
    final int? postRateLimit = int.tryParse(_postLimitController.text.trim());
    final int? commentRateLimit =
        int.tryParse(_commentLimitController.text.trim());
    final int? messageRateLimit =
        int.tryParse(_messageLimitController.text.trim());
    final int? imageMaxMb = int.tryParse(_imageMaxController.text.trim());

    if (postRateLimit == null ||
        commentRateLimit == null ||
        messageRateLimit == null ||
        imageMaxMb == null) {
      _toast('请填写合法的数字配置');
      return;
    }

    final List<String> sensitiveWords = _sensitiveController.text
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();

    final AdminSystemConfig config = AdminSystemConfig(
      sensitiveWords: sensitiveWords,
      postRateLimit: postRateLimit,
      commentRateLimit: commentRateLimit,
      messageRateLimit: messageRateLimit,
      imageMaxMb: imageMaxMb,
    );

    await _runAction(
      () => _repo.updateConfig(config),
      successText: '系统配置已保存',
      onSuccess: _loadConfig,
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successText,
    Future<void> Function()? onSuccess,
  }) async {
    setState(() {
      _actionBusy = true;
    });

    try {
      await action();
      if (onSuccess != null) {
        await onSuccess();
      }
      _toast(successText);
    } catch (error) {
      _toast('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _promptAndHandleReport({
    required String reportId,
    required String action,
    required String actionLabel,
    String defaultResult = '',
  }) async {
    final TextEditingController controller =
        TextEditingController(text: defaultResult);
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(actionLabel),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '处理说明（可选）',
              hintText: '可补充具体处理结果',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确认处理'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value == null) {
      return;
    }
    await _handleReport(reportId, action, result: value);
  }

  Future<void> _promptAndHandleImageReview({
    required String uploadId,
    required String action,
    required String actionLabel,
    String defaultNote = '',
  }) async {
    final TextEditingController controller =
        TextEditingController(text: defaultNote);
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(actionLabel),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '审核备注（可选）',
              hintText: '可填写判定依据',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确认处理'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value == null) {
      return;
    }
    await _handleImageReview(uploadId, action, note: value);
  }

  Future<void> _showImageDialog(AdminImageReviewItem item) async {
    final String url = _resolveMediaUrl(item.url);
    if (url.isEmpty) {
      _toast('该图片地址无效');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            width: 820,
            constraints: const BoxConstraints(maxHeight: 680),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.fileName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('图片加载失败'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSimpleDetail({
    required String title,
    required String subtitle,
    required String content,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Text('$subtitle\n\n$content'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadOverview() async {
    try {
      final AdminOverview overview = await _repo.fetchOverview();
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
      });
    } catch (_) {
      // ignore quick refresh failure
    }
  }

  void _syncConfigControllers() {
    _sensitiveController.text = _config.sensitiveWords.join(',');
    _postLimitController.text = _config.postRateLimit.toString();
    _commentLimitController.text = _config.commentRateLimit.toString();
    _messageLimitController.text = _config.messageRateLimit.toString();
    _imageMaxController.text = _config.imageMaxMb.toString();
  }

  Future<String?> _askNewName({
    required String title,
    required String initial,
  }) async {
    final TextEditingController controller =
        TextEditingController(text: initial);
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '新名称'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return value;
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
