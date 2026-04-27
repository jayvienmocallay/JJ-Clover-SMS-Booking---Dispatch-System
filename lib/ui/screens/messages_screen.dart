// Messages screen: SMS inbox with full send/receive history
import 'dart:async';
import 'package:flutter/material.dart';
import '../../database_helper.dart';
import '../../data/services/app_event_bus.dart';
import '../theme/app_theme.dart';
import './chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _smsMessages = [];
  Map<String, String> _phoneToName = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadMessages());
    AppEventBus().onMessageReceived.listen((_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final results = await Future.wait([
        DatabaseHelper.instance.getTodaySmsMessages(),
        DatabaseHelper.instance.getCustomers(),
      ]);
      final messages = results[0];
      final customers = results[1];
      final phoneToName = <String, String>{};
      for (final c in customers) {
        final phone = c['contact_number'] as String? ?? '';
        final name = c['name'] as String? ?? '';
        if (phone.isNotEmpty && name.isNotEmpty) phoneToName[phone] = name;
      }
      if (mounted) {
        setState(() {
          _smsMessages = messages;
          _phoneToName = phoneToName;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _getUniquePhones() {
    return _smsMessages.map((m) => m['phone_number'] as String).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final uniquePhones = _getUniquePhones();

return RefreshIndicator(
      onRefresh: _loadMessages,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: _loadMessages,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            uniquePhones.isEmpty ? 'No conversations' : '${uniquePhones.length} ${uniquePhones.length == 1 ? 'conversation' : 'conversations'}',
            style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 16),
          if (uniquePhones.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.forum_outlined, size: 48, color: AppColors.mutedForeground.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text('No SMS conversations yet', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
                ],
              ),
            )
          else
            ...uniquePhones.map((phone) {
              final phoneMsgs = _smsMessages.where((m) => m['phone_number'] == phone).toList();
              if (phoneMsgs.isEmpty) return const SizedBox.shrink();

              phoneMsgs.sort((a, b) {
                final timeA = DateTime.tryParse(a['sent_at'] as String? ?? '') ?? DateTime.now();
                final timeB = DateTime.tryParse(b['sent_at'] as String? ?? '') ?? DateTime.now();
                return timeB.compareTo(timeA);
              });

              final lastMsg = phoneMsgs.first;
              final displayName = _phoneToName[phone];
              final message = lastMsg['message'] as String? ?? '';
              final direction = lastMsg['direction'] as String? ?? 'incoming';
              final sentAt = lastMsg['sent_at'] as String? ?? '';
              final isIncoming = direction == 'incoming';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        phoneNumber: phone,
                        contactName: displayName,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.3), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (displayName ?? phone).substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName ?? phone,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedForeground.withValues(alpha: 0.8),
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTimeShort(sentAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            isIncoming ? Icons.call_received : Icons.call_made,
                            size: 14,
                            color: isIncoming ? AppColors.primary : AppColors.statusOperating,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatTimeShort(String sentAt) {
    try {
      final dt = DateTime.parse(sentAt);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return '';
    }
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterTab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: isActive ? AppColors.primary : AppColors.muted, borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isActive ? Colors.white : AppColors.mutedForeground)),
      ),
    );
  }
}