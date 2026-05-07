import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double minHeight;

  const PrimaryActionButton({
    super.key,
    required this.label,
    this.onTap,
    this.backgroundColor,
    this.minHeight = 48,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(kButtonRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.15),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minHeight),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
