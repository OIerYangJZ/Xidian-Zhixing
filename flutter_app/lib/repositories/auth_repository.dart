import '../core/auth/auth_store.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../core/l10n/ui_text.dart';

class XidianAuthSessionResult {
  const XidianAuthSessionResult({
    required this.attemptId,
    required this.status,
    required this.platform,
    this.authorizeUrl,
    this.message,
    this.token,
    this.email,
    this.studentId,
    this.banned = false,
  });

  final String attemptId;
  final String status;
  final String platform;
  final String? authorizeUrl;
  final String? message;
  final String? token;
  final String? email;
  final String? studentId;
  /// The server reports this with the session so the app can route to the
  /// appeal screen without first issuing a request that would be refused.
  final bool banned;

  bool get isPending => status == 'pending';
  bool get isAuthenticated => status == 'authenticated';
  bool get isFailed => status == 'failed';
}

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<XidianAuthSessionResult> createXidianAuthSession({
    required String platform,
    String nextPath = '/',
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.xidianAuthSession,
      auth: false,
      body: <String, dynamic>{'platform': platform, 'nextPath': nextPath},
    );
    final XidianAuthSessionResult result = _parseXidianAuthSession(response);
    if (!result.isPending || (result.authorizeUrl ?? '').isEmpty) {
      throw FormatException(uiTextGlobal(zh: '统一认证会话响应缺少官方授权地址', en: 'The CAS session response is missing the official authorization URL'));
    }
    return result;
  }

  Future<XidianAuthSessionResult> fetchXidianAuthSession(
    String attemptId,
  ) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.xidianAuthSessionById(attemptId),
      auth: false,
    );
    final XidianAuthSessionResult result = _parseXidianAuthSession(response);
    if (result.isAuthenticated) {
      final String token = result.token?.trim() ?? '';
      final String studentId = result.studentId?.trim() ?? '';
      if (token.isEmpty || studentId.isEmpty) {
        throw FormatException(uiTextGlobal(zh: '统一认证结果缺少有效登录凭据', en: 'The CAS result is missing valid login credentials'));
      }
      await AuthStore.instance.saveToken(token);
      AuthStore.instance.setBanned(result.banned);
    }
    return result;
  }

  Future<void> logout() async {
    await _apiClient.post(ApiEndpoints.logout, body: const <String, dynamic>{});
    await AuthStore.instance.clear();
  }

  Future<void> clearLocalAuth() {
    return AuthStore.instance.clear();
  }

  Future<void> saveToken(String token) {
    return AuthStore.instance.saveToken(token);
  }

  XidianAuthSessionResult _parseXidianAuthSession(dynamic response) {
    final Map<String, dynamic> root = asMap(response);
    final Map<String, dynamic> data = asMap(root['data']);
    final String attemptId =
        readString(data, <String>['attemptId'])?.trim() ?? '';
    final String status = readString(data, <String>['status'])?.trim() ?? '';
    final String platform =
        readString(data, <String>['platform'])?.trim() ?? '';
    if (attemptId.isEmpty ||
        !<String>{'pending', 'authenticated', 'failed'}.contains(status)) {
      throw FormatException(uiTextGlobal(zh: '统一认证会话响应格式无效', en: 'The CAS session response format is invalid'));
    }
    final String? token = readString(data, <String>['token']);
    final String? email = readString(data, <String>['email']);
    final String? studentId = readString(data, <String>['studentId']);
    if (status == 'authenticated' &&
        readBool(data, <String>['verified']) != true) {
      throw FormatException(uiTextGlobal(zh: '统一认证结果未经验证', en: 'The CAS result has not been verified'));
    }
    return XidianAuthSessionResult(
      attemptId: attemptId,
      status: status,
      platform: platform,
      authorizeUrl: readString(data, <String>['authorizeUrl']),
      message: readString(data, <String>['message']),
      token: token,
      email: email,
      studentId: studentId,
      banned: readBool(data, <String>['banned']) == true,
    );
  }
}
