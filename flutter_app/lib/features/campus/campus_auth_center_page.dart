import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_store.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/campus_models.dart';

/// Campus account connections live under Settings. Credentials are sent only
/// to the selected service for verification; this page stores just the masked
/// account identifier and its latest verification time on the device.
class CampusAuthCenterPage extends ConsumerStatefulWidget {
  const CampusAuthCenterPage({super.key, this.initialSystem = 'ids'});

  final String initialSystem;

  @override
  ConsumerState<CampusAuthCenterPage> createState() =>
      _CampusAuthCenterPageState();
}

class _CampusAuthCenterPageState extends ConsumerState<CampusAuthCenterPage> {
  static const String _stateKey = 'campus_auth_state';
  static const List<_CampusSystem> _systems = <_CampusSystem>[
    _CampusSystem('ids', '统一认证', _CampusAuthType.password),
    _CampusSystem('payment', '缴费与水电', _CampusAuthType.password),
    _CampusSystem('physics', '物理实验', _CampusAuthType.password),
    _CampusSystem('sport', '体育系统', _CampusAuthType.password),
    _CampusSystem('schoolnet', '校园网', _CampusAuthType.schoolnet),
    _CampusSystem('dormWater', '宿舍水机', _CampusAuthType.phone),
  ];

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _schoolnetCaptchaController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dormWaterImageCodeController =
      TextEditingController();
  final TextEditingController _dormWaterSmsController = TextEditingController();

  String _activeSystem = 'ids';
  Map<String, dynamic> _states = <String, dynamic>{};
  String _schoolnetAttemptId = '';
  Uint8List? _schoolnetCaptchaImage;
  String _dormWaterSessionId = '';
  Uint8List? _dormWaterCaptchaImage;
  bool _busy = false;
  bool _captchaBusy = false;
  bool _smsBusy = false;
  String? _error;

  _CampusSystem get _active =>
      _systems.firstWhere((_CampusSystem item) => item.id == _activeSystem);

  @override
  void initState() {
    super.initState();
    _activeSystem = _systems.any(
      (_CampusSystem item) => item.id == widget.initialSystem,
    )
        ? widget.initialSystem
        : 'ids';
    _identifierController.text =
        AuthStore.instance.currentUser?.studentId.trim() ?? '';
    Future<void>.microtask(_loadState);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _schoolnetCaptchaController.dispose();
    _phoneController.dispose();
    _dormWaterImageCodeController.dispose();
    _dormWaterSmsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('校园账号管理')),
      body: AppPageFrame(
        maxWidth: AppLayout.readingMaxWidth,
        child: ListView(
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final _CampusSystem system in _systems)
                  _SystemSelector(
                    label: system.name,
                    selected: system.id == _activeSystem,
                    connected: _states.containsKey(system.id),
                    onTap: () => _switchSystem(system.id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(_active.name, style: Theme.of(context).textTheme.titleLarge),
            if (_states[_activeSystem] case final Map<dynamic, dynamic> state)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${state['studentId'] ?? ''} · ${state['updatedAt'] ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.mutedInk,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearCurrentState,
                      child: const Text('移除账号'),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: AppInlineMessage(
                  message: _error!,
                  tone: AppMessageTone.error,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            if (_active.type == _CampusAuthType.password)
              _passwordForm()
            else if (_active.type == _CampusAuthType.schoolnet)
              _schoolnetForm()
            else
              _dormWaterForm(),
          ],
        ),
      ),
    );
  }

