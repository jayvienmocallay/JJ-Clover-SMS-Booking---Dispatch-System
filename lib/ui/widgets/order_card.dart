import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../theme/app_theme.dart';
import 'shared/status_badge.dart';

/// Order card with type icon, customer info, status badge, and action buttons.
class OrderCard extends StatelessWidget {
  final Order order;
  final String? customerName;
  final String? phone;
  final String? barangay;
  final String? address;
  final VoidCallback? onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final VoidCallback? onStartDelivery;
  final VoidCallback? onComplete;

  const OrderCard({
    super.key,
    required this.order,
    this.customerName,
    this.phone,
    this.barangay,
    this.address,
    this.onTap,
    this.onConfirm,
    this.onReject,
    this.onStartDelivery,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isDeliver = order.type == OrderType.deliver;
    final isInvalid = order.type == OrderType.unrecognized;
    final palette = AppColors.of(context);

    final typeColor = isInvalid
        ? palette.statusMaintenance
        : isDeliver
        ? palette.primary
        : palette.statusAway;
    final typeBgColor = isInvalid
        ? palette.statusMaintenanceLight
        : isDeliver
        ? palette.primaryLight
        : palette.statusAwayLight;
    final typeIcon = isInvalid
        ? Icons.sms_failed
        : isDeliver
        ? Icons.local_shipping
        : Icons.water_drop;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kCardRadius),
      child: Container(
        padding: const EdgeInsets.all(kCardPadding),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(
            color: isInvalid
                ? palette.statusMaintenance.withValues(alpha: 0.4)
                : palette.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: typeBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, size: 20, color: typeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName ?? order.phoneNumber,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: palette.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (phone != null)
                        Text(
                          phone!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: palette.mutedForeground),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (!isInvalid && (address != null || barangay != null))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [address, barangay].whereType<String>().join(' · '),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: palette.mutedForeground),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: palette.muted,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${order.quantity} gal',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: palette.mutedForeground,
                                    ),
                              ),
                            ),
                            if (order.isPreBook) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 10,
                                      color: palette.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Pre-booked${order.deliveryDay != null ? " (${order.deliveryDay})" : ""}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: palette.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(width: 12),
                            Text(
                              order.isPreBook && order.scheduledFor != null
                                  ? 'Scheduled ${_formatDate(order.scheduledFor!)}'
                                  : _formatTime(order.createdAt),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(palette),
              ],
            ),

            if ((order.status == OrderStatus.cancelled ||
                    order.status == OrderStatus.rejected ||
                    order.type == OrderType.unrecognized) &&
                order.cancelReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.statusMaintenanceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Reason: ${order.cancelReason}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.statusMaintenance,
                    ),
                  ),
                ),
              ),

            if (order.status == OrderStatus.completed && order.id != null)
              _ActionSection(
                child: InkWell(
                  onTap: () => _showDeliveryLogs(context, order.id!),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 14,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'View Delivery Log',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: palette.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (order.status == OrderStatus.pending &&
                (onConfirm != null || onReject != null))
              _ActionSection(
                child: Row(
                  children: [
                    if (onConfirm != null)
                      Expanded(
                        child: _ActionButton(
                          label: 'Confirm',
                          icon: Icons.check,
                          color: palette.statusOperating,
                          onTap: onConfirm!,
                        ),
                      ),
                    if (onConfirm != null && onReject != null)
                      const SizedBox(width: 8),
                    if (onReject != null)
                      Expanded(
                        child: _ActionButton(
                          label: 'Reject',
                          icon: Icons.close,
                          color: palette.statusMaintenance,
                          onTap: onReject!,
                        ),
                      ),
                  ],
                ),
              ),

            if (order.status == OrderStatus.confirmed &&
                onStartDelivery != null)
              _ActionSection(
                child: _ActionButton(
                  label: 'Start Delivery',
                  icon: Icons.local_shipping,
                  color: palette.statusBusy,
                  onTap: onStartDelivery!,
                ),
              ),

            if (order.status == OrderStatus.inTransit && onComplete != null)
              _ActionSection(
                child: _ActionButton(
                  label: 'Complete Delivery',
                  icon: Icons.check_circle,
                  color: palette.statusOperating,
                  onTap: onComplete!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AppPalette palette) {
    Color color;
    Color bgColor;
    switch (order.status) {
      case OrderStatus.pending:
        color = palette.statusAway;
        bgColor = palette.statusAwayLight;
        break;
      case OrderStatus.confirmed:
        color = palette.statusOperating;
        bgColor = palette.statusOperatingLight;
        break;
      case OrderStatus.inTransit:
        color = palette.statusBusy;
        bgColor = palette.statusBusyLight;
        break;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        color = palette.statusMaintenance;
        bgColor = palette.statusMaintenanceLight;
        break;
      case OrderStatus.completed:
        color = palette.statusOperating;
        bgColor = palette.statusOperatingLight;
        break;
    }
    return StatusBadge(
      label: order.status.displayLabel,
      color: color,
      bgColor: bgColor,
    );
  }

  Future<void> _showDeliveryLogs(BuildContext context, int orderId) async {
    if (kIsWeb) return;
    final logs = await context.read<OrderRepository>().getDeliveryLogsForOrder(
      orderId,
    );
    if (!context.mounted) return;
    final palette = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delivery Log',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No delivery logs recorded.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ),
              )
            else
              ...logs.map((log) {
                final qty = log['quantity_delivered'] as int? ?? 0;
                final notes = log['notes'] as String? ?? '';
                final deliveredAt = log['delivered_at'] as String? ?? '';
                String timeStr = '';
                try {
                  timeStr = _formatTime(DateTime.parse(deliveredAt));
                } catch (_) {}
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: palette.statusOperating,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$qty gallon${qty > 1 ? "s" : ""} delivered',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            if (notes.isNotEmpty)
                              Text(
                                notes,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        timeStr,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final displayHour = hour == 0 ? 12 : hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:$minute $period';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _ActionSection extends StatelessWidget {
  final Widget child;
  const _ActionSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.of(context).border)),
      ),
      child: child,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(kButtonRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
