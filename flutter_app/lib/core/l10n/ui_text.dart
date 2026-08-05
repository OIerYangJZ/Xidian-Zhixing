import 'package:flutter/widgets.dart';

String uiText(BuildContext context, {required String zh, required String en}) {
  return Localizations.localeOf(context).languageCode == 'en' ? en : zh;
}
