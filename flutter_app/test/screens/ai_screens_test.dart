import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/features/ai/ai_page.dart';
import 'package:xdu_treehole_web/repositories/ai_repository.dart';

import 'screen_capture.dart';

const String _index = 'xiaodian_conversation_index';
const String _prefix = 'xiaodian_conversation_';

/// Never answers, so the capture shows 小电正在查找资料…; or fails with 503.
class _ScreenAi extends AiRepository {
  _ScreenAi({this.unconfigured = false}) : super(ApiClient());

  final bool unconfigured;

  @override
  Future<AiChatResponse> sendMessage({
    required String content,
    required List<AiMessage> messages,
    String? requestId,
  }) {
    if (unconfigured) {
      return Future<AiChatResponse>.error(
        ApiException(message: '服务器尚未配置 AI 服务', statusCode: 503),
      );
    }
    return Completer<AiChatResponse>().future;
  }

  @override
  Future<void> cancelChat(String requestId) async {}
}

void _seed() {
  final DateTime now = DateTime.now();
  int ago(Duration d) => now.subtract(d).millisecondsSinceEpoch;
  Map<String, Object> row(String id, String title, int ms) => <String, Object>{
    'id': id,
    'title': title,
    'preview': '',
    'updatedAt': '',
    'updatedAtMs': ms,
  };
  SharedPreferences.setMockInitialValues(<String, Object>{
    _index: jsonEncode(<Object>[
      row('c1', '示例：期末周图书馆', ago(const Duration(minutes: 20))),
      row('c2', '示例：南校区哪里可以打印？', ago(const Duration(hours: 2))),
      row('c3', '示例：怎么申请缓考', ago(const Duration(days: 8))),
      row('c4', '示例：校园网报修流程', ago(const Duration(days: 9))),
    ]),
    '${_prefix}c1': jsonEncode(<Object>[
      <String, Object>{'role': 'user', 'content': '图书馆期末周开放到几点？周末也延长吗？'},
      <String, Object>{
        'role': 'assistant',
        'content':
            '根据图书馆发布的通知，期末周（示例：12-20 至 01-12）的开放时间调整为：\n'
            '· 周一至周五 07:30—23:00\n· 周六、周日 08:00—22:00\n\n'
            '四楼研讨间需要提前在预约系统预约，每次最多 2 小时。',
        'references': <Object>[
          <String, String>{'type': '学校通知', 'title': '示例：关于期末周延长开放时间的通知'},
          <String, String>{'type': '官网', 'title': '示例：研讨间预约规则'},
        ],
      },
    ]),
  });
}

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  for (final Brightness b in Brightness.values) {
    testWidgets('ai desktop ${b.name}', (WidgetTester tester) async {
      _seed();
      await captureScreen(
        tester,
        name: 'ai_desktop_${b.name}',
        home: const AiPage(),
        size: desktop,
        brightness: b,
        overrides: <Override>[
          aiRepositoryProvider.overrideWithValue(_ScreenAi()),
        ],
        beforeCapture: () async {
          await tester.tap(find.text('示例：期末周图书馆'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(const Key('ai-input')), '研讨间怎么预约？');
          await tester.tap(find.byKey(const Key('ai-send')));
          for (int i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        },
      );
    }, skip: !capturing);
  }

  testWidgets('ai history phone', (WidgetTester tester) async {
    _seed();
    await captureScreen(
      tester,
      name: 'ai_history_phone_light',
      home: const AiPage(),
      size: phone,
      overrides: <Override>[
        aiRepositoryProvider.overrideWithValue(_ScreenAi()),
      ],
    );
  }, skip: !capturing);

  testWidgets('ai chat phone dark', (WidgetTester tester) async {
    _seed();
    await captureScreen(
      tester,
      name: 'ai_chat_phone_dark',
      home: const AiChatPage(conversationId: 'c1'),
      size: phone,
      brightness: Brightness.dark,
      overrides: <Override>[
        aiRepositoryProvider.overrideWithValue(_ScreenAi()),
      ],
    );
  }, skip: !capturing);

  testWidgets('ai unconfigured phone', (WidgetTester tester) async {
    _seed();
    await captureScreen(
      tester,
      name: 'ai_unconfigured_phone_light',
      home: const AiChatPage(conversationId: 'c1'),
      size: phone,
      overrides: <Override>[
        aiRepositoryProvider.overrideWithValue(_ScreenAi(unconfigured: true)),
      ],
      beforeCapture: () async {
        await tester.enterText(find.byKey(const Key('ai-input')), '研讨间怎么预约？');
        await tester.tap(find.byKey(const Key('ai-send')));
        await tester.pumpAndSettle();
      },
    );
  }, skip: !capturing);

  testWidgets('ai welcome phone', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await captureScreen(
      tester,
      name: 'ai_welcome_phone_light',
      home: const AiChatPage(),
      size: phone,
      overrides: <Override>[
        aiRepositoryProvider.overrideWithValue(_ScreenAi()),
      ],
    );
  }, skip: !capturing);
}
