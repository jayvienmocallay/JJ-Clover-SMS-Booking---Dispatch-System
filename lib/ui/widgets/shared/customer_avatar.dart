import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CustomerAvatar extends StatelessWidget {
  final String name;
  final double size;

  const CustomerAvatar({
    super.key,
    required this.name,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.of(context).primaryLight,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.of(context).primary,
          ),
        ),
      ),
    );
  }
}
