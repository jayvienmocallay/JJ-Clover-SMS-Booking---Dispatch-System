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
import '../widgets/shared/search_field.dart';
import 'delivery_logs_screen.dart';
import 'order_history_screen.dart';

class OrdersScreen extends StatefulWidget {
  final int initialFilterIndex;
  final ValueChanged<int>? onFilterChanged;

  const OrdersScreen({
    super.key,
    this.initialFilterIndex = 0,
    this.onFilterChanged,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late int _filterIndex;
  String _searchQuery = '';

  static const _filterStatuses = ['all', 'pending', 'confirmed', 'in_transit'];

  @override
  void initState() {
    super.initState();
    _filterIndex = _clampFilterIndex(widget.initialFilterIndex);
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilterIndex != widget.initialFilterIndex) {
      final nextIndex = _clampFilterIndex(widget.initialFilterIndex);
      if (_filterIndex != nextIndex) {
        setState(() => _filterIndex = nextIndex);
      }
    }
  }

  int _clampFilterIndex(int index) {
    if (index < 0 || index >= _filterStatuses.length) return 0;
    return index;
  }

  void _setFilterIndex(int index) {
    final nextIndex = _clampFilterIndex(index);
    if (_filterIndex == nextIndex) return;
    setState(() => _filterIndex = nextIndex);
    widget.onFilterChanged?.call(nextIndex);
  }

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

  int _filterCount(List<Map<String, dynamic>> orders, int index) {
    final status = _filterStatuses[_clampFilterIndex(index)];
    return status == 'all'
        ? _operationalCount(orders)
        : _statusCount(orders, status);
  }

  String _filterLabel(int index) {
    switch (_filterStatuses[_clampFilterIndex(index)]) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_transit':
        return 'In Transit';
      default:
        return 'All';
    }
  }

  Color _filterColor(BuildContext context, int index) {
    final palette = AppColors.of(context);
    switch (_filterStatuses[_clampFilterIndex(index)]) {
      case 'pending':
        return palette.statusAway;
      case 'confirmed':
        return palette.statusOperating;
      case 'in_transit':
        return palette.statusBusy;
      default:
        return palette.primary;
    }
  }

  IconData _filterIcon(int index) {
    switch (_filterStatuses[_clampFilterIndex(index)]) {
      case 'pending':
        return Icons.hourglass_top;
      case 'confirmed':
        return Icons.check_circle;
      case 'in_transit':
        return Icons.local_shipping;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  void _showFilterSheet(List<Map<String, dynamic>> orders) {
    final palette = AppColors.of(context);
    final options = List.generate(
      _filterStatuses.length,
      (index) => _OrderFilterOption(
        index: index,
        label: _filterLabel(index),
        count: _filterCount(orders, index),
        color: _filterColor(context, index),
        icon: _filterIcon(index),
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              const SizedBox(height: 18),
              Text(
                'Filter orders',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose which order status to show.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.mutedForeground),
              ),
              const SizedBox(height: 16),
              ...options.map(
                (option) => _FilterOptionTile(
                  option: option,
                  selected: _filterIndex == option.index,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _setFilterIndex(option.index);
                  },
                ),
              ),
            ],
          ),
        ),
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

  Future<bool> _confirmOrder(Order order, OrderProvider orderProv) async {
    await orderProv.updateStatus(order.id!, 'confirmed');
    if (!mounted) return false;
    if (orderProv.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(orderProv.error!)));
      return false;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order confirmed ✓')));
    return true;
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
        final activeFilterColor = _filterColor(context, _filterIndex);
        final activeFilterCount = _filterCount(countableOrders, _filterIndex);

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
                      tooltip: 'Order history',
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
                      tooltip: 'Delivery logs',
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
                        height: 44,
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
              Row(
                children: [
                  Expanded(
                    child: SearchField(
                      hintText: 'Search ID, customer, phone, or barangay...',
                      initialValue: _searchQuery,
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FilterButton(
                    label: _filterLabel(_filterIndex),
                    count: activeFilterCount,
                    color: activeFilterColor,
                    icon: _filterIcon(_filterIndex),
                    onTap: () => _showFilterSheet(countableOrders),
                  ),
                ],
              ),
              if (_filterIndex != 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Showing ${_filterLabel(_filterIndex).toLowerCase()} orders',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: activeFilterColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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

  Future<bool> _showRejectDialog(int orderId, OrderProvider orderProv) async {
    String? reason;
    final confirmed = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    await orderProv.updateStatus(orderId, 'rejected', reason: reason?.trim());
    if (!mounted) return false;
    if (orderProv.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(orderProv.error!)));
      return false;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order rejected ✓')));
    return true;
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.of(context).muted,
        borderRadius: BorderRadius.circular(kButtonRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kButtonRadius),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 20,
              color: AppColors.of(context).mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderFilterOption {
  final int index;
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _OrderFilterOption({
    required this.index,
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
}

class _FilterButton extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Filter orders',
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(kButtonRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52, minWidth: 96),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          '$label ($count)',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, size: 18, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  final _OrderFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  const _FilterOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? option.color.withValues(alpha: 0.14)
                : palette.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? option.color.withValues(alpha: 0.5)
                  : palette.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(option.icon, size: 18, color: option.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: selected ? option.color : palette.foreground,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${option.count}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: option.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 10),
                Icon(Icons.check_circle, size: 18, color: option.color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
