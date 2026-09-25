import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/utils/browser_download.dart';
import '../../design_system/design_system.dart';
import '../../models/app_release_item.dart';
import '../../repositories/app_repositories.dart';

/// 下载 Android 客户端 (web): the latest published APK with its version,
/// size and notes, and a download button. Before any release is published
/// it says so instead.
class AndroidReleasePage extends StatefulWidget {
  const AndroidReleasePage({super.key});

  @override
  State<AndroidReleasePage> createState() => _AndroidReleasePageState();
}

class _AndroidReleasePageState extends State<AndroidReleasePage> {
  late Future<AppReleaseItem?> _release = AppRepositories.releases
      .fetchLatestAndroidRelease();

  void _reload() => setState(
    () => _release = AppRepositories.releases.fetchLatestAndroidRelease(),
  );

  Future<void> _download(AppReleaseItem release) async {
    final String url = AppConfig.resolveUrl(release.downloadUrl);
    final bool started = await triggerBrowserDownload(url);
    if (!mounted) return;
    if (started) {
      zxShowToast(
        context,
        uiText(context, zh: '已开始下载', en: 'Download started'),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    zxShowToast(
      context,
      uiText(
        context,
        zh: '无法直接下载，已复制下载链接',
        en: 'Could not start the download; link copied',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: 'Android 客户端', en: 'Android app')),
      ),
      body: ZxPaper(
        child: FutureBuilder<AppReleaseItem?>(
          future: _release,
          builder: (BuildContext context, AsyncSnapshot<AppReleaseItem?> snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ZxStatePanel(
                error: true,
                icon: Icons.error_outline_rounded,
                title: uiText(
                  context,
                  zh: '版本信息加载失败',
                  en: 'Could not load the release',
                ),
                message: '${snap.error}',
                actionLabel: uiText(context, zh: '重试', en: 'Retry'),
                onAction: _reload,
              );
            }
            final AppReleaseItem? release = snap.data;
            if (release == null) {
              return ZxStatePanel(
                icon: Icons.android_rounded,
                title: uiText(context, zh: '还没有发布安装包', en: 'No release yet'),
                message: uiText(
                  context,
                  zh: '正式版发布后会在这里提供下载。',
                  en: 'The download appears here once a release is published.',
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: <Widget>[
                    ZxHeroWash(
                      borderRadius: ZxRadius.cardAll,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: Column(
                          children: <Widget>[
                            const ZxAvatar.anonymous(name: '知', size: 64),
                            const SizedBox(height: 14),
                            Text(
                              uiText(
                                context,
                                zh: '西电知行 Android 版',
                                en: 'Xidian Zhixing for Android',
                              ),
                              style: ZxType.headline.copyWith(color: t.text),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                release.versionCode > 0
                                    ? '${release.versionName} (${release.versionCode})'
                                    : release.versionName,
                                _size(release.sizeBytes),
                                if (release.uploadedAt.trim().isNotEmpty)
                                  release.uploadedAt.trim(),
                              ].join(' · '),
                              style: ZxType.caption.copyWith(color: t.text3),
                            ),
                            const SizedBox(height: 18),
                            ZxButton(
                              key: const Key('android-release-download'),
                              label: uiText(
                                context,
                                zh: '下载安装包',
                                en: 'Download APK',
                              ),
                              icon: Icons.download_rounded,
                              expand: true,
                              onPressed: () => _download(release),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ZxCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            uiText(context, zh: '更新说明', en: 'Release notes'),
                            style: ZxType.label.copyWith(color: t.text),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            release.releaseNotes.trim().isEmpty
                                ? uiText(
                                    context,
                                    zh: '本次版本暂无额外说明。',
                                    en: 'No notes for this version.',
                                  )
                                : release.releaseNotes.trim(),
                            style: ZxType.body.copyWith(
                              color: t.text2,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ZxInlineMessage(
                      message: uiText(
                        context,
                        zh: '安装时如果提示「未知来源」，请在系统设置里允许浏览器安装应用。',
                        en: 'If Android warns about unknown sources, allow your browser to install apps.',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _size(int bytes) {
    if (bytes <= 0) return '—';
    final double mb = bytes / (1024 * 1024);
    return mb >= 1
        ? '${mb.toStringAsFixed(1)} MB'
        : '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
