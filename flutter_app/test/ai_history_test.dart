import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/features/ai/ai_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';

const String _index = 'xiaodian_conversation_index';
const String _prefix = 'xiaodian_conversation_';

Widget _app() => const ProviderScope(
  child: MaterialApp(
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: <Locale>[Locale('zh', 'CN'), Locale('en')],
    locale: Locale('zh', 'CN'),
    home: AiPage(),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _index: jsonEncode(<Map<String, String>>[
        <String, String>{'id': 'c1', 'title': '图书馆几点关门', 'preview': '23:00', 'updatedAt': '9/24'},
        <String, String>{'id': 'c2', 'title': '怎么申请缓考', 'preview': '…', 'updatedAt': '9/23'},
      ]),
      '${_prefix}c1': '[]',
      '${_prefix}c2': '[]',
    });
  });

  testWidgets('a chat can be renamed, and keeps that name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-conversation-menu-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '期末周图书馆');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('期末周图书馆'), findsOneWidget);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<dynamic> rows = jsonDecode(prefs.getString(_index)!) as List<dynamic>;
    expect(rows.first['title'], '期末周图书馆');
    expect(rows.first['renamed'], isTrue);
  });

  testWidgets('deleting a chat removes its messages too', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-conversation-menu-c2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('怎么申请缓考'), findsNothing);
    expect(find.text('图书馆几点关门'), findsOneWidget);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('${_prefix}c2'), isFalse);
    expect(prefs.containsKey('${_prefix}c1'), isTrue);
  });
}
