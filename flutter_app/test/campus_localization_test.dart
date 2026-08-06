import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xdu_treehole_web/core/l10n/campus_text.dart';

void main() {
  const Locale zh = Locale('zh', 'CN');
  const Locale en = Locale('en');

  /// Every slug seeded by `_seed_campus_services` in
  /// `backend/services/_db_service.py`. The catalogue arrives from the server
  /// in Chinese only, so a slug missing here is a service that silently renders
  /// Chinese inside the English UI.
  const List<String> seededSlugs = <String>[
    'classtable',
    'score',
    'exam',
    'experiment',
    'empty-classroom',
    'attendance',
    'sport',
    'electricity',
    'dorm-water',
    'library',
    'school-card',
    'schoolnet',
    'map',
    'building-map',
    'places',
    'student-info',
    'payment',
    'drinking-water',
    'repair',
    'space-reservation',
    'leave',
    'creative',
    'physics-helper',
    'mobile-portal',
    'venue-reservation',
    'wecom',
    'official-miniprogram',
    'service-hall',
    'remote-access',
    'self-print',
    'campus-email',
    'genuine-software',
    'club-suggestion',
    'schedule-reminder',
  ];

  final RegExp han = RegExp(r'[一-鿿]');

  group('campus catalogue translation', () {
    test('every seeded service has an English name and description', () {
      for (final String slug in seededSlugs) {
        final String name = localizedCampusServiceName(
          en,
          slug: slug,
          name: '未翻译',
        );
        final String description = localizedCampusServiceDescription(
          en,
          slug: slug,
          description: '未翻译',
        );

        expect(name, isNot(matches(han)), reason: 'name for slug "$slug"');
        expect(
          description,
          isNot(matches(han)),
          reason: 'description for slug "$slug"',
        );
      }
    });

    test('every seeded action label has an English form', () {
      const List<String> labels = <String>[
        '查看周历',
        '查看考试日历',
        '查看实验日历',
        '查看楼宇索引',
        '打开一站式',
        '打开体育系统',
        '打开双创平台',
        '打开后勤报修',
        '打开图书馆',
        '打开学校导航系统',
        '打开校园服务大厅',
        '打开校园网自服务',
        '打开校外访问',
        '打开正版软件平台',
        '打开物理计算',
        '打开社团',
        '打开移动门户',
        '打开空间预约',
        '打开缴费系统',
        '打开自助打印',
        '打开订水系统',
        '打开请销假系统',
        '打开邮箱服务',
        '物理实验系统',
        '其他实验系统',
      ];

      for (final String label in labels) {
        expect(
          localizedCampusActionLabel(en, label),
          isNot(matches(han)),
          reason: 'action label "$label"',
        );
      }
    });

    test('group headings and schedule sources translate', () {
      for (final String group in <String>[
        '学习事务',
        '校园生活',
        '校务办理',
        '工具入口',
        '校园服务',
      ]) {
        expect(localizedCampusGroup(en, group), isNot(matches(han)));
      }
      for (final String source in <String>['课表', '考试安排', '实验安排']) {
        expect(localizedScheduleSource(en, source), isNot(matches(han)));
      }
      for (final String period in <String>['上午', '下午', '晚上']) {
        expect(localizedDayPeriod(en, period), isNot(matches(han)));
      }
    });

    test('weekday drops the 周 prefix in English', () {
      expect(localizedWeekdayLabel(zh, '三'), '周三');
      expect(localizedWeekdayLabel(en, '三'), 'Wed');
      expect(localizedWeekdayLabel(en, '日'), 'Sun');
    });

    test('AI citation types translate', () {
      expect(localizedAiReferenceType(zh, '帖子'), '帖子');
      expect(localizedAiReferenceType(en, '帖子'), 'Post');
      expect(localizedAiReferenceType(en, '校园知识'), 'Campus knowledge');
    });

    test('Chinese locale is left untouched', () {
      expect(
        localizedCampusServiceName(zh, slug: 'classtable', name: '课表'),
        '课表',
      );
      expect(localizedCampusGroup(zh, '学习事务'), '学习事务');
      expect(localizedCampusActionLabel(zh, '查看周历'), '查看周历');
    });

    test('a service added after this table falls back to the server text', () {
      expect(
        localizedCampusServiceName(en, slug: 'brand-new', name: '新服务'),
        '新服务',
      );
      expect(localizedCampusActionLabel(en, '打开新系统'), '打开新系统');
    });
  });
}
