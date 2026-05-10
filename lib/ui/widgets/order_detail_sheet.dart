import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../theme/app_theme.dart';
import 'complete_order_sheet.dart';
import 'shared/bottom_sheet_handle.dart';

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
    final logs = await context.read<OrderRepository>().getDeliveryLogsForOrder(id);
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

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final order = widget.order;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BottomSheetHandle(title: 'Order #${order.id ?? '-'}'),
            const SizedBox(height: 16),
            _sectionCard([
              _detailRow('Customer', widget.customerName ?? order.phoneNumber),
              _detailRow('Phone', widget.phone ?? order.phoneNumber),
              _detailRow('Type', _typeLabel(order.type)),
              _detailRow('Status', order.status.displayLabel),
              _detailRow('Quantity', '${order.quantity} gallon${order.quantity == 1 ? '' : 's'}'),
              _detailRow('Gallon type', order.gallonType == GallonType.oldGallon ? 'Old' : 'New'),
              if (widget.address?.isNotEmpty == true) _detailRow('Address', widget.address!),
              if (widget.barangay?.isNotEmpty == true) _detailRow('Barangay', widget.barangay!),
              if (order.deliveryDay != null) _detailRow('Delivery day', order.deliveryDay!),
              if (order.scheduledFor != null) _detailRow('Scheduled date', _formatDate(order.scheduledFor!)),
              _detailRow('Created', _formatDateTime(order.createdAt)),
              if (order.cancelReason?.isNotEmpty == true) _detailRow('Reason', order.cancelReason!),
            ]),
            const SizedBox(height: 16),
            if (_actions.isNotEmpty) ...[
              Text('Actions', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _sectionCard(_actions),
              const SizedBox(height: 16),
            ],
            Text('Delivery log', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            if (_loadingLogs)
              Center(child: CircularProgressIndicator(color: palette.primary))
            else if (_logs.isEmpty)
              _sectionCard([_plainText('No delivery log recorded.')])
            else
              _sectionCard(_logs.map(_logRow).toList()),
          ],
        ),
      ),
    );
  }

  List<Widget> get _actions {
    final order = widget.order;
    return [
      if (order.status == OrderStatus.pending && widget.onConfirm != null)
        _actionRow(Icons.check_circle_outline, 'Confirm order', widget.onConfirm!),
      if (order.status == OrderStatus.pending && widget.onReject != null)
        _actionRow(Icons.cancel_outlined, 'Reject order', widget.onReject!),
      if (order.status == OrderStatus.confirmed && widget.onStartDelivery != null)
        _actionRow(Icons.local_shipping_outlined, 'Start delivery', widget.onStartDelivery!),
      if (order.status == OrderStatus.inTransit)
        _actionRow(Icons.check_circle, 'Complete delivery', _showCompletionSheet),
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
        if (mounted && label != 'Complete delivery') {
          Navigator.pop(context, true);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
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
    final deliveredAt = DateTime.tryParse(log['delivered_at'] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$qty gallon${qty == 1 ? '' : 's'} delivered', style: Theme.of(context).textTheme.bodyMedium),
          if (returned != null) Text('$returned returned container${returned == 1 ? '' : 's'}', style: Theme.of(context).textTheme.bodySmall),
          if (paymentMethod == 'cash') Text('Cash collected', style: Theme.of(context).textTheme.bodySmall),
          if (notes?.isNotEmpty == true) Text(notes!, style: Theme.of(context).textTheme.bodySmall),
          if (deliveredAt != null) Text(_formatDateTime(deliveredAt), style: Theme.of(context).textTheme.labelSmall),
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

  String _formatDate(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime dt) {
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${_formatDate(dt)} ${dt.hour}:$minute';
  }
}
