import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/repositories/auth_repository.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';
import '../../../core/theme/shared_colors.dart';
import '../../core/state/mobile_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final String identifier = _identifierController.text.trim();
    final String password = _passwordController.text.trim();
    if (identifier.isEmpty) {
      _showError('请输入学号或学生邮箱');
      return;
    }
    if (password.isEmpty) {
      _showError('请输入密码');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthLoginResult result = await ref
          .read(authRepositoryProvider)
          .login(identifier: identifier, password: password);
      if (!mounted) {
        return;
      }

      if (result.verified && (result.token ?? '').isNotEmpty) {
        try {
          final profile = await ref.read(userRepositoryProvider).fetchProfile();
          AuthStore.instance.setCurrentUser(profile);
        } catch (error) {
          if (!mounted) return;
          _showError(
            '登录成功，但个人资料加载失败：'
            '${error.toString().replaceAll('Exception: ', '')}',
          );
          return;
        }
        if (!mounted) {
          return;
        }
        ref.invalidate(feedControllerProvider);
        ref.invalidate(notificationsControllerProvider);
        ref.invalidate(messagesControllerProvider);
        context.go('/');
        return;
      }

      final String email = (result.email ?? '').trim();
      if (email.isEmpty) {
        _showError('登录结果异常，请稍后重试');
        return;
      }
      context.go('/auth/verify?email=${Uri.encodeComponent(email)}');
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('登录失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: SharedColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SharedColors.deep, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: SharedColors.deep.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '西电\n电台',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: 2,
                        fontFamily: MobileTheme.brandFontFamily,
                        fontFamilyFallback: MobileTheme.brandFontFamilyFallback,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '西电树洞',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  fontFamily: MobileTheme.brandFontFamily,
                  fontFamilyFallback: MobileTheme.brandFontFamilyFallback,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '欢迎回来',
                style: TextStyle(
                  fontSize: 15,
                  color: colors.textSecondary,
                  fontFamily: MobileTheme.brandFontFamily,
                  fontFamilyFallback: MobileTheme.brandFontFamilyFallback,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '项目组内测仅开放白名单学生邮箱',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _identifierController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '学号或学生邮箱',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: '密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton.icon(
                onPressed: _isLoading ? null : _login,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(_isLoading ? '登录中...' : '登录'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => context.go('/auth/register'),
                child: const Text('注册账号'),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => context.go('/auth/reset-password'),
                child: const Text('忘记密码'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
