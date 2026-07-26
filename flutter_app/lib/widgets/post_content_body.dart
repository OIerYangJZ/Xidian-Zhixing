import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../core/config/app_config.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/shared_colors.dart';
import '../core/utils/hashtag_pattern.dart';

/// Renders inline [#topic] references in the product's blue emphasis colour.
/// Topics remain part of the author's text instead of becoming separate chips.
class HashtagText extends StatefulWidget {
  const HashtagText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.onHashtagTap,
  });

  static final RegExp _hashtagPattern = AppHashtag.pattern;

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final ValueChanged<String>? onHashtagTap;

  static TextSpan spanFor(
    BuildContext context, {
    required String text,
    TextStyle? style,
  }) {
    final EditorialColors colors = EditorialColors.of(context);
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final Match match in _hashtagPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: colors.info, fontWeight: FontWeight.w500),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: spans);
  }

  @override
  State<HashtagText> createState() => _HashtagTextState();
}

class _HashtagTextState extends State<HashtagText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    if (widget.onHashtagTap == null) {
      return Text.rich(
        HashtagText.spanFor(context, text: widget.text, style: widget.style),
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
      );
    }

    final EditorialColors colors = EditorialColors.of(context);
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final Match match in HashtagText._hashtagPattern.allMatches(
      widget.text,
    )) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final String tag = match.group(0)!;
      final TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onHashtagTap!(tag);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: tag,
          style: TextStyle(color: colors.info, fontWeight: FontWeight.w500),
          recognizer: recognizer,
        ),
      );
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}

class PostContentBody extends StatelessWidget {
  const PostContentBody({
    super.key,
    required this.content,
    this.contentFormat = 'plain',
    this.markdownSource = '',
    this.selectable = false,
    this.onHashtagTap,
  });

  final String content;
  final String contentFormat;
  final String markdownSource;
  final bool selectable;
  final ValueChanged<String>? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    final String normalizedFormat = contentFormat.trim().toLowerCase();
    final String markdownData = markdownSource.isNotEmpty
        ? markdownSource
        : content;
    if (normalizedFormat != 'markdown' || markdownData.trim().isEmpty) {
      final TextStyle style = AppTypography.postContentStyle(
        Theme.of(context).textTheme.bodyLarge,
      ).copyWith(height: 1.6);
      if (selectable && onHashtagTap == null) {
        return SelectableText.rich(
          HashtagText.spanFor(context, text: content, style: style),
        );
      }
      return HashtagText(
        text: content,
        style: style,
        onHashtagTap: onHashtagTap,
      );
    }

