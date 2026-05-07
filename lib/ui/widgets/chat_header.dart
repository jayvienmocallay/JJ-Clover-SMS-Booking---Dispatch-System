// Chat header with contact info and action buttons
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import '../theme/app_theme.dart';
import 'customer_info_sheet.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  final String contactName;
  final String phoneNumber;

  const ChatHeader({
    super.key,
    required this.contactName,
    required this.phoneNumber,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _makePhoneCall() async {
    try {
      await Telephony.instance.dialPhoneNumber(phoneNumber);
    } catch (e) {
      debugPrint('Could not make phone call: $e');
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
          onPressed: _makePhoneCall,
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
