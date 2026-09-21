import 'package:flutter/material.dart';

import '../../core/widgets/app_surfaces.dart';

class AndroidReleasePage extends StatelessWidget {
  const AndroidReleasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Android 客户端')),
      body: AppPageFrame(
        maxWidth: 720,
        padding: EdgeInsets.zero,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '当前设备已安装 Android 客户端。\n如需更新安装包，请联系管理员获取最新版本。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
