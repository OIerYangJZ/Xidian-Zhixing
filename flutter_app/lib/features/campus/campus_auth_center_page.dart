import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_store.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/state/app_providers.dart';
import '../../models/campus_models.dart';

class CampusAuthCenterPage extends ConsumerStatefulWidget {
  const CampusAuthCenterPage({super.key, this.initialSystem = 'schoolnet'});

  final String initialSystem;

  @override
  ConsumerState<CampusAuthCenterPage> createState() =>
      _CampusAuthCenterPageState();
}

class _CampusAuthCenterPageState extends ConsumerState<CampusAuthCenterPage> {
  static const String _stateKey = 'campus_auth_state';
  static const List<_CampusSystem> _systems = <_CampusSystem>[
    _CampusSystem(
      'schoolnet',
      _AuthType.schoolnet,
      nameZh: '校园网自服务',
      nameEn: 'Campus network self-service',
      tagZh: '网络',
      tagEn: 'Network',
      descZh: '校园网账号、查询密码和图形验证码',
      descEn: 'Network account, lookup password and image captcha',
    ),
    _CampusSystem(
      'dormWater',
      _AuthType.phone,
      nameZh: '宿舍水机',
      nameEn: 'Dorm water dispenser',
      tagZh: '水机',
      tagEn: 'Water',
      descZh: '手机号、图形验证码和短信验证码',
      descEn: 'Phone number, image captcha and SMS code',
    ),
  ];

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _schoolnetCaptchaController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dormWaterImageCodeController =
      TextEditingController();
  final TextEditingController _dormWaterSmsController = TextEditingController();

