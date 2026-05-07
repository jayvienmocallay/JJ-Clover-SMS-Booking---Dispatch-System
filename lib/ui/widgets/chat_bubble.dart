// Chat bubble widget for individual messages
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isIncoming;
  final String timestamp;
  final String status;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isIncoming,
    required this.timestamp,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isIncoming ? AppColors.of(context).muted : AppColors.of(context).primary;
    final textColor = isIncoming ? AppColors.of(context).foreground : Colors.white;

    return Align(
      alignment: isIncoming ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isIncoming ? const Radius.circular(4) : const Radius.circular(18),
            bottomRight: isIncoming ? const Radius.circular(18) : const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: textColor,
                height: 1.4,
              ),
            ),
            if (_isDeliveryKeyword(message))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _buildKeywordBadge(message),
              ),
          ],
        ),
      ),
    );
  }

  bool _isDeliveryKeyword(String text) {
    return text.contains(RegExp(r'DELIVER\s+\d+|DROP\s+\d+', caseSensitive: false));
  }

  Widget _buildKeywordBadge(String text) {
    final match = RegExp(r'(DELIVER|DROP)\s+(\d+)', caseSensitive: false).firstMatch(text);
    if (match == null) return const SizedBox.shrink();

    final keyword = match.group(1)?.toUpperCase() ?? '';
    final number = match.group(2) ?? '';
    final bgColor = keyword == 'DELIVER' ? AppColors.statusOperating : AppColors.statusAwayLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$keyword $number',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: bgColor,
        ),
      ),
    );
  }
}
