import '../core/network/json_utils.dart';

/// A 分区 from `GET /api/sections/tree`: 综合 (general), a college, or a club.
///
/// Posts carry the section they were filed under (sectionType / sectionId /
/// sectionName); the feed filters on it. Channels are gone: the server keeps
/// them only as tags.
class SectionItem {
  const SectionItem({
    required this.id,
    required this.sectionType,
    required this.sectionId,
    required this.sectionName,
    this.description = '',
  });

  final String id;

  /// general, college or club.
  final String sectionType;
  final String sectionId;
  final String sectionName;
  final String description;

  /// What posts store as their sectionId, and what the feed filters on.
  /// Rows created by admins may have only an id (the mini program does the
  /// same: `sectionId || id`).
  String get key => sectionId.isNotEmpty ? sectionId : id;

  bool get isGeneral => sectionType == 'general';
  bool get isCollege => sectionType == 'college';
  bool get isClub => sectionType == 'club';

  factory SectionItem.fromJson(Map<String, dynamic> json) {
    final SectionItem section = SectionItem(
      id: readString(json, <String>['id']) ?? '',
      sectionType: (readString(json, <String>['sectionType']) ?? '')
          .toLowerCase(),
      sectionId: readString(json, <String>['sectionId']) ?? '',
      sectionName: readString(json, <String>['sectionName', 'name']) ?? '',
      description: readString(json, <String>['description']) ?? '',
    );
    if (section.key.isEmpty ||
        section.sectionName.isEmpty ||
        !const <String>{
          'general',
          'college',
          'club',
        }.contains(section.sectionType)) {
      throw const FormatException('分区数据无效');
    }
    return section;
  }

  @override
  bool operator ==(Object other) =>
      other is SectionItem &&
      other.sectionType == sectionType &&
      other.key == key;

  @override
  int get hashCode => Object.hash(sectionType, key);
}

/// A club from `GET /api/clubs`, with whether the viewer may post as it
/// (owner or manager). A club section takes posts only from its own club,
/// posting as the club.
class ClubItem {
  const ClubItem({
    required this.id,
    required this.name,
    required this.sectionId,
    required this.canPublishAs,
  });

  final String id;
  final String name;
  final String sectionId;
  final bool canPublishAs;

  factory ClubItem.fromJson(Map<String, dynamic> json) {
    final bool? canPublishAs = readBool(json, <String>['canPublishAs']);
    final ClubItem club = ClubItem(
      id: readString(json, <String>['id']) ?? '',
      name: readString(json, <String>['name']) ?? '',
      sectionId: readString(json, <String>['sectionId']) ?? '',
      canPublishAs: canPublishAs ?? false,
    );
    if (club.id.isEmpty || canPublishAs == null) {
      throw const FormatException('社团数据无效');
    }
    return club;
  }

  /// Whether [section] is this club's own section.
  bool owns(SectionItem section) =>
      section.isClub &&
      sectionId.isNotEmpty &&
      (sectionId == section.sectionId || sectionId == section.id);
}

/// The sections one may post to, in the server's order: 综合 and the colleges
/// (the server decides college membership and says so on publish), plus the
/// sections of clubs one may post as.
List<SectionItem> postableSections(
  List<SectionItem> sections,
  List<ClubItem> clubs,
) {
  return sections
      .where(
        (SectionItem section) =>
            !section.isClub ||
            clubs.any(
              (ClubItem club) => club.canPublishAs && club.owns(section),
            ),
      )
      .toList(growable: false);
}

/// The club a post to [section] is published as, or null for a personal post.
ClubItem? publisherClubFor(SectionItem section, List<ClubItem> clubs) {
  if (!section.isClub) return null;
  for (final ClubItem club in clubs) {
    if (club.canPublishAs && club.owns(section)) return club;
  }
  return null;
}
