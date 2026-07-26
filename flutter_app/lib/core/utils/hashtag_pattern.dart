class AppHashtag {
  AppHashtag._();

  static const String expression = r'#[\w\u4e00-\u9fff-]+';
  static final RegExp pattern = RegExp(expression);
}
