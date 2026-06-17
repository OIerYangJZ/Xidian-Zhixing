import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_store.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/shared_colors.dart';
import '../../models/campus_models.dart';

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
    _CampusSystem('ids', '统一认证', 'IDS', '一站式、课表、成绩、考试等入口', _AuthType.password),
    _CampusSystem('payment', '缴费/水电', '水电', '缴费平台和水电系统跳转验证', _AuthType.password),
    _CampusSystem('physics', '物理实验', '实验', '物理实验选课与实验安排', _AuthType.password),
    _CampusSystem('sport', '体育系统', '体育', '体育课程、体测等系统访问', _AuthType.password),
    _CampusSystem('schoolnet', '校园网自服务', '网络', '校园网账号、查询密码和图形验证码', _AuthType.schoolnet),
    _CampusSystem('dormWater', '宿舍水机', '水机', '手机号、图形验证码和短信验证码', _AuthType.phone),
  ];

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _schoolnetCaptchaController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dormWaterImageCodeController = TextEditingController();
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
    _activeSystem = _systems.any((_CampusSystem item) => item.id == widget.initialSystem)
        ? widget.initialSystem
        : 'ids';
    _loadState();
    _identifierController.text =
        AuthStore.instance.currentUser?.studentId.trim() ?? '';
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

  Future<void> _loadState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_stateKey) ?? '{}';
    final dynamic decoded = jsonDecode(raw);
    if (decoded is Map) {
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String studentId =
        result.studentId.isEmpty ? _identifierController.text.trim() : result.studentId;
    final Map<String, dynamic> state = <String, dynamic>{
      'studentId': _mask(studentId),
      'updatedAt': _nowText(),
    };
    final Map<String, dynamic> next = <String, dynamic>{..._states, systemId: state};
    await prefs.setString(_stateKey, jsonEncode(next));
    if (!mounted) {
      return;
    }
    setState(() {
      _states = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录管理')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = constraints.maxWidth >= 900 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: columns == 3 ? 2.3 : 1.45,
                ),
                itemCount: _systems.length,
                itemBuilder: (BuildContext context, int index) {
                  final _CampusSystem system = _systems[index];
                  return _SystemCard(
                    system: system,
                    active: system.id == _activeSystem,
                    verified: _states.containsKey(system.id),
                    onTap: () => _switchSystem(system.id),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SharedColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _active.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (_states.containsKey(_activeSystem))
                      TextButton(onPressed: _clearCurrentState, child: const Text('清除')),
                  ],
                ),
                if (_states[_activeSystem] case final Map state) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SharedColors.softRed.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '已保存账号 · ${state['studentId'] ?? ''} · ${state['updatedAt'] ?? ''}',
                    ),
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 14),
                if (_active.type == _AuthType.password)
                  _passwordForm()
                else if (_active.type == _AuthType.schoolnet)
                  _schoolnetForm()
                else
                  _dormWaterForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordForm() {
    return Column(
      children: <Widget>[
        TextField(
          controller: _identifierController,
          decoration: const InputDecoration(labelText: '学号'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: _activeSystem == 'ids' || _activeSystem == 'payment'
                ? '统一认证密码'
                : '${_active.name}密码',
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _submitPasswordAuth,
            child: Text(_busy ? '正在验证' : '验证${_active.name}'),
          ),
        ),
      ],
    );
  }

  Widget _schoolnetForm() {
    return Column(
      children: <Widget>[
        TextField(
          controller: _identifierController,
          decoration: const InputDecoration(labelText: '账号'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: '校园网查询密码'),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _schoolnetCaptchaController,
                decoration: const InputDecoration(labelText: '验证码'),
              ),
            ),
            const SizedBox(width: 10),
            _CaptchaBox(
              image: _schoolnetCaptchaImage,
              busy: _captchaBusy,
              onTap: _refreshSchoolnetCaptcha,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _captchaBusy ? null : _refreshSchoolnetCaptcha,
            child: const Text('刷新验证码'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _submitSchoolnetAuth,
            child: Text(_busy ? '正在登录' : '登录校园网自服务'),
          ),
        ),
      ],
    );
  }

  Widget _dormWaterForm() {
    return Column(
      children: <Widget>[
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(labelText: '手机号'),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _dormWaterImageCodeController,
                decoration: const InputDecoration(labelText: '图形码'),
              ),
            ),
            const SizedBox(width: 10),
            _CaptchaBox(
              image: _dormWaterCaptchaImage,
              busy: _captchaBusy,
              onTap: _refreshDormWaterCaptcha,
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _dormWaterSmsController,
          decoration: const InputDecoration(labelText: '短信码'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _smsBusy ? null : _sendDormWaterSms,
            child: Text(_smsBusy ? '正在发送' : '发送短信验证码'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _submitDormWaterAuth,
            child: Text(_busy ? '正在登录' : '登录宿舍水机'),
          ),
        ),
      ],
    );
  }

  void _switchSystem(String id) {
    setState(() {
      _activeSystem = id;
      _passwordController.clear();
      _schoolnetCaptchaController.clear();
      _dormWaterImageCodeController.clear();
      _dormWaterSmsController.clear();
      _error = null;
    });
  }

  Future<void> _submitPasswordAuth() async {
    if (!_requireIdentifierAndPassword()) {
      return;
    }
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
      if (mounted) {
        setState(() => _busy = false);
      }
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
      setState(() {
        _schoolnetAttemptId = result.attemptId;
        _schoolnetCaptchaImage = base64Decode(result.imageBase64);
      });
    } catch (error) {
      _setError('校园网验证码获取失败：$error');
    } finally {
      if (mounted) {
        setState(() => _captchaBusy = false);
      }
    }
  }

  Future<void> _submitSchoolnetAuth() async {
    if (!_requireIdentifierAndPassword()) {
      return;
    }
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
      final CampusAuthResult result =
          await ref.read(campusRepositoryProvider).loginSchoolnet(
                attemptId: _schoolnetAttemptId,
                identifier: _identifierController.text.trim(),
                password: _passwordController.text,
                captcha: _schoolnetCaptchaController.text.trim(),
              );
      await _saveState('schoolnet', result);
      _passwordController.clear();
      _schoolnetCaptchaController.clear();
    } catch (error) {
      _setError('校园网自服务登录失败：$error');
      await _refreshSchoolnetCaptcha();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refreshDormWaterCaptcha() async {
    setState(() {
      _captchaBusy = true;
      _error = null;
    });
    try {
      final CampusAuthResult result =
          await ref.read(campusRepositoryProvider).createDormWaterCaptcha();
      setState(() {
        _dormWaterSessionId = result.sessionId;
        _dormWaterCaptchaImage = base64Decode(result.imageBase64);
      });
    } catch (error) {
      _setError('宿舍水机验证码获取失败：$error');
    } finally {
      if (mounted) {
        setState(() => _captchaBusy = false);
      }
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('短信已发送')));
      }
    } catch (error) {
      _setError('短信验证码发送失败：$error');
      await _refreshDormWaterCaptcha();
    } finally {
      if (mounted) {
        setState(() => _smsBusy = false);
      }
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
      final CampusAuthResult result =
          await ref.read(campusRepositoryProvider).loginDormWater(
                phone: _phoneController.text.trim(),
                smsCode: _dormWaterSmsController.text.trim(),
              );
      await _saveState('dormWater', result);
      _dormWaterSmsController.clear();
    } catch (error) {
      _setError('宿舍水机登录失败：$error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> next = <String, dynamic>{..._states};
    next.remove(_activeSystem);
    await prefs.setString(_stateKey, jsonEncode(next));
    if (mounted) {
      setState(() {
        _states = next;
      });
    }
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _error = message;
    });
  }

  String _mask(String value) {
    if (value.length <= 4) {
      return value;
    }
    return '${value.substring(0, 2)}****${value.substring(value.length - 2)}';
  }

  String _nowText() {
    final DateTime now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({
    required this.system,
    required this.active,
    required this.verified,
    required this.onTap,
  });

  final _CampusSystem system;
  final bool active;
  final bool verified;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? primary.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? primary : SharedColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  system.tag,
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (verified)
                  Text(
                    '已验证',
                    style: TextStyle(color: primary, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(system.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(
              system.desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: busy ? null : onTap,
      child: Container(
        width: 116,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SharedColors.divider),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : image == null
                ? const Text('获取')
                : Image.memory(image!, fit: BoxFit.contain),
      ),
    );
  }
}

enum _AuthType { password, schoolnet, phone }

class _CampusSystem {
  const _CampusSystem(this.id, this.name, this.tag, this.desc, this.type);

  final String id;
  final String name;
  final String tag;
  final String desc;
  final _AuthType type;
}
