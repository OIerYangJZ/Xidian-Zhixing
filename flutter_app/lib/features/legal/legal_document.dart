import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';

/// One titled part of a [LegalDocument].
class LegalSection {
  const LegalSection({
    required this.title,
    required this.content,
    this.icon,
    this.isWarning = false,
  });

  final String title;
  final String content;
  final IconData? icon;

  /// Rules whose breach has consequences; set in the danger tone.
  final bool isWarning;
}

/// The shared layout of 用户协议, 隐私政策, 社区规范 and 举报说明: a reading
/// column with the sections, and a contents list beside it on wide screens.
class LegalDocument extends StatefulWidget {
  const LegalDocument({
    super.key,
    required this.title,
    required this.icon,
    required this.lastUpdated,
    required this.sections,
    required this.footer,
  });

  final String title;
  final IconData icon;
  final String lastUpdated;
  final List<LegalSection> sections;
  final String footer;

  @override
  State<LegalDocument> createState() => _LegalDocumentState();
}

class _LegalDocumentState extends State<LegalDocument> {
  static const double _contentsMinWidth = 1080;

  late final List<GlobalKey> _keys = List<GlobalKey>.generate(
    widget.sections.length,
    (_) => GlobalKey(),
  );

  void _jumpTo(int index) {
    final BuildContext? target = _keys[index].currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: ZxMotion.standard,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Widget document = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ZxHeroWash(
          borderRadius: ZxRadius.cardAll,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: ZxRadius.buttonAll,
                    border: Border.all(color: t.line),
                  ),
                  child: Icon(widget.icon, color: t.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: ZxType.headline.copyWith(color: t.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        uiText(
                          context,
                          zh: '最后更新：${widget.lastUpdated}',
                          en: 'Last updated: ${widget.lastUpdated}',
                        ),
                        style: ZxType.caption.copyWith(color: t.text3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < widget.sections.length; i++)
          _SectionView(key: _keys[i], section: widget.sections[i]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.bgSunk,
            borderRadius: ZxRadius.cardAll,
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.info_outline_rounded, size: 18, color: t.text3),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.footer,
                  style: ZxType.caption.copyWith(color: t.text2, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ZxPaper(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool contents = constraints.maxWidth >= _contentsMinWidth;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contents ? 1000 : 720),
                  child: contents
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: document),
                            const SizedBox(width: 28),
                            SizedBox(
                              width: 240,
                              child: _Contents(
                                sections: widget.sections,
                                onTap: _jumpTo,
                              ),
                            ),
                          ],
                        )
                      : document,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({super.key, required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Color hue = section.isWarning ? t.danger : t.primary;
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (section.icon != null) ...<Widget>[
              Icon(section.icon, size: 18, color: hue),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                section.title,
                style: ZxType.title.copyWith(
                  color: section.isWarning ? t.danger : t.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          section.content,
          style: ZxType.body.copyWith(color: t.text2, height: 1.8),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: section.isWarning
          ? Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: t.dangerSoft,
                borderRadius: ZxRadius.cardAll,
                border: Border.all(color: t.danger.withValues(alpha: 0.2)),
              ),
              child: body,
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: body,
            ),
    );
  }
}

class _Contents extends StatelessWidget {
  const _Contents({required this.sections, required this.onTap});

  final List<LegalSection> sections;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return ZxCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Text(
              uiText(context, zh: '目录', en: 'Contents'),
              style: ZxType.caption.copyWith(
                color: t.text3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (int i = 0; i < sections.length; i++)
            InkWell(
              borderRadius: ZxRadius.smallButtonAll,
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Text(
                  sections[i].title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZxType.caption.copyWith(fontSize: 13, color: t.text2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
