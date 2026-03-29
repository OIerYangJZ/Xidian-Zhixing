import 'package:flutter/material.dart';

class XdyouHostPage extends StatelessWidget {
  const XdyouHostPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '校园助手仅在移动端可用',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
