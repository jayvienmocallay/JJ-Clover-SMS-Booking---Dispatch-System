import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import '../../data/models/order_model.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/providers/order_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_order_form.dart';
import '../widgets/complete_order_sheet.dart';
import '../widgets/dispatch_grouping.dart';
import '../widgets/order_card.dart';
import '../widgets/order_detail_sheet.dart';
import '../widgets/shared/app_page_header.dart';
import '../widgets/shared/empty_state.dart';
import '../widgets/shared/filter_chip_row.dart';
import 'delivery_logs_screen.dart';
import 'order_history_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _filterIndex = 0;

  static const _filterTypes = ['all', 'deliver', 'drop', 'unrecognized'];
  static const _filterLabels = ['All', 'Deliveries', 'Walk-ins', 'Invalid'];

  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> orders) {
    final type = _filterTypes[_filterIndex];
    if (type == 'all') return orders;
    return orders.where((order) => order['type'] == type).toList();
  }

  void _showAddOrderSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<OrderProvider>(),
        child: ChangeNotifierProvider.value(
          value: context.read<CustomerProvider>(),
          child: const AddOrderForm(),
        ),
      ),
    );
  }

  Future<void> _confirmOrder(Order order, OrderProvider orderProv) async {
    await orderProv.updateStatus(order.id!, 'confirmed');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order confirmed ✓')),
    );
  }

  Future<void> _startDelivery(Order order, OrderProvider orderProv) async {
    await orderProv.updateStatus(order.id!, 'in_transit');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delivery started ✓')),
    );
  }

  Future<void> _showCompleteOrderSheet(
    Order order,
    OrderProvider orderProv,
  ) async {
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CompleteOrderSheet(order: order),
    );
    if (completed == true) await orderProv.loadOrders();
  }

  Future<void> _showOrderDetails(
    Order order,
    Map<String, dynamic>? customer,
    OrderProvider orderProv,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OrderDetailSheet(
        order: order,
        customerName: customer?['name'] as String?,
        phone: order.phoneNumber,
        barangay: customer?['barangay'] as String?,
        address: order.address ?? (customer?['address'] as String?),
        onConfirm: order.type != OrderType.unrecognized &&
                order.status == OrderStatus.pending
            ? () => _confirmOrder(order, orderProv)
            : null,
        onReject: order.type != OrderType.unrecognized &&
                order.status == OrderStatus.pending
            ? () => _showRejectDialog(order.id!, orderProv)
            : null,
        onStartDelivery: order.type != OrderType.unrecognized &&
                order.status == OrderStatus.confirmed
            ? () => _startDelivery(order, orderProv)
            : null,
        onCompleted: () => orderProv.loadOrders(),
      ),
    );
    if (changed == true) await orderProv.loadOrders();
  }

  Map<String, dynamic> _enrichOrder(
    Map<String, dynamic> order,
    Map<int, Map<String, dynamic>> customerCache,
  ) {
    final customerId = order['customer_id'] as int?;
    final customer = customerId == null ? null : customerCache[customerId];
    return {
      ...order,
      if (customer?['name'] != null) 'customer_name': customer!['name'],
      if (customer?['address'] != null) 'customer_address': customer!['address'],
      if (customer?['barangay'] != null) 'barangay': customer!['barangay'],
      if (customer?['delivery_zone'] != null) 'delivery_zone': customer!['delivery_zone'],
    };
  }

  Widget _buildOrderCard(
    Map<String, dynamic> orderMap,
    Map<int, Map<String, dynamic>> customerCache,
    OrderProvider orderProv,
  ) {
    final order = Order.fromMap(orderMap);
    final customer = order.customerId != null ? customerCache[order.customerId] : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OrderCard(
        onTap: () => _showOrderDetails(order, customer, orderProv),
        order: order,
        customerName: customer?['name'] as String?,
        phone: order.phoneNumber,
        barangay: customer?['barangay'] as String?,
        address: order.address ?? (customer?['address'] as String?),
        onConfirm: order.type != OrderType.unrecognized &&
                order.status == OrderStatus.pending
            ? () => _confirmOrder(order, orderProv)
            : null,
        onReject: order.type != OrderType.unrecognized &&
                order.status == OrderStatus.pending
            ? () => _showRejectDialog(order.id!, orderProv)
            : null,
        onStartDelivery: order.type != OrderType.unrecognized &&
                order.status == OrderStatus.confirmed
            ? () => _startDelivery(order, orderProv)
            : null,
        onComplete: order.type != OrderType.unrecognized &&
                order.status == OrderStatus.inTransit
            ? () => _showCompleteOrderSheet(order, orderProv)
            : null,
      ),
    );
  }

  List<Widget> _buildGroupedDispatchList(
    List<Map<String, dynamic>> filtered,
    Map<int, Map<String, dynamic>> customerCache,
    OrderProvider orderProv,
  ) {
    final activeStatuses = {'pending', 'confirmed', 'in_transit'};
    final activeOrders = filtered
        .where((order) =>
            order['type'] != 'unrecognized' &&
            activeStatuses.contains(order['status'] as String? ?? ''))
        .toList();
    final otherOrders = filtered
        .where((order) => !activeOrders.contains(order))
        .toList();
    final groups = buildDispatchGroups(activeOrders);

    return [
      ...groups.expand((group) => [
            DispatchGroupHeader(title: group.title, subtitle: group.subtitle),
            ...group.items.map(
              (order) => _buildOrderCard(order, customerCache, orderProv),
            ),
          ]),
      if (otherOrders.isNotEmpty) ...[
        const DispatchGroupHeader(
          title: 'Completed / Review',
          subtitle: 'Orders no longer in active dispatch',
        ),
        ...otherOrders.map(
          (order) => _buildOrderCard(order, customerCache, orderProv),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrderProvider, CustomerProvider>(
      builder: (context, orderProv, customerProv, _) {
        final customerCache = <int, Map<String, dynamic>>{};
        for (final customer in customerProv.customers) {
          final id = customer['id'] as int?;
          if (id != null) customerCache[id] = customer;
        }

        final enrichedOrders = orderProv.todayOrders
            .map((order) => _enrichOrder(order, customerCache))
            .toList();
        final filtered = _filterOrders(enrichedOrders);
        final inTransitCount = orderProv.todayOrders
            .where((order) => order['status'] == 'in_transit')
            .length;

        return RefreshIndicator(
          onRefresh: () async {
            if (kIsWeb) return;
            await orderProv.loadOrders();
          },
          child: ListView(
            padding: const EdgeInsets.all(kPagePadding),
            children: [
              AppPageHeader(
                title: 'Today\'s Orders',
                subtitle: "Manage today's dispatch and walk-in queue.",
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderIconButton(
                      icon: Icons.history,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrderHistoryScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HeaderIconButton(
                      icon: Icons.receipt_long,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeliveryLogsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showAddOrderSheet,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.of(context).primary,
                          borderRadius: BorderRadius.circular(kButtonRadius),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Add',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSectionGap),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SummaryChip(
                      label: 'Pending ${orderProv.pendingCount}',
                      color: AppColors.of(context).statusAway,
                    ),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      label: 'Confirmed ${orderProv.confirmedCount}',
                      color: AppColors.of(context).statusOperating,
                    ),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      label: 'In Transit $inTransitCount',
                      color: AppColors.of(context).statusBusy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilterChipRow(
                labels: _filterLabels,
                selectedIndex: _filterIndex,
                onSelected: (i) => setState(() => _filterIndex = i),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                EmptyState(
                  icon: Icons.local_shipping,
                  message: _filterIndex == 0
                      ? 'No orders today.'
                      : 'No ${_filterLabels[_filterIndex].toLowerCase()} orders.',
                )
              else if (_filterTypes[_filterIndex] == 'unrecognized')
                ...filtered.map(
                  (order) => _buildOrderCard(order, customerCache, orderProv),
                )
              else
                ..._buildGroupedDispatchList(
                  filtered,
                  customerCache,
                  orderProv,
                ),
            ],
          ),
        );
      },
    );
  }

  void _showRejectDialog(int orderId, OrderProvider orderProv) {
    String? reason;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.of(ctx).card,
        title: Text('Reject Order', style: Theme.of(ctx).textTheme.headlineSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject this order?',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: AppColors.of(ctx).mutedForeground,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => reason = v,
              style: Theme.of(ctx).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                filled: true,
                fillColor: AppColors.of(ctx).background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kButtonRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(ctx).statusMaintenance,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await orderProv.updateStatus(orderId, 'rejected', reason: reason?.trim());
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order rejected ✓')),
              );
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.of(context).muted,
          borderRadius: BorderRadius.circular(kButtonRadius),
        ),
        child: Icon(icon, size: 20, color: AppColors.of(context).mutedForeground),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
