import 'package:flutter/widgets.dart';

/// The campus catalogue — group headings, service names and descriptions,
/// action button labels, map entries and schedule sources — is seeded
/// server-side in Chinese and returned verbatim by `/campus/*`. Translating it
/// here keeps the backend single-language while still giving the English
/// locale a campus tab that reads as English end to end.
///
/// Everything outside these tables is institutional or user content — a course
/// title, a teacher name, a service added after this table was written — and
/// passes through unchanged.

const Map<String, String> _groupNames = <String, String>{
  '学习事务': 'Academics',
  '校园生活': 'Campus life',
  '校务办理': 'Administration',
  '工具入口': 'Tools',
  '校园服务': 'Campus services',
};

/// Keyed by service slug, which is stable across seed edits; the Chinese name
/// is not.
const Map<String, String> _serviceNames = <String, String>{
  'classtable': 'Class schedule',
  'score': 'Grades',
  'exam': 'Exams',
  'experiment': 'Labs',
  'empty-classroom': 'Free classrooms',
  'attendance': 'Attendance',
  'sport': 'Physical education',
  'electricity': 'Dorm electricity',
  'dorm-water': 'Dorm water dispenser',
  'library': 'Library',
  'school-card': 'Campus card',
  'schoolnet': 'Campus network',
  'map': 'Campus map',
  'building-map': 'Building floor plans',
  'places': 'Campus places',
  'student-info': 'Term and housing info',
  'payment': 'Payments',
  'drinking-water': 'Water delivery',
  'repair': 'Facility repairs',
  'space-reservation': 'Space booking',
  'leave': 'Leave requests',
  'creative': 'Innovation contests',
  'physics-helper': 'Physics lab calculator',
  'mobile-portal': 'Mobile portal',
  'venue-reservation': 'Sports venue booking',
  'wecom': 'University WeCom',
  'official-miniprogram': 'University mini program',
  'service-hall': 'Other campus services',
  'remote-access': 'Off-campus access',
  'self-print': 'Self-service printing',
  'campus-email': 'Campus email',
  'genuine-software': 'Licensed software',
  'club-suggestion': 'Student clubs',
  'schedule-reminder': 'Schedule reminders',
};

const Map<String, String> _serviceDescriptions = <String, String>{
  'classtable':
      'Courses, exams and labs on a weekly calendar; open any date to see the '
      'whole day.',
  'score':
      'Term grades, course type, credits, letter grades and GPA summary.',
  'exam':
      'Scheduled exams and courses still awaiting a slot, opened in the '
      'calendar view.',
  'experiment':
      'Physics and other lab sessions with time, room, instructor, seat and '
      'grade fields.',
  'empty-classroom':
      'Filter free classrooms by campus, building and period — useful for '
      'study or an impromptu meeting.',
  'attendance':
      'Course attendance, check-in details, task points, assignments and exam '
      'progress.',
  'sport': 'PE courses, fitness test results, component scores and grades.',
  'electricity':
      'Dorm electricity balance, arrears and meter history, with a link to the '
      'university payment portal.',
  'dorm-water':
      'Sign in to the water dispenser service by phone and SMS code, manage '
      'devices and start or stop a fill.',
  'library':
      'Loans, renewals, catalogue search and seat availability on both '
      'campuses.',
  'school-card':
      'Campus card balance and transaction history, with room for a payment '
      'code.',
  'schoolnet':
      'Campus network plan, balance, data used, data remaining and online '
      'devices.',
  'map':
      'Opens the official XDU GIS navigation system, with an index of common '
      'south campus locations.',
  'building-map':
      'Floor, classroom, office and facility layouts for campus buildings.',
  'places':
      'Find the library, dining halls, service centre, print points and sports '
      'venues.',
  'student-info':
      'Current term, basic student details and housing address — the base data '
      'behind schedules, electricity and more.',
  'payment':
      'Open the university payment system for electricity and other campus '
      'charges.',
  'drinking-water': 'Open the university water delivery system.',
  'repair':
      'Open the facilities repair system to report dorm, building or network '
      'issues.',
  'space-reservation':
      'Open the booking system for library and other bookable campus spaces.',
  'leave': 'Open the university leave request and return system.',
  'creative':
      'Look up innovation and entrepreneurship contests, positions and '
      'registration details.',
  'physics-helper': 'Open the physics lab calculation helper.',
  'mobile-portal':
      'Open the XDU mobile portal to continue with services already online.',
  'venue-reservation':
      'Book sports venues, check available slots and review your bookings.',
  'wecom': 'Open services provided through the university WeCom workspace.',
  'official-miniprogram':
      'Jump to the official university mini program or the matching service '
      'page.',
  'service-hall':
      'Open the campus service hall for anything not listed here.',
  'remote-access':
      'Open the remote access service for reaching campus network resources '
      'from off campus.',
  'self-print':
      'Self-service printing and registrar services — transcripts, '
      'certificates and similar documents.',
  'campus-email':
      'Open the university mail service for student email and mail security '
      'issues.',
  'genuine-software':
      'Open the licensed software service to see what is available and how to '
      'request it.',
  'club-suggestion':
      'Browse student clubs, read the details and submit an application.',
  'schedule-reminder':
      'Today and this week at a glance, ahead of full class, exam and lab '
      'reminders synced to your calendar.',
};

