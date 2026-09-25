import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/features/campus/campus_page.dart';

import 'package:xdu_treehole_web/features/campus/campus_auth_center_page.dart';
import 'package:xdu_treehole_web/features/campus/campus_service_detail_page.dart';

import 'screen_capture.dart';

String _two(int v) => v.toString().padLeft(2, '0');
String _iso(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

Map<String, Object> _row(
  String id,
  String source,
  String title,
  DateTime date,
  String start,
  String end,
  String location, {
  String seat = '',
}) => <String, Object>{
  'id': id,
  'source': source,
  'sourceLabel': switch (source) {
    'examSchedules' => '考试安排',
    'experimentSchedules' => '实验安排',
    _ => '课表',
  },
  'title': title,
  'date': _iso(date),
  'startTime': start,
  'endTime': end,
  'location': location,
  'seatNo': seat,
};

Map<String, Object> _service(
  String slug,
  String name, {
  bool external = false,
}) => <String, Object>{
  'id': slug,
  'slug': slug,
  'name': name,
  'groupId': external ? 'quick' : 'study',
  'kind': external ? 'external' : 'internal',
  'actions': <Object>[
    <String, Object>{
      'label': '打开',
      'type': external ? 'external' : 'detail',
      'url': external ? 'https://example.edu.cn' : '',
    },
  ],
};

/// Answers the campus endpoints; the calendar depends on its `source`.
http.Client campusClient() {
  final DateTime now = DateTime.now();
  final DateTime monday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  DateTime day(int i) => monday.add(Duration(days: i));
  final List<Map<String, Object>> week = <Map<String, Object>>[
    _row('c1', 'courseSchedules', '高等数学', day(0), '08:30', '10:05', 'A-201'),
    _row('c2', 'courseSchedules', '大学物理', day(0), '10:25', '12:00', 'B-305'),
    _row('c3', 'courseSchedules', '大学英语', day(1), '10:25', '12:00', 'C-105'),
    _row('c4', 'courseSchedules', '电路分析', day(1), '14:00', '15:35', 'B-210'),
    _row('c5', 'courseSchedules', '高等数学', day(2), '08:30', '10:05', 'A-201'),
    _row('c6', 'courseSchedules', '物理实验', day(2), '14:00', '15:35', '实验中心'),
    _row('c7', 'courseSchedules', '大学物理', day(3), '10:25', '12:00', 'B-305'),
    _row('c8', 'courseSchedules', '影视鉴赏', day(3), '15:55', '17:30', 'D-101'),
    _row('c9', 'courseSchedules', '大学英语', day(4), '08:30', '10:05', 'C-105'),
    _row('c10', 'courseSchedules', '程序设计', day(1), '19:00', '20:35', '机房 3'),
  ];
  final List<Map<String, Object>> exams = <Map<String, Object>>[
    _row(
      'e1',
      'examSchedules',
      '示例：大学物理（期中）',
      now.add(const Duration(days: 12)),
      '14:00',
      '16:00',
      'B-305',
      seat: '27',
    ),
    _row(
      'e2',
      'examSchedules',
      '示例：高等数学（期中）',
      now.add(const Duration(days: 25)),
      '09:00',
      '11:00',
      'A-201',
    ),
  ];
  Map<String, Object> calendar(
    DateTime start,
    int days,
    List<Map<String, Object>> rows,
  ) => <String, Object>{
    'startDate': _iso(start),
    'endDate': _iso(start.add(Duration(days: days - 1))),
    'days': <Object>[
      for (int i = 0; i < days; i++)
        <String, Object>{
          'date': _iso(start.add(Duration(days: i))),
          'weekday': '一二三四五六日'[start.add(Duration(days: i)).weekday - 1],
          'isToday': _iso(start.add(Duration(days: i))) == _iso(now),
          'items': rows
              .where(
                (Map<String, Object> r) =>
                    r['date'] == _iso(start.add(Duration(days: i))),
              )
              .toList(),
        },
    ],
  };

  return MockClient((http.Request request) async {
    final String path = request.url.path.replaceFirst('/api', '');
    final Map<String, String> q = request.url.queryParameters;
    Object body = <String, Object>{};
    if (path == '/campus/services') {
      body = <Object>[
        _service('library', '图书馆', external: true),
        _service('schoolnet', '校园网', external: true),
        _service('experiment', '实验预约'),
        _service('card', '一卡通', external: true),
        _service('classroom', '空教室'),
        _service('campus-email', '校园邮箱', external: true),
        _service('guide', '办事指南', external: true),
        _service('exam', '考试安排'),
      ];
    } else if (path.startsWith('/campus/services/')) {
      final String id = path.split('/').last;
      body = id == 'exam'
          ? <String, Object>{
              ..._service('exam', '考试安排'),
              'kind': 'schedule',
              'calendarSource': 'exam',
              'description': '示例：本学期的考试时间与考场。',
            }
          : <String, Object>{
              ..._service(id, '空教室'),
              'description': '示例：按楼宇和节次查询空闲教室。',
            };
    } else if (path == '/campus/schedules/today') {
      body = <String, Object>{
        'date': _iso(now),
        'items': <Object>[
          <String, Object>{
            ..._row(
              't1',
              'courseSchedules',
              '示例：高等数学',
              now,
              '08:30',
              '10:05',
              '教学楼 A-201',
            ),
            'isActive': true,
          },
          _row(
            't2',
            'experimentSchedules',
            '示例：大学物理实验',
            now,
            '14:00',
            '15:35',
            '物理实验中心',
          ),
        ],
      };
    } else if (path == '/campus/schedules/calendar') {
      final DateTime start = DateTime.parse(q['startDate'] ?? _iso(monday));
      final int days = int.tryParse(q['days'] ?? '7') ?? 7;
      body = calendar(
        start,
        days,
        q['source'] == 'examSchedules' ? exams : week,
      );
    } else if (path == '/campus/maps') {
      body = <Object>[
        <String, Object>{
          'id': 'south',
          'name': '南校区地图',
          'description': '教学楼、食堂、快递点',
          'sourceUrl': 'https://gis.xidian.edu.cn',
        },
        <String, Object>{
          'id': 'north',
          'name': '北校区地图',
          'description': '',
          'sourceUrl': 'https://gis.xidian.edu.cn',
        },
      ];
    }
    return http.Response(
      jsonEncode(<String, Object>{'data': body}),
      200,
      headers: const <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );
  });
}

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  final http.Client client = campusClient();

  for (final (String name, Size size, Brightness b)
      in <(String, Size, Brightness)>[
        ('desktop_light', const Size(1440, 1120), Brightness.light),
        ('desktop_dark', const Size(1440, 1120), Brightness.dark),
        ('tablet_light', tablet, Brightness.light),
        ('phone_light', const Size(390, 1900), Brightness.light),
      ]) {
    testWidgets('campus $name', (WidgetTester tester) async {
      await http.runWithClient(
        () => captureScreen(
          tester,
          name: 'campus_$name',
          home: const Scaffold(body: CampusPage()),
          size: size,
          brightness: b,
        ),
        () => client,
      );
    }, skip: !capturing);
  }

  for (final (String name, Widget page) in <(String, Widget)>[
    ('auth_center', const CampusAuthCenterPage()),
    ('service_exam', const CampusServiceDetailPage(serviceId: 'exam')),
    (
      'service_classroom',
      const CampusServiceDetailPage(serviceId: 'classroom'),
    ),
  ]) {
    for (final Brightness b in Brightness.values) {
      testWidgets('campus $name ${b.name}', (WidgetTester tester) async {
        await http.runWithClient(
          () => captureScreen(
            tester,
            name: 'campus_${name}_${b.name}',
            home: page,
            size: phone,
            brightness: b,
          ),
          () => client,
        );
      }, skip: !capturing);
    }
  }
}
