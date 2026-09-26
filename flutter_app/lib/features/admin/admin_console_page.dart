import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/admin_auth_store.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/release_file_picker.dart';
import '../../design_system/design_system.dart';
import '../../models/admin_models.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/admin_repository.dart';

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({super.key, this.repository, this.onLogout});

  final AdminRepository? repository;
  final Future<void> Function()? onLogout;

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  AdminCurrentUser? _currentAdmin;
  AdminOverview? _overview;
  List<AdminReviewItem> _reviews = const <AdminReviewItem>[];
  List<AdminReportEntry> _reports = const <AdminReportEntry>[];
  List<AdminImageReviewItem> _imageReviews = const <AdminImageReviewItem>[];
  List<AdminUserEntry> _users = const <AdminUserEntry>[];
  List<AdminPostPinRequestEntry> _postPinRequests =
      const <AdminPostPinRequestEntry>[];
  List<AdminUserLevelRequestEntry> _userLevelRequests =
      const <AdminUserLevelRequestEntry>[];
  List<AdminAccountEntry> _adminAccounts = const <AdminAccountEntry>[];
  List<AdminAccountCancellationRequest> _accountCancellationRequests =
      const <AdminAccountCancellationRequest>[];
  List<AdminAppealEntry> _appeals = const <AdminAppealEntry>[];
  List<AdminFeedbackEntry> _feedbacks = const <AdminFeedbackEntry>[];
  AdminTagData _tagData = AdminTagData(tags: const <String>[]);
  List<AdminSystemAnnouncement> _announcements =
      const <AdminSystemAnnouncement>[];
  AdminAndroidRelease? _androidRelease;
  AdminSystemConfig _config = AdminSystemConfig(
    sensitiveWords: const <String>[],
    postRateLimit: 10,
    commentRateLimit: 30,
    messageRateLimit: 40,
    imageMaxMb: 5,
  );

  final TextEditingController _newTagController = TextEditingController();
  final TextEditingController _sensitiveController = TextEditingController();
  final TextEditingController _postLimitController = TextEditingController();
  final TextEditingController _commentLimitController = TextEditingController();
  final TextEditingController _messageLimitController = TextEditingController();
  final TextEditingController _imageMaxController = TextEditingController();
  final TextEditingController _announcementTitleController =
      TextEditingController();
  final TextEditingController _announcementContentController =
      TextEditingController();
  final TextEditingController _adminUsernameController =
      TextEditingController();
  final TextEditingController _adminPasswordController =
      TextEditingController();
  final TextEditingController _userAdminStudentIdController =
      TextEditingController();
  final TextEditingController _androidVersionNameController =
      TextEditingController();
  final TextEditingController _androidVersionCodeController =
      TextEditingController();
  final TextEditingController _androidReleaseNotesController =
      TextEditingController();
  final TextEditingController _reportReasonController = TextEditingController();
  final TextEditingController _reviewKeywordController =
      TextEditingController();
  final TextEditingController _reportKeywordController =
      TextEditingController();
  final TextEditingController _userKeywordController = TextEditingController();
  final TextEditingController _imageKeywordController = TextEditingController();
  final TextEditingController _cancellationKeywordController =
      TextEditingController();
  final TextEditingController _appealKeywordController =
      TextEditingController();
  final TextEditingController _postPinKeywordController =
      TextEditingController();
  final TextEditingController _userLevelKeywordController =
      TextEditingController();

  String _reviewType = 'post';
  String _reviewStatus = 'pending';
  String _reportStatus = 'all';
  String _imageStatus = 'pending';
  String _userFilter = 'all';
  String _postPinStatus = 'all';
  String _userLevelStatus = 'all';
  String _cancellationStatus = 'all';
  String _appealStatus = 'all';
  String _feedbackStatus = 'pending';
  String _exportScope = 'users';
  String _exportFormat = 'csv';
  bool _androidForceUpdate = false;
  PickedReleaseFile? _selectedAndroidApk;
  final Set<String> _selectedReviewIds = <String>{};

  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  AdminRepository get _repo => widget.repository ?? AppRepositories.admin;
  bool get _isPrimaryAdmin => _currentAdmin?.isPrimary ?? false;

  @override
  void initState() {
    super.initState();
    _adminSessionExpired = AdminAuthStore.instance.sessionExpired.listen(
      (_) => _onAdminSessionExpired(),
    );
    _loadAll();
  }

  late final StreamSubscription<void> _adminSessionExpired;

  /// The admin token is already cleared; back to sign-in.
  Future<void> _onAdminSessionExpired() async {
    if (!mounted) return;
    _toast('管理员会话已失效，请重新登录');
    await widget.onLogout?.call();
  }

  @override
  void dispose() {
    _adminSessionExpired.cancel();
    _newTagController.dispose();
    _sensitiveController.dispose();
    _postLimitController.dispose();
    _commentLimitController.dispose();
    _messageLimitController.dispose();
    _imageMaxController.dispose();
    _announcementTitleController.dispose();
    _announcementContentController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _userAdminStudentIdController.dispose();
    _androidVersionNameController.dispose();
    _androidVersionCodeController.dispose();
    _androidReleaseNotesController.dispose();
    _reportReasonController.dispose();
    _reviewKeywordController.dispose();
    _reportKeywordController.dispose();
    _userKeywordController.dispose();
    _imageKeywordController.dispose();
    _cancellationKeywordController.dispose();
    _appealKeywordController.dispose();
    _postPinKeywordController.dispose();
    _userLevelKeywordController.dispose();
    super.dispose();
  }

  /// The sidebar entry chosen on wide screens.
  int _sectionIndex = 0;

  int _pending(Iterable<String> statuses) =>
      statuses.where((String s) => s.trim().toLowerCase() == 'pending').length;

  List<_AdminSection> _sections() {
    final List<_AdminSection> all = <_AdminSection>[
      _AdminSection('概览', Icons.space_dashboard_outlined, _buildOverviewTab),
      _AdminSection(
        '帖子管理',
        Icons.fact_check_outlined,
        _buildReviewTab,
        pending: _pending(_reviews.map((AdminReviewItem r) => r.reviewStatus)),
      ),
      _AdminSection(
        '举报处理',
        Icons.flag_outlined,
        _buildReportTab,
        pending: _pending(_reports.map((AdminReportEntry r) => r.status)),
      ),
      _AdminSection(
        '图片审核',
        Icons.image_search_outlined,
        _buildImageReviewTab,
        pending: _pending(
          _imageReviews.map((AdminImageReviewItem r) => r.status),
        ),
      ),
      _AdminSection(
        '帖子置顶',
        Icons.push_pin_outlined,
        _buildPostPinRequestTab,
        pending: _pending(
          _postPinRequests.map((AdminPostPinRequestEntry r) => r.status),
        ),
      ),
      _AdminSection(
        '一级用户申请',
        Icons.verified_user_outlined,
        _buildUserLevelRequestTab,
        pending: _pending(
          _userLevelRequests.map((AdminUserLevelRequestEntry r) => r.status),
        ),
      ),
      _AdminSection(
        '注销申请',
        Icons.person_off_outlined,
        _buildAccountCancellationTab,
        pending: _pending(
          _accountCancellationRequests.map(
            (AdminAccountCancellationRequest r) => r.status,
          ),
        ),
      ),
      _AdminSection(
        '申诉处理',
        Icons.gavel_outlined,
        _buildAppealTab,
        pending: _pending(_appeals.map((AdminAppealEntry r) => r.status)),
      ),
      _AdminSection(
        '用户反馈',
        Icons.mark_email_unread_outlined,
        _buildFeedbackTab,
        pending: _pending(_feedbacks.map((AdminFeedbackEntry r) => r.status)),
      ),
      _AdminSection('用户管理', Icons.group_outlined, _buildUserTab),
      _AdminSection('分类标签', Icons.sell_outlined, _buildTagTab),
      _AdminSection(
        '版本发布',
        Icons.system_update_alt_outlined,
        _buildAndroidReleaseTab,
      ),
      _AdminSection('系统配置', Icons.tune_rounded, _buildConfigTab),
    ];
    if (_isPrimaryAdmin) return all;
    // Secondary admins handle pin requests only; the backend keeps users,
    // reviews and settings to primary admins.
    return all.where((_AdminSection s) => s.label == '帖子置顶').toList();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final AdminCurrentUser? admin = _currentAdmin;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: <Widget>[
            const ZxAvatar.anonymous(name: '知', size: 32),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                MediaQuery.sizeOf(context).width < 600
                    ? '管理工作台'
                    : '西电知行 · 管理工作台',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZxType.headline.copyWith(fontSize: 18, color: t.text),
              ),
            ),
            if (admin != null && admin.username.isNotEmpty) ...<Widget>[
              const SizedBox(width: 12),
              ZxBadge.level('${admin.username} · ${admin.roleLabel}'),
            ],
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _actionBusy ? null : _loadAll,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新全部',
          ),
          if (widget.onLogout != null)
            IconButton(
              onPressed: _actionBusy
                  ? null
                  : () async {
                      await widget.onLogout!.call();
                    },
              icon: const Icon(Icons.logout_rounded),
              tooltip: '退出管理员后台',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ZxPaper(
        child: _loading
            ? const ZxStatePanel(
                icon: Icons.admin_panel_settings_outlined,
                title: '正在加载管理数据',
                message: '正在汇总举报、审核与账号状态。',
              )
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) =>
                    _buildConsole(_sections(), wide: c.maxWidth >= 1000),
              ),
      ),
    );
  }

  Widget _buildConsole(List<_AdminSection> sections, {required bool wide}) {
    final ZxTokens t = ZxTokens.of(context);
    final Widget? error = _error == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: ZxInlineMessage(
              message: '后台数据未完全加载：${_error!}',
              tone: ZxMessageTone.danger,
              actionLabel: '重试',
              onAction: _actionBusy ? null : _loadAll,
            ),
          );
    final Widget? scope = _isPrimaryAdmin
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: const ZxInlineMessage(message: '当前账号开放用户管理和帖子置顶审核'),
          );

    if (wide) {
      final int index = _sectionIndex.clamp(0, sections.length - 1);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: 232,
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(right: BorderSide(color: t.line)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: <Widget>[
                for (int i = 0; i < sections.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: i == index ? t.primarySoft : Colors.transparent,
                      borderRadius: ZxRadius.buttonAll,
                      child: InkWell(
                        key: Key('admin-section-${sections[i].label}'),
                        borderRadius: ZxRadius.buttonAll,
                        onTap: () => setState(() => _sectionIndex = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                sections[i].icon,
                                size: 18,
                                color: i == index ? t.primary : t.text2,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  sections[i].label,
                                  style: ZxType.body.copyWith(
                                    color: i == index ? t.primary : t.text,
                                    fontWeight: i == index
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              ZxCountBadge(sections[i].pending),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ?error,
                ?scope,
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey<String>(sections[index].label),
                    child: sections[index].build(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return DefaultTabController(
      length: sections.length,
      child: Column(
        children: <Widget>[
          ?error,
          ?scope,
          TabBar(
            isScrollable: sections.length > 3,
            tabAlignment: sections.length > 3 ? TabAlignment.start : null,
            tabs: <Tab>[
              for (final _AdminSection section in sections)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(section.label),
                      if (section.pending > 0) ...<Widget>[
                        const SizedBox(width: 6),
                        ZxCountBadge(section.pending),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                for (final _AdminSection section in sections) section.build(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final AdminOverview overview =
        _overview ??
        AdminOverview(
          todayNewUsers: 0,
          todayPosts: 0,
          todayComments: 0,
          todayReports: 0,
          pendingReviews: 0,
          pendingCancellationRequests: 0,
          pendingFeedbacks: 0,
          activeUsers: 0,
          bannedUsers: 0,
          mutedUsers: 0,
        );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            // Two per row on phones; fixed-width cards otherwise.
            _metricWidth = c.maxWidth < 600 ? (c.maxWidth - 10) / 2 : 188;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _metricCard(
                  title: '今日新增用户',
                  value: overview.todayNewUsers,
                  icon: Icons.person_add_alt_1_rounded,
                  color: ZxTokens.of(context).primary,
                ),
                _metricCard(
                  title: '今日发帖数',
                  value: overview.todayPosts,
                  icon: Icons.edit_note_rounded,
                  color: ZxTokens.of(context).success,
                ),
                _metricCard(
                  title: '今日评论数',
                  value: overview.todayComments,
                  icon: Icons.forum_outlined,
                  color: ZxTokens.of(context).text2,
                ),
                _metricCard(
                  title: '今日举报数',
                  value: overview.todayReports,
                  icon: Icons.flag_circle_outlined,
                  color: ZxTokens.of(context).warning,
                ),
                _metricCard(
                  title: '待审核内容',
                  value: overview.pendingReviews,
                  icon: Icons.approval_outlined,
                  color: ZxTokens.of(context).warning,
                ),
                _metricCard(
                  title: '待注销申请',
                  value: overview.pendingCancellationRequests,
                  icon: Icons.person_remove_alt_1_outlined,
                  color: ZxTokens.of(context).warning,
                ),
                _metricCard(
                  title: '待处理反馈',
                  value: overview.pendingFeedbacks,
                  icon: Icons.mark_email_unread_outlined,
                  color: ZxTokens.of(context).warning,
                ),
                _metricCard(
                  title: '正常账号数',
                  value: overview.activeUsers,
                  icon: Icons.groups_rounded,
                  color: ZxTokens.of(context).primary,
                ),
                _metricCard(
                  title: '被封禁用户',
                  value: overview.bannedUsers,
                  icon: Icons.gpp_bad_outlined,
                  color: ZxTokens.of(context).danger,
                ),
                _metricCard(
                  title: '被禁言用户',
                  value: overview.mutedUsers,
                  icon: Icons.volume_off_outlined,
                  color: ZxTokens.of(context).text2,
                ),
              ],
            );
          },
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
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _exportScope,
                    decoration: const InputDecoration(labelText: '导出范围'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'users', child: Text('用户数据')),
                      DropdownMenuItem(value: 'reviews', child: Text('审核列表')),
                      DropdownMenuItem(value: 'reports', child: Text('举报记录')),
                      DropdownMenuItem(
                        value: 'cancellations',
                        child: Text('注销申请'),
                      ),
                      DropdownMenuItem(value: 'appeals', child: Text('申诉记录')),
                      DropdownMenuItem(
                        value: 'postpinrequests',
                        child: Text('置顶申请'),
                      ),
                      DropdownMenuItem(
                        value: 'userlevelrequests',
                        child: Text('一级用户申请'),
                      ),
                      DropdownMenuItem(value: 'auditlogs', child: Text('审计日志')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _exportScope = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: _exportFormat,
                    decoration: const InputDecoration(labelText: '导出格式'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'csv', child: Text('CSV')),
                      DropdownMenuItem(value: 'json', child: Text('JSON')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _exportFormat = value;
                      });
                    },
                  ),
                ),
                FilledButton.icon(
                  onPressed: _actionBusy ? null : _downloadExport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导出数据'),
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
        _adminSectionHeader(
          icon: Icons.article_outlined,
          title: '帖子管理',
          subtitle: '人工审核帖子与评论，处理通过、驳回、风险标记和删除。',
        ),
        const SizedBox(height: 12),
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
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _reviewKeywordController,
                    decoration: const InputDecoration(
                      labelText: '内容/用户/邮箱搜索',
                      hintText: '回车搜索',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onSubmitted: (_) => _loadReviews(),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  '已选 ${_selectedReviewIds.length} 条',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                OutlinedButton.icon(
                  onPressed: _reviews.isEmpty ? null : _toggleSelectAllReviews,
                  icon: Icon(
                    _allVisibleReviewsSelected
                        ? Icons.remove_done_outlined
                        : Icons.select_all_outlined,
                  ),
                  label: Text(_allVisibleReviewsSelected ? '取消全选' : '全选当前页'),
                ),
                OutlinedButton(
                  onPressed: _selectedReviewIds.isEmpty
                      ? null
                      : () => setState(() => _selectedReviewIds.clear()),
                  child: const Text('清空选择'),
                ),
                FilledButton.tonal(
                  onPressed: _actionBusy || _selectedReviewIds.isEmpty
                      ? null
                      : () => _handleReviewBatch('approve'),
                  child: const Text('批量通过'),
                ),
                FilledButton.tonal(
                  onPressed: _actionBusy || _selectedReviewIds.isEmpty
                      ? null
                      : () => _handleReviewBatch('reject'),
                  child: const Text('批量驳回'),
                ),
                FilledButton.tonal(
                  onPressed: _actionBusy || _selectedReviewIds.isEmpty
                      ? null
                      : () => _handleReviewBatch('risk'),
                  child: const Text('批量标风险'),
                ),
                FilledButton(
                  onPressed: _actionBusy || _selectedReviewIds.isEmpty
                      ? null
                      : () => _handleReviewBatch('delete'),
                  child: const Text('批量删除'),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Checkbox(
                        value: _selectedReviewIds.contains(
                          _reviewSelectionKey(item),
                        ),
                        onChanged: (_) => _toggleReviewSelection(item),
                      ),
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
                  Text(
                    item.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text('前台展示：${item.authorAlias} · 时间：${item.createdAt}'),
                  const SizedBox(height: 4),
                  Text(
                    '实际账号：${item.authorNickname}'
                    '${item.authorEmail.isNotEmpty ? ' · ${item.authorEmail}' : ''}'
                    '${item.authorStudentId.isNotEmpty ? ' · 学号 ${item.authorStudentId}' : ''}',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _showSimpleDetail(
                          title: item.title,
                          subtitle:
                              '前台展示：${item.authorAlias}\n'
                              '实际账号：${item.authorNickname}'
                              '${item.authorEmail.isNotEmpty ? ' · ${item.authorEmail}' : ''}'
                              '${item.authorStudentId.isNotEmpty ? ' · 学号 ${item.authorStudentId}' : ''}'
                              '${item.authorUserId.isNotEmpty ? '\n内部ID：${item.authorUserId}' : ''}',
                          content: item.content,
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('详情'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _handleReview(
                                item.targetType,
                                item.id,
                                'approve',
                              ),
                        child: const Text('通过'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _handleReview(
                                item.targetType,
                                item.id,
                                'reject',
                              ),
                        child: const Text('驳回'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _handleReview(
                                item.targetType,
                                item.id,
                                'risk',
                              ),
                        child: const Text('标风险'),
                      ),
                      FilledButton.tonal(
                        onPressed: _actionBusy
                            ? null
                            : () => _handleReview(
                                item.targetType,
                                item.id,
                                'delete',
                              ),
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
    final String reasonKeyword = _reportReasonController.text
        .trim()
        .toLowerCase();
    final String textKeyword = _reportKeywordController.text
        .trim()
        .toLowerCase();

    final List<AdminReportEntry> rows = _reports.where((AdminReportEntry item) {
      final bool matchReason =
          reasonKeyword.isEmpty ||
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
                      DropdownMenuItem(value: 'misreport', child: Text('误报')),
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
                      // A handled report answers 409 to any action.
                      if (report.status.trim().toLowerCase() ==
                          'pending') ...<Widget>[
                        // A reported user has no content to delete; the
                        // server refuses it.
                        if (report.targetType != 'user')
                          OutlinedButton(
                            onPressed: _actionBusy
                                ? null
                                : () => _promptAndHandleReport(
                                    reportId: report.id,
                                    action: 'delete',
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
                                  action: 'warn',
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
                                  action: 'ban',
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
                                  action: 'misreport',
                                  actionLabel: '标记误报',
                                  defaultResult: '标记为误报',
                                ),
                          child: const Text('标记误报'),
                        ),
                      ],
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
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _statusChip(item.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('上传者：${item.uploaderAlias} (${item.uploaderId})'),
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
                            // A rejected or deleted image answers 409 to
                            // every action.
                            if (item.status != 'rejected' &&
                                item.status != 'deleted') ...<Widget>[
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
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }

  Widget _buildPostPinRequestTab() {
    final String keyword = _postPinKeywordController.text.trim().toLowerCase();
    final List<AdminPostPinRequestEntry> rows = _postPinRequests.where((
      AdminPostPinRequestEntry item,
    ) {
      final String merged = [
        item.postId,
        item.postTitle,
        item.userId,
        item.userNickname,
        item.reason,
      ].join(' ').toLowerCase();
      final bool matchKeyword = keyword.isEmpty || merged.contains(keyword);
      final bool matchStatus =
          _postPinStatus == 'all' || item.status == _postPinStatus;
      return matchKeyword && matchStatus;
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
                    controller: _postPinKeywordController,
                    decoration: const InputDecoration(
                      labelText: '置顶申请搜索',
                      hintText: '帖子 / 用户 / 邮箱 / 原因',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _postPinStatus,
                    decoration: const InputDecoration(labelText: '申请状态'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(value: 'pending', child: Text('待处理')),
                      DropdownMenuItem(value: 'approved', child: Text('已通过')),
                      DropdownMenuItem(value: 'rejected', child: Text('已驳回')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _postPinStatus = value;
                      });
                      _loadPostPinRequests();
                    },
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadPostPinRequests,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新置顶申请'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            '匹配置顶申请 ${rows.length} / 总计 ${_postPinRequests.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
        ),
        ...rows.map(
          (AdminPostPinRequestEntry item) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.postTitle.isEmpty
                              ? '帖子 ${item.postId}'
                              : item.postTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _statusChip(item.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${item.userNickname} · ${item.userLevelLabel}'),
                  Text('帖子ID：${item.postId}'),
                  Text(
                    '申请时长：${item.durationLabel.isEmpty ? '-' : item.durationLabel}',
                  ),
                  Text('提交时间：${item.createdAt}'),
                  if (item.reason.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text('申请说明：${item.reason}'),
                  ],
                  if (item.adminNote.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text('处理备注：${item.adminNote}'),
                  ],
                  if (item.handledAt.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      '处理信息：${item.handledAt}'
                      '${item.handledBy.trim().isEmpty ? '' : ' · ${item.handledBy}'}',
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _showSimpleDetail(
                          title: item.postTitle.isEmpty
                              ? '帖子 ${item.postId}'
                              : item.postTitle,
                          subtitle:
                              '${item.userNickname}\n'
                              '帖子ID：${item.postId}\n'
                              '置顶时长：${item.durationLabel.isEmpty ? '-' : item.durationLabel}',
                          content: item.reason.trim().isEmpty
                              ? '无额外申请说明'
                              : item.reason,
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('详情'),
                      ),
                      if (item.status == 'pending')
                        FilledButton(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndHandlePostPinRequest(
                                  requestId: item.id,
                                  action: 'approve',
                                  actionLabel: '通过置顶申请',
                                  defaultNote: '申请通过，帖子已置顶展示',
                                ),
                          child: const Text('通过'),
                        ),
                      if (item.status == 'pending')
                        FilledButton.tonal(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndHandlePostPinRequest(
                                  requestId: item.id,
                                  action: 'reject',
                                  actionLabel: '驳回置顶申请',
                                  defaultNote: '当前不满足置顶条件',
                                ),
                          child: const Text('驳回'),
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
            child: Center(child: Text('暂无匹配的置顶申请。')),
          ),
      ],
    );
  }

  Widget _buildUserLevelRequestTab() {
    final String keyword = _userLevelKeywordController.text
        .trim()
        .toLowerCase();
    final List<AdminUserLevelRequestEntry> rows = _userLevelRequests.where((
      AdminUserLevelRequestEntry item,
    ) {
      final String merged = [
        item.userId,
        item.userEmail,
        item.studentId,
        item.userNickname,
        item.reason,
      ].join(' ').toLowerCase();
      final bool matchKeyword = keyword.isEmpty || merged.contains(keyword);
      final bool matchStatus =
          _userLevelStatus == 'all' || item.status == _userLevelStatus;
      return matchKeyword && matchStatus;
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
                    controller: _userLevelKeywordController,
                    decoration: const InputDecoration(
                      labelText: '一级用户申请搜索',
                      hintText: '用户 / 邮箱 / 学号 / 原因',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _userLevelStatus,
                    decoration: const InputDecoration(labelText: '申请状态'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(value: 'pending', child: Text('待处理')),
                      DropdownMenuItem(value: 'approved', child: Text('已通过')),
                      DropdownMenuItem(value: 'rejected', child: Text('已驳回')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _userLevelStatus = value;
                      });
                      _loadUserLevelRequests();
                    },
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadUserLevelRequests,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新一级用户申请'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            '匹配申请 ${rows.length} / 总计 ${_userLevelRequests.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
        ),
        ...rows.map(
          (AdminUserLevelRequestEntry item) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${item.userNickname} (${item.userEmail})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _statusChip(item.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '用户ID：${item.userId}'
                    '${item.studentId.isEmpty ? '' : ' · 学号 ${item.studentId}'}',
                  ),
                  Text(
                    '申请等级：${item.currentLevelLabel} -> ${item.targetLevelLabel}'
                    ' · 当前账号等级：${item.userCurrentLevelLabel}',
                  ),
                  Text('提交时间：${item.createdAt}'),
                  if (item.reason.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text('申请说明：${item.reason}'),
                  ],
                  if (item.adminNote.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text('处理备注：${item.adminNote}'),
                  ],
                  if (item.handledAt.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      '处理信息：${item.handledAt}'
                      '${item.handledBy.trim().isEmpty ? '' : ' · ${item.handledBy}'}',
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _showSimpleDetail(
                          title: '${item.userNickname} · 一级用户申请',
                          subtitle:
                              '${item.userEmail}\n用户ID：${item.userId}\n'
                              '当前等级：${item.currentLevelLabel} -> ${item.targetLevelLabel}',
                          content: item.reason.trim().isEmpty
                              ? '无额外申请说明'
                              : item.reason,
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('详情'),
                      ),
                      if (item.status == 'pending')
                        FilledButton(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndHandleUserLevelRequest(
                                  requestId: item.id,
                                  action: 'approve',
                                  actionLabel: '通过一级用户申请',
                                  defaultNote: '申请通过，已升级为一级用户',
                                ),
                          child: const Text('通过'),
                        ),
                      if (item.status == 'pending')
                        FilledButton.tonal(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndHandleUserLevelRequest(
                                  requestId: item.id,
                                  action: 'reject',
                                  actionLabel: '驳回一级用户申请',
                                  defaultNote: '当前未通过升级申请',
                                ),
                          child: const Text('驳回'),
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
            child: Center(child: Text('暂无匹配的一级用户申请。')),
          ),
      ],
    );
  }

  Widget _buildAccountCancellationTab() {
    final String keyword = _cancellationKeywordController.text
        .trim()
        .toLowerCase();
    final List<AdminAccountCancellationRequest> rows =
        _accountCancellationRequests.where((
          AdminAccountCancellationRequest request,
        ) {
          final String merged = [
            request.userNickname,
            request.userEmail,
            request.studentId,
            request.userId,
            request.reason,
            request.createdAt,
          ].join(' ').toLowerCase();
          final bool matchKeyword = keyword.isEmpty || merged.contains(keyword);
          final bool matchStatus =
              _cancellationStatus == 'all' ||
              request.status == _cancellationStatus;
          return matchKeyword && matchStatus;
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
                  width: 220,
                  child: TextField(
                    controller: _cancellationKeywordController,
                    decoration: const InputDecoration(
                      labelText: '申请搜索',
                      hintText: '昵称 / 邮箱 / 学号 / 用户ID',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _cancellationStatus,
                    decoration: const InputDecoration(labelText: '申请状态'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(value: 'pending', child: Text('待审核')),
                      DropdownMenuItem(value: 'approved', child: Text('已通过')),
                      DropdownMenuItem(value: 'rejected', child: Text('已驳回')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _cancellationStatus = value;
                      });
                      _loadAccountCancellationRequests();
                    },
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy
                      ? null
                      : _loadAccountCancellationRequests,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新申请列表'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            '匹配申请 ${rows.length} / 总计 ${_accountCancellationRequests.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
        ),
        ...rows.map(
          (AdminAccountCancellationRequest request) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildUserAvatar(
                        request.avatarUrl,
                        label: request.userNickname,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '${request.userNickname} (${request.userEmail})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _statusChip(request.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '用户ID: ${request.userId} · 学号: ${request.studentId.isEmpty ? '-' : request.studentId}',
                            ),
                            Text('提交时间：${request.createdAt}'),
                            if (request.reason.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('申请说明：${request.reason}'),
                              ),
                            if (request.reviewNote.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('审核备注：${request.reviewNote}'),
                              ),
                            if (request.handledAt.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '处理信息：${request.handledAt}'
                                  '${request.handledBy.trim().isEmpty ? '' : ' · ${request.handledBy}'}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _showSimpleDetail(
                          title: '注销申请详情',
                          subtitle:
                              '${request.userNickname} · ${request.userEmail}',
                          content: [
                            '用户ID：${request.userId}',
                            '学号：${request.studentId.isEmpty ? '-' : request.studentId}',
                            '提交时间：${request.createdAt}',
                            if (request.reason.trim().isNotEmpty)
                              '申请说明：${request.reason}',
                            if (request.reviewNote.trim().isNotEmpty)
                              '审核备注：${request.reviewNote}',
                            if (request.handledAt.trim().isNotEmpty)
                              '处理时间：${request.handledAt}',
                            if (request.handledBy.trim().isNotEmpty)
                              '处理人：${request.handledBy}',
                          ].join('\n'),
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('查看详情'),
                      ),
                      if (request.status == 'pending')
                        FilledButton.icon(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndHandleAccountCancellation(
                                  requestId: request.id,
                                  action: 'approve',
                                  actionLabel: '通过注销申请',
                                  defaultNote: '申请核实通过，账号已注销',
                                ),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('通过并注销'),
                        ),
                      if (request.status == 'pending')
                        FilledButton.tonalIcon(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndHandleAccountCancellation(
                                  requestId: request.id,
                                  action: 'reject',
                                  actionLabel: '驳回注销申请',
                                  defaultNote: '申请信息不足，请补充说明后重新提交',
                                ),
                          icon: const Icon(Icons.close_outlined),
                          label: const Text('驳回申请'),
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
            child: Center(child: Text('暂无匹配的注销申请。')),
          ),
      ],
    );
  }

  Widget _buildAppealTab() {
    final String keyword = _appealKeywordController.text.trim().toLowerCase();
    final List<AdminAppealEntry> rows = _appeals.where((AdminAppealEntry item) {
      final String merged = [
        item.userNickname,
        item.userEmail,
        item.studentId,
        item.appealTypeLabel,
        item.title,
        item.content,
        item.targetId,
      ].join(' ').toLowerCase();
      final bool matchKeyword = keyword.isEmpty || merged.contains(keyword);
      final bool matchStatus =
          _appealStatus == 'all' || item.status == _appealStatus;
      return matchKeyword && matchStatus;
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
                    controller: _appealKeywordController,
                    decoration: const InputDecoration(
                      labelText: '申诉搜索',
                      hintText: '邮箱 / 学号 / 标题 / 内容',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _appealStatus,
                    decoration: const InputDecoration(labelText: '申诉状态'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(value: 'pending', child: Text('待处理')),
                      DropdownMenuItem(value: 'approved', child: Text('已通过')),
                      DropdownMenuItem(value: 'rejected', child: Text('已驳回')),
                      DropdownMenuItem(value: 'closed', child: Text('已关闭')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _appealStatus = value;
                      });
                      _loadAppeals();
                    },
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadAppeals,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新申诉列表'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            '匹配申诉 ${rows.length} / 总计 ${_appeals.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
        ),
        ...rows.map(
          (AdminAppealEntry appeal) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          appeal.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _statusChip(appeal.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${appeal.userNickname} · ${appeal.userEmail}'
                    '${appeal.studentId.isEmpty ? '' : ' · 学号 ${appeal.studentId}'}',
                  ),
                  Text(
                    '类型：${appeal.appealTypeLabel}'
                    '${appeal.targetId.isEmpty ? '' : ' · 目标 ${appeal.targetType}:${appeal.targetId}'}',
                  ),
                  Text(
                    '账号状态：${appeal.userDeleted ? '已注销' : '正常'} / '
                    '${appeal.userBanned ? '封禁' : '未封禁'} / '
                    '${appeal.userMuted ? '禁言' : '可发言'}',
                  ),
                  Text('提交时间：${appeal.createdAt}'),
                  const SizedBox(height: 8),
                  Text(appeal.content),
                  if (appeal.adminNote.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text('处理备注：${appeal.adminNote}'),
                  ],
                  if (appeal.handledAt.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      '处理信息：${appeal.handledAt}'
                      '${appeal.handledBy.trim().isEmpty ? '' : ' · ${appeal.handledBy}'}',
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _showSimpleDetail(
                          title: appeal.title,
                          subtitle:
                              '${appeal.userNickname} · ${appeal.userEmail}\n'
                              '类型：${appeal.appealTypeLabel}'
                              '${appeal.targetId.isEmpty ? '' : '\n目标：${appeal.targetType}:${appeal.targetId}'}',
                          content: appeal.content,
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('详情'),
                      ),
                      if (appeal.status == 'pending')
                        FilledButton.tonal(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndHandleAppeal(
                                  appealId: appeal.id,
                                  action: 'approve',
                                  actionLabel: '通过申诉',
                                  defaultNote: '申诉核实通过',
                                ),
                          child: const Text('通过'),
                        ),
                      // Only an account_restore appeal may restore; the
                      // server refuses the rest.
                      if (appeal.status == 'pending' &&
                          appeal.appealType == 'account_restore')
                        FilledButton(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndHandleAppeal(
                                  appealId: appeal.id,
                                  action: 'approve_restore',
                                  actionLabel: '通过并恢复账号',
                                  defaultNote: '申诉核实通过，账号已恢复',
                                ),
                          child: const Text('通过并恢复'),
                        ),
                      if (appeal.status == 'pending')
                        FilledButton.tonal(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndHandleAppeal(
                                  appealId: appeal.id,
                                  action: 'reject',
                                  actionLabel: '驳回申诉',
                                  defaultNote: '申诉材料不足，暂不通过',
                                ),
                          child: const Text('驳回'),
                        ),
                      if (appeal.status == 'pending')
                        OutlinedButton(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndHandleAppeal(
                                  appealId: appeal.id,
                                  action: 'close',
                                  actionLabel: '关闭申诉',
                                  defaultNote: '申诉已关闭',
                                ),
                          child: const Text('关闭'),
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
            child: Center(child: Text('暂无匹配的申诉记录。')),
          ),
      ],
    );
  }

  Widget _buildFeedbackTab() {
    final TextStyle? muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
    );
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
                    key: const Key('admin-feedback-status'),
                    initialValue: _feedbackStatus,
                    decoration: const InputDecoration(labelText: '反馈状态'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(value: 'pending', child: Text('待处理')),
                      DropdownMenuItem(value: 'resolved', child: Text('已回复')),
                      DropdownMenuItem(value: 'closed', child: Text('已关闭')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _feedbackStatus = value;
                      });
                      _loadFeedbacks();
                    },
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadFeedbacks,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新反馈列表'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text('共 ${_feedbacks.length} 条', style: muted),
        ),
        ..._feedbacks.map(
          (AdminFeedbackEntry feedback) => Card(
            key: Key('admin-feedback-${feedback.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          feedback.category,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _feedbackStatusChip(feedback.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${feedback.userNickname} · ${feedback.userEmail}'
                    '${feedback.studentId.isEmpty ? '' : ' · 学号 ${feedback.studentId}'}'
                    '${feedback.userDeleted ? ' · 账号已注销' : ''}',
                  ),
                  if (feedback.contact.isNotEmpty)
                    Text('联系方式：${feedback.contact}'),
                  Text('提交时间：${feedback.createdAt}'),
                  const SizedBox(height: 8),
                  SelectableText(feedback.content),
                  if (feedback.schoolReply.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text('回复：${feedback.schoolReply}'),
                  ],
                  if (feedback.handledAt.isNotEmpty)
                    Text('处理时间：${feedback.handledAt}', style: muted),
                  if (feedback.status == 'pending') ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonal(
                          key: Key('admin-feedback-reply-${feedback.id}'),
                          onPressed: _actionBusy
                              ? null
                              : () =>
                                    _promptAndHandleFeedback(feedback, 'reply'),
                          child: const Text('回复'),
                        ),
                        OutlinedButton(
                          onPressed: _actionBusy
                              ? null
                              : () =>
                                    _promptAndHandleFeedback(feedback, 'close'),
                          child: const Text('关闭'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_feedbacks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('暂无反馈。')),
          ),
      ],
    );
  }

  // Feedback reads 已回复 where reports read 已处理.
  Widget _feedbackStatusChip(String status) =>
      _statusChip(status, label: status == 'resolved' ? '已回复' : null);

  Widget _buildUserTab() {
    final String keyword = _userKeywordController.text.trim().toLowerCase();

    final List<AdminUserEntry> rows = _users.where((AdminUserEntry user) {
      final String merged = [
        user.id,
        user.alias,
        user.email,
        user.studentId,
        user.createdAt,
      ].join(' ').toLowerCase();
      final bool matchKeyword = keyword.isEmpty || merged.contains(keyword);

      final bool matchFilter;
      switch (_userFilter) {
        case 'deleted':
          matchFilter = user.deleted;
          break;
        case 'banned':
          matchFilter = user.banned;
          break;
        case 'muted':
          matchFilter = user.muted;
          break;
        case 'pendingCancellation':
          matchFilter = user.hasPendingCancellationRequest;
          break;
        case 'normal':
          matchFilter =
              !user.deleted &&
              !user.banned &&
              !user.muted &&
              !user.hasPendingCancellationRequest;
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
                      hintText: '昵称 / 邮箱 / 学号 / ID',
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
                      DropdownMenuItem(value: 'deleted', child: Text('已注销')),
                      DropdownMenuItem(value: 'banned', child: Text('封禁中')),
                      DropdownMenuItem(value: 'muted', child: Text('禁言中')),
                      DropdownMenuItem(
                        value: 'pendingCancellation',
                        child: Text('待注销审核'),
                      ),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.58),
            ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildUserAvatar(user.avatarUrl, label: user.alias),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${user.alias} (${user.email})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${user.id} · 学号: ${user.studentId.isEmpty ? '-' : user.studentId}',
                            ),
                            Text('等级：${user.userLevelLabel}'),
                            Text('注册时间：${user.createdAt}'),
                          ],
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
                      if (user.hasPendingCancellationRequest)
                        const Chip(
                          label: Text('待注销审核'),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (user.hasPendingAppeal)
                        const Chip(
                          label: Text('有待处理申诉'),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (user.hasPendingLevelUpgradeRequest)
                        const Chip(
                          label: Text('待处理升级申请'),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (user.deleted)
                        const Chip(
                          label: Text('已注销'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '发帖 ${user.postCount} · 评论 ${user.commentCount} · 被举报 ${user.reportCount}',
                  ),
                  Text(
                    '状态：${user.deleted ? '已注销' : '正常'} / '
                    '${user.banned ? '封禁' : '未封禁'} / '
                    '${user.muted ? '禁言' : '可发言'} / '
                    '${user.isAdmin ? '管理员' : '普通账号'}',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _showSimpleDetail(
                          title: user.alias,
                          subtitle:
                              '${user.email}\n用户ID: ${user.id}\n学号: ${user.studentId.isEmpty ? '-' : user.studentId}\n等级: ${user.userLevelLabel}',
                          content:
                              '注册时间：${user.createdAt}\n发帖 ${user.postCount} · 评论 ${user.commentCount} · 被举报 ${user.reportCount}\n等级：${user.userLevelLabel}\n状态：${user.deleted ? '已注销' : '正常'} / ${user.banned ? '封禁' : '未封禁'} / ${user.muted ? '禁言' : '可发言'}',
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('查看详情'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: user.id));
                          _toast('已复制用户ID：${user.id}');
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('复制ID'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy || user.deleted
                            ? null
                            : () => _updateUser(user.id, 'mute'),
                        child: const Text('禁言'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy || user.deleted
                            ? null
                            : () => _updateUser(user.id, 'unmute'),
                        child: const Text('解禁言'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy || user.deleted
                            ? null
                            : () => _updateUser(user.id, 'ban'),
                        child: const Text('封禁'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy || user.deleted
                            ? null
                            : () => _updateUser(user.id, 'unban'),
                        child: const Text('解封'),
                      ),
                      if (!user.deleted)
                        FilledButton.tonal(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndUpdateUserAction(
                                  userId: user.id,
                                  action: 'cancel',
                                  actionLabel: '注销违规账号',
                                  defaultNote: '因违规处理，管理员已注销该账号',
                                ),
                          child: const Text('注销账号'),
                        ),
                      if (user.deleted)
                        FilledButton(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndUpdateUserAction(
                                  userId: user.id,
                                  action: 'restore',
                                  actionLabel: '恢复已注销账号',
                                  defaultNote: '管理员已恢复该账号的登录资格',
                                ),
                          child: const Text('恢复账号'),
                        ),
                      if (!user.isAdmin)
                        FilledButton.tonal(
                          onPressed: _actionBusy || user.deleted
                              ? null
                              : () => _promptAndUpdateUserAction(
                                  userId: user.id,
                                  action: 'grant_admin',
                                  actionLabel: '设为管理员',
                                  defaultNote: '按用户列表设为管理员',
                                ),
                          child: const Text('设为管理员'),
                        ),
                      if (user.isAdmin)
                        OutlinedButton(
                          onPressed: _actionBusy
                              ? null
                              : () => _promptAndUpdateUserAction(
                                  userId: user.id,
                                  action: 'revoke_admin',
                                  actionLabel: '移除管理员',
                                  defaultNote: '按用户列表移除管理员权限',
                                ),
                          child: const Text('移除管理员'),
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

  Widget _buildUserAvatar(String avatarUrl, {required String label}) {
    final String resolvedUrl = _resolveMediaUrl(avatarUrl);
    final Widget fallback = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        label.trim().isEmpty ? '?' : label.trim().substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
    if (resolvedUrl.isEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        resolvedUrl,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _buildTagTab() {
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
                  '标签管理',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                ..._tagData.tags.map(
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
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '系统公告发布',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _announcementTitleController,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: '公告标题',
                    hintText: '例如：本周六晚服务器维护通知',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _announcementContentController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: '公告内容',
                    hintText: '请输入要广播给全站用户的系统公告。',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _actionBusy ? null : _publishAnnouncement,
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('发布系统公告'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _actionBusy ? null : _loadConfig,
                      icon: const Icon(Icons.history),
                      label: const Text('刷新公告列表'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_announcements.isEmpty)
                  const Text('暂无已发布公告。')
                else
                  ..._announcements.map(
                    (AdminSystemAnnouncement announcement) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            announcement.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(announcement.content),
                          const SizedBox(height: 8),
                          Text(
                            '${announcement.timeText} · ${announcement.id}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.58),
                            ),
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

  Widget _buildAndroidReleaseTab() {
    final AdminAndroidRelease? release = _androidRelease;
    final String resolvedDownloadUrl = release == null
        ? ''
        : AppConfig.resolveUrl(release.downloadUrl);

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
                  '当前已发布版本',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (release == null)
                  const Text('当前还没有已上传的 Android 安装包。')
                else ...<Widget>[
                  Text(
                    '版本 ${release.versionName}（${release.versionCode}）',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '文件：${release.fileName} · ${_formatFileSize(release.sizeBytes)}',
                  ),
                  Text(
                    '发布时间：${release.uploadedAt} · 发布人：${release.uploadedByUsername.isEmpty ? release.uploadedBy : release.uploadedByUsername}',
                  ),
                  Text('强制更新：${release.forceUpdate ? '是' : '否'}'),
                  if (release.releaseNotes.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(release.releaseNotes),
                  ],
                  const SizedBox(height: 8),
                  SelectableText(
                    '下载地址：$resolvedDownloadUrl',
                    style: const TextStyle(fontSize: 12),
                  ),
                  SelectableText(
                    'SHA256：${release.sha256}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: resolvedDownloadUrl),
                        ),
                        icon: const Icon(Icons.link),
                        label: const Text('复制下载链接'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: release.sha256),
                        ),
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('复制 SHA256'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _actionBusy ? null : _loadAndroidRelease,
                        icon: const Icon(Icons.refresh),
                        label: const Text('刷新发布信息'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '上传新版本 APK',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('上传成功后，会覆盖当前“最新 Android 安装包”元数据，并生成新的下载链接。'),
                if (!kIsWeb) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    '当前环境不支持直接上传 APK，请在 Web 管理后台中操作。',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.58),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _androidVersionNameController,
                        decoration: const InputDecoration(
                          labelText: '版本名称',
                          hintText: '例如：1.0.3',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _androidVersionCodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '版本号',
                          hintText: '例如：19',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _androidReleaseNotesController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '更新说明',
                    hintText: '可填写本次版本的主要变更。',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _androidForceUpdate,
                  onChanged: _actionBusy
                      ? null
                      : (bool value) {
                          setState(() {
                            _androidForceUpdate = value;
                          });
                        },
                  contentPadding: EdgeInsets.zero,
                  title: const Text('标记为强制更新'),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(
                    _selectedAndroidApk == null
                        ? '当前未选择 APK 文件'
                        : '已选择：${_selectedAndroidApk!.fileName} · ${_formatFileSize(_selectedAndroidApk!.sizeBytes)}',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: (_actionBusy || !kIsWeb)
                          ? null
                          : _pickAndroidApk,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('选择 APK'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: (_actionBusy || _selectedAndroidApk == null)
                          ? null
                          : () {
                              setState(() {
                                _selectedAndroidApk = null;
                              });
                            },
                      icon: const Icon(Icons.clear),
                      label: const Text('清除文件'),
                    ),
                    FilledButton.icon(
                      onPressed: (_actionBusy || !kIsWeb)
                          ? null
                          : _uploadAndroidRelease,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('上传并发布'),
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

  Widget _buildConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _adminSectionHeader(
          icon: Icons.shield_outlined,
          title: '审核与屏蔽',
          subtitle: '管理敏感词屏蔽、发帖评论频率和图片上传限制。',
        ),
        const SizedBox(height: 12),
        if (_isPrimaryAdmin) _buildAdminAccountCard(),
        if (_isPrimaryAdmin) const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '敏感词屏蔽',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sensitiveController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '屏蔽词',
                    hintText: '广告,引流,辱骂,诈骗',
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
                        decoration: const InputDecoration(labelText: '发帖限制'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _commentLimitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '评论限制'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _messageLimitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '私信限制'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _imageMaxController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '图片上限(MB)',
                        ),
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
                      label: const Text('保存屏蔽规则'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _actionBusy ? null : _loadConfig,
                      icon: const Icon(Icons.restore),
                      label: const Text('重新读取'),
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

  Widget _buildAdminAccountCard() {
    final int userAdminCount = _users
        .where((AdminUserEntry user) => user.isAdmin)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '二级管理员管理',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('普通账号管理员 $userAdminCount 个'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _userAdminStudentIdController,
                    decoration: const InputDecoration(labelText: '学生学号'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _actionBusy
                      ? null
                      : () => _updateUserAdminByStudentId('grant_admin'),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('设为管理员'),
                ),
                OutlinedButton.icon(
                  onPressed: _actionBusy
                      ? null
                      : () => _updateUserAdminByStudentId('revoke_admin'),
                  icon: const Icon(Icons.person_remove_alt_1_outlined),
                  label: const Text('移除管理员'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              '二级管理员账号',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _adminUsernameController,
                    decoration: const InputDecoration(labelText: '二级管理员账号'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _adminPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '初始密码'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _actionBusy ? null : _createSecondaryAdmin,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('创建二级管理员'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _actionBusy ? null : _loadAdminAccounts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新列表'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_adminAccounts.isEmpty)
              const Text('当前暂无二级管理员账号。')
            else
              ..._adminAccounts.map(
                (AdminAccountEntry account) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              account.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(account.statusLabel),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('角色：${account.roleLabel}'),
                      Text(
                        '创建者：${account.createdBy.isEmpty ? '-' : account.createdBy} · 创建时间：${account.createdAt}',
                      ),
                      Text('最近更新时间：${account.updatedAt}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (account.active)
                            FilledButton.tonal(
                              onPressed: _actionBusy
                                  ? null
                                  : () => _updateSecondaryAdmin(
                                      account.id,
                                      'deactivate',
                                    ),
                              child: const Text('注销账号'),
                            ),
                          if (!account.active)
                            FilledButton(
                              onPressed: _actionBusy
                                  ? null
                                  : () => _updateSecondaryAdmin(
                                      account.id,
                                      'activate',
                                    ),
                              child: const Text('恢复账号'),
                            ),
                        ],
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

  Widget _adminSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _metricWidth = 188;

  Widget _metricCard({
    required String title,
    required int value,
    required IconData icon,
    Color? color,
  }) {
    final ZxTokens t = ZxTokens.of(context);
    // Hues come from the theme so they hold in dark mode.
    color = t.channelFor(title);
    return SizedBox(
      width: _metricWidth,
      child: ZxCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color.lerp(color, t.surface, 0.86),
                    borderRadius: ZxRadius.smallButtonAll,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: ZxType.caption.copyWith(color: t.text2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: ZxType.display.copyWith(fontSize: 30, color: t.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status, {String? label}) {
    final String normalized = status.trim().toLowerCase();
    final Map<String, Color> colors = <String, Color>{
      'pending': ZxTokens.of(context).warning,
      'approved': ZxTokens.of(context).success,
      'resolved': ZxTokens.of(context).success,
      'rejected': ZxTokens.of(context).danger,
      'closed': ZxTokens.of(context).text2,
      'misreport': ZxTokens.of(context).text2,
      'risk': ZxTokens.of(context).warning,
    };
    final Map<String, String> labels = <String, String>{
      'pending': '待处理',
      'approved': '已通过',
      'resolved': '已处理',
      'rejected': '已拒绝',
      'closed': '已关闭',
      'misreport': '误报',
      'risk': '风险',
    };
    final Color color =
        colors[normalized] ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label ?? labels[normalized] ?? status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  String _resolveMediaUrl(String value) {
    return AppConfig.resolveUrl(value);
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
      final AdminCurrentUser currentAdmin = await _repo.fetchCurrentAdmin();
      // The user roster is primary-only on the backend (it carries every
      // email and student id), so a secondary admin never asks for it.
      final List<AdminUserEntry> users = currentAdmin.isPrimary
          ? await _repo.fetchUsers()
          : const <AdminUserEntry>[];
      final List<AdminPostPinRequestEntry> postPinRequests = await _repo
          .fetchPostPinRequests(
            status: _postPinStatus,
            keyword: _postPinKeywordController.text.trim(),
          );

      if (!mounted) {
        return;
      }

      if (!currentAdmin.isPrimary) {
        setState(() {
          _currentAdmin = currentAdmin;
          _users = users;
          _overview = null;
          _reviews = const <AdminReviewItem>[];
          _reports = const <AdminReportEntry>[];
          _imageReviews = const <AdminImageReviewItem>[];
          _postPinRequests = postPinRequests;
          _userLevelRequests = const <AdminUserLevelRequestEntry>[];
          _accountCancellationRequests =
              const <AdminAccountCancellationRequest>[];
          _appeals = const <AdminAppealEntry>[];
          _feedbacks = const <AdminFeedbackEntry>[];
          _tagData = AdminTagData(tags: const <String>[]);
          _announcements = const <AdminSystemAnnouncement>[];
          _adminAccounts = const <AdminAccountEntry>[];
          _androidRelease = null;
        });
        return;
      }

      final AdminOverview overview = await _repo.fetchOverview();
      final List<AdminReviewItem> reviews = await _repo.fetchReviews(
        type: _reviewType,
        status: _reviewStatus,
        keyword: _reviewKeywordController.text.trim(),
      );
      final List<AdminReportEntry> reports = await _repo.fetchReports(
        status: _reportStatus,
      );
      final List<AdminImageReviewItem> imageReviews = await _repo
          .fetchImageReviews(
            status: _imageStatus,
            keyword: _imageKeywordController.text.trim(),
          );
      final List<AdminUserLevelRequestEntry> userLevelRequests = await _repo
          .fetchUserLevelRequests(
            status: _userLevelStatus,
            keyword: _userLevelKeywordController.text.trim(),
          );
      final List<AdminAccountCancellationRequest> accountCancellationRequests =
          await _repo.fetchAccountCancellationRequests(
            status: _cancellationStatus,
            keyword: _cancellationKeywordController.text.trim(),
          );
      final List<AdminAppealEntry> appeals = await _repo.fetchAppeals(
        status: _appealStatus,
        keyword: _appealKeywordController.text.trim(),
      );
      final List<AdminFeedbackEntry> feedbacks = await _repo.fetchFeedbacks(
        status: _feedbackStatus,
      );
      final AdminTagData tagData = await _repo.fetchTags();
      final AdminSystemConfig config = await _repo.fetchConfig();
      final List<AdminSystemAnnouncement> announcements = await _repo
          .fetchAnnouncements();
      final List<AdminAccountEntry> adminAccounts = await _repo
          .fetchAdminAccounts();
      final AdminAndroidRelease? androidRelease = await _repo
          .fetchAndroidRelease();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentAdmin = currentAdmin;
        _overview = overview;
        _reviews = reviews;
        _reports = reports;
        _imageReviews = imageReviews;
        _postPinRequests = postPinRequests;
        _userLevelRequests = userLevelRequests;
        _accountCancellationRequests = accountCancellationRequests;
        _appeals = appeals;
        _feedbacks = feedbacks;
        _users = users;
        _tagData = tagData;
        _config = config;
        _announcements = announcements;
        _adminAccounts = adminAccounts;
        _androidRelease = androidRelease;
      });
      _syncSelectedReviews();

      _syncConfigControllers();
      _syncReleaseControllers();
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

  /// Each list's latest request. Changing a filter while an earlier load is
  /// in flight must not let the slower, older answer overwrite the list.
  final Map<String, int> _loadGenerations = <String, int>{};

  int _beginLoad(String list) =>
      _loadGenerations[list] = (_loadGenerations[list] ?? 0) + 1;

  bool _isLatestLoad(String list, int load) => _loadGenerations[list] == load;

  Future<void> _loadReviews() async {
    final int load = _beginLoad('_loadReviews');
    try {
      final List<AdminReviewItem> reviews = await _repo.fetchReviews(
        type: _reviewType,
        status: _reviewStatus,
        keyword: _reviewKeywordController.text.trim(),
      );
      if (!mounted || !_isLatestLoad('_loadReviews', load)) {
        return;
      }
      setState(() {
        _reviews = reviews;
      });
      _syncSelectedReviews();
    } catch (error) {
      _toast('加载审核列表失败：$error');
    }
  }

  Future<void> _loadReports() async {
    final int load = _beginLoad('_loadReports');
    try {
      final List<AdminReportEntry> reports = await _repo.fetchReports(
        status: _reportStatus,
        keyword: _reportKeywordController.text.trim(),
      );
      if (!mounted || !_isLatestLoad('_loadReports', load)) {
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
    final int load = _beginLoad('_loadImageReviews');
    try {
      final List<AdminImageReviewItem> rows = await _repo.fetchImageReviews(
        status: _imageStatus,
        keyword: _imageKeywordController.text.trim(),
      );
      if (!mounted || !_isLatestLoad('_loadImageReviews', load)) {
        return;
      }
      setState(() {
        _imageReviews = rows;
      });
    } catch (error) {
      _toast('加载图片审核列表失败：$error');
    }
  }

  Future<void> _loadPostPinRequests() async {
    final int load = _beginLoad('_loadPostPinRequests');
    try {
      final List<AdminPostPinRequestEntry> rows = await _repo
          .fetchPostPinRequests(
            status: _postPinStatus,
            keyword: _postPinKeywordController.text.trim(),
          );
      if (!mounted || !_isLatestLoad('_loadPostPinRequests', load)) {
        return;
      }
      setState(() {
        _postPinRequests = rows;
      });
    } catch (error) {
      _toast('加载置顶申请失败：$error');
    }
  }

  Future<void> _loadAccountCancellationRequests() async {
    final int load = _beginLoad('_loadAccountCancellationRequests');
    try {
      final List<AdminAccountCancellationRequest> rows = await _repo
          .fetchAccountCancellationRequests(
            status: _cancellationStatus,
            keyword: _cancellationKeywordController.text.trim(),
          );
      if (!mounted ||
          !_isLatestLoad('_loadAccountCancellationRequests', load)) {
        return;
      }
      setState(() {
        _accountCancellationRequests = rows;
      });
    } catch (error) {
      _toast('加载注销申请失败：$error');
    }
  }

  Future<void> _loadUsers() async {
    final int load = _beginLoad('_loadUsers');
    try {
      final List<AdminUserEntry> users = await _repo.fetchUsers();
      if (!mounted || !_isLatestLoad('_loadUsers', load)) {
        return;
      }
      setState(() {
        _users = users;
      });
    } catch (error) {
      _toast('加载用户列表失败：$error');
    }
  }

  Future<void> _loadFeedbacks() async {
    final int load = _beginLoad('_loadFeedbacks');
    try {
      final List<AdminFeedbackEntry> rows = await _repo.fetchFeedbacks(
        status: _feedbackStatus,
      );
      if (!mounted || !_isLatestLoad('_loadFeedbacks', load)) {
        return;
      }
      setState(() {
        _feedbacks = rows;
      });
    } catch (error) {
      _toast('加载反馈列表失败：$error');
    }
  }

  /// 回复 answers the user (已回复); 关闭 ends it, the reply optional.
  Future<void> _promptAndHandleFeedback(
    AdminFeedbackEntry feedback,
    String action,
  ) async {
    final bool reply = action == 'reply';
    final String? value = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: reply ? '回复反馈' : '关闭反馈',
        label: reply ? '回复内容（必填，用户可见）' : '说明（可选，用户可见）',
        hint: reply ? '最多 1000 字' : '',
        confirmLabel: reply ? '发送回复' : '确认关闭',
      ),
    );
    if (value == null) {
      return;
    }
    await _runAction(
      () => _repo.handleFeedback(
        feedbackId: feedback.id,
        action: action,
        reply: value,
      ),
      successText: reply ? '已回复，用户会收到通知' : '反馈已关闭',
      onSuccess: () async {
        await _loadFeedbacks();
        await _loadOverview();
      },
    );
  }

  Future<void> _loadAppeals() async {
    final int load = _beginLoad('_loadAppeals');
    try {
      final List<AdminAppealEntry> rows = await _repo.fetchAppeals(
        status: _appealStatus,
        keyword: _appealKeywordController.text.trim(),
      );
      if (!mounted || !_isLatestLoad('_loadAppeals', load)) {
        return;
      }
      setState(() {
        _appeals = rows;
      });
    } catch (error) {
      _toast('加载申诉列表失败：$error');
    }
  }

  Future<void> _loadUserLevelRequests() async {
    if (!_isPrimaryAdmin) {
      return;
    }
    final int load = _beginLoad('_loadUserLevelRequests');
    try {
      final List<AdminUserLevelRequestEntry> rows = await _repo
          .fetchUserLevelRequests(
            status: _userLevelStatus,
            keyword: _userLevelKeywordController.text.trim(),
          );
      if (!mounted || !_isLatestLoad('_loadUserLevelRequests', load)) {
        return;
      }
      setState(() {
        _userLevelRequests = rows;
      });
    } catch (error) {
      _toast('加载一级用户申请失败：$error');
    }
  }

  Future<void> _loadTags() async {
    try {
      final AdminTagData data = await _repo.fetchTags();
      if (!mounted) {
        return;
      }
      setState(() {
        _tagData = data;
      });
    } catch (error) {
      _toast('加载分类标签失败：$error');
    }
  }

  Future<void> _loadConfig() async {
    if (!_isPrimaryAdmin) {
      return;
    }
    try {
      final AdminSystemConfig config = await _repo.fetchConfig();
      final List<AdminSystemAnnouncement> announcements = await _repo
          .fetchAnnouncements();
      final List<AdminAccountEntry> adminAccounts = await _repo
          .fetchAdminAccounts();
      final AdminAndroidRelease? androidRelease = await _repo
          .fetchAndroidRelease();
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
        _announcements = announcements;
        _adminAccounts = adminAccounts;
        _androidRelease = androidRelease;
      });
      _syncConfigControllers();
      _syncReleaseControllers();
    } catch (error) {
      _toast('加载配置失败：$error');
    }
  }

  Future<void> _loadAndroidRelease() async {
    if (!_isPrimaryAdmin) {
      return;
    }
    try {
      final AdminAndroidRelease? release = await _repo.fetchAndroidRelease();
      if (!mounted) {
        return;
      }
      setState(() {
        _androidRelease = release;
      });
      _syncReleaseControllers();
    } catch (error) {
      _toast('加载版本发布信息失败：$error');
    }
  }

  Future<void> _loadAdminAccounts() async {
    if (!_isPrimaryAdmin) {
      return;
    }
    try {
      final List<AdminAccountEntry> rows = await _repo.fetchAdminAccounts();
      if (!mounted) {
        return;
      }
      setState(() {
        _adminAccounts = rows;
      });
    } catch (error) {
      _toast('加载二级管理员失败：$error');
    }
  }

  Future<void> _pickAndroidApk() async {
    try {
      final PickedReleaseFile? file = await pickReleaseFile();
      if (!mounted || file == null) {
        return;
      }
      setState(() {
        _selectedAndroidApk = file;
      });
    } catch (error) {
      _toast('选择 APK 失败：$error');
    }
  }

  Future<void> _uploadAndroidRelease() async {
    final PickedReleaseFile? file = _selectedAndroidApk;
    if (file == null) {
      _toast('请先选择 APK 文件');
      return;
    }
    final String versionName = _androidVersionNameController.text.trim();
    final int? versionCode = int.tryParse(
      _androidVersionCodeController.text.trim(),
    );
    final String releaseNotes = _androidReleaseNotesController.text.trim();

    if (versionName.isEmpty) {
      _toast('请输入版本名称');
      return;
    }
    if (versionCode == null || versionCode <= 0) {
      _toast('请输入合法的版本号');
      return;
    }

    setState(() {
      _actionBusy = true;
    });
    try {
      final AdminAndroidRelease release = await _repo.uploadAndroidRelease(
        versionName: versionName,
        versionCode: versionCode,
        releaseNotes: releaseNotes,
        forceUpdate: _androidForceUpdate,
        fileBytes: file.bytes,
        fileName: file.fileName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _androidRelease = release;
        _selectedAndroidApk = null;
      });
      _syncReleaseControllers();
      _toast('Android 安装包已上传发布');
    } catch (error) {
      _toast('上传 APK 失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _handleReview(
    String targetType,
    String targetId,
    String action,
  ) async {
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

  Future<void> _handleReviewBatch(String action) async {
    final List<String> targetIds = _reviews
        .where(
          (AdminReviewItem item) =>
              _selectedReviewIds.contains(_reviewSelectionKey(item)),
        )
        .map((AdminReviewItem item) => item.id)
        .toList();
    if (targetIds.isEmpty) {
      _toast('请先选择要处理的内容');
      return;
    }
    setState(() {
      _actionBusy = true;
    });
    try {
      final List<String> failures = await _repo.handleReviewBatch(
        targetType: _reviewType,
        targetIds: targetIds,
        action: action,
      );
      if (mounted) {
        setState(() {
          _selectedReviewIds.clear();
        });
      }
      // Items are applied one by one: the rest are saved even when some fail.
      await _loadReviews();
      await _loadOverview();
      _toast(
        failures.isEmpty
            ? '批量审核成功'
            : '${targetIds.length - failures.length} 项成功，${failures.length} 项失败：${failures.join('；')}',
      );
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

  Future<void> _handleAccountCancellation(
    String requestId,
    String action, {
    String? note,
  }) async {
    await _runAction(
      () => _repo.handleAccountCancellationRequest(
        requestId: requestId,
        action: action,
        note: note,
      ),
      successText: action == 'approve' ? '账号已注销' : '注销申请已驳回',
      onSuccess: () async {
        await _loadAccountCancellationRequests();
        await _loadUsers();
        await _loadOverview();
      },
    );
  }

  Future<void> _handlePostPinRequest(
    String requestId,
    String action, {
    String? note,
  }) async {
    await _runAction(
      () => _repo.handlePostPinRequest(
        requestId: requestId,
        action: action,
        note: note,
      ),
      successText: action == 'approve' ? '置顶申请已通过' : '置顶申请已驳回',
      onSuccess: () async {
        await _loadPostPinRequests();
        if (_isPrimaryAdmin) {
          await _loadOverview();
        }
      },
    );
  }

  Future<void> _handleUserLevelRequest(
    String requestId,
    String action, {
    String? note,
  }) async {
    await _runAction(
      () => _repo.handleUserLevelRequest(
        requestId: requestId,
        action: action,
        note: note,
      ),
      successText: action == 'approve' ? '一级用户申请已通过' : '一级用户申请已驳回',
      onSuccess: () async {
        await _loadUserLevelRequests();
        await _loadUsers();
      },
    );
  }

  Future<void> _handleAppeal(
    String appealId,
    String action, {
    String? note,
  }) async {
    await _runAction(
      () => _repo.handleAppeal(appealId: appealId, action: action, note: note),
      successText: action == 'approve_restore' ? '申诉已处理并恢复账号' : '申诉处理成功',
      onSuccess: () async {
        await _loadAppeals();
        await _loadUsers();
        await _loadOverview();
      },
    );
  }

  Future<void> _updateUser(String userId, String action, {String? note}) async {
    await _runAction(
      () => _repo.updateUserState(userId: userId, action: action, note: note),
      successText: action == 'cancel'
          ? '账号已注销'
          : action == 'restore'
          ? '账号已恢复'
          : '用户状态已更新',
      onSuccess: () async {
        await _loadUsers();
        await _loadPostPinRequests();
        if (_isPrimaryAdmin) {
          await _loadUserLevelRequests();
          await _loadAccountCancellationRequests();
          await _loadAppeals();
          await _loadOverview();
        }
      },
    );
  }

  Future<void> _createSecondaryAdmin() async {
    final String username = _adminUsernameController.text.trim();
    final String password = _adminPasswordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      _toast('请输入管理员账号和密码');
      return;
    }
    await _runAction(
      () => _repo.createAdminAccount(username: username, password: password),
      successText: '二级管理员已创建',
      onSuccess: () async {
        _adminUsernameController.clear();
        _adminPasswordController.clear();
        await _loadAdminAccounts();
      },
    );
  }

  Future<void> _updateSecondaryAdmin(String adminId, String action) async {
    await _runAction(
      () => _repo.updateAdminAccount(adminId: adminId, action: action),
      successText: action == 'deactivate' ? '二级管理员已注销' : '二级管理员已恢复',
      onSuccess: _loadAdminAccounts,
    );
  }

  Future<void> _updateUserAdminByStudentId(String action) async {
    final String studentId = _userAdminStudentIdController.text.trim();
    if (studentId.isEmpty) {
      _toast('请输入学号');
      return;
    }
    final List<AdminUserEntry> matches = _users
        .where((AdminUserEntry user) => user.studentId.trim() == studentId)
        .toList();
    if (matches.isEmpty) {
      _toast('未找到该学号对应的普通账号');
      return;
    }
    if (matches.length > 1) {
      _toast('该学号匹配到多个账号，请先在用户列表核对');
      return;
    }
    final AdminUserEntry user = matches.single;
    await _runAction(
      () => _repo.updateUserState(
        userId: user.id,
        action: action,
        note: action == 'grant_admin'
            ? '按学号 $studentId 设为管理员'
            : '按学号 $studentId 移除管理员权限',
      ),
      successText: action == 'grant_admin' ? '管理员已设置' : '管理员权限已移除',
      onSuccess: () async {
        _userAdminStudentIdController.clear();
        await _loadUsers();
        await _loadOverview();
      },
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
        await _loadTags();
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
      onSuccess: _loadTags,
    );
  }

  Future<void> _deleteTag(String name) async {
    await _runAction(
      () => _repo.deleteTag(name),
      successText: '标签已删除',
      onSuccess: _loadTags,
    );
  }

  Future<void> _saveConfig() async {
    final int? postRateLimit = int.tryParse(_postLimitController.text.trim());
    final int? commentRateLimit = int.tryParse(
      _commentLimitController.text.trim(),
    );
    final int? messageRateLimit = int.tryParse(
      _messageLimitController.text.trim(),
    );
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

  Future<void> _publishAnnouncement() async {
    final String title = _announcementTitleController.text.trim();
    final String content = _announcementContentController.text.trim();
    if (title.isEmpty) {
      _toast('请输入公告标题');
      return;
    }
    if (content.isEmpty) {
      _toast('请输入公告内容');
      return;
    }
    await _runAction(
      () => _repo.publishAnnouncement(title: title, content: content),
      successText: '系统公告已发布',
      onSuccess: () async {
        _announcementTitleController.clear();
        _announcementContentController.clear();
        await _loadConfig();
      },
    );
  }

  Future<void> _downloadExport() async {
    setState(() {
      _actionBusy = true;
    });
    try {
      final AdminExportFile file = await _repo.exportData(
        scope: _exportScope,
        format: _exportFormat,
        reviewType: _reviewType,
        reviewStatus: _reviewStatus,
        reportStatus: _reportStatus,
        appealStatus: _appealStatus,
      );
      final bool downloaded = downloadTextFile(
        fileName: file.fileName,
        content: file.content,
        contentType: file.contentType,
      );
      if (!downloaded) {
        await Clipboard.setData(ClipboardData(text: file.content));
        _toast('当前环境不支持直接下载，导出内容已复制到剪贴板');
      } else {
        _toast('导出完成，共 ${file.rowCount} 条记录');
      }
    } catch (error) {
      _toast('导出失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
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
    final String? value = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: actionLabel,
        label: '处理说明（可选）',
        hint: '可补充具体处理结果',
        confirmLabel: '确认处理',
        initial: defaultResult,
      ),
    );
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
    final String? value = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: actionLabel,
        label: '审核备注（可选）',
        hint: '可填写判定依据',
        confirmLabel: '确认处理',
        initial: defaultNote,
      ),
    );
    if (value == null) {
      return;
    }
    await _handleImageReview(uploadId, action, note: value);
  }

  Future<void> _promptAndHandleAccountCancellation({
    required String requestId,
    required String action,
    required String actionLabel,
    String defaultNote = '',
  }) async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: actionLabel,
        label: '审核备注（可选）',
        hint: '可填写注销原因确认或驳回原因',
        confirmLabel: '确认处理',
        initial: defaultNote,
      ),
    );
    if (value == null) {
      return;
    }
    await _handleAccountCancellation(requestId, action, note: value);
  }

  Future<void> _promptAndHandlePostPinRequest({
    required String requestId,
    required String action,
    required String actionLabel,
    String defaultNote = '',
  }) async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: actionLabel,
        label: '处理备注（可选）',
        hint: '可填写置顶通过或驳回原因',
        confirmLabel: '确认处理',
        initial: defaultNote,
      ),
    );
    if (value == null) {
      return;
    }
    await _handlePostPinRequest(requestId, action, note: value);
  }

  Future<void> _promptAndHandleAppeal({
    required String appealId,
    required String action,
    required String actionLabel,
    String defaultNote = '',
  }) async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: actionLabel,
        label: '处理备注（可选）',
        hint: '可填写处理依据或恢复说明',
        confirmLabel: '确认处理',
        initial: defaultNote,
      ),
    );
    if (value == null) {
      return;
    }
    await _handleAppeal(appealId, action, note: value);
  }

  Future<void> _promptAndHandleUserLevelRequest({
    required String requestId,
    required String action,
    required String actionLabel,
    String defaultNote = '',
  }) async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: actionLabel,
        label: '处理备注（可选）',
        hint: '可填写升级通过或驳回说明',
        confirmLabel: '确认处理',
        initial: defaultNote,
      ),
    );
    if (value == null) {
      return;
    }
    await _handleUserLevelRequest(requestId, action, note: value);
  }

  Future<void> _promptAndUpdateUserAction({
    required String userId,
    required String action,
    required String actionLabel,
    String defaultNote = '',
  }) async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: actionLabel,
        label: '操作备注（可选）',
        hint: '建议填写处理依据，便于后续追踪',
        confirmLabel: '确认执行',
        initial: defaultNote,
      ),
    );
    if (value == null) {
      return;
    }
    await _updateUser(userId, action, note: value);
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
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Text('图片加载失败')),
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
            child: SingleChildScrollView(child: Text('$subtitle\n\n$content')),
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
    if (!_isPrimaryAdmin) {
      return;
    }
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

  String _reviewSelectionKey(AdminReviewItem item) {
    return '${item.targetType}:${item.id}';
  }

  bool get _allVisibleReviewsSelected =>
      _reviews.isNotEmpty &&
      _reviews.every(
        (AdminReviewItem item) =>
            _selectedReviewIds.contains(_reviewSelectionKey(item)),
      );

  void _toggleReviewSelection(AdminReviewItem item) {
    final String key = _reviewSelectionKey(item);
    setState(() {
      if (_selectedReviewIds.contains(key)) {
        _selectedReviewIds.remove(key);
      } else {
        _selectedReviewIds.add(key);
      }
    });
  }

  void _toggleSelectAllReviews() {
    setState(() {
      if (_allVisibleReviewsSelected) {
        _selectedReviewIds.removeWhere(
          (String key) => _reviews.any(
            (AdminReviewItem item) => _reviewSelectionKey(item) == key,
          ),
        );
      } else {
        _selectedReviewIds.addAll(_reviews.map(_reviewSelectionKey));
      }
    });
  }

  void _syncSelectedReviews() {
    if (!mounted) {
      return;
    }
    final Set<String> allowed = _reviews.map(_reviewSelectionKey).toSet();
    setState(() {
      _selectedReviewIds.removeWhere((String key) => !allowed.contains(key));
    });
  }

  void _syncConfigControllers() {
    _sensitiveController.text = _config.sensitiveWords.join(',');
    _postLimitController.text = _config.postRateLimit.toString();
    _commentLimitController.text = _config.commentRateLimit.toString();
    _messageLimitController.text = _config.messageRateLimit.toString();
    _imageMaxController.text = _config.imageMaxMb.toString();
  }

  void _syncReleaseControllers() {
    final AdminAndroidRelease? release = _androidRelease;
    if (release == null) {
      return;
    }
    _androidVersionNameController.text = release.versionName;
    _androidVersionCodeController.text = release.versionCode.toString();
    _androidReleaseNotesController.text = release.releaseNotes;
    _androidForceUpdate = release.forceUpdate;
  }

  Future<String?> _askNewName({
    required String title,
    required String initial,
  }) async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: title,
        label: '新名称',
        hint: '',
        confirmLabel: '确定',
        initial: initial,
      ),
    );
    return value;
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 处理说明 for an admin action. Owns its controller, so it lives until the
/// dialog's exit animation ends; pops the trimmed text, or null.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    this.initial = '',
  });

  final String title;
  final String label;
  final String hint;
  final String confirmLabel;
  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const Key('admin-note-input'),
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint.isEmpty ? null : widget.hint,
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: <Widget>[
        ZxButton(
          label: '取消',
          variant: ZxButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ZxButton(
          key: const Key('admin-note-confirm'),
          label: widget.confirmLabel,
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}

class _AdminSection {
  const _AdminSection(this.label, this.icon, this.build, {this.pending = 0});

  final String label;
  final IconData icon;
  final Widget Function() build;

  /// Items waiting for a decision, shown as a count.
  final int pending;
}
