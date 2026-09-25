import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:xdu_treehole_web/core/config/app_config.dart';
import '../../../design_system/design_system.dart';

/// A real-name avatar: the design-system rounded square, with the photo
/// cached on device. [radius] is half the side, as before.
class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String nickname;
  final double radius;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    required this.nickname,
    this.radius = 30,
  });

  @override
  Widget build(BuildContext context) {
    final double size = radius * 2;
    final String resolved = avatarUrl?.trim().isNotEmpty == true
        ? AppConfig.resolveUrl(avatarUrl!)
        : '';
    final Widget initial = ZxAvatar(
      name: nickname.trim().isEmpty ? '匿' : nickname,
      size: size,
    );
    if (resolved.isEmpty) return initial;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => initial,
        errorWidget: (_, _, _) => initial,
      ),
    );
  }
}
