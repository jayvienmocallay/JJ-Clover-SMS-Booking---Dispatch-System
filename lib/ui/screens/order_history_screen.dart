import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/order_detail_sheet.dart';
import '../widgets/shared/empty_state.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  String _dateFilter = 'all';
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final range = _dateRange(_dateFilter);
    final rows = await context.read<OrderRepository>().getOrderHistory(
          startDate: range?.$1,
          endDate: range?.$2,
          status: _statusFilter,
          type: _typeFilter,
          search: _searchController.text,
        );
    if (!mounted) return;
    setState(() {
      _orders = rows;
      _loading = false;
    });
  }

  (DateTime, DateTime)? _dateRange(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case 'today':
        return (today, today.add(const Duration(days: 1)));
      case 'yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        return (yesterday, today);
      case 'week':
        return (today.subtract(const Duration(days: 7)), today.add(const Duration(days: 1)));
      case 'month':
        return (DateTime(now.year, now.month, 1), today.add(const Duration(days: 1)));
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Order History',
          style: TextStyle(color: palette.foreground, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          padding: const EdgeInsets.all(kPagePadding),
          children: [
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _loadOrders(),
              decoration: InputDecoration(
                hintText: 'Search name, phone, or order ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _loadOrders,
                ),
                filled: true,
                fillColor: palette.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kButtonRadius),
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _filterRow([
              _FilterOption('all', 'All Time'),
              _FilterOption('today', 'Today'),
              _FilterOption('yesterday', 'Yesterday'),
              _FilterOption('week', 'This Week'),
              _FilterOption('month', 'This Month'),
            ], _dateFilter, (value) {
              setState(() => _dateFilter = value);
              _loadOrders();
            }),
            const SizedBox(height: 8),
            _filterRow([
              _FilterOption('all', 'All'),
              _FilterOption('pending', 'Pending'),
              _FilterOption('confirmed', 'Confirmed'),
              _FilterOption('in_transit', 'In Transit'),
              _FilterOption('completed', 'Completed'),
              _FilterOption('cancelled', 'Cancelled'),
              _FilterOption('rejected', 'Rejected'),
            ], _statusFilter, (value) {
              setState(() => _statusFilter = value);
              _loadOrders();
            }),
            const SizedBox(height: 8),
            _filterRow([
              _FilterOption('all', 'All Types'),
              _FilterOption('deliver', 'Delivery'),
              _FilterOption('drop', 'Walk-in'),
              _FilterOption('unrecognized', 'Invalid'),
            ], _typeFilter, (value) {
              setState(() => _typeFilter = value);
              _loadOrders();
            }),
            const SizedBox(height: 16),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 56),
                child: Center(child: CircularProgressIndicator(color: palette.primary)),
              )
            else if (_orders.isEmpty)
              const EmptyState(icon: Icons.history, message: 'No matching orders found.')
            else
              ..._orders.map((row) => _HistoryCard(row: row, onChanged: _loadOrders)),
          ],
        ),
      ),
    );
  }

  Widget _filterRow(List<_FilterOption> options, String selected, ValueChanged<String> onChanged) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          final isSelected = option.value == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option.label),
              selected: isSelected,
              onSelected: (_) => onChanged(option.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  const _HistoryCard({required this.row, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final order = Order.fromMap(row);
    final palette = AppColors.of(context);
    final customerName = row['customer_name'] as String?;
    final barangay = row['barangay'] as String?;
    final address = order.address ?? row['customer_address'] as String?;
    return GestureDetector(
      onTap: () => _showDetails(context, order, customerName, barangay, address),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_typeIcon(order.type), color: palette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName ?? order.phoneNumber,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${order.id} · ${order.quantity} gal · ${_typeLabel(order.type)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (barangay?.isNotEmpty == true || address?.isNotEmpty == true)
                    Text(
                      [address, barangay].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Text(_formatDateTime(order.createdAt), style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.muted,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(order.status.displayLabel, style: Theme.of(context).textTheme.labelSmall),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    Order order,
    String? customerName,
    String? barangay,
    String? address,
  ) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OrderDetailSheet(
        order: order,
        customerName: customerName,
        phone: order.phoneNumber,
        barangay: barangay,
        address: address,
        onCompleted: onChanged,
      ),
    );
    onChanged();
  }

  IconData _typeIcon(OrderType type) {
    switch (type) {
      case OrderType.deliver:
        return Icons.local_shipping;
      case OrderType.drop:
        return Icons.water_drop;
      case OrderType.unrecognized:
        return Icons.sms_failed;
    }
  }

  String _typeLabel(OrderType type) {
    switch (type) {
      case OrderType.deliver:
        return 'Delivery';
      case OrderType.drop:
        return 'Walk-in';
      case OrderType.unrecognized:
        return 'Invalid';
    }
  }

  String _formatDateTime(DateTime dt) {
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour}:$minute';
  }
}

class _FilterOption {
  final String value;
  final String label;
  const _FilterOption(this.value, this.label);
}
