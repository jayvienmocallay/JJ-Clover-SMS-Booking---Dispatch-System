// Modern chat interface: SMS conversations with bubble-based layout
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/phone_number_utils.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/repositories/sms_message_repository.dart';
import '../../data/services/app_event_bus.dart';
import '../../data/services/native_sms_sender.dart';
import '../theme/app_theme.dart';
import '../widgets/add_order_form.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_header.dart';
import '../widgets/message_input.dart';
import '../widgets/shared/brand_mascot.dart';
import '../widgets/shared/empty_state.dart';

class ChatScreen extends StatefulWidget {
  final String phoneNumber;
  final String? contactName;

  const ChatScreen({super.key, required this.phoneNumber, this.contactName});

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
  final _expandedMessageKeys = <String>{};
  late final SmsMessageRepository _smsRepo;

  @override
  void initState() {
    super.initState();
    _smsRepo = context.read<SmsMessageRepository>();
    _loadMessages(isInitial: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadMessages(isInitial: false),
    );
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

  Future<void> _loadMessages({
    bool isInitial = false,
    bool isNewMessage = false,
  }) async {
    try {
      final messages = await _smsRepo.getSmsMessagesForPhone(
        widget.phoneNumber,
      );
      final indexedMessages = messages.asMap().entries.toList()
        ..sort((a, b) {
          final timeCompare = _messageSortDate(
            a.value,
          ).compareTo(_messageSortDate(b.value));
          if (timeCompare != 0) return timeCompare;
          return a.key.compareTo(b.key);
        });
      final sorted = indexedMessages.map((entry) => entry.value).toList();
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

  void _openAddOrderForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<OrderProvider>()),
          ChangeNotifierProvider.value(value: context.read<CustomerProvider>()),
        ],
        child: AddOrderForm(prefilledPhone: widget.phoneNumber),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    setState(() => _isComposing = false);

    final messageId = await _smsRepo.insertSmsMessage({
      'phone_number': PhoneNumberUtils.normalize(widget.phoneNumber),
      'message': message,
      'direction': 'outgoing',
      'status': 'sending',
      'sent_at': DateTime.now().toIso8601String(),
    });
    AppEventBus().notifyMessageReceived();
    await _loadMessages(isNewMessage: true);
    await _sendExistingMessage(messageId, message, showSuccess: true);
  }

  Future<void> _sendExistingMessage(
    int messageId,
    String message, {
    bool showSuccess = false,
  }) async {
    try {
      final queued = await _smsRepo.updateSmsMessageStatus(
        messageId,
        'sending',
      );
      if (queued == 0) {
        throw StateError('Message was not queued for sending.');
      }
      await _loadMessages(isNewMessage: true);
      await NativeSmsSender.sendSms(to: widget.phoneNumber, message: message);
      final markedSent = await _smsRepo.updateSmsMessageStatus(
        messageId,
        'sent',
      );
      if (markedSent == 0) {
        throw StateError('Message was sent, but local status was not updated.');
      }
      AppEventBus().notifyMessageReceived();
      await _loadMessages(isNewMessage: true);
      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      await _smsRepo.updateSmsMessageStatus(messageId, 'failed');
      AppEventBus().notifyMessageReceived();
      await _loadMessages(isNewMessage: true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send SMS: $e')));
      }
    }
  }

