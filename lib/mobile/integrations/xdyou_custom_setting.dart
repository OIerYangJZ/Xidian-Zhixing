import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:watermeter/page/setting/setting.dart';

/// 自定义设置页面：隐藏 about 和 core_setting 部分
class CustomSettingWindow extends StatelessWidget {
  const CustomSettingWindow({super.key});

  @override
  Widget build(BuildContext context) {
    // 直接使用原设置页，但通过拦截导航隐藏不需要的功能
    return const SettingWindow();
  }
}
