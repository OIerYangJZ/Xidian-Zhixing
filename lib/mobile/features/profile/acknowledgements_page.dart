import 'package:flutter/material.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:watermeter/page/public_widget/app_icon.dart';
import 'package:watermeter/page/public_widget/re_x_card.dart';
import 'package:watermeter/page/setting/about_page/developer_widget.dart';

class AcknowledgementsPage extends StatefulWidget {
  const AcknowledgementsPage({super.key});

  @override
  State<AcknowledgementsPage> createState() => _AcknowledgementsPageState();
}

class _AcknowledgementsPageState extends State<AcknowledgementsPage> {
  List<Developer> _developers() => const [
    Developer(
      'BenderBlog Rodriguez',
      'https://avatars.githubusercontent.com/u/14026321',
      'XDYou 项目发起与长期维护',
      'https://space.bilibili.com/284290692',
    ),
    Developer(
      'A1nair',
      'https://avatars.githubusercontent.com/u/36269472',
      '功能开发与工程支持',
      'https://github.com/A1nair',
    ),
    Developer(
      'Appkad (Kevin)',
      'https://avatars.githubusercontent.com/u/97880629',
      '功能开发与优化',
      'https://github.com/aqqkad',
    ),
    Developer(
      'BellssGit',
      'https://avatars.githubusercontent.com/u/107785251',
      '问题反馈与支持',
      'https://space.bilibili.com/17772726',
    ),
    Developer(
      'BrackRat',
      'https://avatars.githubusercontent.com/u/35328547',
      '界面与登录流程改进',
      'https://github.com/BrackRat',
    ),
    Developer(
      'Dimole',
      'https://avatars.githubusercontent.com/u/24828354',
      '功能支持与优化',
      'https://github.com/Dimole',
    ),
    Developer(
      'hhzm',
      'https://avatars.githubusercontent.com/u/19224718',
      '电费与工具能力支持',
      'https://hhzm.win/',
    ),
    Developer(
      'imoscarz',
      'https://avatars.githubusercontent.com/u/52318095',
      '课表与 UI 功能支持',
      'https://imoscarz.me/',
    ),
    Developer(
      'LichtYy',
      'https://avatars.githubusercontent.com/u/105974550',
      '功能开发',
      'https://github.com/lichtYy',
    ),
    Developer(
      'stalomeow',
      'https://avatars.githubusercontent.com/u/47203031',
      '工程支持',
      'https://stalomeow.com',
    ),
    Developer(
      'xeonds',
      'https://avatars.githubusercontent.com/u/68117734',
      '开源支持',
      'https://mxts.jiujiuer.xyz',
    ),
    Developer(
      'ZCWzy',
      'https://avatars.githubusercontent.com/u/87163986',
      '功能开发与维护',
      'https://github.com/ZCWzy',
    ),
  ];

  Widget _titleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        AppIconWidget(),
        SizedBox(height: 12),
        Text(
          'XDYou 致谢',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6),
        Text(
          '感谢 XDYou 开发者与贡献者',
          style: TextStyle(fontSize: 14, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    ).padding(all: 24);
  }

  Widget _developerCard() {
    final developers = _developers();
    return ReXCard(
      title: Text('开发者 (${developers.length})').padding(bottom: 8).center(),
      remaining: const [],
      bottomRow: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: developers
            .map((developer) => DeveloperWidget(developer: developer))
            .toList(),
      ),
    );
  }

  Widget _thanksCard() {
    return ReXCard(
      title: const Text('致谢说明').padding(bottom: 8).center(),
      remaining: const [],
      bottomRow: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本页延续校园设置「关于页」布局，仅用于致谢 XDYou 开发者。'),
          SizedBox(height: 8),
          Text('感谢所有为 XDYou 提交代码、反馈问题、参与测试的同学。'),
          SizedBox(height: 8),
          Text('感谢每一位让校园助手变得更好的贡献者。'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('致谢页')),
      body: Builder(
        builder: (context) {
          final size = MediaQuery.sizeOf(context);
          final isWide = size.width > 600 && size.width / size.height > 1;
          if (isWide) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [_titleBlock(), _developerCard()],
                ).padding(vertical: 8).scrollable().flexible(flex: 1),
                Column(
                  children: [const SizedBox(height: 24), _thanksCard()],
                ).padding(vertical: 8).scrollable().flexible(flex: 1),
              ],
            ).constrained(maxWidth: 900).center();
          }
          return Column(
                children: [
                  _titleBlock(),
                  _developerCard(),
                  _thanksCard().padding(top: 12, bottom: 18),
                ],
              )
              .padding(horizontal: 16)
              .scrollable()
              .constrained(maxWidth: 680)
              .center();
        },
      ),
    );
  }
}
