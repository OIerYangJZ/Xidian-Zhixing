// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '西电知行';

  @override
  String get brandShort => '知行';

  @override
  String get tagline => '让校园里的真实声音被听见';

  @override
  String get taglineSupporting => '一个为西电同学准备的克制、真诚、可持续讨论的校园社区。';

  @override
  String get home => '首页';

  @override
  String get treehole => '树洞';

  @override
  String get treeholeSubtitle => '校园里的声音';

  @override
  String get campus => '校园';

  @override
  String get campusSubtitle => '服务、日程、地图';

  @override
  String get campusAi => '校园 AI';

  @override
  String get campusAiSubtitle => '学习与校园问答';

  @override
  String get messages => '消息';

  @override
  String get profile => '我的';

  @override
  String get login => '登录';

  @override
  String get loginTitle => '登录西电知行';

  @override
  String get welcomeBack => '欢迎回来';

  @override
  String get loginDescription => '使用学号或学生邮箱登录。';

  @override
  String get studentIdentifier => '学号或学生邮箱';

  @override
  String get studentIdentifierHint => '2023123456 或学生邮箱';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get loggingIn => '正在登录';

  @override
  String get registerAccount => '注册账号';

  @override
  String get forgotPassword => '忘记密码';

  @override
  String get adminLogin => '管理员后台登录';

  @override
  String get agreements => '用户协议';

  @override
  String get identifierRequired => '请输入学号或学生邮箱。';

  @override
  String get passwordRequired => '请输入密码。';

  @override
  String get loginResultError => '登录结果异常，请稍后重试。';

  @override
  String loginFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get loginButton => '登录';

  @override
  String get logout => '退出登录';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get languageSettings => '语言设置';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get traditionalChinese => '繁体中文';

  @override
  String get english => 'English';

  @override
  String get followSystem => '跟随系统';

  @override
  String get createPost => '发帖';

  @override
  String get publishVoice => '发布心声';

  @override
  String get published => '帖子已发布';

  @override
  String get latest => '最新';

  @override
  String get popular => '热度';

  @override
  String get allChannels => '全部分区';

  @override
  String get filterChannels => '筛选分区';

  @override
  String get filter => '筛选';

  @override
  String get search => '搜索';

  @override
  String get notifications => '通知';

  @override
  String get personalCenter => '个人中心';

  @override
  String get profileAndSettings => '个人资料与设置';

  @override
  String get conversations => '会话';

  @override
  String get readFirst => '阅读优先';

  @override
  String get readFirstDescription => '克制的正文宽度与清晰的信息层级';

  @override
  String get crossScreen => '跨屏可用';

  @override
  String get crossScreenDescription => '适配电脑、平板与手机浏览器';

  @override
  String get postDetail => '帖子详情';

  @override
  String get comments => '评论';

  @override
  String get reply => '回复';

  @override
  String get send => '发送';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get share => '分享';

  @override
  String get report => '举报';

  @override
  String get loading => '加载中...';

  @override
  String get loadMore => '加载更多';

  @override
  String get noMoreData => '没有更多了';

  @override
  String get networkError => '网络错误';

  @override
  String get retry => '重试';

  @override
  String get userProfile => '用户资料';

  @override
  String get myPosts => '我的帖子';

  @override
  String get myComments => '我的评论';

  @override
  String chatWith(Object name) {
    return '与 $name 聊天';
  }

  @override
  String get sendMessage => '发送消息';

  @override
  String get noMessages => '暂无消息';

  @override
  String get imageGallery => '图片浏览';

  @override
  String get selectImages => '选择图片';

  @override
  String get postContent => '帖子内容';

  @override
  String get commentPlaceholder => '说点什么...';
}