  Future<void> _retryMessage(Map<String, dynamic> message) async {
    final id = message['id'] as int?;
    final body = message['message'] as String? ?? '';
    if (id == null || body.trim().isEmpty) return;
    await _sendExistingMessage(id, body, showSuccess: true);
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final id = message['id'] as int?;
    if (id == null) return;
    final deleted = await _smsRepo.deleteSmsMessage(id);
    if (!mounted) return;
    if (deleted == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message was not deleted.')));
      return;
    }
    AppEventBus().notifyMessageReceived();
    await _loadMessages();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted from local history')),
      );
    }
  }

  Future<bool> _confirmDeleteMessage(Map<String, dynamic> message) async {
    final preview = (message['message'] as String? ?? '').trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.of(context).card,
        title: Text(
          'Delete this message?',
          style: TextStyle(color: AppColors.of(context).foreground),
        ),
        content: Text(
          'This removes the message from this app only. It does not delete the SMS from the phone inbox or the customer device.\n\n${preview.length > 120 ? '${preview.substring(0, 120)}...' : preview}',
          style: TextStyle(color: AppColors.of(context).mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusMaintenance,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmAndDeleteMessage(Map<String, dynamic> message) async {
    if (await _confirmDeleteMessage(message)) {
      await _deleteMessage(message);
    }
  }

  void _toggleExpandedMessage(String messageKey) {
    setState(() {
      if (_expandedMessageKeys.contains(messageKey)) {
        _expandedMessageKeys.remove(messageKey);
      } else {
        _expandedMessageKeys.add(messageKey);
      }
    });
  }

  List<Map<String, dynamic>> _buildDisplayList(
    List<Map<String, dynamic>> messages,
  ) {
    final result = <Map<String, dynamic>>[];
    String? lastDateKey;

    for (final msg in messages) {
      final sentAt = msg['sent_at'] as String? ?? '';
      final dt = DateTime.tryParse(sentAt);
      final dateKey = dt == null
          ? 'unknown'
          : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

      if (lastDateKey != dateKey) {
        result.add({
          '_isDateDivider': true,
          'sent_at': sentAt,
          'label': dt == null ? 'Unknown date' : null,
        });
        lastDateKey = dateKey;
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
          child: CircularProgressIndicator(
            color: AppColors.of(context).primary,
          ),
        ),
      );
    }

    final displayList = _buildDisplayList(_messages);

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: ChatHeader(
        contactName: widget.contactName ?? 'Unknown',
        phoneNumber: widget.phoneNumber,
        onCreateOrder: () => _openAddOrderForm(context),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyConversation()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final item = displayList[index];

                      if (item['_isDateDivider'] == true) {
                        return _buildDateDivider(
                          item['sent_at'] as String? ?? '',
                          label: item['label'] as String?,
                        );
                      }

                      final message = item['message'] as String? ?? '';
                      final direction =
                          item['direction'] as String? ?? 'incoming';
                      final sentAt = item['sent_at'] as String? ?? '';
                      final status = item['status'] as String? ?? '';
                      final isIncoming = direction == 'incoming';
                      final messageKey = _messageExpansionKey(item, index);
                      final isExpanded = _expandedMessageKeys.contains(
                        messageKey,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: isIncoming
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => _toggleExpandedMessage(messageKey),
                              onLongPress: () => _confirmAndDeleteMessage(item),
                              child: ChatBubble(
                                message: message,
                                isIncoming: isIncoming,
                                timestamp: sentAt,
                                status: status,
                                onRetry:
                                    !isIncoming &&
                                        status.toLowerCase() == 'failed'
                                    ? () => _retryMessage(item)
                                    : null,
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              child: isExpanded
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        left: 4,
                                        right: 4,
                                      ),
                                      child: Text(
                                        _formatTime(sentAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.of(context)
                                              .mutedForeground
                                              .withValues(alpha: 0.6),
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

  Widget _buildDateDivider(String sentAt, {String? label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.of(context).border.withValues(alpha: 0.4),
              thickness: 1,
            ),
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
                label ?? _formatDateOnly(sentAt),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.of(context).mutedForeground,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: AppColors.of(context).border.withValues(alpha: 0.4),
              thickness: 1,
            ),
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
      return 'Unknown time';
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
      return 'Unknown date';
    }
  }

  DateTime _messageSortDate(Map<String, dynamic> message) {
    return DateTime.tryParse(message['sent_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _messageExpansionKey(Map<String, dynamic> message, int index) {
    final id = message['id'];
    if (id != null) return 'id:$id';

    final sourceMessageId = message['source_message_id'] as String? ?? '';
    if (sourceMessageId.isNotEmpty) return 'source:$sourceMessageId';

    final sentAt = message['sent_at'] as String? ?? '';
    final direction = message['direction'] as String? ?? '';
    final body = message['message'] as String? ?? '';
    return 'fallback:$index:$sentAt:$direction:$body';
  }
}

class _EmptyConversation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: EmptyState(
        icon: Icons.forum_outlined,
        mascot: MascotPose.smsConfirm,
        title: 'No messages yet',
        message: 'Start a conversation',
      ),
    );
  }
}
