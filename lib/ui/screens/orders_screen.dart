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
import '../widgets/shared/brand_mascot.dart';
import '../widgets/shared/empty_state.dart';
import 'delivery_logs_screen.dart';
import 'order_history_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _filterIndex = 0;
  String _searchQuery = '';

  static const _filterStatuses = ['all', 'pending', 'confirmed', 'in_transit'];

  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> orders) {
    var result = orders;
    final status = _filterStatuses[_filterIndex];
    if (status != 'all') {
      result = result.where((o) => o['status'] == status).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((o) {
        final name = (o['customer_name'] as String? ?? '').toLowerCase();
        final phone = (o['phone_number'] as String? ?? '').toLowerCase();
        final id = (o['id']?.toString() ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q) || id.contains(q);
      }).toList();
    }
    return result;
  }

  PopupMenuItem<int> _buildStatusMenuItem({
    required BuildContext context,
    required int index,
    required String label,
    required int count,
    required Color color,
  }) {
    final palette = AppColors.of(context);
    final selected = _filterIndex == index;
    return PopupMenuItem<int>(
      value: index,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check, size: 16, color: palette.primary),
          ],
        ],
      ),
    );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order confirmed ✓')));
  }

  Future<void> _startDelivery(Order order, OrderProvider orderProv) async {
    await orderProv.updateStatus(order.id!, 'in_transit');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Delivery started ✓')));
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
        onConfirm:
            order.type != OrderType.unrecognized &&
                order.status == OrderStatus.pending
            ? () => _confirmOrder(order, orderProv)
            : null,
        onReject:
            order.type != OrderType.unrecognized &&
                order.status == OrderStatus.pending
            ? () => _showRejectDialog(order.id!, orderProv)
            : null,
        onStartDelivery:
            order.type != OrderType.unrecognized &&
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
      if (customer?['address'] != null)
        'customer_address': customer!['address'],
      if (customer?['barangay'] != null) 'barangay': customer!['barangay'],
      if (customer?['delivery_zone'] != null)
        'delivery_zone': customer!['delivery_zone'],
    };
  }

  Widget _buildOrderCard(
    Map<String, dynamic> orderMap,
    Map<int, Map<String, dynamic>> customerCache,
    OrderProvider orderProv,
  ) {
    final order = Order.fromMap(orderMap);
    final customer = order.customerId != null
        ? customerCache[order.customerId]
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OrderCard(
        onTap: () => _showOrderDetails(order, customer, orderProv),
        order: order,
        customerName: customer?['name'] as String?,
        phone: order.phoneNumber,
        barangay: customer?['barangay'] as String?,
        address: order.address ?? (customer?['address'] as String?),
        onConfirm:
            order.type != OrderType.unrecognized &&
                order.status == OrderStatus.pending
            ? () => _confirmOrder(order, orderProv)
            : null,
        onReject:
            order.type != OrderType.unrecognized &&
                order.status == OrderStatus.pending
            ? () => _showRejectDialog(order.id!, orderProv)
            : null,
        onStartDelivery:
            order.type != OrderType.unrecognized &&
                order.status == OrderStatus.confirmed
            ? () => _startDelivery(order, orderProv)
            : null,
        onComplete:
            order.type != OrderType.unrecognized &&
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
        .where(
          (order) =>
              order['type'] != 'unrecognized' &&
              activeStatuses.contains(order['status'] as String? ?? ''),
        )
        .toList();
    final otherOrders = filtered
        .where((order) => !activeOrders.contains(order))
        .toList();
    final groups = buildDispatchGroups(activeOrders);

    return [
      ...groups.expand(
        (group) => [
          DispatchGroupHeader(title: group.title, subtitle: group.subtitle),
          ...group.items.map(
            (order) => _buildOrderCard(order, customerCache, orderProv),
          ),
        ],
      ),
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
        final palette = AppColors.of(context);
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
        final allCount = orderProv.todayOrders
            .where((o) => o['type'] != 'unrecognized')
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
                title: 'Orders',
                subtitle: "Manage today's delivery and walk-in orders.",
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderIconButton(
                      icon: Icons.calendar_month,
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
                            const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Add',
                              style: Theme.of(context).textTheme.labelLarge
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
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(kButtonRadius),
                  border: Border.all(color: palette.border),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search order ID, customer, or address...',
                    hintStyle: TextStyle(
                      color: palette.mutedForeground,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: palette.mutedForeground,
                    ),
                    suffixIcon: PopupMenuButton<int>(
                      tooltip: 'Filter status',
                      onSelected: (index) =>
                          setState(() => _filterIndex = index),
                      itemBuilder: (context) => [
                        _buildStatusMenuItem(
                          context: context,
                          index: 0,
                          label: 'All',
                          count: allCount,
                          color: palette.primary,
                        ),
                        _buildStatusMenuItem(
                          context: context,
                          index: 1,
                          label: 'Pending',
                          count: orderProv.pendingCount,
                          color: palette.statusAway,
                        ),
                        _buildStatusMenuItem(
                          context: context,
                          index: 2,
                          label: 'Confirmed',
                          count: orderProv.confirmedCount,
                          color: palette.statusOperating,
                        ),
                        _buildStatusMenuItem(
                          context: context,
                          index: 3,
                          label: 'In Transit',
                          count: inTransitCount,
                          color: palette.statusBusy,
                        ),
                      ],
                      icon: SizedBox(
                        width: 24,
                        height: 24,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.tune,
                              size: 20,
                              color: palette.mutedForeground,
                            ),
                            if (_filterIndex != 0)
                              Positioned(
                                right: 1,
                                top: 2,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: palette.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                EmptyState(
                  icon: Icons.local_shipping,
                  mascot: _searchQuery.isNotEmpty
                      ? MascotPose.checklist
                      : MascotPose.deliveryTruck,
                  title: _searchQuery.isNotEmpty
                      ? 'Nothing matched'
                      : 'No active orders',
                  message: _searchQuery.isNotEmpty
                      ? 'No orders match "$_searchQuery".'
                      : _filterIndex == 0
                      ? 'No orders today.'
                      : 'No ${_filterStatuses[_filterIndex]} orders.',
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
        title: Text(
          'Reject Order',
          style: Theme.of(ctx).textTheme.headlineSmall,
        ),
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
              await orderProv.updateStatus(
                orderId,
                'rejected',
                reason: reason?.trim(),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Order rejected ✓')));
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
        child: Icon(
          icon,
          size: 20,
          color: AppColors.of(context).mutedForeground,
        ),
      ),
    );
  }
}
