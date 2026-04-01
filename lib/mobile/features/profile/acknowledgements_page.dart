import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:watermeter/page/public_widget/re_x_card.dart';
import 'package:watermeter/page/setting/about_page/developer_widget.dart';

class AcknowledgementsPage extends StatefulWidget {
  const AcknowledgementsPage({super.key});

  @override
  State<AcknowledgementsPage> createState() => _AcknowledgementsPageState();
}

class _AcknowledgementsPageState extends State<AcknowledgementsPage> {
  List<Developer> _developers() => [
    Developer(
      'BenderBlog Rodriguez',
      'https://avatars.githubusercontent.com/u/14026321',
      FlutterI18n.translate(context, 'setting.about_page.benderblog'),
      'https://space.bilibili.com/284290692',
    ),
    Developer(
      'A1nair',
      'https://avatars.githubusercontent.com/u/36269472',
      FlutterI18n.translate(context, 'setting.about_page.alnair'),
      'https://github.com/A1nair',
    ),
    Developer(
      'Appkad (Kevin)',
      'https://avatars.githubusercontent.com/u/97880629',
      FlutterI18n.translate(context, 'setting.about_page.aqqkad'),
      'https://github.com/aqqkad',
    ),
    Developer(
      'BellssGit',
      'https://avatars.githubusercontent.com/u/107785251',
      FlutterI18n.translate(context, 'setting.about_page.bellssgit'),
      'https://space.bilibili.com/17772726',
    ),
    Developer(
      'BrackRat',
      'https://avatars.githubusercontent.com/u/35328547',
      FlutterI18n.translate(context, 'setting.about_page.brackrat'),
      'https://github.com/BrackRat',
    ),
    Developer(
      'Breezeline',
      'https://avatars.githubusercontent.com/u/74224286',
      FlutterI18n.translate(context, 'setting.about_page.breezeline'),
      'mailto:ydzhang.ruc@gmail.com',
    ),
    Developer(
      '0xCAFEBABE',
      'https://blog.hxzzz.asia/usr/uploads/2024/05/1717631110.jpg',
      FlutterI18n.translate(context, 'setting.about_page.cafebabe'),
      'https://blog.hxzzz.asia/',
    ),
    Developer(
      'chitao1234',
      'https://avatars.githubusercontent.com/u/25598632',
      FlutterI18n.translate(context, 'setting.about_page.chitao1234'),
      'https://github.com/chitao1234',
    ),
    Developer(
      'Dimole',
      'https://avatars.githubusercontent.com/u/24828354',
      FlutterI18n.translate(context, 'setting.about_page.dimole'),
      'https://github.com/Dimole',
    ),
    Developer(
      'EliteWars',
      'https://avatars.githubusercontent.com/u/44139545',
      FlutterI18n.translate(context, 'setting.about_page.elitewars'),
      'https://space.bilibili.com/49892391/',
    ),
    Developer(
      'Mother Elliot Flores',
      'https://legacy.superbart.top/picture/Random/hirasawa.jpg',
      FlutterI18n.translate(context, 'setting.about_page.elliot'),
      'https://mp.weixin.qq.com/s/_egmj3rjwOTAB-KHzKsYGw',
    ),
    Developer(
      'FlyingPig278',
      'https://avatars.githubusercontent.com/u/88129602',
      FlutterI18n.translate(context, 'setting.about_page.flyingpig'),
      'https://github.com/FlyingPig278',
    ),
    Developer(
      'GodHu777777',
      'https://avatars.githubusercontent.com/u/111997394',
      FlutterI18n.translate(context, 'setting.about_page.godhu777777'),
      'https://github.com/GodHu777777',
    ),
    Developer(
      'Hancl777',
      'https://avatars.githubusercontent.com/u/74408609',
      FlutterI18n.translate(context, 'setting.about_page.hancl777'),
      'https://github.com/Hancl777',
    ),
    Developer(
      'Hazuki Keatsu (叶月枫)',
      'https://avatars.githubusercontent.com/u/111259147',
      FlutterI18n.translate(context, 'setting.about_page.hazuki-keatsu'),
      'https://keatsu.top',
    ),
    Developer(
      'hawa130',
      'https://avatars.githubusercontent.com/u/26119430',
      FlutterI18n.translate(context, 'setting.about_page.hawa130'),
      'https://hawa130.com/',
    ),
    Developer(
      'hhzm (闪电豹猫)',
      'https://avatars.githubusercontent.com/u/19224718',
      FlutterI18n.translate(context, 'setting.about_page.hhzm'),
      'https://hhzm.win/',
    ),
    Developer(
      'imoscarz',
      'https://avatars.githubusercontent.com/u/52318095',
      FlutterI18n.translate(context, 'setting.about_page.imoscarz'),
      'https://imoscarz.me/',
    ),
    Developer(
      'Ka-mate-ka-ora',
      'https://avatars.githubusercontent.com/u/187651078',
      FlutterI18n.translate(context, 'setting.about_page.ka-mate-ka-ora'),
      'https://github.com/Ka-mate-ka-ora/',
    ),
    Developer(
      'lhx-666-cool',
      'https://avatars.githubusercontent.com/u/63273792',
      FlutterI18n.translate(context, 'setting.about_page.lhx-666-cool'),
      'https://github.com/lhx-666-cool/',
    ),
    Developer(
      'LichtYy',
      'https://avatars.githubusercontent.com/u/105974550',
      FlutterI18n.translate(context, 'setting.about_page.lichtyy'),
      'https://github.com/lichtYy',
    ),
    Developer(
      'LQSY-H',
      'https://avatars.githubusercontent.com/u/142521812',
      FlutterI18n.translate(context, 'setting.about_page.lqsy-h'),
      'https://github.com/LQSY-H',
    ),
    Developer(
      'lsy223622 (木生睡不着)',
      'https://avatars.githubusercontent.com/u/57913213',
      FlutterI18n.translate(context, 'setting.about_page.lsy223622'),
      'https://lsy223622.com/',
    ),
    Developer(
      'MrBrilliant2046',
      'https://avatars.githubusercontent.com/u/94728421?v=4',
      FlutterI18n.translate(context, 'setting.about_page.mrbrilliant2046'),
      'https://github.com/MrBrilliant2046',
    ),
    Developer(
      'NanCunChild',
      'https://avatars.githubusercontent.com/u/85873278?v=4',
      FlutterI18n.translate(context, 'setting.about_page.nancunchild'),
      'https://github.com/NanCunChild',
    ),
    Developer(
      'Pairman',
      'https://avatars.githubusercontent.com/u/18365163',
      FlutterI18n.translate(context, 'setting.about_page.pairman'),
      'https://github.com/Pairman',
    ),
    Developer(
      'ReverierXu',
      'https://avatars.githubusercontent.com/u/41937333',
      FlutterI18n.translate(context, 'setting.about_page.reverierxu'),
      'https://blog.woooo.tech/',
    ),
    Developer(
      'Rrrilac',
      'https://avatars.githubusercontent.com/u/128341096',
      FlutterI18n.translate(context, 'setting.about_page.rrrilac'),
      'https://github.com/Rrrilac',
    ),
    Developer(
      'Ray Flores',
      'https://sns-avatar-qc.xhscdn.com/avatar/65fb96e24f8a7c5709c421f2.jpg',
      FlutterI18n.translate(context, 'setting.about_page.ray'),
      'https://www.xiaohongshu.com/user/profile/63d293990000000026010075',
    ),
    Developer(
      'shadowyingyi',
      'https://avatars.githubusercontent.com/u/42831635',
      FlutterI18n.translate(context, 'setting.about_page.shadowyingyi'),
      'https://github.com/shadowyingyi',
    ),
    Developer(
      'stalomeow',
      'https://avatars.githubusercontent.com/u/47203031',
      FlutterI18n.translate(context, 'setting.about_page.stalomeow'),
      'https://stalomeow.com',
    ),
    Developer(
      'xeonds',
      'https://avatars.githubusercontent.com/u/68117734',
      FlutterI18n.translate(context, 'setting.about_page.xeonds'),
      'https://mxts.jiujiuer.xyz',
    ),
    Developer(
      'XingShuyu',
      'https://avatars.githubusercontent.com/u/82715884',
      FlutterI18n.translate(context, 'setting.about_page.xingshuyu'),
      'https://xingshuyu.github.io',
    ),
    Developer(
      'Xiue233',
      'https://avatars.githubusercontent.com/u/30972246',
      FlutterI18n.translate(context, 'setting.about_page.xiue233'),
      'https://xiue233.github.io/',
    ),
    Developer(
      'xizi',
      'https://static.wikia.nocookie.net/chiikawa/images/c/c3/Hachi_main.png/revision/latest?cb=20231016011752&path-prefix=zh',
      FlutterI18n.translate(context, 'setting.about_page.xizi'),
      'https://www.bilibili.com/video/BV1Rg4y1x7su/',
    ),
    Developer(
      'wirsbf',
      'https://avatars.githubusercontent.com/u/144008530',
      FlutterI18n.translate(context, 'setting.about_page.wirsbf'),
      'https://xiue233.github.io/',
    ),
    Developer(
      'ZCWzy',
      'https://avatars.githubusercontent.com/u/87163986',
      FlutterI18n.translate(context, 'setting.about_page.zcwzy'),
      'https://github.com/ZCWzy',
    ),
    Developer(
      'ZYar-er',
      'https://avatars.githubusercontent.com/u/95170599?v=4',
      FlutterI18n.translate(context, 'setting.about_page.zyar-er'),
      'https://github.com/ZYar-er',
    ),
  ];

  Widget _titleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'packages/watermeter/assets/icon.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.apps, size: 120);
          },
        ),
        const SizedBox(height: 12),
        Text(
          '感谢 XDYou 开发者与贡献者',
          style: TextStyle(fontSize: 16, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    ).padding(all: 24);
  }

  Widget _developerCard() {
    final developers = _developers();
    return ReXCard(
      title: Text(
        FlutterI18n.translate(
          context,
          'setting.acknowledgement',
          translationParams: {'developers': developers.length.toString()},
        ),
      ).padding(bottom: 8).center(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('致谢')),
      body: Builder(
        builder: (context) {
          final size = MediaQuery.sizeOf(context);
          final isWide = size.width > 600 && size.width / size.height > 1;
          if (isWide) {
            return Column(children: [_titleBlock(), _developerCard()])
                .padding(horizontal: 16, vertical: 8)
                .scrollable()
                .constrained(maxWidth: 900)
                .center();
          }
          return Column(
                children: [_titleBlock(), _developerCard().padding(bottom: 18)],
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
