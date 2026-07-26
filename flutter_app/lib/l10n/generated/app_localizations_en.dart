// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Xidian Zhixing';

  @override
  String get brandShort => 'Zhixing';

  @override
  String get tagline => 'Let authentic campus voices be heard';

  @override
  String get taglineSupporting =>
      'A calm and sincere campus community for lasting conversations at Xidian.';

  @override
  String get home => 'Home';

  @override
  String get treehole => 'Treehole';

  @override
  String get treeholeSubtitle => 'Voices from campus';

  @override
  String get campus => 'Campus';

  @override
  String get campusSubtitle => 'Services, calendar, maps';

  @override
  String get campusAi => 'Campus AI';

  @override
  String get campusAiSubtitle => 'Study and campus questions';

  @override
  String get messages => 'Messages';

  @override
  String get profile => 'Profile';

  @override
  String get login => 'Login';

  @override
  String get loginTitle => 'Login to Xidian Zhixing';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get loginDescription =>
      'Sign in with your student ID or campus email.';

  @override
  String get studentIdentifier => 'Student ID or email';

  @override
  String get studentIdentifierHint => '2023123456 or student email';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get loggingIn => 'Signing in';

  @override
  String get registerAccount => 'Create account';

  @override
  String get forgotPassword => 'Forgot password';

  @override
  String get adminLogin => 'Admin sign in';

  @override
  String get agreements => 'Terms of service';

  @override
  String get identifierRequired => 'Enter your student ID or email.';

  @override
  String get passwordRequired => 'Enter your password.';

  @override
  String get loginResultError =>
      'The sign-in response was incomplete. Please try again.';

  @override
  String loginFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get loginButton => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSettings => 'Language Settings';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get english => 'English';

  @override
  String get followSystem => 'Follow System';

  @override
  String get createPost => 'Create Post';

  @override
  String get publishVoice => 'Share a voice';

  @override
  String get published => 'Post published';

  @override
  String get latest => 'Latest';

  @override
  String get popular => 'Popular';

  @override
  String get allChannels => 'All channels';

  @override
  String get filterChannels => 'Filter channels';

  @override
  String get filter => 'Filter';

  @override
  String get search => 'Search';

  @override
  String get notifications => 'Notifications';

  @override
  String get personalCenter => 'Profile';

  @override
  String get profileAndSettings => 'Profile and settings';

  @override
  String get conversations => 'Conversations';

  @override
  String get readFirst => 'Reading first';

  @override
  String get readFirstDescription =>
      'A measured line length and a clear information hierarchy';

  @override
  String get crossScreen => 'Across screens';

  @override
  String get crossScreenDescription =>
      'Designed for desktop, tablet, and mobile browsers';

  @override
  String get postDetail => 'Post Detail';

  @override
  String get comments => 'Comments';

  @override
  String get reply => 'Reply';

  @override
  String get send => 'Send';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get share => 'Share';

  @override
  String get report => 'Report';

  @override
  String get loading => 'Loading...';

  @override
  String get loadMore => 'Load More';

  @override
  String get noMoreData => 'No More Data';

  @override
  String get networkError => 'Network Error';

  @override
  String get retry => 'Retry';

  @override
  String get userProfile => 'User Profile';

  @override
  String get myPosts => 'My Posts';

  @override
  String get myComments => 'My Comments';

  @override
  String chatWith(Object name) {
    return 'Chat with $name';
  }

  @override
  String get sendMessage => 'Send Message';

  @override
  String get noMessages => 'No Messages';

  @override
  String get imageGallery => 'Image Gallery';

  @override
  String get selectImages => 'Select Images';

  @override
  String get postContent => 'Post Content';

  @override
  String get commentPlaceholder => 'Say something...';
}
