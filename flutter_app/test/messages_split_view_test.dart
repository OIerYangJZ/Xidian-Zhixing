import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/features/messages/chat_page.dart';
import 'package:xdu_treehole_web/features/messages/messages_controller.dart';
import 'package:xdu_treehole_web/features/messages/messages_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/models/conversation_item.dart';

void main() {
  final List<ConversationItem> conversations = <ConversationItem>[
    ConversationItem(
      id: 'c1',
      peerUserId: 'u1',
      name: '同学甲',
      avatarUrl: '',
      lastMessage: '在吗',
      timeText: '10:00',
    ),
    ConversationItem(
      id: 'c2',
      peerUserId: 'u2',
      name: '同学乙',
      avatarUrl: '',
      lastMessage: '收到',
      timeText: '09:00',
    ),
  ];

  Future<void> pumpMessages(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagesControllerProvider.overrideWith(
            (Ref ref) => _FixedMessagesController(ref, conversations),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: <Locale>[Locale('zh', 'CN'), Locale('en')],
          locale: Locale('zh', 'CN'),
          home: MessagesPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('wide layout opens a conversation beside the list', (
    WidgetTester tester,
  ) async {
    await pumpMessages(tester, 1200);

    expect(find.text('选择会话'), findsOneWidget);
    expect(find.byType(ChatPage), findsNothing);

    await tester.tap(find.text('同学甲'));
    await tester.pump();

    final Finder chat = find.byType(ChatPage);
    expect(chat, findsOneWidget);
    expect(tester.widget<ChatPage>(chat).embedded, isTrue);
    expect(tester.widget<ChatPage>(chat).conversation.id, 'c1');
    // The list stays on screen next to the chat.
    expect(find.text('同学乙'), findsOneWidget);

    await tester.tap(find.text('同学乙'));
    await tester.pump();
    expect(tester.widget<ChatPage>(find.byType(ChatPage)).conversation.id, 'c2');
  });

  testWidgets('narrow layout still pushes the chat as its own route', (
    WidgetTester tester,
  ) async {
    await pumpMessages(tester, 600);

    expect(find.text('选择会话'), findsNothing);

    await tester.tap(find.text('同学甲'));
    await tester.pumpAndSettle();

    final Finder chat = find.byType(ChatPage);
    expect(chat, findsOneWidget);
    expect(tester.widget<ChatPage>(chat).embedded, isFalse);
    // Pushed over the list, not beside it.
    expect(find.text('同学乙'), findsNothing);
  });
}

class _FixedMessagesController extends MessagesController {
  _FixedMessagesController(super.ref, List<ConversationItem> conversations) {
    state = MessagesState(conversations: conversations, loading: false);
  }

  @override
  Future<void> loadInitial() async {}

  @override
  Future<void> refresh() async {}
}
