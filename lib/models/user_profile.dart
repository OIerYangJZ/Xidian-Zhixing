class UserProfile {
  UserProfile({
    required this.nickname,
    required this.studentId,
    required this.avatarUrl,
    required this.email,
    required this.verified,
    required this.verifiedAt,
    required this.allowStrangerDm,
    required this.showContactable,
    required this.favoriteCount,
    required this.isAdmin,
    required this.accountCancellationRequest,
  });

  final String nickname;
  final String studentId;
  final String avatarUrl;
  final String email;
  final bool verified;
  final String verifiedAt;
  final bool allowStrangerDm;
  final bool showContactable;
  final int favoriteCount;
  final bool isAdmin;
  final AccountCancellationRequestSummary? accountCancellationRequest;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final String nickname =
        (json['nickname'] ?? json['alias'] ?? json['anonymousAlias'] ?? '匿名同学')
            .toString();
    return UserProfile(
      nickname: nickname,
      studentId: (json['studentId'] ?? json['userId'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      verified: _toBool(json['verified']) ?? true,
      verifiedAt: (json['verifiedAt'] ?? json['verifyTime'] ?? '-').toString(),
      allowStrangerDm: _toBool(json['allowStrangerDm']) ?? true,
      showContactable: _toBool(json['showContactable']) ?? true,
      favoriteCount: _toInt(json['favoriteCount']) ?? 0,
      isAdmin: _toBool(json['isAdmin']) ?? false,
      accountCancellationRequest: json['accountCancellationRequest'] is Map
          ? AccountCancellationRequestSummary.fromJson(
              (json['accountCancellationRequest'] as Map<dynamic, dynamic>).map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
    );
  }

  UserProfile copyWith({
    String? nickname,
    String? studentId,
    String? avatarUrl,
    String? email,
    bool? allowStrangerDm,
    bool? showContactable,
    int? favoriteCount,
    bool? isAdmin,
    AccountCancellationRequestSummary? accountCancellationRequest,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      studentId: studentId ?? this.studentId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      verified: verified,
      verifiedAt: verifiedAt,
      allowStrangerDm: allowStrangerDm ?? this.allowStrangerDm,
      showContactable: showContactable ?? this.showContactable,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      isAdmin: isAdmin ?? this.isAdmin,
      accountCancellationRequest:
          accountCancellationRequest ?? this.accountCancellationRequest,
    );
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String lowered = value.toLowerCase();
      if (lowered == 'true' || lowered == '1') {
        return true;
      }
      if (lowered == 'false' || lowered == '0') {
        return false;
      }
    }
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

class AccountCancellationRequestSummary {
  AccountCancellationRequestSummary({
    required this.id,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.reviewNote,
    required this.createdAt,
    required this.handledAt,
    required this.handledBy,
  });

  final String id;
  final String reason;
  final String status;
  final String statusLabel;
  final String reviewNote;
  final String createdAt;
  final String handledAt;
  final String handledBy;

  factory AccountCancellationRequestSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return AccountCancellationRequestSummary(
      id: (json['id'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['statusLabel'] ?? '待审核').toString(),
      reviewNote: (json['reviewNote'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
      handledBy: (json['handledBy'] ?? '').toString(),
    );
  }
}
