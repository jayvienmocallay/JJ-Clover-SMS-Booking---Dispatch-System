// Modern chat interface: SMS conversations with bubble-based layout
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telephony/telephony.dart';
import '../../core/utils/phone_number_utils.dart';
import '../../data/repositories/sms_message_repository.dart';
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
  StreamSubscription? _messageSub;
  bool _isComposing = false;
  int _lastMessageCount = 0;
  final _expandedTimestamps = <String>{};
  late final SmsMessageRepository _smsRepo;

  @override
  void initState() {
    super.initState();
    _smsRepo = context.read<SmsMessageRepository>();
    _loadMessages(isInitial: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadMessages(isInitial: false));
    _messageSub = AppEventBus().onMessageReceived.listen((_) {
      _loadMessages(isInitial: false, isNewMessage: true);
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
    _messageSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool isInitial = false, bool isNewMessage = false}) async {
    try {
      final messages = await _smsRepo.getSmsMessagesForPhone(widget.phoneNumber);
      final sorted = messages.toList()..sort((a, b) {
        final timeA = DateTime.tryParse(a['sent_at'] as String? ?? '') ?? DateTime(2000);
        final timeB = DateTime.tryParse(b['sent_at'] as String? ?? '') ?? DateTime(2000);
        return timeA.compareTo(timeB);
      });
      if (mounted) {
        final newMessageCount = sorted.length;
        setState(() {
          _messages = sorted;
          _isLoading = false;
        });
        if (isInitial) {
          _scrollToBottom();
        } else if (isNewMessage || newMessageCount > _lastMessageCount) {
          _scrollToBottom();
        }
        _lastMessageCount = newMessageCount;
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
      await _smsRepo.insertSmsMessage({
        'phone_number': PhoneNumberUtils.normalize(widget.phoneNumber),
        'message': message,
        'direction': 'outgoing',
        'status': 'sent',
        'sent_at': DateTime.now().toIso8601String(),
      });
      await _loadMessages(isNewMessage: true);
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

  void _toggleTimestamp(String sentAt) {
    setState(() {
      if (_expandedTimestamps.contains(sentAt)) {
        _expandedTimestamps.remove(sentAt);
      } else {
        _expandedTimestamps.add(sentAt);
      }
    });
  }

  List<Map<String, dynamic>> _buildDisplayList(List<Map<String, dynamic>> messages) {
    final result = <Map<String, dynamic>>[];
    DateTime? lastDate;

    for (final msg in messages) {
      final dt = DateTime.parse(msg['sent_at'] as String? ?? '');
      final msgDate = DateTime(dt.year, dt.month, dt.day);

      if (lastDate == null || msgDate != lastDate) {
        result.add({'_isDateDivider': true, 'sent_at': msg['sent_at']});
        lastDate = msgDate;
      }
      result.add(msg);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        appBar: AppBar(backgroundColor: AppColors.of(context).background),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.of(context).primary),
        ),
      );
    }

    final displayList = _buildDisplayList(_messages);

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
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
                          color: AppColors.of(context).mutedForeground.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.of(context).mutedForeground.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.of(context).mutedForeground.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final item = displayList[index];

                      if (item['_isDateDivider'] == true) {
                        return _buildDateDivider(item['sent_at'] as String);
                      }

                      final message = item['message'] as String? ?? '';
                      final direction = item['direction'] as String? ?? 'incoming';
                      final sentAt = item['sent_at'] as String? ?? '';
                      final status = item['status'] as String? ?? '';
                      final isIncoming = direction == 'incoming';
                      final isExpanded = _expandedTimestamps.contains(sentAt);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: isIncoming ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => _toggleTimestamp(sentAt),
                              child: ChatBubble(
                                message: message,
                                isIncoming: isIncoming,
                                timestamp: sentAt,
                                status: status,
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              child: isExpanded
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                                      child: Text(
                                        _formatTime(sentAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.of(context).mutedForeground.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
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

  Widget _buildDateDivider(String sentAt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: AppColors.of(context).border.withValues(alpha: 0.4), thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.of(context).muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatDateOnly(sentAt),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.of(context).mutedForeground,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(color: AppColors.of(context).border.withValues(alpha: 0.4), thickness: 1),
          ),
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
