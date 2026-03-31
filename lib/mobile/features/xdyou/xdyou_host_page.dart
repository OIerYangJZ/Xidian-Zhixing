import 'package:flutter/material.dart';
import 'package:xdu_treehole_web/mobile/integrations/xdyou_bootstrap.dart';

/// 在底部 Tab 中全屏嵌入 XDYou（Traintime PDA / watermeter）。
class XdyouHostPage extends StatefulWidget {
  const XdyouHostPage({super.key});

  @override
  State<XdyouHostPage> createState() => _XdyouHostPageState();
}

class _XdyouHostPageState extends State<XdyouHostPage>
    with AutomaticKeepAliveClientMixin {
  bool _ready = false;
  Object? _error;

  /// 保持页面状态，防止在 PageView 切换 Tab 时被销毁重建。
  /// XDYou（watermeter）内含 GetX 全局控制器，重建会引发状态冲突崩溃。
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await ensureXdyouEmbedInitialized();
      await initXdyouNotificationServices();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('校园助手')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'XDYou 初始化失败：$_error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return buildXdyouApp();
  }
}
