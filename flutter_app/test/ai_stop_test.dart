import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/features/ai/ai_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/repositories/ai_repository.dart';

class _PendingAi extends AiRepository {
  _PendingAi() : super(ApiClient());

  final Completer<AiChatResponse> answer = Completer<AiChatResponse>();
  String? sentRequestId;
  final List<String> cancelled = <String>[];

  @override
  Future<AiChatResponse> sendMessage({
    required String content,
    required List<AiMessage> messages,
    String? requestId,
  }) {
    sentRequestId = requestId;
    return answer.future;
  }

  @override
  Future<void> cancelChat(String requestId) async {
    cancelled.add(requestId);
  }
}

void main() {
  testWidgets('停止 cancels the same request on the server and drops its answer', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final _PendingAi ai = _PendingAi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiRepositoryProvider.overrideWithValue(ai)],
        child: const MaterialApp(
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: <Locale>[Locale('zh', 'CN'), Locale('en')],
          locale: Locale('zh', 'CN'),
          home: AiChatPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '图书馆几点关门？');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();

    expect(ai.sentRequestId, isNotNull);
    expect(find.byTooltip('停止'), findsOneWidget);

    await tester.tap(find.byTooltip('停止'));
    await tester.pump();

    expect(ai.cancelled, <String>[ai.sentRequestId!]);
    expect(find.byTooltip('发送'), findsOneWidget, reason: 'input is free again');

    // The server answers the cancelled request with 409; nothing surfaces.
    ai.answer.completeError(
      ApiException(message: '已停止生成', statusCode: 409),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
