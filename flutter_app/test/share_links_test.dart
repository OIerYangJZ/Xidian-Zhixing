import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/core/navigation/share_links.dart';
import 'package:xdu_treehole_web/mobile/core/navigation/login_return.dart';

void main() {
  group('share link path', () {
    test('reads posts from /p/<id> and profiles from /u/<id>', () {
      expect(ShareLink.parsePath('/p/p12'), const ShareLink.post('p12'));
      expect(ShareLink.parsePath('/p/p12/'), const ShareLink.post('p12'));
      expect(ShareLink.parsePath('/u/u_7'), const ShareLink.user('u_7'));
      expect(ShareLink.parsePath('/p/abc_DEF-9')!.id, 'abc_DEF-9');
    });

    test('ignores anything that is not exactly a share link', () {
      for (final String path in <String>[
        '/',
        '/p/',
        '/u/',
        '/p/p12/comments',
        '/px/p12',
        '/post/p12',
        '/user/u1',
        '/p/../admin',
        '/x/u1',
      ]) {
        expect(ShareLink.parsePath(path), isNull, reason: path);
      }
    });

    test('builds paths the parser accepts', () {
      for (final ShareLink link in const <ShareLink>[
        ShareLink.post('p12'),
        ShareLink.user('u7'),
      ]) {
        expect(ShareLink.parsePath(link.path), link);
      }
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
