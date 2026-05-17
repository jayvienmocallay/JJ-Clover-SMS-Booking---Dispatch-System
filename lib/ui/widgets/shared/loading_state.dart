import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'brand_mascot.dart';

class LoadingState extends StatelessWidget {
  final String title;
  final String message;
  final MascotPose? mascot;

  const LoadingState({
    super.key,
    this.title = 'Loading',
    this.message = 'Please wait...',
    this.mascot,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mascot != null) ...[
              MascotBadge(pose: mascot!, size: 72),
              const SizedBox(height: 18),
            ],
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: palette.primary,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palette.mutedForeground),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
