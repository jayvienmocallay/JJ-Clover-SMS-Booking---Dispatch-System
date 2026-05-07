import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget action;
  final bool isDanger;

  const SettingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isDanger
        ? AppColors.statusMaintenance
        : AppColors.foreground;
    return Container(
      padding: const EdgeInsets.all(kCardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(
          color: isDanger
              ? AppColors.statusMaintenance.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: accentColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          action,
        ],
      ),
    );
  }
}
