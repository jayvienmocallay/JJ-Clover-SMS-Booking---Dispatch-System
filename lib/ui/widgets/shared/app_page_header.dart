import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontSize: 26),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.of(context).mutedForeground,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 12),
          // action can be a single icon button or a Row of buttons.
          // Individual buttons inside must maintain ≥44×44 tap targets.
          action!,
        ],
      ],
    );
  }
}
