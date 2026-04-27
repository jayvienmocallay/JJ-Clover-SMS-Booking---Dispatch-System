// Modern chat interface: SMS conversations with bubble-based layout
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import '../../database_helper.dart';
import '../../core/utils/phone_number_utils.dart';
import '../../data/services/app_event_bus.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_header.dart';
import '../widgets/message_input.dart';

class ChatScreen extends StatefulWidget {
  final String phoneNumber;
  final String? contactName;

  const ChatScreen({
    super.key,
    required this.phoneNumber,
    this.contactName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages());
    AppEventBus().onMessageReceived.listen((_) {
      _loadMessages();
    });
    _messageController.addListener(() {
      setState(() {
        _isComposing = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await DatabaseHelper.instance.getSmsMessagesForPhone(widget.phoneNumber);
      final sorted = messages.toList()..sort((a, b) {
        final timeA = DateTime.parse(a['sent_at'] as String? ?? '');
        final timeB = DateTime.parse(b['sent_at'] as String? ?? '');
        return timeA.compareTo(timeB);
      });
      if (mounted) {
        setState(() {
          _messages = sorted;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    setState(() => _isComposing = false);

    try {
      await Telephony.instance.sendSms(to: widget.phoneNumber, message: message);
      await DatabaseHelper.instance.insertSmsMessage({
        'phone_number': PhoneNumberUtils.normalize(widget.phoneNumber),
        'message': message,
        'direction': 'outgoing',
        'status': 'sent',
        'sent_at': DateTime.now().toIso8601String(),
      });
      await _loadMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      _messageController.text = message;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _groupMessagesByTime(List<Map<String, dynamic>> messages) {
    final grouped = <Map<String, dynamic>>[];
    for (int i = 0; i < messages.length; i++) {
      grouped.add(messages[i]);

      if (i < messages.length - 1) {
        final current = DateTime.parse(messages[i]['sent_at'] as String? ?? '');
        final next = DateTime.parse(messages[i + 1]['sent_at'] as String? ?? '');
        final diff = next.difference(current);

        if (diff.inMinutes > 15) {
          grouped.add({'_isTimestamp': true, 'sent_at': next.toIso8601String()});
        }
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final groupedMessages = _groupMessagesByTime(_messages);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ChatHeader(
        contactName: widget.contactName ?? 'Unknown',
        phoneNumber: widget.phoneNumber,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 56,
                          color: AppColors.mutedForeground.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.mutedForeground.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mutedForeground.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: groupedMessages.length,
                    itemBuilder: (context, index) {
                      final item = groupedMessages[index];

                      if (item['_isTimestamp'] == true) {
                        return _buildTimestampDivider(item['sent_at'] as String);
                      }

                      final message = item['message'] as String? ?? '';
                      final direction = item['direction'] as String? ?? 'incoming';
                      final sentAt = item['sent_at'] as String? ?? '';
                      final status = item['status'] as String? ?? '';
                      final isIncoming = direction == 'incoming';

                      bool showTimestamp = true;
                      if (index > 0) {
                        final prev = groupedMessages[index - 1];
                        if (prev['_isTimestamp'] != true) {
                          final prevTime = DateTime.parse(prev['sent_at'] as String? ?? '');
                          final currTime = DateTime.parse(sentAt);
                          showTimestamp = currTime.difference(prevTime).inMinutes > 5;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: isIncoming ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            ChatBubble(
                              message: message,
                              isIncoming: isIncoming,
                              timestamp: sentAt,
                              status: status,
                            ),
                            if (showTimestamp)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _formatTime(sentAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          MessageInput(
            controller: _messageController,
            isComposing: _isComposing,
            onSend: _sendMessage,
            phoneNumber: widget.phoneNumber,
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampDivider(String sentAt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.border.withValues(alpha: 0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDateOnly(sentAt),
              style: TextStyle(fontSize: 12, color: AppColors.mutedForeground.withValues(alpha: 0.6)),
            ),
          ),
          Expanded(child: Container(height: 1, color: AppColors.border.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  String _formatTime(String sentAt) {
    try {
      final dt = DateTime.parse(sentAt);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return '';
    }
  }

  String _formatDateOnly(String sentAt) {
    try {
      final dt = DateTime.parse(sentAt);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDate = DateTime(dt.year, dt.month, dt.day);

      if (msgDate == today) return 'Today';
      if (msgDate == yesterday) return 'Yesterday';
      return '${dt.month}/${dt.day}/${dt.year.toString().substring(2)}';
    } catch (_) {
      return '';
    }
  }
}
