import '../core/network/api_client.dart';
import '../core/network/json_utils.dart';
import '../models/announcement_item.dart';

class AnnouncementRepository {
  AnnouncementRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AnnouncementItem>> fetchAnnouncements({String type = ''}) async {
    final dynamic response = await _apiClient.get(
      '/announcements',
      queryParameters: <String, dynamic>{if (type.isNotEmpty) 'type': type},
    );
    return extractList(response)
        .map((dynamic item) => AnnouncementItem.fromJson(asMap(item)))
        .where((AnnouncementItem item) => item.id.isNotEmpty || item.title.isNotEmpty)
        .toList();
  }

  Future<AnnouncementItem> fetchAnnouncement(String id) async {
    final dynamic response = await _apiClient.get('/announcements/$id');
    final Map<String, dynamic> map = extractMap(response);
    if (map.isEmpty) {
      throw Exception('公告不存在');
    }
    return AnnouncementItem.fromJson(map);
  }

  Future<AnnouncementFilters> fetchFilters() async {
    final dynamic response = await _apiClient.get('/announcements/filters');
    return AnnouncementFilters.fromJson(extractMap(response));
  }

  Future<DailyAnnouncementSummary> fetchDailySummary() async {
    final dynamic response = await _apiClient.get('/announcements/daily-summary');
    return DailyAnnouncementSummary.fromJson(extractMap(response));
  }
}
