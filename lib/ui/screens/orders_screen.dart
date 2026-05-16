import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import '../../data/models/order_model.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/services/command_handlers/sms_handler_utils.dart';
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
        final address =
            ((o['address'] ?? o['customer_address']) as String? ?? '')
                .toLowerCase();
        final barangay = (o['barangay'] as String? ?? '').toLowerCase();
        return name.contains(q) ||
            phone.contains(q) ||
            id.contains(q) ||
            address.contains(q) ||
            barangay.contains(q);
      }).toList();
    }
    return result;
  }

  int _operationalCount(List<Map<String, dynamic>> orders) {
    return orders.where((o) => o['type'] != 'unrecognized').length;
  }

  int _statusCount(List<Map<String, dynamic>> orders, String status) {
    return orders
        .where((o) => o['type'] != 'unrecognized' && o['status'] == status)
        .length;
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

  Future<bool> _startDelivery(Order order, OrderProvider orderProv) async {
    final orderId = order.id;
    if (orderId == null) return false;

    final smsMessage = _deliveryStartedSms(order);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: palette.card,
          title: Text(
            'Start Delivery?',
            style: Theme.of(ctx).textTheme.headlineSmall,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will move the order to In Transit and notify the customer by SMS.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.muted,
                  borderRadius: BorderRadius.circular(kButtonRadius),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  smsMessage,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.statusBusy,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Start Delivery'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return false;

    await orderProv.updateStatus(orderId, 'in_transit');
    if (!mounted) return false;
    if (orderProv.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(orderProv.error!)));
      return false;
    }

    await SmsHandlerUtils.sendReply(order.phoneNumber, smsMessage);
    if (!mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery started. Customer SMS notification queued.'),
      ),
    );
    return true;
  }

  String _deliveryStartedSms(Order order) {
    final quantity = order.quantity > 0
        ? ' (${order.quantity} gallon${order.quantity == 1 ? '' : 's'})'
        : '';
    return 'JJ Clover: Your water order$quantity is on the way. '
        'Please prepare to receive it. Thank you!';
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
            ? () {
                _startDelivery(order, orderProv);
              }
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

  List<Widget> _buildPreBookSection(
    List<Map<String, dynamic>> preBookOrders,
    Map<int, Map<String, dynamic>> customerCache,
    OrderProvider orderProv,
  ) {
    final count = preBookOrders.length;
    return [
      DispatchGroupHeader(
        title: 'Pre-booked Orders',
        subtitle:
            '$count upcoming ${count == 1 ? 'order' : 'orders'} scheduled after today',
      ),
      ...preBookOrders.map(
        (order) => _buildOrderCard(order, customerCache, orderProv),
      ),
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
        final enrichedPreBookOrders = orderProv.upcomingPreBookOrders
            .map((order) => _enrichOrder(order, customerCache))
            .toList();
        final countableOrders = [...enrichedOrders, ...enrichedPreBookOrders];
        final filtered = _filterOrders(enrichedOrders);
        final filteredPreBook = _filterOrders(enrichedPreBookOrders);
        final hasVisibleOrders =
            filtered.isNotEmpty || filteredPreBook.isNotEmpty;
        final inTransitCount = _statusCount(countableOrders, 'in_transit');
        final allCount = _operationalCount(countableOrders);

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
                subtitle:
                    "Manage today's delivery, walk-in, and pre-booked orders.",
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
              // Status filter tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatusTab(
                      label: 'All',
                      count: allCount,
                      selected: _filterIndex == 0,
                      color: AppColors.of(context).primary,
                      onTap: () => setState(() => _filterIndex = 0),
                    ),
                    const SizedBox(width: 8),
                    _StatusTab(
                      label: 'Pending',
                      count: _statusCount(countableOrders, 'pending'),
                      selected: _filterIndex == 1,
                      color: AppColors.of(context).statusAway,
                      onTap: () => setState(() => _filterIndex = 1),
                    ),
                    const SizedBox(width: 8),
                    _StatusTab(
                      label: 'Confirmed',
                      count: _statusCount(countableOrders, 'confirmed'),
                      selected: _filterIndex == 2,
                      color: AppColors.of(context).statusOperating,
                      onTap: () => setState(() => _filterIndex = 2),
                    ),
                    const SizedBox(width: 8),
                    _StatusTab(
                      label: 'In Transit',
                      count: inTransitCount,
                      selected: _filterIndex == 3,
                      color: AppColors.of(context).statusBusy,
                      onTap: () => setState(() => _filterIndex = 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.of(context).card,
                  borderRadius: BorderRadius.circular(kButtonRadius),
                  border: Border.all(color: AppColors.of(context).border),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search order ID, customer, or address...',
                    hintStyle: TextStyle(
                      color: AppColors.of(context).mutedForeground,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.of(context).mutedForeground,
                    ),
                    suffixIcon: Icon(
                      Icons.tune,
                      size: 20,
                      color: AppColors.of(context).mutedForeground,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!hasVisibleOrders)
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
              else ...[
                if (filteredPreBook.isNotEmpty)
                  ..._buildPreBookSection(
                    filteredPreBook,
                    customerCache,
                    orderProv,
                  ),
                if (filtered.isNotEmpty)
                  ..._buildGroupedDispatchList(
                    filtered,
                    customerCache,
                    orderProv,
                  ),
              ],
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

class _StatusTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatusTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.3)
                    : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
