import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/core/navigation/post_link.dart';
import 'package:xdu_treehole_web/mobile/core/navigation/login_return.dart';

void main() {
  group('post link path', () {
    test('reads the post id from /p/<id>', () {
      expect(postIdFromLinkPath('/p/p12'), 'p12');
      expect(postIdFromLinkPath('/p/p12/'), 'p12');
      expect(postIdFromLinkPath('/p/abc_DEF-9'), 'abc_DEF-9');
    });

    test('ignores anything that is not exactly a post link', () {
      expect(postIdFromLinkPath('/'), isNull);
      expect(postIdFromLinkPath('/p/'), isNull);
      expect(postIdFromLinkPath('/p/p12/comments'), isNull);
      expect(postIdFromLinkPath('/px/p12'), isNull);
      expect(postIdFromLinkPath('/post/p12'), isNull);
      expect(postIdFromLinkPath('/p/../admin'), isNull);
    });

    test('builds a path the parser accepts', () {
      expect(postIdFromLinkPath(postLinkPath('p12')), 'p12');
    });
  });

  group('mobile login return', () {
    Uri login(String from) => Uri(
      path: '/auth/login',
      queryParameters: <String, String>{'from': from},
    );

    test('returns to the recorded in-app location', () {
      expect(loginReturnLocation(login('/p/p12')), '/p/p12');
      expect(
        loginReturnLocation(login('/post/p12?commentId=c3')),
        '/post/p12?commentId=c3',
      );
    });

    test('falls back to home for anything else', () {
      expect(loginReturnLocation(Uri.parse('/auth/login')), '/');
      expect(loginReturnLocation(login('https://evil.example/')), '/');
      expect(loginReturnLocation(login('//evil.example/')), '/');
      expect(loginReturnLocation(login('/auth/login')), '/');
    });
  });
}
