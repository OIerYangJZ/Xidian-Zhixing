import 'package:flutter/material.dart';

import '../utils/hashtag_pattern.dart';

/// Renders hashtag tokens in the editor with the active theme's link color
/// while keeping the original text and selection unchanged.
class HashtagTextEditingController extends TextEditingController {
  HashtagTextEditingController({super.text});

  bool _highlightHashtags = true;

  set highlightHashtags(bool value) {
    if (_highlightHashtags == value) return;
    _highlightHashtags = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final String source = value.text;
    if (!_highlightHashtags) {
      return TextSpan(style: style, text: source);
    }
    final Color hashtagColor = Theme.of(context).colorScheme.tertiary;
    final List<InlineSpan> children = <InlineSpan>[];
    int cursor = 0;

    for (final RegExpMatch match in AppHashtag.pattern.allMatches(source)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: source.substring(cursor, match.start)));
      }
      children.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: hashtagColor),
        ),
      );
      cursor = match.end;
    }

    if (cursor < source.length) {
      children.add(TextSpan(text: source.substring(cursor)));
    }

    return TextSpan(style: style, children: children);
  }
}
