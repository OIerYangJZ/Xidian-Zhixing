import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/browser_download.dart';
import '../../models/app_release_item.dart';
import '../../repositories/app_repositories.dart';

class AndroidReleasePage extends StatefulWidget {
  const AndroidReleasePage({super.key});

  @override
  State<AndroidReleasePage> createState() => _AndroidReleasePageState();
}

class _AndroidReleasePageState extends State<AndroidReleasePage> {
  AppReleaseItem? _release;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('下载 Android 客户端')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFEAF3FB), Color(0xFFF6F8FB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildBody(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final AppReleaseItem? release = _release;
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '当前无法获取最新安装包',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('重新获取'),
          ),
        ],
      );
    }

    if (release == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Android 客户端暂未发布',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('管理员上传新版 APK 后，这里会自动显示下载信息。'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
          ),
        ],
      );
    }

    final String resolvedUrl = AppConfig.resolveUrl(release.downloadUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Android 客户端下载',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '最新版本 ${release.versionName}（${release.versionCode}）',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _infoChip('文件名 ${release.fileName}'),
            _infoChip('大小 ${_formatFileSize(release.sizeBytes)}'),
            _infoChip(release.forceUpdate ? '强制更新' : '可选更新'),
            if (release.uploadedByUsername.isNotEmpty)
              _infoChip('发布人 ${release.uploadedByUsername}'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD7E4EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('更新说明', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                release.releaseNotes.trim().isEmpty
                    ? '本次版本暂无额外说明。'
                    : release.releaseNotes,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(
          '下载地址：$resolvedUrl',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        SelectableText(
          'SHA256：${release.sha256}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () async {
                final bool started = await triggerBrowserDownload(resolvedUrl);
                if (!mounted) {
                  return;
                }
                if (!started) {
                  _copyAndToast(resolvedUrl, '当前环境不支持直接下载，链接已复制');
                  return;
                }
                _toast('已开始下载 APK');
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('下载 APK'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _copyAndToast(resolvedUrl, '下载链接已复制'),
              icon: const Icon(Icons.link),
              label: const Text('复制下载链接'),
            ),
            FilledButton.tonalIcon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新版本信息'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF5FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final AppReleaseItem? release = await AppRepositories.releases
          .fetchLatestAndroidRelease();
      if (!mounted) {
        return;
      }
      setState(() {
        _release = release;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _copyAndToast(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    _toast(message);
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatFileSize(int sizeBytes) {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    }
    final double kb = sizeBytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final double mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }
}
