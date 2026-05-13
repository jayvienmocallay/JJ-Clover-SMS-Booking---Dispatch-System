import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'brand_mascot.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final MascotPose? mascot;
  final String? title;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.mascot,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (mascot != null)
              MascotImage(pose: mascot!, size: 116)
            else
              Icon(
                icon,
                size: 48,
                color: AppColors.of(
                  context,
                ).mutedForeground.withValues(alpha: 0.4),
              ),
            const SizedBox(height: 12),
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.of(context).mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
