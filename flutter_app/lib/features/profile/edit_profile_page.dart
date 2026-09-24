import 'package:flutter/material.dart';

import '../../core/auth/auth_store.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/media/image_picker_adapter.dart';
import '../../core/media/picked_image_data.dart';
import '../../design_system/design_system.dart';
import '../../models/user_profile.dart';
import '../../repositories/app_repositories.dart';

/// 编辑资料: avatar, background, nickname, bio and gender. Pops with the
/// saved profile, or null when left unsaved.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nicknameController = TextEditingController(
    text: widget.profile.nickname,
  );
  late final TextEditingController _avatarUrlController = TextEditingController(
    text: widget.profile.avatarUrl,
  );
  late final TextEditingController _bioController = TextEditingController(
    text: widget.profile.bio,
  );
  late final TextEditingController _backgroundUrlController =
      TextEditingController(text: widget.profile.backgroundImageUrl);
  late String _gender = widget.profile.gender;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    // Previews follow the link fields as they are typed.
    _avatarUrlController.addListener(_refresh);
    _backgroundUrlController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _nicknameController.dispose();
    _avatarUrlController.dispose();
    _bioController.dispose();
    _backgroundUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    final ZxTokens t = ZxTokens.of(context);
    final bool busy = _saving || _uploading;
    final String background = AppConfig.resolveUrl(
      _backgroundUrlController.text.trim(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(text('编辑资料', 'Edit profile')),
        actions: <Widget>[
          ZxButton(
            key: const Key('edit-profile-save'),
            label: text('保存', 'Save'),
            small: true,
            loading: _saving,
            onPressed: busy ? null : _save,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ZxPaper(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ZxCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _BackgroundPicker(
                            url: background,
                            busy: busy,
                            onPick: _pickBackground,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Row(
                              children: <Widget>[
                                ZxAvatar(
                                  name: _nicknameController.text.trim().isEmpty
                                      ? widget.profile.nickname
                                      : _nicknameController.text.trim(),
                                  imageUrl: _avatarUrlController.text.trim(),
                                  size: 64,
                                  onTap: busy ? null : _pickAvatar,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        text('头像', 'Avatar'),
                                        style: ZxType.label.copyWith(
                                          color: t.text,
                                        ),
                                      ),
                                      Text(
                                        text(
                                          '点击头像选择图片，上传后经审核展示',
                                          'Tap to choose an image; it shows after review',
                                        ),
                                        style: ZxType.caption.copyWith(
                                          color: t.text3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ZxButton(
                                  key: const Key('edit-profile-avatar'),
                                  label: text('更换', 'Change'),
                                  variant: ZxButtonVariant.secondary,
                                  small: true,
                                  loading: _uploading,
                                  onPressed: busy ? null : _pickAvatar,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ZxCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextField(
                            key: const Key('edit-profile-nickname'),
                            controller: _nicknameController,
                            enabled: !busy,
                            maxLength: 24,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: text('昵称', 'Nickname'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _bioController,
                            enabled: !busy,
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: text('个性签名', 'Bio'),
                              hintText: text(
                                '介绍一下自己吧',
                                'Tell others a little about yourself',
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            text('性别', 'Gender'),
                            style: ZxType.caption.copyWith(
                              color: t.text3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: <ButtonSegment<String>>[
                              ButtonSegment<String>(
                                value: '',
                                label: Text(text('不显示', 'Hidden')),
                              ),
                              ButtonSegment<String>(
                                value: '男',
                                label: Text(text('男', 'Male')),
                              ),
                              ButtonSegment<String>(
                                value: '女',
                                label: Text(text('女', 'Female')),
                              ),
                            ],
                            selected: <String>{_gender},
                            onSelectionChanged: busy
                                ? null
                                : (Set<String> value) =>
                                      setState(() => _gender = value.first),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ZxCard(
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(
                            text('使用图片链接', 'Use image links'),
                            style: ZxType.body.copyWith(color: t.text),
                          ),
                          subtitle: Text(
                            text(
                              '已有图片地址时，可直接填写',
                              'If the image is already online, paste its address',
                            ),
                            style: ZxType.caption.copyWith(color: t.text3),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          children: <Widget>[
                            TextField(
                              controller: _avatarUrlController,
                              enabled: !busy,
                              decoration: InputDecoration(
                                labelText: text('头像 URL', 'Avatar URL'),
                                hintText: 'https://...',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _backgroundUrlController,
                              enabled: !busy,
                              decoration: InputDecoration(
                                labelText: text(
                                  '主页背景图 URL',
                                  'Profile background URL',
                                ),
                                hintText: 'https://...',
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
        ),
      ),
    );
  }

  Future<PickedImageData?> _pickOne() async {
    final List<PickedImageData> selected = await pickImageFiles(
      multiple: false,
    );
    return selected.isEmpty ? null : selected.first;
  }

  Future<void> _pickAvatar() async {
    setState(() => _uploading = true);
    try {
      final PickedImageData? image = await _pickOne();
      if (image == null || !mounted) return;
      final String url = await AppRepositories.users.uploadAvatar(
        fileName: image.fileName,
        contentType: image.contentType,
        dataBase64: image.dataBase64,
      );
      if (!mounted) return;
      if (url.trim().isNotEmpty) _avatarUrlController.text = url.trim();
      _toast(
        uiTextGlobal(zh: '头像上传成功，记得保存', en: 'Avatar uploaded — save to apply'),
      );
    } catch (error) {
      _toast(
        uiTextGlobal(zh: '头像上传失败：$error', en: 'Avatar upload failed: $error'),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickBackground() async {
    setState(() => _uploading = true);
    try {
      final PickedImageData? image = await _pickOne();
      if (image == null || !mounted) return;
      final String url = await AppRepositories.users.uploadBackgroundImage(
        fileName: image.fileName,
        contentType: image.contentType,
        dataBase64: image.dataBase64,
      );
      if (!mounted) return;
      if (url.trim().isNotEmpty) _backgroundUrlController.text = url.trim();
      _toast(
        uiTextGlobal(
          zh: '背景图上传成功，记得保存',
          en: 'Background uploaded — save to apply',
        ),
      );
    } catch (error) {
      _toast(
        uiTextGlobal(
          zh: '背景图上传失败：$error',
          en: 'Background upload failed: $error',
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final String nickname = _nicknameController.text.trim();
    final String nextNickname = nickname.isEmpty
        ? widget.profile.nickname
        : nickname;
    final String avatarUrl = _avatarUrlController.text.trim();
    final String bio = _bioController.text.trim();
    final String backgroundImageUrl = _backgroundUrlController.text.trim();
    setState(() => _saving = true);
    try {
      await AppRepositories.users.updateProfile(
        nickname: nextNickname,
        avatarUrl: avatarUrl,
        bio: bio,
        backgroundImageUrl: backgroundImageUrl,
        gender: _gender,
      );
      final UserProfile next = widget.profile.copyWith(
        nickname: nextNickname,
        avatarUrl: avatarUrl,
        bio: bio,
        backgroundImageUrl: backgroundImageUrl,
        gender: _gender,
      );
      AuthStore.instance.setCurrentUser(next);
      if (!mounted) return;
      _toast(uiTextGlobal(zh: '资料已更新', en: 'Profile updated'));
      Navigator.of(context).pop(next);
    } catch (error) {
      _toast(uiTextGlobal(zh: '保存失败：$error', en: 'Save failed: $error'));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (mounted) zxShowToast(context, message);
  }
}

class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({
    required this.url,
    required this.busy,
    required this.onPick,
  });

  final String url;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(ZxRadius.card),
      ),
      child: SizedBox(
        height: 120,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (url.isEmpty)
              ZxHeroWash(child: const SizedBox.expand())
            else
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ZxHeroWash(child: const SizedBox.expand()),
              ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: t.surface.withValues(alpha: 0.92),
                borderRadius: ZxRadius.badgeAll,
                child: InkWell(
                  key: const Key('edit-profile-background'),
                  borderRadius: ZxRadius.badgeAll,
                  onTap: busy ? null : onPick,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.wallpaper_outlined,
                          size: 15,
                          color: t.text2,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          uiText(
                            context,
                            zh: '更换主页背景图',
                            en: 'Change background',
                          ),
                          style: ZxType.caption.copyWith(
                            color: t.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
