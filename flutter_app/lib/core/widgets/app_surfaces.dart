import 'package:flutter/material.dart';

import '../config/app_brand.dart';
import '../theme/design_tokens.dart';
import '../theme/shared_colors.dart';

class AppPageFrame extends StatelessWidget {
  const AppPageFrame({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.contentMaxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? AppLayout.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.highlighted = false,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool highlighted;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.standard),
      curve: AppMotion.emphasis,
      decoration: BoxDecoration(
        color: highlighted ? colors.primarySubtle : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(elevated ? AppRadii.large : 0),
        boxShadow: elevated ? AppElevation.soft : const <BoxShadow>[],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A flat interactive surface. It preserves the open page rhythm while making
/// hover and tap state obvious on pointer-based devices.
class AppHoverSurface extends StatefulWidget {
  const AppHoverSurface({
    super.key,
    required this.child,
    this.onTap,
    this.radius = AppRadii.medium,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  @override
  State<AppHoverSurface> createState() => _AppHoverSurfaceState();
}

/// Opens the product's single, centred overlay surface.
///
/// Selection and action flows use this presentation across the web app so
/// they never slide up from the bottom of the viewport.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 480,
  double? maxHeight,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext dialogContext) {
      final EditorialColors colors = EditorialColors.of(dialogContext);
      final Size viewport = MediaQuery.sizeOf(dialogContext);
      return Dialog(
        backgroundColor: colors.surface.withValues(alpha: 0),
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight ?? viewport.height - AppSpacing.xl * 2,
          ),
          child: Material(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadii.large),
            clipBehavior: Clip.antiAlias,
            child: builder(dialogContext),
          ),
        ),
      );
    },
  );
}

class _AppHoverSurfaceState extends State<AppHoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(widget.radius);
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.emphasis,
        decoration: BoxDecoration(
          color: _hovered ? colors.surfaceHover : colors.surfaceRaised,
          borderRadius: borderRadius,
        ),
        child: Material(
          color: colors.surface.withValues(alpha: 0),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: borderRadius,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The single visual brand mark used by every user-facing entry point.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({super.key, this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppBrand.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: AppBrand.displayName,
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actionLabel != null)
          onAction == null
              ? Text(actionLabel!, style: Theme.of(context).textTheme.bodySmall)
              : TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// A flat comment-tree item used by discussion pages. Root items are separated
/// by a divider; replies inherit a vertical rail and a short branch connector.
class AppThreadBranch extends StatelessWidget {
  const AppThreadBranch({super.key, required this.depth, required this.child});

  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final bool hasParent = depth > 0;
    return Padding(
      padding: EdgeInsets.only(
        left: hasParent ? AppThread.indent : 0,
        top: AppSpacing.sm,
      ),
      child: Stack(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: hasParent
                    ? BorderSide.none
                    : BorderSide(color: colors.line),
                left: hasParent
                    ? BorderSide(color: colors.line, width: AppThread.railWidth)
                    : BorderSide.none,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                hasParent ? AppThread.indent : 0,
                AppSpacing.md,
                0,
                AppSpacing.sm,
              ),
              child: child,
            ),
          ),
          if (hasParent)
            Positioned(
              left: 0,
              top: AppThread.connectorTop,
              child: SizedBox(
                width: AppThread.connectorLength,
                height: AppThread.railWidth,
                child: ColoredBox(color: colors.line),
              ),
            ),
        ],
      ),
    );
  }
}

enum AppMessageTone { info, success, warning, error }

class AppInlineMessage extends StatelessWidget {
  const AppInlineMessage({
    super.key,
    required this.message,
    this.title,
    this.tone = AppMessageTone.info,
    this.action,
  });

  final String message;
  final String? title;
  final AppMessageTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Color color = switch (tone) {
      AppMessageTone.info => colors.info,
      AppMessageTone.success => colors.success,
      AppMessageTone.warning => colors.warning,
      AppMessageTone.error => colors.danger,
    };
    final IconData icon = switch (tone) {
      AppMessageTone.info => Icons.info_outline_rounded,
      AppMessageTone.success => Icons.check_circle_outline_rounded,
      AppMessageTone.warning => Icons.warning_amber_rounded,
      AppMessageTone.error => Icons.error_outline_rounded,
    };

    return Semantics(
      liveRegion: tone == AppMessageTone.error,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title != null)
                    Text(
                      title!,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (title != null) const SizedBox(height: AppSpacing.xxs),
                  Text(message, style: TextStyle(color: color, height: 1.45)),
                ],
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppStatePanel extends StatelessWidget {
  const AppStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EditorialColors colors = EditorialColors.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: compact ? 52 : 68,
                height: compact ? 52 : 68,
                decoration: BoxDecoration(
                  color: colors.primarySubtle,
                  borderRadius: BorderRadius.circular(
                    compact ? AppRadii.medium : AppRadii.large,
                  ),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                  size: compact ? 26 : 32,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
