// Chat header with contact info and action buttons
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  final String contactName;
  final String phoneNumber;
  final VoidCallback onCallPressed;
  final VoidCallback onInfoPressed;

  const ChatHeader({
    super.key,
    required this.contactName,
    required this.phoneNumber,
    required this.onCallPressed,
    required this.onInfoPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.card,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.foreground),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            contactName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          Text(
            phoneNumber,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_outlined, color: AppColors.primary),
          onPressed: onCallPressed,
          tooltip: 'Call',
        ),
        IconButton(
          icon: const Icon(Icons.info_outlined, color: AppColors.primary),
          onPressed: onInfoPressed,
          tooltip: 'Details',
        ),
      ],
    );
  }
}
