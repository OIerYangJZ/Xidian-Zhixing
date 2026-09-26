// Renders every design-system component in each theme and brightness to PNG
// for side-by-side review against the Claude Design handoff. Skipped unless
// ZX_GALLERY_OUT names an output directory:
//
//   ZX_GALLERY_OUT=/tmp/zx-gallery flutter test test/design_system_gallery_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/design_system/design_system.dart';

final String? _out = Platform.environment['ZX_GALLERY_OUT'];

Future<void> _loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    final File file = File(path);
    if (file.existsSync()) {
      loader.addFont(
        Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    if (_out == null) return;
    final String sdk = '${Platform.environment['HOME']}/flutter';
    await _loadFont('MaterialIcons', <String>[
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
    await _loadFont('STZhongsong', <String>['assets/fonts/STZhongsong-Subset.ttf']);
    await _loadFont('STSong', <String>['web/fonts/STSong-Rare.ttf']);
    // Stand-in for the platform sans the app uses on Android, registered over
    // the test harness's default family too, whose placeholder glyphs would
    // otherwise draw Latin text and digits as boxes.
    for (final String family in <String>[
      'PingFang SC',
      'Roboto',
      'FlutterTest',
    ]) {
      await _loadFont(family, <String>['/Library/Fonts/Arial Unicode.ttf']);
    }
  });

  for (final ZxThemeInfo theme in zxThemes) {
    for (final Brightness brightness in Brightness.values) {
      testWidgets('gallery ${theme.key}/${brightness.name}', (
        WidgetTester tester,
      ) async {
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = const Size(1000 * 2, 1180 * 2);
        addTearDown(tester.view.reset);
        final GlobalKey boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ZxTheme.build(themeKey: theme.key, brightness: brightness),
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: ZxPaper(child: _Gallery(theme: theme)),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.runAsync(() async {
          final RenderRepaintBoundary render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final ui.Image image = await render.toImage(pixelRatio: 2);
          final ByteData? png = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          Directory(_out!).createSync(recursive: true);
          File(
            '$_out/${theme.key}_${brightness.name}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        });
      }, skip: _out == null);
    }
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.theme});

  final ZxThemeInfo theme;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        s,
        style: ZxType.micro.copyWith(color: t.text3, letterSpacing: 1),
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ZxHeroWash(
                  borderRadius: ZxRadius.cardAll,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('树洞', style: ZxType.display),
                        Text(
                          '让校园里的真实声音被听见 · ${theme.labelZh}',
                          style: ZxType.body.copyWith(color: t.text2),
                        ),
                      ],
                    ),
                  ),
                ),
                label('BUTTON'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ZxButton(
                      label: '发布帖子',
                      icon: Icons.edit_outlined,
                      onPressed: () {},
                    ),
                    ZxButton(
                      label: '取消',
                      variant: ZxButtonVariant.secondary,
                      onPressed: () {},
                    ),
                    ZxButton(
                      label: '私信作者',
                      variant: ZxButtonVariant.outline,
                      onPressed: () {},
                    ),
                    ZxButton(
                      label: '删除',
                      variant: ZxButtonVariant.danger,
                      onPressed: () {},
                    ),
                    const ZxButton(label: '不可用', onPressed: null),
                    ZxButton(label: '提交中…', loading: true, onPressed: () {}),
                    ZxButton(
                      label: '查看全部',
                      variant: ZxButtonVariant.ghost,
                      small: true,
                      onPressed: () {},
                    ),
                  ],
                ),
                label('INPUT'),
                const TextField(
                  decoration: InputDecoration(
                    labelText: '标题',
                    hintText: '期末复习资料互助',
                    helperText: '8/60',
                  ),
                ),
                const SizedBox(height: 10),
                const TextField(
                  decoration: InputDecoration(
                    hintText: '发表评论',
                    errorText: '评论不能为空',
                  ),
                ),
                label('BADGE'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    const ZxBadge.pinned('置顶'),
                    const ZxBadge.anonymous('匿名'),
                    ZxBadge.channel('学习交流', color: t.channelFor('学习交流')),
                    const ZxBadge.inProgress('进行中'),
                    const ZxBadge.resolved('已解决'),
                    const ZxBadge.closed('已结束'),
                    const ZxBadge.private('仅自己可见'),
                    const ZxBadge.pendingReview('待审核'),
                    const ZxBadge.rejected('未通过审核'),
                    const ZxBadge.deleted('已删除'),
                    const ZxBadge.author('洞主'),
                    const ZxBadge.blocked('已屏蔽'),
                    const ZxBadge.level('Lv.1'),
                    const ZxBadge.verified('已认证'),
                    const ZxCountBadge(3),
                    const ZxCountBadge(120),
                  ],
                ),
                label('AVATAR'),
                const Row(
                  children: <Widget>[
                    ZxAvatar(name: '林小舟'),
                    SizedBox(width: 10),
                    ZxAvatar(name: 'Alex'),
                    SizedBox(width: 10),
                    ZxAvatar(name: '北门的风'),
                    SizedBox(width: 10),
                    ZxAvatar.anonymous(name: '匿'),
                    SizedBox(width: 10),
                    ZxAvatar.anonymous(name: '安', size: 48),
                  ],
                ),
                label('INLINE MESSAGE'),
                const ZxInlineMessage(message: '明暗模式自动跟随浏览器与系统。'),
                const SizedBox(height: 8),
                const ZxInlineMessage(
                  message: '隐私设置已更新',
                  tone: ZxMessageTone.success,
                ),
                const SizedBox(height: 8),
                const ZxInlineMessage(
                  message: '对方回复前只能发送一条消息，请谨慎措辞。',
                  tone: ZxMessageTone.warning,
                ),
                const SizedBox(height: 8),
                ZxInlineMessage(
                  message: '内容加载失败',
                  tone: ZxMessageTone.danger,
                  actionLabel: '重试',
                  onAction: () {},
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                label('LIST ITEM'),
                ZxListSection(
                  title: '账号',
                  children: <Widget>[
                    ZxListItem(
                      icon: Icons.star_outline_rounded,
                      iconColor: t.accentInk,
                      title: '我的收藏',
                      subtitle: '当前收藏帖子：24',
                      onTap: () {},
                    ),
                    ZxListItem(
                      icon: Icons.language_rounded,
                      title: '语言',
                      trailing: Text(
                        '简体中文',
                        style: ZxType.caption.copyWith(color: t.text3),
                      ),
                      onTap: () {},
                    ),
                    ZxListItem(
                      icon: Icons.mail_lock_outlined,
                      title: '允许陌生人私信',
                      trailing: Switch(value: true, onChanged: (_) {}),
                    ),
                    ZxListItem(
                      icon: Icons.person_off_outlined,
                      title: '注销账号申请',
                      subtitle: '待审核 · 09-20 提交',
                      trailing: const ZxBadge.pendingReview('审核中'),
                      danger: true,
                      onTap: () {},
                    ),
                    ZxListItem(
                      icon: Icons.logout_rounded,
                      title: '退出登录',
                      danger: true,
                      onTap: () {},
                    ),
                  ],
                ),
                label('CARD · SKELETON'),
                ZxCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          ZxSkeleton(
                            width: 36,
                            height: 36,
                            borderRadius: ZxRadius.smallButtonAll,
                          ),
                          SizedBox(width: 10),
                          ZxSkeleton(width: 120),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const ZxSkeleton(),
                      const SizedBox(height: 8),
                      ZxSkeleton(
                        width: 220,
                        height: 12,
                        borderRadius: ZxRadius.badgeAll,
                      ),
                    ],
                  ),
                ),
                label('STATE'),
                ZxCard(
                  child: ZxStatePanel(
                    title: '这里还没有帖子',
                    message: '成为第一位分享校园日常的人',
                    actionLabel: '发布帖子',
                    onAction: () {},
                  ),
                ),
                const SizedBox(height: 12),
                ZxCard(
                  child: ZxStatePanel(
                    icon: Icons.cloud_off_rounded,
                    title: '内容加载失败',
                    message: '网络连接超时（示例错误信息）',
                    actionLabel: '重试',
                    onAction: () {},
                    error: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
