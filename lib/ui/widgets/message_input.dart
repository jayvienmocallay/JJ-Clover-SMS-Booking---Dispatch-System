// Message input field with send button
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isComposing;
  final VoidCallback onSend;
  final String phoneNumber;

  const MessageInput({
    super.key,
    required this.controller,
    required this.isComposing,
    required this.onSend,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Container(
        color: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.foreground,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(
                      color: AppColors.mutedForeground.withValues(alpha: 0.6),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: isComposing ? onSend : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isComposing ? AppColors.primary : AppColors.muted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: isComposing ? Colors.white : AppColors.mutedForeground,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
