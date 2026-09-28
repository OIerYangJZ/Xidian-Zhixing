import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/models/section_item.dart';

SectionItem _section(String type, String id, String name) =>
    SectionItem(sectionType: type, sectionId: id, sectionName: name);

void main() {
  final List<SectionItem> sections = <SectionItem>[
    _section('general', 'general', '综合'),
    _section('college', 'cs', '计算机科学与技术学院'),
    _section('college', 'ee', '电子工程学院'),
  ];

  test('only one\'s own college takes posts', () {
    final List<String> keys = postableSections(
      sections,
      const <ClubItem>[],
      college: '电子工程学院',
    ).map((SectionItem s) => s.key).toList();
    expect(keys, <String>['general', 'ee']);
  });

  test('no verified college: 综合 only', () {
    final List<String> keys = postableSections(
      sections,
      const <ClubItem>[],
      college: '',
    ).map((SectionItem s) => s.key).toList();
    expect(keys, <String>['general']);
  });

  test('a section is named by its sectionId alone', () {
    final SectionItem section = SectionItem.fromJson(<String, dynamic>{
      'sectionType': 'college',
      'sectionId': 'ee',
      'sectionName': '电子工程学院',
    });
    expect(section.key, 'ee');
    expect(
      () => SectionItem.fromJson(<String, dynamic>{
        'id': 'sec5',
        'sectionType': 'college',
        'sectionName': '无 sectionId',
      }),
      throwsFormatException,
    );
  });
}