  Widget _passwordForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextField(
        controller: _identifierController,
        enabled: !_busy,
        decoration: AppInput.decoration(hintText: '学号'),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _passwordController,
        enabled: !_busy,
        obscureText: true,
        onSubmitted: (_) => _submitPasswordAuth(),
        decoration: AppInput.decoration(
          hintText: _activeSystem == 'ids' || _activeSystem == 'payment'
              ? '统一认证密码'
              : '${_active.name}密码',
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
        onPressed: _busy ? null : _submitPasswordAuth,
        child: Text(_busy ? '正在验证' : '验证并保存'),
      ),
    ],
  );

  Widget _schoolnetForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextField(
        controller: _identifierController,
        enabled: !_busy,
        decoration: AppInput.decoration(hintText: '账号'),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _passwordController,
        enabled: !_busy,
        obscureText: true,
        decoration: AppInput.decoration(hintText: '校园网查询密码'),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _schoolnetCaptchaController,
              enabled: !_busy,
              decoration: AppInput.decoration(hintText: '验证码'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _CaptchaBox(
            image: _schoolnetCaptchaImage,
            busy: _captchaBusy,
            onTap: _refreshSchoolnetCaptcha,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton(
        onPressed: _captchaBusy ? null : _refreshSchoolnetCaptcha,
        child: const Text('刷新验证码'),
      ),
      const SizedBox(height: AppSpacing.sm),
      FilledButton(
        onPressed: _busy ? null : _submitSchoolnetAuth,
        child: Text(_busy ? '正在登录' : '登录并保存'),
      ),
    ],
  );

  Widget _dormWaterForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextField(
        controller: _phoneController,
        enabled: !_busy,
        keyboardType: TextInputType.phone,
        decoration: AppInput.decoration(hintText: '手机号'),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _dormWaterImageCodeController,
              enabled: !_busy,
              decoration: AppInput.decoration(hintText: '图形验证码'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _CaptchaBox(
            image: _dormWaterCaptchaImage,
            busy: _captchaBusy,
            onTap: _refreshDormWaterCaptcha,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _dormWaterSmsController,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        decoration: AppInput.decoration(hintText: '短信验证码'),
      ),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton(
        onPressed: _smsBusy ? null : _sendDormWaterSms,
        child: Text(_smsBusy ? '正在发送' : '发送短信验证码'),
      ),
      const SizedBox(height: AppSpacing.sm),
      FilledButton(
        onPressed: _busy ? null : _submitDormWaterAuth,
        child: Text(_busy ? '正在登录' : '登录并保存'),
      ),
    ],
  );

  Future<void> _loadState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final dynamic decoded = jsonDecode(prefs.getString(_stateKey) ?? '{}');
    if (decoded is Map && mounted) {
      setState(() {
        _states = decoded.map(
          (dynamic key, dynamic value) => MapEntry<String, dynamic>(
            key.toString(),
            value,
          ),
        );
      });
    }
  }

  Future<void> _saveState(String systemId, CampusAuthResult result) async {
    final String identifier = result.studentId.isEmpty
        ? _identifierController.text.trim()
        : result.studentId;
    final Map<String, dynamic> next = <String, dynamic>{
      ..._states,
      systemId: <String, dynamic>{
        'studentId': _mask(identifier),
        'updatedAt': _nowText(),
      },
    };
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, jsonEncode(next));
    if (mounted) setState(() => _states = next);
  }

  void _switchSystem(String id) {
    setState(() {
      _activeSystem = id;
      _passwordController.clear();
      _schoolnetCaptchaController.clear();
      _dormWaterImageCodeController.clear();
      _dormWaterSmsController.clear();
      _schoolnetAttemptId = '';
      _dormWaterSessionId = '';
      _error = null;
    });
  }

  Future<void> _submitPasswordAuth() async {
    if (!_requireIdentifierAndPassword()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(campusRepositoryProvider);
      final CampusAuthResult result = switch (_activeSystem) {
        'payment' => await repository.loginPayment(
          _identifierController.text.trim(),
          _passwordController.text,
        ),
        'physics' => await repository.loginPhysics(
          _identifierController.text.trim(),
          _passwordController.text,
        ),
        'sport' => await repository.loginSport(
          _identifierController.text.trim(),
          _passwordController.text,
        ),
        _ => await repository.loginIds(
          _identifierController.text.trim(),
          _passwordController.text,
        ),
      };
      await _saveState(_activeSystem, result);
      _passwordController.clear();
    } catch (error) {
      _setError('${_active.name}验证失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshSchoolnetCaptcha() async {
    if (_identifierController.text.trim().isEmpty) {
      _setError('请输入学号后获取验证码');
      return;
    }
    setState(() {
      _captchaBusy = true;
      _error = null;
    });
    try {
      final CampusAuthResult result = await ref
          .read(campusRepositoryProvider)
          .createSchoolnetCaptcha(_identifierController.text.trim());
      if (mounted) {
        setState(() {
          _schoolnetAttemptId = result.attemptId;
          _schoolnetCaptchaImage = base64Decode(result.imageBase64);
        });
      }
    } catch (error) {
      _setError('校园网验证码获取失败：$error');
    } finally {
      if (mounted) setState(() => _captchaBusy = false);
    }
  }

  Future<void> _submitSchoolnetAuth() async {
    if (!_requireIdentifierAndPassword()) return;
    if (_schoolnetAttemptId.isEmpty ||
        _schoolnetCaptchaController.text.trim().isEmpty) {
      _setError('请先获取并填写验证码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final CampusAuthResult result = await ref
          .read(campusRepositoryProvider)
          .loginSchoolnet(
            attemptId: _schoolnetAttemptId,
            identifier: _identifierController.text.trim(),
            password: _passwordController.text,
            captcha: _schoolnetCaptchaController.text.trim(),
          );
      await _saveState('schoolnet', result);
      _passwordController.clear();
      _schoolnetCaptchaController.clear();
    } catch (error) {
      _setError('校园网登录失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshDormWaterCaptcha() async {
    setState(() {
      _captchaBusy = true;
      _error = null;
    });
    try {
      final CampusAuthResult result = await ref
          .read(campusRepositoryProvider)
          .createDormWaterCaptcha();
      if (mounted) {
        setState(() {
          _dormWaterSessionId = result.sessionId;
          _dormWaterCaptchaImage = base64Decode(result.imageBase64);
        });
      }
    } catch (error) {
      _setError('宿舍水机验证码获取失败：$error');
    } finally {
      if (mounted) setState(() => _captchaBusy = false);
    }
  }

  Future<void> _sendDormWaterSms() async {
    if (_phoneController.text.trim().isEmpty ||
        _dormWaterSessionId.isEmpty ||
        _dormWaterImageCodeController.text.trim().isEmpty) {
      _setError('请填写手机号和图形验证码');
      return;
    }
    setState(() {
      _smsBusy = true;
      _error = null;
    });
    try {
      await ref.read(campusRepositoryProvider).sendDormWaterSms(
        sessionId: _dormWaterSessionId,
        phone: _phoneController.text.trim(),
        imageCode: _dormWaterImageCodeController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('短信已发送')));
      }
    } catch (error) {
      _setError('短信验证码发送失败：$error');
    } finally {
      if (mounted) setState(() => _smsBusy = false);
    }
  }

  Future<void> _submitDormWaterAuth() async {
    if (_phoneController.text.trim().isEmpty ||
        _dormWaterSmsController.text.trim().isEmpty) {
      _setError('请输入手机号和短信验证码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final CampusAuthResult result = await ref
          .read(campusRepositoryProvider)
          .loginDormWater(
            phone: _phoneController.text.trim(),
            smsCode: _dormWaterSmsController.text.trim(),
          );
      await _saveState('dormWater', result);
      _dormWaterSmsController.clear();
    } catch (error) {
      _setError('宿舍水机登录失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _requireIdentifierAndPassword() {
    if (_identifierController.text.trim().isEmpty) {
      _setError('请输入学号');
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _setError('请输入密码');
      return false;
    }
    return true;
  }

  Future<void> _clearCurrentState() async {
    final Map<String, dynamic> next = <String, dynamic>{..._states}
      ..remove(_activeSystem);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, jsonEncode(next));
    if (mounted) setState(() => _states = next);
  }

  void _setError(String message) {
    if (mounted) setState(() => _error = message);
  }

  String _mask(String value) {
    if (value.length <= 4) return value;
    return '${value.substring(0, 2)}****${value.substring(value.length - 2)}';
  }

  String _nowText() {
    final DateTime now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
  }
}

class _SystemSelector extends StatelessWidget {
  const _SystemSelector({
    required this.label,
    required this.selected,
    required this.connected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected ? colors.primary : colors.mutedInk,
        backgroundColor: selected ? colors.primarySubtle : colors.surface,
      ),
      child: Text(connected ? '$label · 已连接' : label),
    );
  }
}

class _CaptchaBox extends StatelessWidget {
  const _CaptchaBox({
    required this.image,
    required this.busy,
    required this.onTap,
  });

  final Uint8List? image;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadii.input),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: SizedBox(
          width: 122,
          height: 58,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : image == null
                ? Text('获取验证码', style: Theme.of(context).textTheme.bodySmall)
                : Image.memory(image!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

enum _CampusAuthType { password, schoolnet, phone }

class _CampusSystem {
  const _CampusSystem(this.id, this.name, this.type);

  final String id;
  final String name;
  final _CampusAuthType type;
}