    return MarkdownBody(
      data: markdownData,
      selectable: selectable,
      softLineBreak: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: <md.InlineSyntax>[_InlineMathSyntax(), _HashtagSyntax()],
      blockSyntaxes: <md.BlockSyntax>[_BlockMathSyntax()],
      builders: <String, MarkdownElementBuilder>{
        'math-inline': _MathElementBuilder(isBlock: false),
        'math-block': _MathElementBuilder(isBlock: true),
        'hashtag': _HashtagElementBuilder(),
      },
      sizedImageBuilder: (MarkdownImageConfig config) {
        final String resolvedUrl = AppConfig.resolveUrl(config.uri.toString());
        final String rawSemanticLabel = (config.alt ?? config.title ?? '')
            .trim();
        final String semanticLabel = rawSemanticLabel.isEmpty
            ? '图片'
            : rawSemanticLabel;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              resolvedUrl,
              width: config.width ?? double.infinity,
              height: config.height,
              fit: BoxFit.contain,
              semanticLabel: semanticLabel,
              loadingBuilder:
                  (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2.4),
                    );
                  },
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '图片加载失败',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.58),
                        ),
                      ),
                    );
                  },
            ),
          ),
        );
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: AppTypography.postContentStyle(
          Theme.of(context).textTheme.bodyLarge,
        ).copyWith(height: 1.7),
        h1: AppTypography.postContentStyle(
          Theme.of(context).textTheme.headlineSmall,
        ),
        h2: AppTypography.postContentStyle(
          Theme.of(context).textTheme.titleLarge,
        ),
        h3: AppTypography.postContentStyle(
          Theme.of(context).textTheme.titleMedium,
        ),
        h4: AppTypography.postContentStyle(
          Theme.of(context).textTheme.titleSmall,
        ),
        h5: AppTypography.postContentStyle(
          Theme.of(context).textTheme.bodyLarge,
        ),
        h6: AppTypography.postContentStyle(
          Theme.of(context).textTheme.bodyMedium,
        ),
        blockquote:
            AppTypography.postContentStyle(
              Theme.of(context).textTheme.bodyMedium,
            ).copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.74),
              height: 1.6,
            ),
        code: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: AppTypography.englishBody,
          fontFamilyFallback: AppTypography.englishBodyFallback,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _HashtagElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Text(
    element.textContent,
    style: (preferredStyle ?? parentStyle)?.copyWith(
      color: EditorialColors.of(context).info,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _HashtagSyntax extends md.InlineSyntax {
  _HashtagSyntax() : super(AppHashtag.expression);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final String tag = match.group(0) ?? '';
    if (tag.isEmpty) {
      return false;
    }
    parser.addNode(md.Element.text('hashtag', tag));
    return true;
  }
}

class _MathElementBuilder extends MarkdownElementBuilder {
  _MathElementBuilder({required this.isBlock});

  final bool isBlock;

  @override
  bool isBlockElement() => isBlock;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final String source = (element.attributes['tex'] ?? element.textContent)
        .trim();
    if (source.isEmpty) {
      return const SizedBox.shrink();
    }
    final Widget math = Math.tex(
      source,
      mathStyle: isBlock ? MathStyle.display : MathStyle.text,
      textStyle: preferredStyle ?? parentStyle,
      onErrorFallback: (FlutterMathException error) {
        return Text(
          source,
          style: (preferredStyle ?? parentStyle)?.copyWith(
            fontFamily: AppTypography.englishBody,
            fontFamilyFallback: AppTypography.englishBodyFallback,
            color: Theme.of(context).colorScheme.error,
          ),
        );
      },
    );
    if (!isBlock) {
      return Text.rich(
        TextSpan(
          children: <InlineSpan>[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: math,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: math,
      ),
    );
  }
}

class _InlineMathSyntax extends md.InlineSyntax {
  _InlineMathSyntax() : super(r'(?<!\$)\$([^\$\n]+?)(?<!\\)\$(?!\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final String expression = (match.group(1) ?? '').trim();
    if (expression.isEmpty) {
      return false;
    }
    final md.Element element = md.Element.text('math-inline', expression)
      ..attributes['tex'] = expression;
    parser.addNode(element);
    return true;
  }
}

class _BlockMathSyntax extends md.BlockSyntax {
  @override
  bool canParse(md.BlockParser parser) {
    return parser.current.content.trim().startsWith(r'$$');
  }

  @override
  RegExp get pattern => RegExp(r'^\$\$');

  @override
  md.Node parse(md.BlockParser parser) {
    final String firstLine = parser.current.content.trim();
    parser.advance();

    final StringBuffer buffer = StringBuffer();
    if (firstLine.length > 4 && firstLine.endsWith(r'$$')) {
      buffer.write(firstLine.substring(2, firstLine.length - 2).trim());
    } else {
      final String leading = firstLine.substring(2).trim();
      if (leading.isNotEmpty) {
        buffer.writeln(leading);
      }
      while (!parser.isDone) {
        final String line = parser.current.content;
        final String trimmed = line.trim();
        if (trimmed.endsWith(r'$$')) {
          final String trailing = trimmed
              .substring(0, trimmed.length - 2)
              .trim();
          if (trailing.isNotEmpty) {
            buffer.writeln(trailing);
          }
          parser.advance();
          break;
        }
        buffer.writeln(line);
        parser.advance();
      }
    }

    final String expression = buffer.toString().trim();
    final md.Element element = md.Element.empty('math-block')
      ..attributes['tex'] = expression;
    return element;
  }
}
