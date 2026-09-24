import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/widgets/post_card.dart';

void main() {
  const TextStyle mark = TextStyle(color: Color(0xFFA43B32));

  List<String> marked(String text, String? q) => highlightSpans(text, q, mark)
      .where((TextSpan s) => s.style == mark)
      .map((TextSpan s) => s.text!)
      .toList();

  test('marks every occurrence, keeps the original case', () {
    expect(marked('组队找组队的同学', '组队'), <String>['组队', '组队']);
    expect(marked('LaTeX and latex', 'latex'), <String>['LaTeX', 'latex']);
  });

  test('ignores a leading # and empty queries', () {
    expect(marked('数学建模组队', '#组队'), <String>['组队']);
    expect(highlightSpans('原文', '', mark).single.text, '原文');
    expect(highlightSpans('原文', null, mark).single.text, '原文');
  });

  test('the spans rebuild the text exactly', () {
    const String text = '示例：组队，组队！';
    expect(
      highlightSpans(text, '组队', mark).map((TextSpan s) => s.text).join(),
      text,
    );
  });
}
