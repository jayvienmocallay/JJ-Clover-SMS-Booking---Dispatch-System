import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/order_provider.dart';
import '../../data/repositories/order_repository.dart';
import '../theme/app_theme.dart';
import 'complete_order_sheet.dart';
import 'delivery_issue_sheet.dart';
import 'staff_assignment_sheet.dart';

class OrderDetailSheet extends StatefulWidget {
  final Order order;
  final String? customerName;
  final String? phone;
  final String? barangay;
  final String? address;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final VoidCallback? onStartDelivery;
  final VoidCallback? onCompleted;

  const OrderDetailSheet({
    super.key,
    required this.order,
    this.customerName,
    this.phone,
    this.barangay,
    this.address,
    this.onConfirm,
    this.onReject,
    this.onStartDelivery,
    this.onCompleted,
  });

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
  List<Map<String, dynamic>> _logs = [];
  bool _loadingLogs = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final id = widget.order.id;
    if (id == null) return;
    setState(() => _loadingLogs = true);
    final logs = await context.read<OrderRepository>().getDeliveryLogsForOrder(
      id,
    );
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loadingLogs = false;
    });
  }

  Future<void> _showCompletionSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CompleteOrderSheet(order: widget.order),
    );
    if (result == true) {
      widget.onCompleted?.call();
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _showStaffAssignmentSheet() async {
    final orderId = widget.order.id;
    if (orderId == null) return;
    final provider = context.read<OrderProvider>();
    final staffId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          StaffAssignmentSheet(initialStaffId: widget.order.staffId),
    );
    if (staffId == null) return;
    await provider.assignStaffToOrder(orderId, staffId);
    if (!mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(provider.error!)));
      return;
    }
    widget.onCompleted?.call();
    Navigator.pop(context, true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Staff assigned ✓')));
  }

  Future<void> _showDeliveryIssueSheet() async {
    final orderId = widget.order.id;
    if (orderId == null) return;
    final provider = context.read<OrderProvider>();
    final result = await showModalBottomSheet<DeliveryIssueResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DeliveryIssueSheet(),
    );
    if (result == null) return;
    await provider.recordDeliveryIssue(
      orderId,
      note: result.note,
      keepForRedispatch: result.keepForRedispatch,
    );
    if (!mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(provider.error!)));
      return;
    }
    widget.onCompleted?.call();
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.keepForRedispatch
              ? 'Delivery note saved and returned to dispatch ✓'
              : 'Delivery note saved and order moved out of dispatch ✓',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final order = widget.order;
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Order ID + status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '#${order.id?.toString().padLeft(6, '0') ?? '-'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _statusPill(context, order.status.name),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: palette.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.border),
                ),
                labelColor: palette.foreground,
                unselectedLabelColor: palette.mutedForeground,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [Tab(text: 'Details'), Tab(text: 'History')],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Tab content
          Flexible(
            child: TabBarView(
              children: [
                _buildDetailsTab(context, order, palette),
                _buildHistoryTab(context, palette),
              ],
            ),
          ),
          // Action buttons
          if (_actions.isNotEmpty)
            _buildActionButtons(context, order, palette),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(BuildContext context, Order order, AppPalette palette) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer section
          Text('Customer', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.muted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, size: 20, color: palette.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customerName ?? 'Unknown',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.phone ?? order.phoneNumber,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _iconBtn(context, Icons.phone, palette.statusOperating, onTap: () async {
                  final phone = widget.phone ?? order.phoneNumber;
                  try {
                    await Telephony.instance.dialPhoneNumber(phone);
                  } catch (_) {}
                }),
                const SizedBox(width: 8),
                _iconBtn(context, Icons.chat_bubble_outline, palette.primary),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Address section
          if (widget.address?.isNotEmpty == true || widget.barangay?.isNotEmpty == true) ...[
            Text('Address', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, size: 18, color: palette.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.address?.isNotEmpty == true)
                          Text(widget.address!, style: Theme.of(context).textTheme.bodyMedium),
                        if (widget.barangay?.isNotEmpty == true)
                          Text(widget.barangay!, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          'View on map',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: palette.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Order information
          Text('Order Information', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          _sectionCard([
            _detailRow('Type', _typeLabel(order.type)),
            _detailRow('Product / Item', '${order.quantity} Gallon${order.quantity == 1 ? '' : 's'}'),
            _detailRow('Quantity', '${order.quantity}'),
            if (order.staffId != null) _detailRow('Assigned Staff', '#${order.staffId}'),
            if (order.deliveryDay != null) _detailRow('Delivery Day', order.deliveryDay!),
            if (order.scheduledFor != null) _detailRow('Scheduled', _formatDate(order.scheduledFor!)),
            _detailRow('Placed', _formatDateTime(order.createdAt)),
            if (order.cancelReason?.isNotEmpty == true) _detailRow('Reason', order.cancelReason!),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, AppPalette palette) {
    if (_loadingLogs) {
      return Center(child: CircularProgressIndicator(color: palette.primary));
    }
    if (_logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: _sectionCard([_plainText('No delivery log recorded.')]),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: _sectionCard(_logs.map(_logRow).toList()),
    );
  }

  Widget _buildActionButtons(BuildContext context, Order order, AppPalette palette) {
    final canCancel = order.status == OrderStatus.pending && widget.onReject != null;
    final canConfirm = order.status == OrderStatus.pending && widget.onConfirm != null;
    final canStartDelivery = order.status == OrderStatus.confirmed && widget.onStartDelivery != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: [
          if (_actions.isNotEmpty && !canCancel && !canConfirm && !canStartDelivery)
            _sectionCard(_actions)
          else ...[
            Row(
              children: [
                if (canCancel)
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onReject,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.statusMaintenance),
                        ),
                        child: Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.statusMaintenance,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (canCancel && (canConfirm || canStartDelivery))
                  const SizedBox(width: 12),
                if (canConfirm)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        widget.onConfirm!();
                        Navigator.pop(context, true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: palette.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Confirm Order',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (canStartDelivery)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        widget.onStartDelivery!();
                        Navigator.pop(context, true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: palette.statusBusy,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Start Delivery',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_secondaryActions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _sectionCard(_secondaryActions),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> get _secondaryActions {
    final order = widget.order;
    return [
      if ((order.status == OrderStatus.confirmed ||
              order.status == OrderStatus.inTransit) &&
          order.type != OrderType.unrecognized)
        _actionRow(Icons.badge_outlined, 'Assign staff', _showStaffAssignmentSheet),
      if (order.status == OrderStatus.inTransit)
        _actionRow(Icons.report_problem_outlined, 'Record delivery issue', _showDeliveryIssueSheet),
      if (order.status == OrderStatus.inTransit)
        _actionRow(Icons.check_circle, 'Complete delivery', _showCompletionSheet),
    ];
  }

  Widget _iconBtn(BuildContext context, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _statusPill(BuildContext context, String status) {
    final palette = AppColors.of(context);
    Color color;
    Color bg;
    String label;
    switch (status) {
      case 'pending':
        color = palette.statusAway; bg = palette.statusAwayLight; label = 'Pending';
        break;
      case 'confirmed':
        color = palette.statusOperating; bg = palette.statusOperatingLight; label = 'Confirmed';
        break;
      case 'in_transit':
        color = palette.statusBusy; bg = palette.statusBusyLight; label = 'In Transit';
        break;
      case 'completed':
        color = palette.statusOperating; bg = palette.statusOperatingLight; label = 'Completed';
        break;
      default:
        color = palette.mutedForeground; bg = palette.muted; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  List<Widget> get _actions {
    final order = widget.order;
    return [
      if (order.status == OrderStatus.pending && widget.onConfirm != null)
        _actionRow(
          Icons.check_circle_outline,
          'Confirm order',
          widget.onConfirm!,
        ),
      if (order.status == OrderStatus.pending && widget.onReject != null)
        _actionRow(Icons.cancel_outlined, 'Reject order', widget.onReject!),
      if ((order.status == OrderStatus.confirmed ||
              order.status == OrderStatus.inTransit) &&
          order.type != OrderType.unrecognized)
        _actionRow(
          Icons.badge_outlined,
          'Assign staff',
          _showStaffAssignmentSheet,
        ),
      if (order.status == OrderStatus.confirmed &&
          widget.onStartDelivery != null)
        _actionRow(
          Icons.local_shipping_outlined,
          'Start delivery',
          widget.onStartDelivery!,
        ),
      if (order.status == OrderStatus.inTransit)
        _actionRow(
          Icons.report_problem_outlined,
          'Record delivery issue',
          _showDeliveryIssueSheet,
        ),
      if (order.status == OrderStatus.inTransit)
        _actionRow(
          Icons.check_circle,
          'Complete delivery',
          _showCompletionSheet,
        ),
    ];
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, color: AppColors.of(context).border),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _plainText(String value) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _actionRow(IconData icon, String label, VoidCallback onTap) {
    final palette = AppColors.of(context);
    return InkWell(
      onTap: () async {
        onTap();
        if (mounted &&
            label != 'Complete delivery' &&
            label != 'Assign staff' &&
            label != 'Record delivery issue') {
          Navigator.pop(context, true);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Icon(Icons.chevron_right, color: palette.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _logRow(Map<String, dynamic> log) {
    final qty = log['quantity_delivered'] as int? ?? 0;
    final returned = log['returned_containers'] as int?;
    final paymentMethod = log['payment_method'] as String?;
    final notes = log['notes'] as String?;
    final staffId = log['staff_id'] as int?;
    final deliveredAt = DateTime.tryParse(log['delivered_at'] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$qty gallon${qty == 1 ? '' : 's'} delivered',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (staffId != null)
            Text(
              'Staff #$staffId',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (returned != null)
            Text(
              '$returned returned container${returned == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (paymentMethod == 'cash')
            Text(
              'Cash collected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (notes?.isNotEmpty == true)
            Text(notes!, style: Theme.of(context).textTheme.bodySmall),
          if (deliveredAt != null)
            Text(
              _formatDateTime(deliveredAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }

  String _typeLabel(OrderType type) {
    switch (type) {
      case OrderType.deliver:
        return 'Delivery';
      case OrderType.drop:
        return 'Walk-in';
      case OrderType.unrecognized:
        return 'Invalid SMS';
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime dt) {
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${_formatDate(dt)} ${dt.hour}:$minute';
  }
}
