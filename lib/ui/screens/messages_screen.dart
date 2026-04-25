// Messages screen: SMS inbox with full send/receive history
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import '../../database_helper.dart';
import '../../core/utils/phone_number_utils.dart';
import '../theme/app_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _filter = 'all';
  bool _isLoading = true;
  List<Map<String, dynamic>> _smsMessages = [];
  String? _selectedPhone;
  final _replyController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await DatabaseHelper.instance.getTodaySmsMessages();
      if (mounted) {
        setState(() {
          _smsMessages = messages;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply(String phoneNumber) async {
    final message = _replyController.text.trim();
    if (message.isEmpty) return;

    try {
      await Telephony.instance.sendSms(to: phoneNumber, message: message);
      await DatabaseHelper.instance.insertSmsMessage({
        'phone_number': PhoneNumberUtils.normalize(phoneNumber),
        'message': message,
        'direction': 'outgoing',
        'status': 'sent',
        'sent_at': DateTime.now().toIso8601String(),
      });
      _replyController.clear();
      await _loadMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredMessages() {
    if (_filter == 'incoming') {
      return _smsMessages.where((m) => m['direction'] == 'incoming').toList();
    } else if (_filter == 'outgoing') {
      return _smsMessages.where((m) => m['direction'] == 'outgoing').toList();
    }
    return _smsMessages;
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

    final filtered = _getFilteredMessages();
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
            filtered.isEmpty ? 'No messages yet' : '${filtered.length} messages today',
            style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _FilterTab(label: 'All', isActive: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
              const SizedBox(width: 8),
              _FilterTab(label: 'Incoming', isActive: _filter == 'incoming', onTap: () => setState(() => _filter = 'incoming')),
              const SizedBox(width: 8),
              _FilterTab(label: 'Outgoing', isActive: _filter == 'outgoing', onTap: () => setState(() => _filter = 'outgoing')),
            ],
          ),
          const SizedBox(height: 16),
          if (uniquePhones.length > 1 && _filter == 'all')
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: uniquePhones.length,
                itemBuilder: (_, i) {
                  final phone = uniquePhones[i];
                  final isSelected = _selectedPhone == phone;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPhone = isSelected ? null : phone),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.muted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        phone,
                        style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.mutedForeground),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (uniquePhones.length > 1 && _filter == 'all') const SizedBox(height: 16),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.sms, size: 48, color: AppColors.mutedForeground.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text('No SMS messages yet', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
                ],
              ),
            )
          else
            ...filtered.map((msg) {
              final phone = msg['phone_number'] as String? ?? '';
              final message = msg['message'] as String? ?? '';
              final direction = msg['direction'] as String? ?? 'incoming';
              final sentAt = msg['sent_at'] as String? ?? '';
              final isIncoming = direction == 'incoming';

              if (_selectedPhone != null && phone != _selectedPhone) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isIncoming ? AppColors.primary.withValues(alpha: 0.3) : AppColors.statusOperating.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(isIncoming ? Icons.call_received : Icons.call_made, size: 16, color: isIncoming ? AppColors.primary : AppColors.statusOperating),
                            const SizedBox(width: 8),
                            Text(phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                          ],
                        ),
                        Text(_formatTime(sentAt), style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(message, style: const TextStyle(fontSize: 14, color: AppColors.foreground)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => _showReplyDialog(phone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
                          child: const Text('Reply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showReplyDialog(String phoneNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Reply to $phoneNumber', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _replyController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                decoration: const InputDecoration(hintText: 'Type your reply...', hintStyle: TextStyle(color: AppColors.mutedForeground), border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _sendReply(phoneNumber);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Send', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String sentAt) {
    try {
      final dt = DateTime.parse(sentAt);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
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