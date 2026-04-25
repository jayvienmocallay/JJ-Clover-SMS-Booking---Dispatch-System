// Task 010 — Messages screen: SMS inbox showing processed orders as messages
// Task 011 — Connected to OrderProvider to show real-time order messages
// SMS inbox with unread/all filter, smart time formatting, expandable details
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jj_clover_sms/database_helper.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../theme/app_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // Filter: 'all' or 'unread'
  String _filter = 'all';
  // Track read message IDs - persisted to database
  Set<int> _readIds = {};
  // Track expanded message ID
  int? _expandedId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReadIds();
  }

  Future<void> _loadReadIds() async {
    try {
      final ids = await DatabaseHelper.instance.getReadMessageIds();
      if (mounted) {
        setState(() {
          _readIds = ids;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveReadIds() async {
    try {
      await DatabaseHelper.instance.setReadMessageIds(_readIds);
    } catch (_) {}
  }

  /// Smart time formatting: "Just now", "Xm ago", "Xh ago", or time string
  String _formatTime(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt);
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

  bool _isUnread(int? orderId) {
    if (orderId == null) return true;
    return !_readIds.contains(orderId);
  }

  Future<void> _markAsRead(int? orderId) async {
    if (orderId == null) return;
    setState(() => _readIds.add(orderId));
    await _saveReadIds();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Consumer2<OrderProvider, CustomerProvider>(
      builder: (context, orderProv, customerProv, _) {
        final orders = orderProv.todayOrders;
        final unreadCount = orders.where((o) => _isUnread(o['id'] as int?)).length;

        // Apply filter
        final filteredOrders = _filter == 'unread'
            ? orders.where((o) => _isUnread(o['id'] as int?)).toList()
            : orders;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Messages',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      orders.isEmpty
                          ? 'All caught up!'
                          : '${orders.length} messages today',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
                // Unread badge
                if (unreadCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount new',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Filter tabs ---
            Row(
              children: [
                _FilterTab(
                  label: 'All',
                  isActive: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterTab(
                  label: 'Unread',
                  isActive: _filter == 'unread',
                  onTap: () => setState(() => _filter = 'unread'),
                  badge: unreadCount > 0 ? unreadCount : null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- SMS integration notice ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SMS Inbox Integration',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This page displays incoming SMS messages processed by the background service. Orders are automatically created from valid commands.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Message list ---
            if (filteredOrders.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox,
                      size: 48,
                      color: AppColors.mutedForeground.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _filter == 'unread'
                          ? 'No unread messages.'
                          : 'SMS messages will appear here when received.',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.mutedForeground),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...filteredOrders.map((order) {
                final orderId = order['id'] as int?;
                final phone = order['phone_number'] as String? ?? 'Unknown';
                final type = order['type'] as String? ?? 'deliver';
                final quantity = order['quantity'] as int? ?? 0;
                final status = order['status'] as String? ?? 'pending';
                final createdAt = order['created_at'] as String? ?? '';
                final isDeliver = type == 'deliver';
                final isUnread = _isUnread(orderId);
                final isExpanded = _expandedId == orderId;

                final timeStr = _formatTime(createdAt);
                final command =
                    isDeliver ? 'DELIVER $quantity' : (type == 'unrecognized' ? 'INVALID' : 'DROP $quantity');

                // Determine if this is an unrecognized message
                final isUnrecognized = type == 'unrecognized';

                // Look up customer name
                final customerId = order['customer_id'] as int?;
                final customer = customerId != null
                    ? customerProv.getById(customerId)
                    : null;
                final customerName = customer?['name'] as String?;

                return GestureDetector(
                  onTap: () {
                    _markAsRead(orderId);
                    setState(() {
                      _expandedId = isExpanded ? null : orderId;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isUnread
                          ? AppColors.primary.withValues(alpha: 0.03)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUnread
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SMS icon with unread dot
                            Stack(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isUnrecognized
                                        ? AppColors.statusMaintenanceLight
                                        : (isDeliver
                                            ? AppColors.primaryLight
                                            : AppColors.statusAwayLight),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isUnrecognized
                                        ? Icons.error_outline
                                        : Icons.sms,
                                    size: 18,
                                    color: isUnrecognized
                                        ? AppColors.statusMaintenance
                                        : (isDeliver
                                            ? AppColors.primary
                                            : AppColors.statusAway),
                                  ),
                                ),
                                if (isUnread)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.card, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Message content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          customerName ?? phone,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isUnread
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: AppColors.foreground,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isUnread
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isUnread
                                              ? AppColors.primary
                                              : AppColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    command,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isUnread
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Status badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getStatusBgColor(status),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: _getStatusTextColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Expanded details
                        if (isExpanded) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _detailRow('Phone', phone),
                                if (customerName != null)
                                  _detailRow('Customer', customerName),
                                _detailRow('Type',
                                    isDeliver ? 'Delivery' : 'Walk-in (DROP)'),
                                _detailRow('Quantity', '$quantity gallon(s)'),
                                _detailRow('Status', status.toUpperCase()),
                                if (order['delivery_day'] != null)
                                  _detailRow('Delivery Day',
                                      order['delivery_day'] as String),
                                if (order['is_pre_book'] == 1)
                                  _detailRow('Pre-booked', 'Yes'),
                                _detailRow('Received', _formatFullTime(createdAt)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullTime(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt);
      final hour =
          dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return createdAt;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.statusOperatingLight;
      case 'pending':
        return AppColors.statusAwayLight;
      case 'cancelled':
        return AppColors.statusMaintenanceLight;
      default:
        return AppColors.muted;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.statusOperating;
      case 'pending':
        return AppColors.statusAway;
      case 'cancelled':
        return AppColors.statusMaintenance;
      default:
        return AppColors.mutedForeground;
    }
  }
}

/// Rounded filter tab with optional badge count
class _FilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badge;

  const _FilterTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.muted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : AppColors.mutedForeground,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
