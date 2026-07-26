import 'package:flutter/material.dart';

/// Breakpoints shared by every Flutter Web feature.
class AppBreakpoints {
  AppBreakpoints._();

  static const double compact = 600;
  static const double medium = 960;
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

/// Geometry is intentionally small and consistent: content surfaces, controls
/// and pills each have one role-specific radius.
class AppRadii {
  AppRadii._();

  static const double small = 8;
  static const double medium = 10;
  static const double large = 12;
  static const double input = 16;
  static const double hero = 16;
  static const double pill = 999;
}

class AppLayout {
  AppLayout._();

  static const double pageMaxWidth = 1440;
  static const double contentMaxWidth = 1184;
  static const double readingMaxWidth = 680;
  static const double formMaxWidth = 680;
  static const double authMaxWidth = 1080;
  static const double sidebarWidth = 248;
  static const double compactSidebarWidth = 84;
  static const double asideWidth = 304;

  static EdgeInsets pagePadding(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.expanded) {
      return const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
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

  static const List<BoxShadow> soft = <BoxShadow>[];
}

/// Shared geometry for continuous discussion threads. Comment content stays
/// aligned while the gutter renders the parent-child relationship as rails
/// and connectors.
class AppThread {
  AppThread._();

  static const double railWidth = 2;
  static const double avatarDiameter = 36;
  static const int maxVisibleDepth = 3;
  static const double levelOffset = AppSpacing.xs;
  static const double contentGutter =
      AppSpacing.lg + maxVisibleDepth * levelOffset;
  static const double connectorTop = AppSpacing.md + avatarDiameter / 2;

  static int visibleDepth(int depth) {
    if (depth < 1) return 0;
    return depth > maxVisibleDepth ? maxVisibleDepth : depth;
  }

  static double railOffset(int level) => (level - 1) * levelOffset;
}

/// Shared interaction timing. Motion is only used to explain a state change.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration page = Duration(milliseconds: 240);
  static const Curve emphasis = Curves.easeOutCubic;
  static const Curve settle = Curves.easeOutQuart;

  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
