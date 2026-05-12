import 'dart:async';

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
  bool _filtersOpen = false;
  List<Map<String, dynamic>> _orders = [];
  String _dateFilter = 'all';
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  Timer? _searchTimer;
  final _searchController = TextEditingController();

  static const _dateOptions = [
    _FilterOption('all', 'All Time'),
    _FilterOption('today', 'Today'),
    _FilterOption('yesterday', 'Yesterday'),
    _FilterOption('week', '7 Days'),
    _FilterOption('month', 'This Month'),
  ];
  static const _statusOptions = [
    _FilterOption('all', 'All Statuses'),
    _FilterOption('pending', 'Pending'),
    _FilterOption('confirmed', 'Confirmed'),
    _FilterOption('in_transit', 'In Transit'),
    _FilterOption('completed', 'Completed'),
    _FilterOption('cancelled', 'Cancelled'),
    _FilterOption('rejected', 'Rejected'),
  ];
  static const _typeOptions = [
    _FilterOption('all', 'All Types'),
    _FilterOption('deliver', 'Delivery'),
    _FilterOption('drop', 'Walk-in'),
    _FilterOption('unrecognized', 'Invalid'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final range = _dateRange(_dateFilter);
      final rows = await context.read<OrderRepository>().getOrderHistory(
            startDate: range?.$1,
            endDate: range?.$2,
            status: _statusFilter,
            type: _typeFilter,
            search: _searchController.text,
          );
      if (!mounted) return;
      setState(() => _orders = rows);
    } catch (e, st) {
      debugPrint('Failed to load order history: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load orders. Please restart or check logs.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  int get _activeFilterCount {
    var count = 0;
    if (_dateFilter != 'all') count++;
    if (_statusFilter != 'all') count++;
    if (_typeFilter != 'all') count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  void _setFilter(void Function() change) {
    setState(change);
    _loadOrders();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), _loadOrders);
    setState(() {});
  }

  void _clearFilters() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _dateFilter = 'all';
      _statusFilter = 'all';
      _typeFilter = 'all';
      _filtersOpen = false;
    });
    _loadOrders();
  }

  String _label(List<_FilterOption> options, String value) =>
      options.firstWhere((o) => o.value == value).label;

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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: palette.primary),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        color: palette.primary,
        child: ListView(
          padding: const EdgeInsets.all(kPagePadding),
          children: [
            _FilterPanel(
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              onSearchSubmit: _loadOrders,
              filtersOpen: _filtersOpen,
              onToggleFilters: () => setState(() => _filtersOpen = !_filtersOpen),
              activeFilterCount: _activeFilterCount,
              summary: '${_label(_dateOptions, _dateFilter)} / ${_label(_statusOptions, _statusFilter)} / ${_label(_typeOptions, _typeFilter)}',
              dateOptions: _dateOptions,
              statusOptions: _statusOptions,
              typeOptions: _typeOptions,
              dateFilter: _dateFilter,
              statusFilter: _statusFilter,
              typeFilter: _typeFilter,
              onDateChanged: (v) => _setFilter(() => _dateFilter = v),
              onStatusChanged: (v) => _setFilter(() => _statusFilter = v),
              onTypeChanged: (v) => _setFilter(() => _typeFilter = v),
              onClearSearch: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _loading ? 'Loading orders...' : '${_orders.length} ${_orders.length == 1 ? 'order' : 'orders'} found',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                if (_activeFilterCount > 0)
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(foregroundColor: palette.primary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
}

class _FilterPanel extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmit;
  final bool filtersOpen;
  final VoidCallback onToggleFilters;
  final int activeFilterCount;
  final String summary;
  final List<_FilterOption> dateOptions;
  final List<_FilterOption> statusOptions;
  final List<_FilterOption> typeOptions;
  final String dateFilter;
  final String statusFilter;
  final String typeFilter;
  final ValueChanged<String> onDateChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onClearSearch;

  const _FilterPanel({
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmit,
    required this.filtersOpen,
    required this.onToggleFilters,
    required this.activeFilterCount,
    required this.summary,
    required this.dateOptions,
    required this.statusOptions,
    required this.typeOptions,
    required this.dateFilter,
    required this.statusFilter,
    required this.typeFilter,
    required this.onDateChanged,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(kCardPadding),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            onSubmitted: (_) => onSearchSubmit(),
            decoration: InputDecoration(
              hintText: 'Search name, phone, or order ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.trim().isEmpty
                  ? IconButton(icon: const Icon(Icons.arrow_forward), onPressed: onSearchSubmit)
                  : IconButton(icon: const Icon(Icons.close), onPressed: onClearSearch),
              filled: true,
              fillColor: palette.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kButtonRadius),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              InkWell(
                onTap: onToggleFilters,
                borderRadius: BorderRadius.circular(kButtonRadius),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.muted,
                    borderRadius: BorderRadius.circular(kButtonRadius),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 16, color: palette.primary),
                      const SizedBox(width: 6),
                      Text(
                        activeFilterCount == 0 ? 'Filters' : 'Filters ($activeFilterCount)',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Icon(filtersOpen ? Icons.expand_less : Icons.expand_more, size: 16, color: palette.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterSection(title: 'Date range', options: dateOptions, selected: dateFilter, onChanged: onDateChanged),
                  const SizedBox(height: 12),
                  _FilterSection(title: 'Order status', options: statusOptions, selected: statusFilter, onChanged: onStatusChanged),
                  const SizedBox(height: 12),
                  _FilterSection(title: 'Order type', options: typeOptions, selected: typeFilter, onChanged: onTypeChanged),
                ],
              ),
            ),
            crossFadeState: filtersOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final List<_FilterOption> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterSection({required this.title, required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option.value == selected;
            return ChoiceChip(
              label: Text(option.label),
              selected: isSelected,
              onSelected: (_) => onChanged(option.value),
              selectedColor: palette.primaryLight,
              backgroundColor: palette.muted,
              side: BorderSide(color: isSelected ? palette.primary : palette.border),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? palette.primary : palette.mutedForeground,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
            );
          }).toList(),
        ),
      ],
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
    final typeColor = _typeColor(context, order.type);
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(_typeIcon(order.type), size: 18, color: typeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName ?? (order.phoneNumber.isEmpty ? 'Unknown customer' : order.phoneNumber),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text('#${order.id} / ${order.quantity} gal / ${_typeLabel(order.type)}', style: Theme.of(context).textTheme.bodySmall),
                  if (barangay?.isNotEmpty == true || address?.isNotEmpty == true)
                    Text(
                      [address, barangay].whereType<String>().where((v) => v.isNotEmpty).join(' / '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Text(_formatDateTime(order.createdAt), style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusPill(status: order.status),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context, Order order, String? customerName, String? barangay, String? address) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

  Color _typeColor(BuildContext context, OrderType type) {
    final palette = AppColors.of(context);
    switch (type) {
      case OrderType.deliver:
        return palette.primary;
      case OrderType.drop:
        return palette.statusAway;
      case OrderType.unrecognized:
        return palette.statusMaintenance;
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

class _StatusPill extends StatelessWidget {
  final OrderStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final color = _statusColor(palette, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        status.displayLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _statusColor(AppPalette palette, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return palette.statusAway;
      case OrderStatus.confirmed:
        return palette.statusOperating;
      case OrderStatus.inTransit:
        return palette.statusBusy;
      case OrderStatus.completed:
        return palette.primary;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return palette.statusMaintenance;
    }
  }
}

class _FilterOption {
  final String value;
  final String label;
  const _FilterOption(this.value, this.label);
}
