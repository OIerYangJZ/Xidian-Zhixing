import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/home_shell.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key, required this.campusEmail, this.password});

  final String campusEmail;
  final String? password;

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final TextEditingController _codeController = TextEditingController();
  String? _errorText;
  bool _isBusy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageTopActions(leading: BackButton()),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('认证邮箱：${widget.campusEmail}'),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('verification-code-input'),
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: AppInput.decoration(
                      hintText: '输入 6 位验证码',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      counterMaxLength: 6,
                    ),
                  ),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: _isBusy ? null : _submit,
                    child: Text(_isBusy ? '认证中...' : '完成认证并进入首页'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isBusy ? null : _resend,
                    child: const Text('重新发送验证码'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final String code = _codeController.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() {
        _errorText = '请输入 6 位验证码。';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      final AuthLoginResult result = await AppRepositories.auth.verifyEmail(
        email: widget.campusEmail,
        code: code,
        password: widget.password,
      );

      if (!mounted) {
        return;
      }

      if (!result.verified) {
        setState(() {
          _errorText = '认证结果异常，请稍后重试。';
        });
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
        (Route<dynamic> route) => false,
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('认证失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      await AppRepositories.auth.resendCode(widget.campusEmail);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码已重新发送。')));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('重发失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorText = message;
    });
  }
}
