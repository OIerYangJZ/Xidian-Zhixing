import 'package:flutter/material.dart';

import 'package:xdu_treehole_web/design_system/design_system.dart';

/// 树洞 while the first page loads: post rows drawn with the design
/// system's skeleton (§06 骨架屏), so they follow the theme and dark mode.
class HomePageShimmer extends StatelessWidget {
  const HomePageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return ColoredBox(
      color: t.surface,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8),
        itemCount: 4,
        separatorBuilder: (_, _) => Divider(height: 1, color: t.line),
        itemBuilder: (_, int i) => const _PostRowSkeleton(),
      ),
    );
  }
}

class _PostRowSkeleton extends StatelessWidget {
  const _PostRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZxSkeleton(
            width: 40,
            height: 40,
            borderRadius: ZxRadius.smallButtonAll,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ZxSkeleton(width: 140),
                SizedBox(height: 10),
                ZxSkeleton(width: 96, height: 18),
                SizedBox(height: 12),
                ZxSkeleton(height: 16),
                SizedBox(height: 8),
                ZxSkeleton(width: 240),
                SizedBox(height: 14),
                ZxSkeleton(width: 180, height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
