import '../core/network/api_client.dart';
import '../core/network/json_utils.dart';
import '../models/campus_models.dart';
import '../core/l10n/ui_text.dart';

class CampusRepository {
  CampusRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CampusService>> fetchServices() async {
    final dynamic response = await _apiClient.get('/campus/services');
    return extractList(response)
        .map((dynamic item) => CampusService.fromJson(asMap(item)))
        .where(
          (CampusService item) => item.id.isNotEmpty && item.name.isNotEmpty,
        )
        .toList();
  }

  Future<CampusService> fetchServiceDetail(String id) async {
    final dynamic response = await _apiClient.get('/campus/services/$id');
    final Map<String, dynamic> map = extractMap(response);
    if (map.isEmpty) {
      throw Exception(
        uiTextGlobal(zh: '服务不存在', en: 'This service does not exist'),
      );
    }
    return CampusService.fromJson(map);
  }

  Future<List<CampusMap>> fetchMaps() async {
    final dynamic response = await _apiClient.get('/campus/maps');
    return extractList(response)
        .map((dynamic item) => CampusMap.fromJson(asMap(item)))
        .where((CampusMap item) => item.id.isNotEmpty || item.name.isNotEmpty)
        .toList();
  }

  Future<CampusTodaySchedules> fetchTodaySchedules() async {
    final dynamic response = await _apiClient.get('/campus/schedules/today');
    return CampusTodaySchedules.fromJson(extractMap(response));
  }

  Future<CampusCalendar> fetchCalendar({
    String source = 'academic',
    String startDate = '',
    int days = 7,
  }) async {
    final dynamic response = await _apiClient.get(
      '/campus/schedules/calendar',
      queryParameters: <String, dynamic>{
        'source': source,
        if (startDate.isNotEmpty) 'startDate': startDate,
        'days': days,
      },
    );
    return CampusCalendar.fromJson(extractMap(response));
  }

  Future<CampusAuthResult> createSchoolnetCaptcha(String identifier) {
    return _postAuth('/campus/auth/schoolnet/captcha', <String, dynamic>{
      'identifier': identifier,
    });
  }

  Future<CampusAuthResult> loginSchoolnet({
    required String attemptId,
    required String identifier,
    required String password,
    required String captcha,
  }) {
    return _postAuth('/campus/auth/schoolnet/login', <String, dynamic>{
      'attemptId': attemptId,
      'identifier': identifier,
      'password': password,
      'captcha': captcha,
    });
  }

  Future<CampusAuthResult> createDormWaterCaptcha() {
    return _postAuth(
      '/campus/auth/dorm-water/captcha',
      const <String, dynamic>{},
    );
  }

  Future<void> sendDormWaterSms({
    required String sessionId,
    required String phone,
    required String imageCode,
  }) async {
    await _apiClient.post(
      '/campus/auth/dorm-water/sms',
      body: <String, dynamic>{
        'sessionId': sessionId,
        'phone': phone,
        'imageCode': imageCode,
      },
    );
  }

  Future<CampusAuthResult> loginDormWater({
    required String sessionId,
    required String phone,
    required String smsCode,
  }) {
    return _postAuth('/campus/auth/dorm-water/login', <String, dynamic>{
      'sessionId': sessionId,
      'phone': phone,
      'smsCode': smsCode,
    });
  }

  Future<CampusAuthResult> _postAuth(
    String path,
    Map<String, dynamic> body,
  ) async {
    final dynamic response = await _apiClient.post(path, body: body);
    return CampusAuthResult.fromJson(extractMap(response));
  }
}
