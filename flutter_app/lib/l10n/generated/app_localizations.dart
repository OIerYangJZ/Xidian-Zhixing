import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'西电知行'**
  String get appTitle;

  /// No description provided for @brandShort.
  ///
  /// In zh, this message translates to:
  /// **'知行'**
  String get brandShort;

  /// No description provided for @tagline.
  ///
  /// In zh, this message translates to:
  /// **'让校园里的真实声音被听见'**
  String get tagline;

  /// No description provided for @taglineSupporting.
  ///
  /// In zh, this message translates to:
  /// **'一个为西电同学准备的克制、真诚、可持续讨论的校园社区。'**
  String get taglineSupporting;

  /// No description provided for @home.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get home;

  /// No description provided for @treehole.
  ///
  /// In zh, this message translates to:
  /// **'树洞'**
  String get treehole;

  /// No description provided for @treeholeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'校园里的声音'**
  String get treeholeSubtitle;

  /// No description provided for @campus.
  ///
  /// In zh, this message translates to:
  /// **'校园'**
  String get campus;

  /// No description provided for @campusSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'服务、日程、地图'**
  String get campusSubtitle;

  /// No description provided for @campusAi.
  ///
  /// In zh, this message translates to:
  /// **'校园 AI'**
  String get campusAi;

  /// No description provided for @campusAiSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'学习与校园问答'**
  String get campusAiSubtitle;

  /// No description provided for @messages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messages;

  /// No description provided for @profile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get profile;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @loginTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录西电知行'**
  String get loginTitle;

  /// No description provided for @welcomeBack.
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来'**
  String get welcomeBack;

  /// No description provided for @loginDescription.
  ///
  /// In zh, this message translates to:
  /// **'前往西电官方统一身份认证页面完成登录。'**
  String get loginDescription;

  /// No description provided for @loggingIn.
  ///
  /// In zh, this message translates to:
  /// **'等待官方认证'**
  String get loggingIn;

  /// No description provided for @betaAccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'账号登录时，学号和密码仅在西电官方页面输入，西电知行不会接触或保存统一认证密码。首次认证成功后自动创建账号；当前仅开放白名单学号。'**
  String get betaAccessMessage;

  /// No description provided for @adminLogin.
  ///
  /// In zh, this message translates to:
  /// **'管理员后台登录'**
  String get adminLogin;

  /// No description provided for @agreements.
  ///
  /// In zh, this message translates to:
  /// **'用户协议 · 隐私政策 · 社区规范'**
  String get agreements;

  /// No description provided for @loginFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录失败：{error}'**
  String loginFailed(String error);

  /// No description provided for @loginButton.
  ///
  /// In zh, this message translates to:
  /// **'前往西电官方认证'**
  String get loginButton;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSettings.
  ///
  /// In zh, this message translates to:
  /// **'语言设置'**
  String get languageSettings;

  /// No description provided for @simplifiedChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// No description provided for @traditionalChinese.
  ///
  /// In zh, this message translates to:
  /// **'繁体中文'**
  String get traditionalChinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @createPost.
  ///
  /// In zh, this message translates to:
  /// **'发帖'**
  String get createPost;

  /// No description provided for @publishVoice.
  ///
  /// In zh, this message translates to:
  /// **'发布心声'**
  String get publishVoice;

  /// No description provided for @published.
  ///
  /// In zh, this message translates to:
  /// **'帖子已发布'**
  String get published;

  /// No description provided for @latest.
  ///
  /// In zh, this message translates to:
  /// **'最新'**
  String get latest;

  /// No description provided for @popular.
  ///
  /// In zh, this message translates to:
  /// **'热度'**
  String get popular;

  /// No description provided for @allChannels.
  ///
  /// In zh, this message translates to:
  /// **'全部分区'**
  String get allChannels;

  /// No description provided for @filterChannels.
  ///
  /// In zh, this message translates to:
  /// **'筛选分区'**
  String get filterChannels;

  /// No description provided for @filter.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get filter;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @notifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get notifications;

  /// No description provided for @personalCenter.
  ///
  /// In zh, this message translates to:
  /// **'个人中心'**
  String get personalCenter;

  /// No description provided for @profileAndSettings.
  ///
  /// In zh, this message translates to:
  /// **'个人资料与设置'**
  String get profileAndSettings;

  /// No description provided for @conversations.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get conversations;

  /// No description provided for @readFirst.
  ///
  /// In zh, this message translates to:
  /// **'阅读优先'**
  String get readFirst;

  /// No description provided for @readFirstDescription.
  ///
  /// In zh, this message translates to:
  /// **'克制的正文宽度与清晰的信息层级'**
  String get readFirstDescription;

  /// No description provided for @crossScreen.
  ///
  /// In zh, this message translates to:
  /// **'跨屏可用'**
  String get crossScreen;

  /// No description provided for @crossScreenDescription.
  ///
  /// In zh, this message translates to:
  /// **'适配电脑、平板与手机浏览器'**
  String get crossScreenDescription;

  /// No description provided for @postDetail.
  ///
  /// In zh, this message translates to:
  /// **'帖子详情'**
  String get postDetail;

  /// No description provided for @comments.
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get comments;

  /// No description provided for @reply.
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get reply;

  /// No description provided for @send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get send;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// No description provided for @report.
  ///
  /// In zh, this message translates to:
  /// **'举报'**
  String get report;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @loadMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多'**
  String get loadMore;

  /// No description provided for @noMoreData.
  ///
  /// In zh, this message translates to:
  /// **'没有更多了'**
  String get noMoreData;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络错误'**
  String get networkError;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @userProfile.
  ///
  /// In zh, this message translates to:
  /// **'用户资料'**
  String get userProfile;

  /// No description provided for @myPosts.
  ///
  /// In zh, this message translates to:
  /// **'我的帖子'**
  String get myPosts;

  /// No description provided for @myComments.
  ///
  /// In zh, this message translates to:
  /// **'我的评论'**
  String get myComments;

  /// No description provided for @chatWith.
  ///
  /// In zh, this message translates to:
  /// **'与 {name} 聊天'**
  String chatWith(Object name);

  /// No description provided for @sendMessage.
  ///
  /// In zh, this message translates to:
  /// **'发送消息'**
  String get sendMessage;

  /// No description provided for @noMessages.
  ///
  /// In zh, this message translates to:
  /// **'暂无消息'**
  String get noMessages;

  /// No description provided for @imageGallery.
  ///
  /// In zh, this message translates to:
  /// **'图片浏览'**
  String get imageGallery;

  /// No description provided for @selectImages.
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get selectImages;

  /// No description provided for @postContent.
  ///
  /// In zh, this message translates to:
  /// **'帖子内容'**
  String get postContent;

  /// No description provided for @commentPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'说点什么...'**
  String get commentPlaceholder;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
