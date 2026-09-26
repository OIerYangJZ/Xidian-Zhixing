/// One 信箱 record from GET /api/feedback/mine
/// (`_user_handler.handle_my_feedbacks`).
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.category,
    required this.content,
    required this.contact,
    required this.status,
    required this.schoolReply,
    required this.createdAt,
    required this.handledAt,
  });

  /// The categories the 信箱 offers, as in the mini program.
  static const List<String> categories = <String>[
    '学校服务意见',
    '校园设施反馈',
    '平台功能建议',
    '学校管理或流程建议',
    '其他反馈',
  ];

  /// POST /api/feedback's limit.
  static const int maxContentLength = 1000;
  static const int maxContactLength = 80;

  static const Set<String> _statuses = <String>{
    'pending',
    'resolved',
    'closed',
  };

  final String id;
  final String category;
  final String content;
  final String contact;

  /// pending, resolved (已回复) or closed (已关闭).
  final String status;
  final String schoolReply;
  final String createdAt;
  final String handledAt;

  bool get isPending => status == 'pending';

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    String field(String key) {
      final dynamic value = json[key];
      if (value is! String) {
        throw FormatException('信箱记录缺少 $key');
      }
      return value;
    }

    final String id = field('id');
    final String status = field('status');
    if (id.isEmpty) {
      throw const FormatException('信箱记录缺少 ID');
    }
    if (!_statuses.contains(status)) {
      throw FormatException('信箱记录状态无效：$status');
    }
    return FeedbackItem(
      id: id,
      category: field('category'),
      content: field('content'),
      contact: field('contact'),
      status: status,
      schoolReply: field('schoolReply'),
      createdAt: field('createdAt'),
      handledAt: field('handledAt'),
    );
  }
}
