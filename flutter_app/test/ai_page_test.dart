import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/ai/ai_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/repositories/ai_repository.dart';

const String _index = 'xiaodian_conversation_index';
const String _prefix = 'xiaodian_conversation_';

/// Answers each question with `答：<question> #<n>`, or throws [error].
class _FakeAi extends AiRepository {
  _FakeAi() : super(ApiClient());

  final List<String> asked = <String>[];
  Object? error;

  @override
  Future<AiChatResponse> sendMessage({
    required String content,
    required List<AiMessage> messages,
    String? requestId,
  }) async {
    asked.add(content);
    if (error != null) throw error!;
    return AiChatResponse(
      answer: '答：$content #${asked.length}',
      references: const <AiReference>[
        AiReference(type: '学校通知', title: '关于期末周延长开放时间的通知'),
      ],
    );
  }

  @override
  Future<void> cancelChat(String requestId) async {}
}

Future<_FakeAi> _pump(WidgetTester tester, Widget home, {Size? size}) async {
  if (size != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }
  final _FakeAi ai = _FakeAi();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [aiRepositoryProvider.overrideWithValue(ai)],
      child: MaterialApp(
        theme: AppTheme.designSystemFor(
          themeKey: 'zhushachi',
          brightness: Brightness.light,
        ),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
        locale: const Locale('zh', 'CN'),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ai;
}

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('ai-input')), text);
  await tester.tap(find.byKey(const Key('ai-send')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      _index: jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'id': 'c1',
          'title': '期末周图书馆',
          'preview': '23:00',
          'updatedAt': '9/24',
          'updatedAtMs': now,
        },
        // Saved before updatedAtMs existed.
        <String, Object>{
          'id': 'c2',
          'title': '一卡通补办',
          'preview': '…',
          'updatedAt': '9/20',
        },
      ]),
      '${_prefix}c1': jsonEncode(<Map<String, String>>[
        <String, String>{'role': 'user', 'content': '图书馆几点关门'},
        <String, String>{'role': 'assistant', 'content': '23:00'},
      ]),
      '${_prefix}c2': '[]',
    });
  });

  testWidgets('history groups by age and filters by search', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const AiPage());
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('更早'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('ai-history-search')), '一卡通');
    await tester.pump();
    expect(find.text('一卡通补办'), findsOneWidget);
    expect(find.text('期末周图书馆'), findsNothing);
  });

  testWidgets('wide screens open a chat beside the history', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const AiPage(), size: const Size(1280, 900));
    expect(find.byType(AiChatPage), findsOneWidget, reason: 'new chat pane');
    await tester.tap(find.text('期末周图书馆'));
    await tester.pumpAndSettle();
    expect(find.text('图书馆几点关门'), findsOneWidget);
    expect(find.byKey(const Key('ai-chat-rename')), findsOneWidget);
  });

  testWidgets('regenerate asks the last question again in place', (
    WidgetTester tester,
  ) async {
    final _FakeAi ai = await _pump(tester, const AiChatPage());
    await _ask(tester, '研讨间怎么预约');
    expect(find.text('答：研讨间怎么预约 #1'), findsOneWidget);
    expect(find.text('关于期末周延长开放时间的通知'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-regenerate')));
    await tester.pumpAndSettle();
    expect(ai.asked, <String>['研讨间怎么预约', '研讨间怎么预约']);
    expect(find.text('答：研讨间怎么预约 #1'), findsNothing);
    expect(find.text('答：研讨间怎么预约 #2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('研讨间怎么预约'),
      ),
      findsOneWidget,
      reason: 'the question is not duplicated',
    );
  });

  testWidgets('a 503 shows the not-configured banner and locks the input', (
    WidgetTester tester,
  ) async {
    final _FakeAi ai = await _pump(tester, const AiChatPage());
    ai.error = ApiException(message: '服务器尚未配置 AI 服务', statusCode: 503);
    await _ask(tester, '图书馆几点关门');

    expect(find.byKey(const Key('ai-unavailable')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('ai-input'))).enabled,
      isFalse,
    );

    ai.error = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-unavailable')), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(const Key('ai-input'))).enabled,
      isTrue,
    );
  });
}
