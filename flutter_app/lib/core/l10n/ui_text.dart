import 'package:flutter/widgets.dart';

import '../state/app_locale_store.dart';

/// Resolves a bilingual literal against an explicit [locale].
///
/// Use this in layers that already carry a `Locale` — theme options, model
/// helpers invoked from a widget that has already looked the locale up.
String uiTextFor(Locale locale, {required String zh, required String en}) {
  return locale.languageCode == 'en' ? en : zh;
}

/// Resolves a bilingual literal against the locale of [context].
String uiText(BuildContext context, {required String zh, required String en}) {
  return uiTextFor(Localizations.localeOf(context), zh: zh, en: en);
}

/// Maps the server-rendered anonymous placeholders, which always arrive in
/// Chinese, onto the active locale. Real nicknames pass through untouched.
String localizedAlias(Locale locale, String alias) {
  if (alias == '匿名同学' || alias == '匿名用户') {
    return uiTextFor(locale, zh: alias, en: 'Anonymous');
  }
  return alias;
}

/// Maps the built-in channel sentinels onto the active locale. Channel names
/// created on the server are user content and pass through untouched.
String localizedChannel(Locale locale, String channel) {
  switch (channel) {
    case '全部':
      return uiTextFor(locale, zh: channel, en: 'All');
    case '未分类':
      return uiTextFor(locale, zh: channel, en: 'Uncategorized');
    case '其他':
      return uiTextFor(locale, zh: channel, en: 'Other');
    default:
      return channel;
  }
}

/// The app-wide locale, for code paths that run without a mounted
/// `BuildContext` — async callbacks, repositories, model parsing.
Locale get appLocale => AppLocaleStore.instance.locale;

/// Resolves a bilingual literal against the app-wide locale.
///
/// For layers without a `BuildContext` — the API client, repositories and
/// model parsing — whose messages still end up on screen.
String uiTextGlobal({required String zh, required String en}) {
  return uiTextFor(AppLocaleStore.instance.locale, zh: zh, en: en);
}
