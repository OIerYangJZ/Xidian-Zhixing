import '../core/network/json_utils.dart';

class CampusAction {
  const CampusAction({
    required this.label,
    required this.type,
    required this.url,
    required this.path,
    required this.payload,
  });

  final String label;
  final String type;
  final String url;
  final String path;
  final Map<String, dynamic> payload;

  factory CampusAction.fromJson(Map<String, dynamic> json) {
    return CampusAction(
      label: readString(json, <String>['label']) ?? '',
      type: readString(json, <String>['type']) ?? '',
      url: readString(json, <String>['url']) ?? '',
      path: readString(json, <String>['path']) ?? '',
      payload: asMap(json['payload']),
    );
  }
}

class CampusService {
  const CampusService({
    required this.id,
    required this.slug,
    required this.name,
    required this.groupId,
    required this.groupName,
    required this.kind,
    required this.iconKey,
    required this.authType,
    required this.description,
    required this.calendarSource,
    required this.actions,
    required this.maps,
  });

  final String id;
  final String slug;
  final String name;
  final String groupId;
  final String groupName;
  final String kind;
  final String iconKey;
  final String authType;
  final String description;
  final String calendarSource;
  final List<CampusAction> actions;
  final List<CampusMap> maps;

  bool get hasBusinessAction =>
      groupId != 'account' && actions.any((CampusAction action) => action.type != 'notice');

  factory CampusService.fromJson(Map<String, dynamic> json) {
    return CampusService(
      id: readString(json, <String>['id']) ?? '',
      slug: readString(json, <String>['slug']) ?? '',
      name: readString(json, <String>['name']) ?? '',
      groupId: readString(json, <String>['groupId']) ?? '',
      groupName: readString(json, <String>['groupName']) ?? '',
      kind: readString(json, <String>['kind']) ?? '',
      iconKey: readString(json, <String>['iconKey']) ?? '',
      authType: readString(json, <String>['authType']) ?? '',
      description: readString(json, <String>['description']) ?? '',
      calendarSource: readString(json, <String>['calendarSource']) ?? '',
      actions: asList(json['actions'])
          .map((dynamic item) => CampusAction.fromJson(asMap(item)))
          .where((CampusAction item) => item.label.isNotEmpty || item.type.isNotEmpty)
          .toList(),
      maps: asList(json['maps'])
          .map((dynamic item) => CampusMap.fromJson(asMap(item)))
          .where((CampusMap item) => item.id.isNotEmpty || item.name.isNotEmpty)
          .toList(),
    );
  }
}

class CampusMap {
  const CampusMap({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceUrl,
  });

  final String id;
  final String name;
  final String description;
  final String sourceUrl;

  factory CampusMap.fromJson(Map<String, dynamic> json) {
    return CampusMap(
      id: readString(json, <String>['id']) ?? '',
      name: readString(json, <String>['name']) ?? '',
      description: readString(json, <String>['description']) ?? '',
      sourceUrl: readString(json, <String>['sourceUrl', 'url']) ?? '',
    );
  }
}

class CampusScheduleItem {
  const CampusScheduleItem({
    required this.id,
    required this.source,
    required this.sourceLabel,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.date,
    required this.teacher,
    required this.section,
    required this.seatNo,
    required this.examType,
    required this.timeRange,
    this.isActive = false,
  });

  final String id;
  final String source;
  final String sourceLabel;
  final String title;
  final String startTime;
  final String endTime;
  final String location;
  final String date;
  final String teacher;
  final String section;
  final String seatNo;
  final String examType;
  final String timeRange;
  final bool isActive;

  bool get isExam => source == 'examSchedules';

  factory CampusScheduleItem.fromJson(Map<String, dynamic> json) {
    return CampusScheduleItem(
      id: readString(json, <String>['id']) ?? '',
      source: readString(json, <String>['source']) ?? '',
      sourceLabel: readString(json, <String>['sourceLabel']) ?? '',
      title: readString(json, <String>['title']) ?? '',
      startTime: readString(json, <String>['startTime']) ?? '',
      endTime: readString(json, <String>['endTime']) ?? '',
      location: readString(json, <String>['location']) ?? '',
      date: readString(json, <String>['date']) ?? '',
      teacher: readString(json, <String>['teacher']) ?? '',
      section: readString(json, <String>['section']) ?? '',
      seatNo: readString(json, <String>['seatNo']) ?? '',
      examType: readString(json, <String>['examType']) ?? '',
      timeRange: readString(json, <String>['timeRange']) ?? '',
      isActive: readBool(json, <String>['isActive']) ?? false,
    );
  }
}

class CampusTodaySchedules {
  const CampusTodaySchedules({
    required this.date,
    required this.items,
  });

  final String date;
  final List<CampusScheduleItem> items;

  factory CampusTodaySchedules.fromJson(Map<String, dynamic> json) {
    return CampusTodaySchedules(
      date: readString(json, <String>['date']) ?? '',
      items: asList(json['items'])
          .map((dynamic item) => CampusScheduleItem.fromJson(asMap(item)))
          .toList(),
    );
  }
}

class CampusCalendarDay {
  const CampusCalendarDay({
    required this.date,
    required this.weekday,
    required this.isToday,
    required this.items,
  });

  final String date;
  final String weekday;
  final bool isToday;
  final List<CampusScheduleItem> items;

  factory CampusCalendarDay.fromJson(Map<String, dynamic> json) {
    return CampusCalendarDay(
      date: readString(json, <String>['date']) ?? '',
      weekday: readString(json, <String>['weekday']) ?? '',
      isToday: readBool(json, <String>['isToday']) ?? false,
      items: asList(json['items'])
          .map((dynamic item) => CampusScheduleItem.fromJson(asMap(item)))
          .toList(),
    );
  }
}

class CampusCalendar {
  const CampusCalendar({
    required this.startDate,
    required this.endDate,
    required this.days,
  });

  final String startDate;
  final String endDate;
  final List<CampusCalendarDay> days;

  factory CampusCalendar.fromJson(Map<String, dynamic> json) {
    return CampusCalendar(
      startDate: readString(json, <String>['startDate']) ?? '',
      endDate: readString(json, <String>['endDate']) ?? '',
      days: asList(json['days'])
          .map((dynamic item) => CampusCalendarDay.fromJson(asMap(item)))
          .toList(),
    );
  }
}

class CampusAuthResult {
  const CampusAuthResult({
    required this.studentId,
    required this.campusEmail,
    required this.attemptId,
    required this.imageBase64,
    required this.imageContentType,
    required this.sessionId,
  });

  final String studentId;
  final String campusEmail;
  final String attemptId;
  final String imageBase64;
  final String imageContentType;
  final String sessionId;

  factory CampusAuthResult.fromJson(Map<String, dynamic> json) {
    return CampusAuthResult(
      studentId: readString(json, <String>['studentId']) ?? '',
      campusEmail: readString(json, <String>['campusEmail']) ?? '',
      attemptId: readString(json, <String>['attemptId']) ?? '',
      imageBase64: readString(json, <String>['imageBase64']) ?? '',
      imageContentType: readString(json, <String>['imageContentType']) ?? 'image/png',
      sessionId: readString(json, <String>['sessionId']) ?? '',
    );
  }
}
