import 'package:flutter/material.dart';
import 'package:watermeter/page/homepage/homepage.dart';
import 'package:watermeter/page/toolbox/toolbox_page.dart';

/// 简化版 XDYou 入口：只保留 homepage 和 toolbox，支持左右滑动切换
class SimplifiedXdyouHome extends StatefulWidget {
  const SimplifiedXdyouHome({super.key});

  @override
  State<SimplifiedXdyouHome> createState() => _SimplifiedXdyouHomeState();
}

class _SimplifiedXdyouHomeState extends State<SimplifiedXdyouHome> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: PageView(
        controller: _controller,
        children: [
          MainPage(
            changePage: () {
              _controller.jumpToPage(1);
            },
          ),
          const ToolBoxPage(),
        ],
      ),
    );
  }
}