  String _activeSystem = 'schoolnet';
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
    _activeSystem =
        _systems.any((_CampusSystem item) => item.id == widget.initialSystem)
        ? widget.initialSystem
        : 'schoolnet';
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
          (dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        );
      });
    }
  }

  Future<void> _saveState(String systemId, CampusAuthResult result) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String studentId = result.studentId.isEmpty
        ? _identifierController.text.trim()
        : result.studentId;
    final Map<String, dynamic> state = <String, dynamic>{
      'studentId': _mask(studentId),
      'updatedAt': _nowText(),
    };
    final Map<String, dynamic> next = <String, dynamic>{
      ..._states,
      systemId: state,
    };
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
    final Locale locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '登录管理', en: 'Sign-in manager')),
      ),
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
                  // A fixed height: two lines of description always fit.
                  mainAxisExtent: 124,
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
              border: Border.all(color: ZxTokens.of(context).line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _active.name(locale),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (_states.containsKey(_activeSystem))
                      TextButton(
                        onPressed: _clearCurrentState,
                        child: Text(uiText(context, zh: '清除', en: 'Clear')),
                      ),
                  ],
                ),
                if (_states[_activeSystem] case final Map state) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ZxTokens.of(context).primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      uiText(
                        context,
                        zh:
                            '已保存账号 · ${state['studentId'] ?? ''} · '
                            '${state['updatedAt'] ?? ''}',
                        en:
                            'Saved account · ${state['studentId'] ?? ''} · '
                            '${state['updatedAt'] ?? ''}',
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(color: ZxTokens.of(context).danger),
                  ),
                ],
                const SizedBox(height: 14),
                if (_active.type == _AuthType.schoolnet)
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

  Widget _schoolnetForm() {
    return Column(
      children: <Widget>[
        TextField(
          controller: _identifierController,
          decoration: InputDecoration(
            labelText: uiText(context, zh: '账号', en: 'Account'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: uiText(
              context,
              zh: '校园网查询密码',
              en: 'Network lookup password',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _schoolnetCaptchaController,
                decoration: InputDecoration(
                  labelText: uiText(context, zh: '验证码', en: 'Captcha'),
                ),
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
            child: Text(uiText(context, zh: '刷新验证码', en: 'Refresh captcha')),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _submitSchoolnetAuth,
            child: Text(
              _busy
                  ? uiText(context, zh: '正在登录', en: 'Signing in')
                  : uiText(
                      context,
                      zh: '登录校园网自服务',
                      en: 'Sign in to campus network',
                    ),
            ),
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
          decoration: InputDecoration(
            labelText: uiText(context, zh: '手机号', en: 'Phone number'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _dormWaterImageCodeController,
                decoration: InputDecoration(
                  labelText: uiText(context, zh: '图形码', en: 'Image code'),
                ),
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
          decoration: InputDecoration(
            labelText: uiText(context, zh: '短信码', en: 'SMS code'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _smsBusy ? null : _sendDormWaterSms,
            child: Text(
              _smsBusy
                  ? uiText(context, zh: '正在发送', en: 'Sending')
                  : uiText(context, zh: '发送短信验证码', en: 'Send SMS code'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _submitDormWaterAuth,
            child: Text(
              _busy
                  ? uiText(context, zh: '正在登录', en: 'Signing in')
                  : uiText(
                      context,
                      zh: '登录宿舍水机',
                      en: 'Sign in to water dispenser',
                    ),
            ),
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

  Future<void> _refreshSchoolnetCaptcha() async {
    if (_identifierController.text.trim().isEmpty) {
      _setError(
        uiTextGlobal(
          zh: '请输入学号后获取验证码',
          en: 'Enter your student ID before requesting a captcha',
        ),
      );
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
      _setError(
        uiTextGlobal(
          zh: '校园网验证码获取失败：$error',
          en: 'Could not load the campus network captcha: $error',
        ),
      );
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
      _setError(
        uiTextGlobal(
          zh: '请先获取并填写验证码',
          en: 'Request a captcha and fill it in first',
        ),
      );
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
      _setError(
        uiTextGlobal(
          zh: '校园网自服务登录失败：$error',
          en: 'Campus network sign-in failed: $error',
        ),
      );
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
      final CampusAuthResult result = await ref
          .read(campusRepositoryProvider)
          .createDormWaterCaptcha();
      setState(() {
        _dormWaterSessionId = result.sessionId;
        _dormWaterCaptchaImage = base64Decode(result.imageBase64);
      });
    } catch (error) {
      _setError(
        uiTextGlobal(
          zh: '宿舍水机验证码获取失败：$error',
          en: 'Could not load the water dispenser captcha: $error',
        ),
      );
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
      _setError(
        uiTextGlobal(
          zh: '请填写手机号和图形验证码',
          en: 'Fill in your phone number and the image captcha',
        ),
      );
      return;
    }
    setState(() {
      _smsBusy = true;
      _error = null;
    });
    try {
      await ref
          .read(campusRepositoryProvider)
          .sendDormWaterSms(
            sessionId: _dormWaterSessionId,
            phone: _phoneController.text.trim(),
            imageCode: _dormWaterImageCodeController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uiText(context, zh: '短信已发送', en: 'SMS sent')),
          ),
        );
      }
    } catch (error) {
      _setError(
        uiTextGlobal(
          zh: '短信验证码发送失败：$error',
          en: 'Could not send the SMS code: $error',
        ),
      );
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
      _setError(
        uiTextGlobal(
          zh: '请输入手机号和短信验证码',
          en: 'Enter your phone number and the SMS code',
        ),
      );
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
            sessionId: _dormWaterSessionId,
            phone: _phoneController.text.trim(),
            smsCode: _dormWaterSmsController.text.trim(),
          );
      await _saveState('dormWater', result);
      _dormWaterSmsController.clear();
    } catch (error) {
      _setError(
        uiTextGlobal(
          zh: '宿舍水机登录失败：$error',
          en: 'Water dispenser sign-in failed: $error',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool _requireIdentifierAndPassword() {
    if (_identifierController.text.trim().isEmpty) {
      _setError(uiTextGlobal(zh: '请输入学号', en: 'Enter your student ID'));
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _setError(uiTextGlobal(zh: '请输入密码', en: 'Enter your password'));
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
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    return Material(
      color: active ? t.primarySoft : t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: ZxRadius.cardAll,
        side: BorderSide(
          color: active ? t.primary : t.line,
          width: active ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: ZxRadius.cardAll),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    system.tag(locale),
                    style: ZxType.label.copyWith(color: t.primary),
                  ),
                  const Spacer(),
                  if (verified)
                    ZxBadge.verified(
                      uiText(context, zh: '已验证', en: 'Verified'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                system.name(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZxType.label.copyWith(color: t.text),
              ),
              const SizedBox(height: 4),
              Text(
                system.desc(locale),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ZxType.caption.copyWith(color: t.text3),
              ),
            ],
          ),
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
          border: Border.all(color: ZxTokens.of(context).line),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : image == null
            ? Text(uiText(context, zh: '获取', en: 'Load'))
            : Image.memory(image!, fit: BoxFit.contain),
      ),
    );
  }
}

enum _AuthType { schoolnet, phone }

class _CampusSystem {
  const _CampusSystem(
    this.id,
    this.type, {
    required this.nameZh,
    required this.nameEn,
    required this.tagZh,
    required this.tagEn,
    required this.descZh,
    required this.descEn,
  });

  final String id;
  final _AuthType type;
  final String nameZh;
  final String nameEn;
  final String tagZh;
  final String tagEn;
  final String descZh;
  final String descEn;

  String name(Locale locale) => uiTextFor(locale, zh: nameZh, en: nameEn);

  String tag(Locale locale) => uiTextFor(locale, zh: tagZh, en: tagEn);

  String desc(Locale locale) => uiTextFor(locale, zh: descZh, en: descEn);
}
