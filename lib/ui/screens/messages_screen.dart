import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/sms_message_repository.dart';
import '../../data/services/app_event_bus.dart';
import '../theme/app_theme.dart';
import '../widgets/shared/app_page_header.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/brand_mascot.dart';
import '../widgets/shared/empty_state.dart';
import '../widgets/shared/loading_state.dart';
import '../widgets/shared/status_badge.dart';
import './chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _refreshPending = false;
  String? _error;
  List<Map<String, dynamic>> _smsMessages = [];
  Map<String, String> _phoneToName = {};
  StreamSubscription? _messageSub;
  late final SmsMessageRepository _smsRepo;
  late final CustomerRepository _customerRepo;

  @override
  void initState() {
    super.initState();
    _smsRepo = context.read<SmsMessageRepository>();
    _customerRepo = context.read<CustomerRepository>();
    _loadMessages();
    _messageSub = AppEventBus().onMessageReceived.listen((_) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!mounted) return;
    if (_isRefreshing) {
      _refreshPending = true;
      return;
    }
    _isRefreshing = true;
    try {
      final results = await Future.wait([
        _smsRepo.getAllSmsMessages(),
        _customerRepo.getCustomers(),
      ]);
      final phoneToName = <String, String>{};
      for (final c in results[1]) {
        final phone = c['contact_number'] as String? ?? '';
        final name = c['name'] as String? ?? '';
        if (phone.isNotEmpty && name.isNotEmpty) phoneToName[phone] = name;
      }
      if (!mounted) return;
      setState(() {
        _smsMessages = results[0];
        _phoneToName = phoneToName;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      _isRefreshing = false;
      if (_refreshPending && mounted) {
        _refreshPending = false;
        unawaited(_loadMessages(silent: true));
      }
    }
  }

  List<String> _getUniquePhones() {
    return _smsMessages
        .map((m) => m['phone_number'] as String)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingState(
        title: 'Loading messages',
        message: 'Collecting recent SMS conversations...',
        mascot: MascotPose.smsConfirm,
      );
    }

    final uniquePhones = _getUniquePhones();
    return RefreshIndicator(
      onRefresh: _loadMessages,
      color: AppColors.of(context).primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppPageHeader(
            title: 'Messages',
            subtitle: uniquePhones.isEmpty
                ? 'No conversations'
                : '${uniquePhones.length} ${uniquePhones.length == 1 ? 'conversation' : 'conversations'}',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MascotBadge(pose: MascotPose.smsConfirm, size: 44),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: AppColors.of(context).primary,
                  ),
                  onPressed: _loadMessages,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            EmptyState(
              icon: Icons.error_outline,
              mascot: MascotPose.checklist,
              title: 'Messages could not load',
              message: _error!,
            )
          else if (uniquePhones.isEmpty)
            const EmptyState(
              icon: Icons.forum_outlined,
              mascot: MascotPose.smsConfirm,
              title: 'Inbox is quiet',
              message: 'No SMS conversations yet',
            )
          else
            ...uniquePhones.map(_conversationTile),
        ],
      ),
    );
  }

  Widget _conversationTile(String phone) {
    final phoneMsgs = _smsMessages
        .where((m) => m['phone_number'] == phone)
        .toList();
    if (phoneMsgs.isEmpty) return const SizedBox.shrink();
    phoneMsgs.sort((a, b) {
      final timeA =
          DateTime.tryParse(a['sent_at'] as String? ?? '') ?? DateTime.now();
      final timeB =
          DateTime.tryParse(b['sent_at'] as String? ?? '') ?? DateTime.now();
      return timeB.compareTo(timeA);
    });

    final lastMsg = phoneMsgs.first;
    final displayName = _phoneToName[phone];
    final message = lastMsg['message'] as String? ?? '';
    final direction = lastMsg['direction'] as String? ?? 'incoming';
    final sentAt = lastMsg['sent_at'] as String? ?? '';
    final isIncoming = direction == 'incoming';
    final title = displayName ?? phone;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(phoneNumber: phone, contactName: displayName),
          ),
        );
      },
      child: Row(
        children: [
          _Avatar(label: title),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.of(context).mutedForeground,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimeShort(sentAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 6),
              StatusBadge(
                label: isIncoming ? 'Incoming' : 'Outgoing',
                icon: isIncoming ? Icons.call_received : Icons.call_made,
                color: isIncoming
                    ? AppColors.of(context).primary
                    : AppColors.of(context).statusOperating,
                bgColor: isIncoming
                    ? AppColors.of(context).primaryLight
                    : AppColors.of(context).statusOperatingLight,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeShort(String sentAt) {
    try {
      final dt = DateTime.parse(sentAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}/${dt.year.toString().substring(2)}';
    } catch (_) {
      return '';
    }
  }
}

class _Avatar extends StatelessWidget {
  final String label;

  const _Avatar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.of(context).primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label.isNotEmpty ? label.substring(0, 1).toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.of(context).primary,
          ),
        ),
      ),
    );
  }
}
