// Customer/Conversation info bottom sheet — shown when the ⓘ button is tapped
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/services/command_handlers/sms_handler_utils.dart';
import '../../core/utils/phone_number_utils.dart';
import '../theme/app_theme.dart';
import 'complete_order_sheet.dart';

class CustomerInfoSheet extends StatefulWidget {
  final String phoneNumber;
  final String contactName;
  final VoidCallback? onCreateOrder;

  const CustomerInfoSheet({
    super.key,
    required this.phoneNumber,
    required this.contactName,
    this.onCreateOrder,
  });

  @override
  State<CustomerInfoSheet> createState() => _CustomerInfoSheetState();
}

class _CustomerInfoSheetState extends State<CustomerInfoSheet> {
  bool _loading = true;
  Customer? _customer;
  Order? _activeOrder;
  Order? _lastCompletedOrder;
  int _totalOrders = 0;
  late final CustomerRepository _customerRepo;
  late final OrderRepository _orderRepo;

  @override
  void initState() {
    super.initState();
    _customerRepo = context.read<CustomerRepository>();
    _orderRepo = context.read<OrderRepository>();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final customerMap = await _customerRepo.getCustomerWithBarangayByPhone(
        widget.phoneNumber,
      );

      final Customer? customer = customerMap != null
          ? Customer.fromMap(customerMap)
          : null;

      final normalizedPhone = PhoneNumberUtils.normalize(widget.phoneNumber);

      final activeRows = await _orderRepo.getOrders(
        where: 'phone_number = ? AND status NOT IN (?, ?, ?)',
        whereArgs: [normalizedPhone, 'completed', 'cancelled', 'rejected'],
      );

      Order? activeOrder;
      if (activeRows.isNotEmpty) {
        activeOrder = Order.fromMap(activeRows.first);
      }

      final allRows = await _orderRepo.getOrders(
        where: 'phone_number = ?',
        whereArgs: [normalizedPhone],
      );

      Order? lastCompleted;
      for (final row in allRows) {
        if (row['status'] == 'completed') {
          lastCompleted = Order.fromMap(row);
          break;
        }
      }

      if (mounted) {
        setState(() {
          _customer = customer;
          _activeOrder = activeOrder;
          _lastCompletedOrder = lastCompleted;
          _totalOrders = allRows.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _makePhoneCall() async {
    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: widget.phoneNumber),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not open dialer');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not dial: $e')));
      }
    }
  }

  Future<bool> _updateOrderStatus(String status, {String? reason}) async {
    final id = _activeOrder?.id;
    if (id == null) return false;
    try {
      final provider = context.read<OrderProvider>();
      final updated = await provider.updateStatus(id, status, reason: reason);
      if (!updated) {
        throw StateError(provider.error ?? 'No order was updated.');
      }
      await _loadData();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return false;
    }
  }

  Future<void> _confirmOrder() async {
    final updated = await _updateOrderStatus('confirmed');
    if (mounted) {
      if (updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Order confirmed'),
            backgroundColor: AppColors.of(context).statusOperating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _startDelivery() async {
    final order = _activeOrder;
    if (order?.id == null) return;
    final updated = await _updateOrderStatus('in_transit');
    if (!updated || !mounted) return;

    await SmsHandlerUtils.sendReply(
      order!.phoneNumber,
      _deliveryStartedSms(order),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery started. Customer SMS notification queued.'),
      ),
    );
  }

  Future<void> _completeDelivery() async {
    final order = _activeOrder;
    if (order == null) return;
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CompleteOrderSheet(order: order),
    );
    if (completed == true) {
      await _loadData();
    }
  }

  String _deliveryStartedSms(Order order) {
    final quantity = order.quantity > 0
        ? ' (${order.quantity} gallon${order.quantity == 1 ? '' : 's'})'
        : '';
    return 'JJ Clover: Your water order$quantity is on the way. '
        'Please prepare to receive it. Thank you!';
  }

  Future<void> _rejectOrder() async {
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.of(context).card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Reject Order',
            style: TextStyle(color: AppColors.of(context).foreground),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: AppColors.of(context).foreground),
            decoration: InputDecoration(
              hintText: 'Reason (optional)',
              filled: true,
              fillColor: AppColors.of(context).muted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => reason = v.trim().isEmpty ? null : v.trim(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.of(context).mutedForeground),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Reject',
                style: TextStyle(color: AppColors.of(context).statusBusy),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final updated = await _updateOrderStatus('rejected', reason: reason);
    if (mounted) {
      if (updated) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order rejected')));
      }
    }
  }

  Future<void> _toggleContactFlag({
    bool? isMuted,
    bool? isBlocked,
    bool? isSpam,
    required String successMessage,
  }) async {
    final customer = _customer;
    final customerId = customer?.id;
    if (customerId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Register this customer first.')),
      );
      return;
    }

    try {
      final provider = context.read<CustomerProvider>();
      final updated = await provider.updateContactFlags(
        customerId,
        isMuted: isMuted,
        isBlocked: isBlocked,
        isSpam: isSpam,
      );
      if (!updated) {
        throw StateError(provider.error ?? 'No customer was updated.');
      }
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showOrderHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OrderHistorySheet(phoneNumber: widget.phoneNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.93,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _buildHandle(),
            _buildTitle(),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.of(context).primary,
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      children: [
                        _buildCustomerSection(),
                        const SizedBox(height: 24),
                        _buildActiveOrderSection(),
                        const SizedBox(height: 24),
                        _buildQuickActionsSection(),
                        const SizedBox(height: 24),
                        _buildOptionsSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  // ── Handle & title ──────────────────────────────────────────────────────────

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.of(context).border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Text(
            'Customer Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.of(context).foreground,
            ),
          ),
          if (_loading) ...[
            const Spacer(),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.of(context).primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Customer info ───────────────────────────────────────────────────────────

  Widget _buildCustomerSection() {
    final isRegistered = _customer != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.of(context).foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.phoneNumber,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.of(context).mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusBadge(isRegistered),
          ],
        ),
        if (isRegistered) ...[
          const SizedBox(height: 16),
          _buildCard([
            if (_customer!.barangay.isNotEmpty)
              _detailRow(
                Icons.location_on_outlined,
                'Area',
                _customer!.barangay,
              ),
            if (_customer!.address?.isNotEmpty == true)
              _detailRow(Icons.home_outlined, 'Address', _customer!.address!),
            if (_customer!.deliveryZone.isNotEmpty)
              _detailRow(Icons.map_outlined, 'Zone', _customer!.deliveryZone),
            _detailRow(
              Icons.shopping_bag_outlined,
              'Orders',
              '$_totalOrders order${_totalOrders == 1 ? '' : 's'} total',
            ),
            if (_lastCompletedOrder != null)
              _detailRow(
                Icons.history,
                'Last Delivered',
                _formatDate(_lastCompletedOrder!.createdAt),
              ),
          ]),
        ],
      ],
    );
  }

  Widget _buildAvatar() {
    final initial = widget.contactName.isNotEmpty
        ? widget.contactName[0].toUpperCase()
        : '?';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.of(context).primaryLight,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.of(context).primary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isRegistered) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isRegistered
            ? AppColors.of(context).statusOperatingLight
            : AppColors.of(context).muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isRegistered ? 'Regular' : 'Unregistered',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isRegistered
              ? AppColors.of(context).statusOperating
              : AppColors.of(context).mutedForeground,
        ),
      ),
    );
  }

  // ── Active order ────────────────────────────────────────────────────────────

  Widget _buildActiveOrderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Active Order'),
        const SizedBox(height: 8),
        if (_activeOrder == null)
          _buildCard([
            _detailRow(Icons.inbox_outlined, 'Status', 'No active order'),
          ])
        else
          _buildOrderCard(_activeOrder!),
      ],
    );
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _statusColor(order.status);
    final statusBgColor = _statusBgColor(order.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.quantity} gallon${order.quantity == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.of(context).foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _orderTypeLabel(order.type) +
                      (order.isPreBook ? ' • Pre-booked' : ''),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.of(context).mutedForeground,
                  ),
                ),
                if (order.deliveryDay != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Scheduled for ${order.deliveryDay}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.of(context).mutedForeground,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Placed ${_formatDate(order.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.status.displayLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick actions ───────────────────────────────────────────────────────────

  Widget _buildQuickActionsSection() {
    final order = _activeOrder;

    final canConfirm =
        order?.status == OrderStatus.pending &&
        order?.type != OrderType.unrecognized;
    final canStartDelivery =
        order?.status == OrderStatus.confirmed &&
        order?.type != OrderType.unrecognized;
    final canCompleteDelivery =
        order?.status == OrderStatus.inTransit &&
        order?.type != OrderType.unrecognized;
    final canReject =
        order != null &&
        (order.status == OrderStatus.pending ||
            order.status == OrderStatus.confirmed);

    final orderActions = <Widget>[
      if (canConfirm)
        _listAction(
          icon: Icons.check_circle_outline,
          label: order!.isPreBook ? 'Confirm Pre-book' : 'Confirm Order',
          color: AppColors.of(context).statusOperating,
          onTap: _confirmOrder,
        ),
      if (canStartDelivery)
        _listAction(
          icon: Icons.local_shipping_outlined,
          label: 'Start Delivery',
          color: AppColors.of(context).primary,
          onTap: _startDelivery,
        ),
      if (canCompleteDelivery)
        _listAction(
          icon: Icons.check_circle_outline,
          label: 'Complete Delivery',
          color: AppColors.of(context).statusOperating,
          onTap: _completeDelivery,
        ),
      if (canReject)
        _listAction(
          icon: Icons.cancel_outlined,
          label: 'Reject / Cancel',
          color: AppColors.of(context).statusBusy,
          onTap: _rejectOrder,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Actions'),
        const SizedBox(height: 8),
        Row(
          children: [
            _iconAction(
              icon: Icons.call,
              label: 'Call',
              color: AppColors.of(context).statusOperating,
              onTap: _makePhoneCall,
            ),
            const SizedBox(width: 8),
            _iconAction(
              icon: Icons.add_circle_outline,
              label: 'New Order',
              color: AppColors.of(context).primary,
              onTap: () {
                Navigator.pop(context);
                widget.onCreateOrder?.call();
              },
            ),
            const SizedBox(width: 8),
            _iconAction(
              icon: Icons.history,
              label: 'History',
              color: AppColors.of(context).mutedForeground,
              onTap: _showOrderHistory,
            ),
          ],
        ),
        if (orderActions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildCard(orderActions),
        ],
      ],
    );
  }

  // ── Conversation / customer options ─────────────────────────────────────────

  Widget _buildOptionsSection() {
    final isRegistered = _customer != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Customer Options'),
        const SizedBox(height: 8),
        _buildCard([
          if (!isRegistered)
            _listAction(
              icon: Icons.person_add_outlined,
              label: 'Register Customer',
              color: AppColors.of(context).primary,
              onTap: () {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Go to the Customers tab to register'),
                  ),
                );
              },
            ),
          _listAction(
            icon: _customer?.isMuted == true
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined,
            label: _customer?.isMuted == true
                ? 'Unmute Messages'
                : 'Mute Messages',
            color: AppColors.of(context).mutedForeground,
            onTap: () => _toggleContactFlag(
              isMuted: !(_customer?.isMuted ?? false),
              successMessage: _customer?.isMuted == true
                  ? 'Messages unmuted'
                  : 'Messages muted',
            ),
          ),
          _listAction(
            icon: Icons.block_outlined,
            label: _customer?.isBlocked == true
                ? 'Unblock Number'
                : 'Block Number',
            color: AppColors.of(context).statusAway,
            onTap: () => _toggleContactFlag(
              isBlocked: !(_customer?.isBlocked ?? false),
              successMessage: _customer?.isBlocked == true
                  ? 'Number unblocked'
                  : 'Number blocked',
            ),
          ),
          _listAction(
            icon: Icons.report_outlined,
            label: _customer?.isSpam == true ? 'Unmark Spam' : 'Mark as Spam',
            color: AppColors.of(context).statusAway,
            onTap: () => _toggleContactFlag(
              isSpam: !(_customer?.isSpam ?? false),
              successMessage: _customer?.isSpam == true
                  ? 'Removed from spam'
                  : 'Marked as spam',
            ),
          ),
        ]),
      ],
    );
  }

  // ── Shared card primitives ──────────────────────────────────────────────────

  Widget _buildCard(List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: AppColors.of(context).muted,
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(
                  color: AppColors.of(context).border.withValues(alpha: 0.6),
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.of(context).mutedForeground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.of(context).mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.of(context).foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.of(context).mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.of(context).muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.of(context).mutedForeground,
        letterSpacing: 0.8,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.of(context).statusAway;
      case OrderStatus.confirmed:
        return AppColors.of(context).primary;
      case OrderStatus.inTransit:
        return AppColors.of(context).primary;
      case OrderStatus.completed:
        return AppColors.of(context).statusOperating;
      case OrderStatus.cancelled:
        return AppColors.of(context).mutedForeground;
      case OrderStatus.rejected:
        return AppColors.of(context).statusBusy;
    }
  }

  Color _statusBgColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.of(context).statusAwayLight;
      case OrderStatus.confirmed:
        return AppColors.of(context).primaryLight;
      case OrderStatus.inTransit:
        return AppColors.of(context).primaryLight;
      case OrderStatus.completed:
        return AppColors.of(context).statusOperatingLight;
      case OrderStatus.cancelled:
        return AppColors.of(context).muted;
      case OrderStatus.rejected:
        return AppColors.of(context).statusBusyLight;
    }
  }

  String _orderTypeLabel(OrderType type) {
    switch (type) {
      case OrderType.deliver:
        return 'Deliver';
      case OrderType.drop:
        return 'Drop / Walk-in';
      case OrderType.unrecognized:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Order history sub-sheet ───────────────────────────────────────────────────

class _OrderHistorySheet extends StatefulWidget {
  final String phoneNumber;

  const _OrderHistorySheet({required this.phoneNumber});

  @override
  State<_OrderHistorySheet> createState() => _OrderHistorySheetState();
}

class _OrderHistorySheetState extends State<_OrderHistorySheet> {
  bool _loading = true;
  List<Order> _orders = [];
  late final OrderRepository _orderRepo;

  @override
  void initState() {
    super.initState();
    _orderRepo = context.read<OrderRepository>();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final rows = await _orderRepo.getOrders(
        where: 'phone_number = ?',
        whereArgs: [PhoneNumberUtils.normalize(widget.phoneNumber)],
      );
      if (mounted) {
        setState(() {
          _orders = rows.map(Order.fromMap).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.of(context).border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Text(
            'Order History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.of(context).foreground,
            ),
          ),
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.of(context).primary,
              ),
            ),
          )
        else if (_orders.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Text(
              'No orders found for this number.',
              style: TextStyle(color: AppColors.of(context).mutedForeground),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.52,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: _orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildHistoryItem(_orders[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryItem(Order order) {
    Color statusColor;
    Color statusBg;
    switch (order.status) {
      case OrderStatus.completed:
        statusColor = AppColors.of(context).statusOperating;
        statusBg = AppColors.of(context).statusOperatingLight;
        break;
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        statusColor = AppColors.of(context).statusBusy;
        statusBg = AppColors.of(context).statusBusyLight;
        break;
      case OrderStatus.pending:
        statusColor = AppColors.of(context).statusAway;
        statusBg = AppColors.of(context).statusAwayLight;
        break;
      default:
        statusColor = AppColors.of(context).primary;
        statusBg = AppColors.of(context).primaryLight;
    }

    final typeLabel = order.type == OrderType.deliver
        ? 'Deliver'
        : order.type == OrderType.drop
        ? 'Drop'
        : 'Unknown';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dt = order.createdAt;
    final dateLabel = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.of(context).muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.quantity} gallon${order.quantity == 1 ? '' : 's'} · $typeLabel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(context).foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).mutedForeground,
                  ),
                ),
                if (order.deliveryDay != null)
                  Text(
                    'Scheduled: ${order.deliveryDay}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.of(context).mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              order.status.displayLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
