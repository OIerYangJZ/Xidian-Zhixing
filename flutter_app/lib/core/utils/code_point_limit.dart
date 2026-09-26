import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Caps input at [max] Unicode code points, the way the server measures
/// (Python `len`). `maxLength` counts grapheme clusters instead, so an emoji
/// that is one grapheme but several code points would pass the field and be
/// cut short by the server.
class CodePointLimitFormatter extends TextInputFormatter {
  const CodePointLimitFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) {
      return newValue;
    }
    final String text = String.fromCharCodes(newValue.text.runes.take(max));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// A field counter in code points, to go with [CodePointLimitFormatter]:
/// `maxLength`'s own counter counts grapheme clusters.
InputCounterWidgetBuilder codePointCounter(TextEditingController controller) {
  return (
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    int? maxLength,
  }) {
    return Text(
      '${controller.text.runes.length}/$maxLength',
      style: Theme.of(context).textTheme.bodySmall,
    );
  };
}
