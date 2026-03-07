import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/media/image_picker_adapter.dart';
import '../../core/media/picked_image_data.dart';
import '../../models/user_profile.dart';
import '../../repositories/app_repositories.dart';
import '../auth/login_page.dart';
import '../auth/reset_password_page.dart';
import 'emoji_settings_page.dart';
import '../me/my_comments_page.dart';
import '../me/my_favorites_page.dart';
import '../me/my_posts_page.dart';
import '../me/my_reports_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();

  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final UserProfile profile = _profile ??
        UserProfile(
          nickname: '匿名同学',
          studentId: '',
          avatarUrl: '',
          email: '',
          verified: false,
          verifiedAt: '-',
          allowStrangerDm: false,
          showContactable: false,
          favoriteCount: 0,
          isAdmin: false,
        );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: <Widget>[
              _buildAvatar(profile.avatarUrl, profile.nickname),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.nickname,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        '学号：${profile.studentId.isEmpty ? '未设置' : profile.studentId}'),
                    Text('邮箱：${profile.email.isEmpty ? '-' : profile.email}'),
                    Text(
                      '认证状态：${profile.verified ? '已通过' : '未认证'}（${profile.verifiedAt}）',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '个人信息',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nicknameController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: '用户昵称',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _avatarUrlController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: '头像 URL',
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickAndUploadAvatar,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('选择图片并上传头像'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? '保存中...' : '保存资料'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('我的帖子'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const MyPostsPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.comment_bank_outlined),
                title: const Text('我的评论'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const MyCommentsPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('我的举报'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const MyReportsPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('我的收藏'),
                subtitle: Text('当前收藏帖子：${profile.favoriteCount}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyFavoritesPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('修改密码'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ResetPasswordPage(
                        initialEmail: profile.email,
                        lockEmail: profile.email.trim().isNotEmpty,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('删除账号申请'),
                onTap: _saving ? null : _deleteAccount,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Card(
          child: Column(
            children: <Widget>[
              SwitchListTile(
                title: const Text('允许陌生人私信'),
                value: profile.allowStrangerDm,
                onChanged: _saving
                    ? null
                    : (bool value) {
                        _updatePrivacy(
                          allowStrangerDm: value,
                          showContactable: profile.showContactable,
                        );
                      },
              ),
              SwitchListTile(
                title: const Text('显示“可联系”状态'),
                value: profile.showContactable,
                onChanged: _saving
                    ? null
                    : (bool value) {
                        _updatePrivacy(
                          allowStrangerDm: profile.allowStrangerDm,
                          showContactable: value,
                        );
                      },
              ),
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('黑名单管理'),
                onTap: () => _toast('黑名单管理页下一步接入。'),
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('表情设置'),
                subtitle: const Text('配置常用表情和输入面板开关'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EmojiSettingsPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('退出登录'),
                onTap: _saving ? null : _logout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String url, String nickname) {
    final String resolved = _resolveAvatarUrl(url);
    if (resolved.isNotEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundImage: NetworkImage(resolved),
      );
    }
    final String trimmed = nickname.trim();
    final String label = trimmed.isEmpty ? '匿' : trimmed.substring(0, 1);
    return CircleAvatar(
      radius: 30,
      child: Text(label),
    );
  }

  String _resolveAvatarUrl(String url) {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      final Uri base = Uri.parse(AppConfig.apiBaseUrl);
      return '${base.scheme}://${base.authority}$trimmed';
    }
    return '';
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final UserProfile profile = await AppRepositories.users.fetchProfile();
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _nicknameController.text = profile.nickname;
        _avatarUrlController.text = profile.avatarUrl;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '资料加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() {
      _saving = true;
    });

    try {
      final List<PickedImageData> selected =
          await pickImageFiles(multiple: false);
      if (!mounted || selected.isEmpty) {
        return;
      }
      final PickedImageData image = selected.first;
      final String avatarUrl = await AppRepositories.users.uploadAvatar(
        fileName: image.fileName,
        contentType: image.contentType,
        dataBase64: image.dataBase64,
      );
      if (!mounted) {
        return;
      }
      if (avatarUrl.trim().isNotEmpty) {
        _avatarUrlController.text = avatarUrl.trim();
      }
      setState(() {
        _profile = (_profile ??
                UserProfile(
                  nickname: _nicknameController.text.trim().isEmpty
                      ? '匿名同学'
                      : _nicknameController.text.trim(),
                  studentId: '',
                  avatarUrl: '',
                  email: '',
                  verified: false,
                  verifiedAt: '-',
                  allowStrangerDm: false,
                  showContactable: false,
                  favoriteCount: 0,
                  isAdmin: false,
                ))
            .copyWith(avatarUrl: _avatarUrlController.text.trim());
      });
      _toast('头像上传成功');
    } catch (error) {
      _toast('头像上传失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final String nickname = _nicknameController.text.trim();
    final String avatarUrl = _avatarUrlController.text.trim();
    if (nickname.isEmpty) {
      _toast('昵称不能为空');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await AppRepositories.users.updateProfile(
        nickname: nickname,
        avatarUrl: avatarUrl,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = (_profile ??
                UserProfile(
                  nickname: nickname,
                  studentId: '',
                  avatarUrl: '',
                  email: '',
                  verified: false,
                  verifiedAt: '-',
                  allowStrangerDm: false,
                  showContactable: false,
                  favoriteCount: 0,
                  isAdmin: false,
                ))
            .copyWith(
          nickname: nickname,
          avatarUrl: avatarUrl,
        );
      });
      _toast('资料已更新');
    } catch (error) {
      _toast('保存失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _updatePrivacy({
    required bool allowStrangerDm,
    required bool showContactable,
  }) async {
    setState(() {
      _saving = true;
    });

    try {
      await AppRepositories.users.updatePrivacy(
        allowStrangerDm: allowStrangerDm,
        showContactable: showContactable,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = (_profile ??
                UserProfile(
                  nickname: '匿名同学',
                  studentId: '',
                  avatarUrl: '',
                  email: '',
                  verified: false,
                  verifiedAt: '-',
                  allowStrangerDm: false,
                  showContactable: false,
                  favoriteCount: 0,
                  isAdmin: false,
                ))
            .copyWith(
          allowStrangerDm: allowStrangerDm,
          showContactable: showContactable,
        );
      });
      _toast('隐私设置已更新');
    } catch (error) {
      _toast('保存失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _saving = true;
    });

    try {
      await AppRepositories.users.deleteAccount();
      if (!mounted) {
        return;
      }
      _toast('删除账号申请已提交');
    } catch (error) {
      _toast('提交失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _saving = true;
    });

    try {
      await AppRepositories.auth.logout();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      _toast('退出失败：$error');
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
