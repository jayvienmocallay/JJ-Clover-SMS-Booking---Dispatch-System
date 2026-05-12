// Chat header with contact info and action buttons
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'customer_info_sheet.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  final String contactName;
  final String phoneNumber;
  final VoidCallback? onCreateOrder;

  const ChatHeader({
    super.key,
    required this.contactName,
    required this.phoneNumber,
    this.onCreateOrder,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _openDialer() async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) debugPrint('Could not open dialer for $phoneNumber');
    } catch (e) {
      debugPrint('Could not open dialer: $e');
    }
  }

  void _showContactInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CustomerInfoSheet(
        phoneNumber: phoneNumber,
        contactName: contactName,
        onCreateOrder: onCreateOrder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.of(context).card,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.of(context).foreground),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            contactName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.of(context).foreground,
            ),
          ),
          Text(
            phoneNumber,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.of(context).mutedForeground,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.call_outlined, color: AppColors.of(context).primary),
          onPressed: _openDialer,
          tooltip: 'Call customer',
        ),
        IconButton(
          icon: Icon(Icons.info_outlined, color: AppColors.of(context).primary),
          onPressed: () => _showContactInfo(context),
          tooltip: 'Contact details',
        ),
      ],
    );
  }
}
