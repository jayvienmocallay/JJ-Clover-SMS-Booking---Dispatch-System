// Chat bubble widget for individual messages
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isIncoming;
  final String timestamp;
  final String status;
  final VoidCallback? onRetry;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isIncoming,
    required this.timestamp,
    required this.status,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isIncoming ? AppColors.of(context).muted : AppColors.of(context).primary;
    final textColor = isIncoming ? AppColors.of(context).foreground : Colors.white;
    final normalizedStatus = status.toLowerCase();

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
            if (!isIncoming && normalizedStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _buildStatus(context, normalizedStatus),
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

  Widget _buildStatus(BuildContext context, String normalizedStatus) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.85),
    );

    switch (normalizedStatus) {
      case 'sending':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text('Sending', style: style),
          ],
        );
      case 'failed':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 4),
            Text('Failed', style: style),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Retry',
                    style: style.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      case 'sent':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.done,
              size: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 4),
            Text('Sent', style: style),
          ],
        );
      default:
        return Text(normalizedStatus, style: style);
    }
  }
}
