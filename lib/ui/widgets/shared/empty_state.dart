import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'brand_mascot.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final MascotPose? mascot;
  final String? title;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.mascot,
    this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (mascot != null)
                MascotImage(pose: mascot!, size: 116)
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: palette.muted,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.border),
                  ),
                  child: Icon(icon, size: 28, color: palette.mutedForeground),
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
                  color: palette.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ),
    );
  }
}
