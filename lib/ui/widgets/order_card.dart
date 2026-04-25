// Task 010 — Order card widget: displays a single order
// Task 011 — Added pre-book badge for future-scheduled orders
// Displays a single order with customer info, status, and action buttons
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../data/models/order_model.dart';
import '../../database_helper.dart';
import '../theme/app_theme.dart';

/// Displays a single order as a card with customer info, quantity,
/// status badge, and confirm/reject action buttons for pending orders.
class OrderCard extends StatelessWidget {
  final Order order;
  final String? customerName;
  final String? phone;
  final String? barangay;
  final String? address;
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
    this.onConfirm,
    this.onReject,
    this.onStartDelivery,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isDeliver = order.type == OrderType.deliver;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // --- Top row: icon + customer info + status badge ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order type icon (Truck for deliver, Water drop for walk-in)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDeliver ? AppColors.primaryLight : AppColors.statusAwayLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDeliver ? Icons.local_shipping : Icons.water_drop,
                  size: 20,
                  color: isDeliver ? AppColors.primary : AppColors.statusAway,
                ),
              ),
              const SizedBox(width: 12),
              // Customer details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer name
                    Text(
                      customerName ?? order.phoneNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                    ),
                    // Phone number
                    if (phone != null)
                      Text(
                        phone!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    // Address & barangay
                    if (address != null || barangay != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [address, barangay].whereType<String>().join(' · '),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Quantity badge + pre-book badge + time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${order.quantity} gallon${order.quantity > 1 ? "s" : ""}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        // Task 011 — Pre-book badge
                        if (order.isPreBook) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule, size: 10, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Pre-booked${order.deliveryDay != null ? " (${order.deliveryDay})" : ""}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                        Text(
                          _formatTime(order.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status badge
              _StatusBadge(status: order.status),
            ],
          ),

          // Cancel reason display for cancelled/rejected orders
          if ((order.status == OrderStatus.cancelled || order.status == OrderStatus.rejected) && order.cancelReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusMaintenanceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Reason: ${order.cancelReason}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.statusMaintenance,
                  ),
                ),
              ),
            ),

          // Task 011 — Delivery log link for completed orders
          if (order.status == OrderStatus.completed && order.id != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: GestureDetector(
                onTap: () => _showDeliveryLogs(context, order.id!),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'View Delivery Log',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // --- Action buttons for pending orders ---
          if (order.status == OrderStatus.pending &&
              (onConfirm != null || onReject != null)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  // Confirm button
                  if (onConfirm != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: onConfirm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.statusOperating,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (onConfirm != null && onReject != null)
                    const SizedBox(width: 8),
                  // Reject button
                  if (onReject != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: onReject,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.statusMaintenance,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Reject',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // --- Action buttons for confirmed orders (start delivery) ---
          if (order.status == OrderStatus.confirmed && onStartDelivery != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onStartDelivery,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.statusBusy,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Start Delivery',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // --- Action buttons for in_transit orders (complete delivery) ---
          if (order.status == OrderStatus.inTransit && onComplete != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onComplete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.statusOperating,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Mark Delivered',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Task 011 — Shows delivery logs for a completed order
  void _showDeliveryLogs(BuildContext context, int orderId) async {
    if (kIsWeb) return;
    final logs = await DatabaseHelper.instance.getDeliveryLogsForOrder(orderId);

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
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
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delivery Log',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 16),
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No delivery logs recorded.',
                      style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                    ),
                  ),
                )
              else
                ...logs.map((log) {
                  final qty = log['quantity_delivered'] as int? ?? 0;
                  final gType = log['gallon_type'] as String? ?? '';
                  final notes = log['notes'] as String? ?? '';
                  final deliveredAt = log['delivered_at'] as String? ?? '';
                  String timeStr = '';
                  try {
                    final dt = DateTime.parse(deliveredAt);
                    timeStr = _formatTime(dt);
                  } catch (_) {}

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 18, color: AppColors.statusOperating),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$qty gallon${qty > 1 ? "s" : ""} delivered${gType.isNotEmpty ? " ($gType)" : ""}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.foreground,
                                ),
                              ),
                              if (notes.isNotEmpty)
                                Text(
                                  notes,
                                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  /// Formats a DateTime to a short time string (e.g., "2:30 PM")
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final displayHour = hour == 0 ? 12 : hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:$minute $period';
  }
}

/// Colored status badge (pending = orange, confirmed = green, etc.)
class _StatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case OrderStatus.confirmed:
        bgColor = AppColors.statusOperatingLight;
        textColor = AppColors.statusOperating;
        break;
      case OrderStatus.pending:
        bgColor = AppColors.statusAwayLight;
        textColor = AppColors.statusAway;
        break;
      case OrderStatus.inTransit:
        bgColor = AppColors.statusBusyLight;
        textColor = AppColors.statusBusy;
        break;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        bgColor = AppColors.statusMaintenanceLight;
        textColor = AppColors.statusMaintenance;
        break;
      case OrderStatus.completed:
        bgColor = AppColors.muted;
        textColor = AppColors.mutedForeground;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
