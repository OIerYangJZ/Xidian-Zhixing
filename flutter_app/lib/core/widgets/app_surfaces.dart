import 'package:flutter/material.dart';

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
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(
          color: highlighted
              ? colors.primary.withValues(alpha: 0.28)
              : colors.line,
        ),
        boxShadow: elevated ? AppElevation.soft : const <BoxShadow>[],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppSealMark extends StatelessWidget {
  const AppSealMark({super.key, this.label = '知', this.size = 38});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.standard),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.onDarkPanel,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class AppStatusTag extends StatelessWidget {
  const AppStatusTag({
    super.key,
    required this.label,
    this.color,
    this.outlined = false,
  });

  final String label;
  final Color? color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Color effectiveColor = color ?? colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: outlined
            ? colors.surface.withValues(alpha: 0)
            : effectiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(
          color: effectiveColor.withValues(alpha: outlined ? 0.72 : 0.18),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: effectiveColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
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

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
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
          border: Border.all(color: color.withValues(alpha: 0.24)),
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
