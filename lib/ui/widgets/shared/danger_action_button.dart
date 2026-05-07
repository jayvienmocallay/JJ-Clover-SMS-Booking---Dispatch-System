import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'primary_action_button.dart';

class DangerActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const DangerActionButton({
    super.key,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryActionButton(
      label: label,
      onTap: onTap,
      backgroundColor: AppColors.statusMaintenance,
    );
  }
}
