import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/navigation/share_links.dart';
import '../../design_system/design_system.dart';

/// A shared post that is gone, private or never existed (handoff W8). The
/// server answers all three with 404, so the page does not guess which.
class PostUnavailablePage extends StatelessWidget {
  const PostUnavailablePage({super.key, required this.link});

  final ShareLink link;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final String url = link.url.replaceFirst(RegExp(r'^https?://'), '');
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: <Widget>[
            const ZxAvatar.anonymous(name: '知', size: 30),
            const SizedBox(width: 10),
            Text(
              uiText(context, zh: '西电知行', en: 'Xidian Zhixing'),
              style: ZxType.headline.copyWith(fontSize: 18, color: t.text),
            ),
          ],
        ),
      ),
      body: ZxPaper(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _LockedSeal(),
                  const SizedBox(height: 26),
                  Text(
                    uiText(
                      context,
                      zh: '帖子不存在，\n或你没有权限查看',
                      en: 'This post does not exist,\nor you cannot view it',
                    ),
                    textAlign: TextAlign.center,
                    style: ZxType.headline.copyWith(color: t.text),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    uiText(
                      context,
                      zh: '帖子可能已被删除、仅作者可见，或链接有误。',
                      en:
                          'It may have been deleted, made private by its '
                          'author, or the link is wrong.',
                    ),
                    textAlign: TextAlign.center,
                    style: ZxType.body.copyWith(color: t.text2),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: ZxRadius.buttonAll,
                      border: Border.all(color: t.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.link_rounded, size: 15, color: t.text3),
                        const SizedBox(width: 6),
                        Flexible(
                          child: SelectableText(
                            url,
                            key: const Key('post-unavailable-url'),
                            style: ZxType.caption.copyWith(color: t.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ZxButton(
                    key: const Key('post-unavailable-back'),
                    label: uiText(context, zh: '返回树洞', en: 'Back to Treehole'),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 知 seal, tilted and dashed, with a lock at its corner.
class _LockedSeal extends StatelessWidget {
  const _LockedSeal();

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Transform.rotate(
            angle: -6 * math.pi / 180,
            child: CustomPaint(
              painter: _DashedRRect(color: t.primary.withValues(alpha: 0.55)),
              child: Container(
                width: 112,
                height: 112,
                margin: const EdgeInsets.all(8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.primarySoft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  '知',
                  style: TextStyle(
                    fontFamily: ZxFonts.display,
                    fontFamilyFallback: ZxFonts.displayFallback,
                    fontSize: 48,
                    color: t.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: 4,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: t.surface,
                shape: BoxShape.circle,
                boxShadow: t.shadow1,
              ),
              child: Icon(Icons.lock_outline_rounded, size: 17, color: t.text2),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  const _DashedRRect({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26)),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect oldDelegate) => oldDelegate.color != color;
}
