import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/core/navigation/share_links.dart';
import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/auth/banned_account_page.dart';
import 'package:xdu_treehole_web/features/post/post_unavailable_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import 'package:xdu_treehole_web/repositories/appeal_repository.dart';

class _FakeAppeals extends AppealRepository {
  _FakeAppeals(this.state) : super(ApiClient());

  AppealState state;
  final List<String> submitted = <String>[];

  @override
  Future<AppealState> fetchLatest() async => state;

  @override
  Future<void> submitUnbanAppeal({
    required String email,
    required String content,
  }) async {
    if (content.trim().isEmpty) {
      throw const FormatException('请填写申诉说明');
    }
    submitted.add(content.trim());
    state = AppealState.fromJson(<String, dynamic>{
      'banned': true,
      'canSubmit': false,
      'appeal': <String, dynamic>{'status': 'pending', 'content': content},
    });
  }
}

/// What GET /appeals/mine answers: [canSubmit] is the server's call, true
/// while banned with no pending appeal and this ban's appeal not turned down.
/// The form was open, but the server already counts this ban's appeal as
/// turned down (another device, say) and answers 409.
class _UsedUpAppeals extends _FakeAppeals {
  _UsedUpAppeals() : super(_state(''));

  @override
  Future<void> submitUnbanAppeal({
    required String email,
    required String content,
  }) async {
    state = _state('rejected');
    throw ApiException(
      message: '本次封禁的站内申诉已用完，请用本人校园邮箱发送至 support@example.edu.cn',
      statusCode: 409,
    );
  }
}

AppealState _state(String status, {bool banned = true, bool? canSubmit}) =>
    AppealState.fromJson(<String, dynamic>{
      'banned': banned,
      'canSubmit':
          canSubmit ??
          (banned &&
              !<String>{'pending', 'rejected', 'closed'}.contains(status)),
      'supportEmail': 'support@example.edu.cn',
      'appeal': <String, dynamic>{
        'status': status,
        'adminNote': status == 'rejected' ? '证据不足' : '',
      },
    });

Widget _app(Widget home, {List<Override> overrides = const <Override>[]}) =>
    ProviderScope(
      overrides: overrides,
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
    );

void main() {
  testWidgets('an appeal submits, then shows as pending', (
    WidgetTester tester,
  ) async {
    final _FakeAppeals appeals = _FakeAppeals(_state(''));
    // The appeal goes out under the signed-in campus address.
    AuthStore.instance.setCurrentUser(
      UserProfile.fromJson(<String, dynamic>{
        'email': '2500100@stu.xidian.edu.cn',
      }),
    );
    addTearDown(() => AuthStore.instance.setCurrentUser(null));
    await tester.pumpWidget(
      _app(
        const BannedAccountPage(),
        overrides: <Override>[
          appealRepositoryProvider.overrideWithValue(appeals),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('banned-appeal-form')), findsOneWidget);

    // An empty appeal is refused with the bare message.
    await tester.tap(find.byKey(const Key('banned-appeal-submit')));
    await tester.pumpAndSettle();
    expect(find.text('请填写申诉说明'), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('banned-appeal-input')),
      '我没有发过那条帖子',
    );
    await tester.tap(find.byKey(const Key('banned-appeal-submit')));
    await tester.pumpAndSettle();
    expect(appeals.submitted, <String>['我没有发过那条帖子']);
    expect(find.byKey(const Key('banned-pending')), findsOneWidget);
    expect(find.text('我没有发过那条帖子'), findsOneWidget);
    expect(find.byKey(const Key('banned-appeal-form')), findsNothing);
  });

  testWidgets('a rejected appeal leaves only the support email', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BannedAccountPage(),
        overrides: <Override>[
          appealRepositoryProvider.overrideWithValue(
            _FakeAppeals(_state('rejected')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('banned-email-only')), findsOneWidget);
    expect(find.text('support@example.edu.cn'), findsOneWidget);
    expect(find.textContaining('证据不足'), findsOneWidget);
    expect(find.byKey(const Key('banned-appeal-form')), findsNothing);
  });

  testWidgets('an appeal turned down during an earlier ban leaves the form', (
    WidgetTester tester,
  ) async {
    // The server's canSubmit, not the latest status, decides.
    await tester.pumpWidget(
      _app(
        const BannedAccountPage(),
        overrides: <Override>[
          appealRepositoryProvider.overrideWithValue(
            _FakeAppeals(_state('rejected', canSubmit: true)),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('banned-appeal-form')), findsOneWidget);
    expect(find.byKey(const Key('banned-email-only')), findsNothing);
  });

  testWidgets('a used-up appeal says why and turns to the mailbox', (
    WidgetTester tester,
  ) async {
    final _UsedUpAppeals appeals = _UsedUpAppeals();
    AuthStore.instance.setCurrentUser(
      UserProfile.fromJson(<String, dynamic>{
        'email': '2500100@stu.xidian.edu.cn',
      }),
    );
    addTearDown(() => AuthStore.instance.setCurrentUser(null));
    await tester.pumpWidget(
      _app(
        const BannedAccountPage(),
        overrides: <Override>[
          appealRepositoryProvider.overrideWithValue(appeals),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('banned-appeal-input')),
      '请再看一次',
    );
    await tester.tap(find.byKey(const Key('banned-appeal-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('本次封禁的站内申诉已用完'), findsOneWidget);
    expect(find.byKey(const Key('banned-email-only')), findsOneWidget);
    expect(find.byKey(const Key('banned-appeal-form')), findsNothing);
  });

  testWidgets('a lifted ban clears the local flag', (
    WidgetTester tester,
  ) async {
    AuthStore.instance.setBanned(true);
    addTearDown(() => AuthStore.instance.setBanned(false));
    await tester.pumpWidget(
      _app(
        const BannedAccountPage(),
        overrides: <Override>[
          appealRepositoryProvider.overrideWithValue(
            _FakeAppeals(_state('approved', banned: false)),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(AuthStore.instance.isBanned, isFalse);
  });

  testWidgets('the unavailable page names the link and goes back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const PostUnavailablePage(link: ShareLink.post('48213')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/p/48213'), findsOneWidget);

    await tester.tap(find.byKey(const Key('post-unavailable-back')));
    await tester.pumpAndSettle();
    expect(find.byType(PostUnavailablePage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
