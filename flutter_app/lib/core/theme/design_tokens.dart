import 'package:flutter/material.dart';

/// Flutter Web 统一设计令牌。
///
/// 页面只消费这些语义值，避免在业务组件中重复定义断点、间距和圆角。
class AppBreakpoints {
  AppBreakpoints._();

  static const double compact = 600;
  static const double medium = 801;
  static const double expanded = 1200;
  static const double wide = 1440;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isMedium(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return width >= compact && width < medium;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

class AppRadii {
  AppRadii._();

  static const double small = 8;
  static const double medium = 12;
  static const double large = 24;
  static const double hero = 24;
  static const double pill = 999;
}

class AppLayout {
  AppLayout._();

  // reference-ai.css: 493 rail + 1357 main + 146 trailing space.
  // reference-pages.css: 888 feed, left edge 493 + 61 = (1996-888)/2.
  static const double referenceWidth = 1996;
  static const double referenceRail = 493;
  static const double referenceMain = 1357;
  static const double referenceFeed = 888;

  static double shellScale(double viewportWidth) =>
      viewportWidth / referenceWidth;

  static const double pageMaxWidth = 1440;
  static const double contentMaxWidth = 1280;
  static const double readingMaxWidth = 760;
  static const double formMaxWidth = 680;
  static const double authMaxWidth = 1080;
  static const double sidebarWidth = 216;
  static const double asideWidth = 280;

  static EdgeInsets pagePadding(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.expanded) {
      return const EdgeInsets.symmetric(
        horizontal: 28,
        vertical: AppSpacing.lg,
      );
    }
    if (width >= AppBreakpoints.compact) {
      return const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      );
    }
    return const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    );
  }
}

class AppElevation {
  AppElevation._();

  static List<BoxShadow> soft(Color color) => const <BoxShadow>[];
}
