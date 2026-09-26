import '../core/l10n/ui_text.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';

/// State of the account's most recent appeal, as the server reports it.
///
/// A ban gets one in-app appeal; once it is turned down the holder is pointed
/// at the support mailbox. The server decides that ([AppealState.canSubmit]):
/// an appeal rejected during an earlier ban does not use up this one.
enum AppealStatus { none, pending, approved, rejected, closed }

class AppealState {
  const AppealState({
    required this.status,
    required this.banned,
    required this.supportEmail,
    required this.canSubmit,
    this.content = '',
    this.adminNote = '',
    this.createdAt = '',
    this.handledAt = '',
  });

  final AppealStatus status;
  final bool banned;
  final String supportEmail;
  final String content;

  /// Written by a human about this account, so it is shown to its owner.
  final String adminNote;
  final String createdAt;
  final String handledAt;

  /// Whether the appeal form applies: banned, nothing pending, and this
  /// ban's one in-app appeal not yet turned down.
  final bool canSubmit;

  bool get hasPending => status == AppealStatus.pending;

  /// Whether the in-app route is exhausted and only email remains.
  bool get mustUseEmail => banned && !hasPending && !canSubmit;

  factory AppealState.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> appeal = asMap(json['appeal']);
    final bool? canSubmit = readBool(json, <String>['canSubmit']);
    if (canSubmit == null) {
      throw FormatException(
        uiTextGlobal(
          zh: '申诉状态缺少 canSubmit',
          en: 'The appeal state is missing canSubmit',
        ),
      );
    }
    final String raw = (readString(appeal, <String>['status']) ?? '').trim();
    return AppealState(
      status: switch (raw) {
        'pending' => AppealStatus.pending,
        'approved' => AppealStatus.approved,
        'rejected' => AppealStatus.rejected,
        'closed' => AppealStatus.closed,
        _ => AppealStatus.none,
      },
      banned: readBool(json, <String>['banned']) == true,
      supportEmail: readString(json, <String>['supportEmail']) ?? '',
      canSubmit: canSubmit,
      content: readString(appeal, <String>['content']) ?? '',
      adminNote: readString(appeal, <String>['adminNote']) ?? '',
      createdAt: readString(appeal, <String>['createdAt']) ?? '',
      handledAt: readString(appeal, <String>['handledAt']) ?? '',
    );
  }
}

class AppealRepository {
  AppealRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AppealState> fetchLatest() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myLatestAppeal);
    return AppealState.fromJson(extractMap(response));
  }

  /// The server accepts this with the session alone, but it still validates the
  /// campus address, so the caller passes the one it signed in with.
  Future<void> submitUnbanAppeal({
    required String email,
    required String content,
  }) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw FormatException(
        uiTextGlobal(zh: '请填写申诉说明', en: 'Describe your appeal'),
      );
    }
    await _apiClient.post(
      ApiEndpoints.appeals,
      body: <String, dynamic>{
        'email': email.trim(),
        'appealType': 'ban_revoke',
        'content': trimmed,
      },
    );
  }
}