/// Action buttons are seeded as free-form labels rather than typed keys, so the
/// Chinese literal is the only stable key available.
const Map<String, String> _actionLabels = <String, String>{
  '查看周历': 'Open weekly view',
  '查看考试日历': 'Open exam calendar',
  '查看实验日历': 'Open lab calendar',
  '查看楼宇索引': 'Open building index',
  '打开一站式': 'Open the one-stop portal',
  '打开体育系统': 'Open the PE system',
  '打开双创平台': 'Open the innovation platform',
  '打开后勤报修': 'Open facility repairs',
  '打开图书馆': 'Open the library',
  '打开学校导航系统': 'Open campus navigation',
  '打开校园服务大厅': 'Open the service hall',
  '打开校园网自服务': 'Open campus network self-service',
  '打开校外访问': 'Open off-campus access',
  '打开正版软件平台': 'Open the licensed software platform',
  '打开物理计算': 'Open the physics calculator',
  '打开社团': 'Open student clubs',
  '打开移动门户': 'Open the mobile portal',
  '打开空间预约': 'Open space booking',
  '打开缴费系统': 'Open the payment system',
  '打开自助打印': 'Open self-service printing',
  '打开订水系统': 'Open water delivery',
  '打开请销假系统': 'Open leave requests',
  '打开邮箱服务': 'Open campus email',
  '物理实验系统': 'Physics lab system',
  '其他实验系统': 'Other lab systems',
};

const Map<String, String> _mapNames = <String, String>{
  '南校区常用地点': 'South campus landmarks',
  '楼宇结构图': 'Building floor plans',
};

const Map<String, String> _mapDescriptions = <String, String>{
  '图书馆、教学楼、食堂、体育馆等南校区常用地点索引。':
      'An index of the library, teaching buildings, dining halls and sports '
      'facilities on the south campus.',
  '楼层、教室、办公室与功能空间的结构化索引。':
      'A structured index of floors, classrooms, offices and facility spaces.',
};

/// `sourceLabel` on a schedule item — the feed it came from.
const Map<String, String> _scheduleSources = <String, String>{
  '课表': 'Class',
  '考试安排': 'Exam',
  '实验安排': 'Lab',
};

/// The half-day marker shown once per block in the class-schedule time column.
const Map<String, String> _dayPeriods = <String, String>{
  '上午': 'AM',
  '下午': 'PM',
  '晚上': 'EVE',
};

const Map<String, String> _weekdays = <String, String>{
  '一': 'Mon',
  '二': 'Tue',
  '三': 'Wed',
  '四': 'Thu',
  '五': 'Fri',
  '六': 'Sat',
  '日': 'Sun',
};

String _translate(Locale locale, Map<String, String> table, String value) {
  if (locale.languageCode != 'en') {
    return value;
  }
  return table[value.trim()] ?? value;
}

String localizedCampusGroup(Locale locale, String groupName) =>
    _translate(locale, _groupNames, groupName);

/// Falls back to the server name when the slug is unknown — a service added
/// after this table was written still renders, just in Chinese.
String localizedCampusServiceName(
  Locale locale, {
  required String slug,
  required String name,
}) {
  if (locale.languageCode != 'en') {
    return name;
  }
  return _serviceNames[slug.trim()] ?? name;
}

String localizedCampusServiceDescription(
  Locale locale, {
  required String slug,
  required String description,
}) {
  if (locale.languageCode != 'en') {
    return description;
  }
  return _serviceDescriptions[slug.trim()] ?? description;
}

String localizedCampusActionLabel(Locale locale, String label) =>
    _translate(locale, _actionLabels, label);

String localizedCampusMapName(Locale locale, String name) =>
    _translate(locale, _mapNames, name);

String localizedCampusMapDescription(Locale locale, String description) =>
    _translate(locale, _mapDescriptions, description);

String localizedDayPeriod(Locale locale, String period) =>
    _translate(locale, _dayPeriods, period);

String localizedScheduleSource(Locale locale, String sourceLabel) =>
    _translate(locale, _scheduleSources, sourceLabel);

/// Renders `周三` in Chinese and `Wed` in English — the prefix only belongs in
/// the Chinese form, so the whole label is built here.
String localizedWeekdayLabel(Locale locale, String weekday) {
  if (locale.languageCode != 'en') {
    return '周$weekday';
  }
  return _weekdays[weekday.trim()] ?? weekday;
}

/// The AI answer citations carry a Chinese `sourceType` from the server.
String localizedAiReferenceType(Locale locale, String type) {
  if (locale.languageCode != 'en') {
    return switch (type.trim()) {
      'knowledge' => '校园知识',
      'post' => '帖子',
      _ => type,
    };
  }
  switch (type.trim()) {
    case '帖子':
    case 'post':
      return 'Post';
    case '校园知识':
    case 'knowledge':
      return 'Campus knowledge';
    default:
      return type;
  }
}
