class ApiEndpoints {
  static const String sendEmailCode = '/auth/send-code';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String verifyEmail = '/auth/verify';
  static const String resendCode = '/auth/resend-code';
  static const String passwordResetSendCode = '/auth/password/send-code';
  static const String passwordReset = '/auth/password/reset';
  static const String logout = '/auth/logout';

  static const String me = '/users/me';
  static const String privacy = '/users/privacy';
  static const String avatarUpload = '/users/avatar';
  static const String meCancellationRequest = '/users/me/cancellation-request';

  static const String channels = '/channels';
  static const String posts = '/posts';
  static const String myPosts = '/posts/mine';
  static const String favoritePosts = '/posts/favorites';
  static const String uploadImages = '/uploads/images';
  static const String myUploads = '/uploads/mine';

  static const String myComments = '/comments/mine';
  static const String myReports = '/reports/mine';
  static const String reports = '/reports';

  static const String dmRequests = '/messages/requests';
  static const String conversations = '/messages/conversations';

  static const String adminOverview = '/admin/overview';
  static const String adminLogin = '/admin/auth/login';
  static const String adminLogout = '/admin/auth/logout';
  static const String adminMe = '/admin/auth/me';
  static const String adminPassword = '/admin/auth/password';
  static const String adminReviews = '/admin/reviews';
  static const String adminReports = '/admin/reports';
  static const String adminImageReviews = '/admin/images/reviews';
  static const String adminUsers = '/admin/users';
  static const String adminAccountCancellationRequests =
      '/admin/account-cancellation-requests';
  static const String adminChannelsTags = '/admin/channels-tags';
  static const String adminChannels = '/admin/channels';
  static const String adminTags = '/admin/tags';
  static const String adminConfig = '/admin/config';

  static String postById(String postId) => '/posts/$postId';
  static String postComments(String postId) => '/posts/$postId/comments';
  static String postLike(String postId) => '/posts/$postId/like';
  static String postFavorite(String postId) => '/posts/$postId/favorite';
  static String postUnfavorite(String postId) => '/posts/$postId/favorite';

  static String dmRequestAction(String requestId, String action) =>
      '/messages/requests/$requestId/$action';
  static String dmConversationMessages(String conversationId) =>
      '/messages/conversations/$conversationId/messages';
  static String dmConversation(String conversationId) =>
      '/messages/conversations/$conversationId';
  static String dmConversationBlock(String conversationId, bool block) =>
      '/messages/conversations/$conversationId/${block ? 'block' : 'unblock'}';

  static String commentById(String commentId) => '/comments/$commentId';
  static String reportById(String reportId) => '/reports/$reportId';

  static String adminReviewAction(
          String targetType, String targetId, String action) =>
      '/admin/reviews/$targetType/$targetId/$action';

  static String adminReportHandle(String reportId) =>
      '/admin/reports/$reportId/handle';

  static String adminImageReview(String uploadId) =>
      '/admin/images/$uploadId/review';

  static String adminUserAction(String userId) => '/admin/users/$userId/action';

  static String adminAccountCancellationHandle(String requestId) =>
      '/admin/account-cancellation-requests/$requestId/handle';

  static String adminChannelByName(String name) => '/admin/channels/$name';

  static String adminTagByName(String name) => '/admin/tags/$name';
}
