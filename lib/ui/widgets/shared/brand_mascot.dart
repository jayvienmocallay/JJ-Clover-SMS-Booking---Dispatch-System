import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum MascotPose { waterBottle, smsConfirm, deliveryTruck, checklist }

extension MascotPoseDetails on MascotPose {
  String get assetPath {
    switch (this) {
      case MascotPose.waterBottle:
        return 'assets/mascots/mascot-water-bottle.png';
      case MascotPose.smsConfirm:
        return 'assets/mascots/mascot-sms-confirm.png';
      case MascotPose.deliveryTruck:
        return 'assets/mascots/mascot-delivery-truck.png';
      case MascotPose.checklist:
        return 'assets/mascots/mascot-checklist.png';
    }
  }

  String get semanticLabel {
    switch (this) {
      case MascotPose.waterBottle:
        return 'JJ Clover mascot carrying water';
      case MascotPose.smsConfirm:
        return 'JJ Clover mascot confirming an SMS';
      case MascotPose.deliveryTruck:
        return 'JJ Clover mascot beside a delivery truck';
      case MascotPose.checklist:
        return 'JJ Clover mascot holding a checklist';
    }
  }
}

class MascotImage extends StatelessWidget {
  final MascotPose pose;
  final double size;
  final double opacity;
  final BoxFit fit;

  const MascotImage({
    super.key,
    required this.pose,
    this.size = 96,
    this.opacity = 1,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final image = Image.asset(
      pose.assetPath,
      width: size,
      height: size,
      fit: fit,
      filterQuality: FilterQuality.medium,
      semanticLabel: pose.semanticLabel,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.water_drop, size: size * 0.58, color: palette.primary),
    );

    if (opacity >= 1) return image;

    return Opacity(opacity: opacity, child: image);
  }
}

class MascotBadge extends StatelessWidget {
  final MascotPose pose;
  final double size;

  const MascotBadge({super.key, required this.pose, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: palette.primaryLight,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: palette.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: MascotImage(pose: pose, size: size),
    );
  }
}

class MascotCallout extends StatelessWidget {
  final MascotPose pose;
  final String title;
  final String subtitle;
  final String? eyebrow;
  final Widget? trailing;

  const MascotCallout({
    super.key,
    required this.pose,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final mascotSize = isCompact ? 88.0 : 118.0;

        return Container(
          padding: const EdgeInsets.all(kCardPadding),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(kCardRadius),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow!.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.statusOperating,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.mutedForeground,
                        height: 1.35,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(height: 12),
                      trailing!,
                    ],
                  ],
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              MascotImage(pose: pose, size: mascotSize),
            ],
          ),
        );
      },
    );
  }
}
