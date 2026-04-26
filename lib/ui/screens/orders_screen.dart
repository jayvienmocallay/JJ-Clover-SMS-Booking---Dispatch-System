// Task 010 — Orders screen: scrollable list with filter tabs and add order form
// Task 011 — Connected to OrderProvider via Consumer for reactive updates
// Scrollable list with filter tabs, order cards, and add order form
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/models/order_model.dart';
import '../../core/constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../widgets/order_card.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  // Filter: 'all', 'deliver', 'drop', or 'unrecognized'
  String _filter = 'all';

  /// Filters orders by type
  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> orders) {
    if (_filter == 'all') return orders;
    return orders.where((o) => o['type'] == _filter).toList();
  }

  /// Shows the Add Order bottom sheet form
  void _showAddOrderSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<OrderProvider>(),
        child: ChangeNotifierProvider.value(
          value: context.read<CustomerProvider>(),
          child: const _AddOrderForm(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrderProvider, CustomerProvider>(
      builder: (context, orderProv, customerProv, _) {
        final filtered = _filterOrders(orderProv.todayOrders);
        // Build customer cache for name/phone lookup
        final customerCache = <int, Map<String, dynamic>>{};
        for (final c in customerProv.customers) {
          final id = c['id'] as int?;
          if (id != null) customerCache[id] = c;
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (kIsWeb) return;
            await orderProv.loadOrders();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Header ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orders',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Manage today's delivery and walk-in orders.",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showAddOrderSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Add Order',
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
                ],
              ),
              const SizedBox(height: 20),

              // --- Filter tabs ---
              Row(
                children: [
                  _FilterTab(
                    label: 'All',
                    isActive: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    label: 'Deliveries',
                    isActive: _filter == 'deliver',
                    onTap: () => setState(() => _filter = 'deliver'),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    label: 'Walk-ins',
                    isActive: _filter == 'drop',
                    onTap: () => setState(() => _filter = 'drop'),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    label: 'Invalid',
                    isActive: _filter == 'unrecognized',
                    onTap: () => setState(() => _filter = 'unrecognized'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Order list ---
              if (filtered.isEmpty)
                _buildEmptyState()
              else
                ...filtered.map((orderMap) {
                  final order = Order.fromMap(orderMap);
                  final customer = order.customerId != null
                      ? customerCache[order.customerId]
                      : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OrderCard(
                      order: order,
                      customerName: customer?['name'] as String?,
                      phone: order.phoneNumber,
                      barangay: customer?['barangay'] as String?,
                      address:
                          order.address ?? (customer?['address'] as String?),
                      onConfirm:
                          order.type != OrderType.unrecognized &&
                              order.status == OrderStatus.pending
                          ? () => orderProv.updateStatus(order.id!, 'confirmed')
                          : null,
                      onReject:
                          order.type != OrderType.unrecognized &&
                              order.status == OrderStatus.pending
                          ? () => _showRejectDialog(order.id!, orderProv)
                          : null,
                      onStartDelivery:
                          order.type != OrderType.unrecognized &&
                              order.status == OrderStatus.confirmed
                          ? () =>
                                orderProv.updateStatus(order.id!, 'in_transit')
                          : null,
                      onComplete:
                          order.type != OrderType.unrecognized &&
                              order.status == OrderStatus.inTransit
                          ? () => orderProv.updateStatus(order.id!, 'completed')
                          : null,
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  /// Empty state when no orders match the filter
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.local_shipping,
            size: 48,
            color: AppColors.mutedForeground.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            _filter == 'all' ? 'No orders found.' : 'No $_filter orders found.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(int orderId, OrderProvider orderProv) {
    String? reason;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Reject Order',
          style: TextStyle(color: AppColors.foreground),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to reject this order?',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => reason = v,
              style: const TextStyle(color: AppColors.foreground),
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                hintStyle: const TextStyle(color: AppColors.mutedForeground),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
              backgroundColor: AppColors.statusMaintenance,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              orderProv.updateStatus(orderId, 'cancelled', reason: reason);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

/// Rounded filter tab button
class _FilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.muted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

/// Add Order bottom sheet form with existing/new customer toggle,
/// searchable customer list, and +/- quantity buttons
class _AddOrderForm extends StatefulWidget {
  const _AddOrderForm();

  @override
  State<_AddOrderForm> createState() => _AddOrderFormState();
}

class _AddOrderFormState extends State<_AddOrderForm> {
  // Customer mode: 'existing' or 'new'
  String _customerMode = 'existing';
  String _customerSearch = '';
  int? _selectedCustomerId;

  final _phoneController = TextEditingController();
  String _type = 'deliver';
  int _quantity = 1;
  String _gallonType = 'new';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();

    if (_customerMode == 'existing' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }
    if (_customerMode == 'new' && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    final orderData = {
      'customer_id': _selectedCustomerId,
      'phone_number': phone,
      'type': _type,
      'quantity': _quantity,
      'gallon_type': _gallonType,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'is_pre_book': 0,
    };

    await context.read<OrderProvider>().addOrder(orderData);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.read<CustomerProvider>().customers;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Filter customers by search
    final filteredCustomers = _customerSearch.isEmpty
        ? customers
        : customers.where((c) {
            final name = (c['name'] as String? ?? '').toLowerCase();
            final phone = (c['contact_number'] as String? ?? '').toLowerCase();
            return name.contains(_customerSearch.toLowerCase()) ||
                phone.contains(_customerSearch.toLowerCase());
          }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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
            'New Order',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 20),

          // Customer mode toggle
          const Text(
            'Customer',
            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildModeOption('existing', 'Existing Customer', Icons.people),
              const SizedBox(width: 12),
              _buildModeOption('new', 'New / Manual', Icons.person_add),
            ],
          ),
          const SizedBox(height: 16),

          // Existing customer: searchable list
          if (_customerMode == 'existing') ...[
            // Search input
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _customerSearch = val),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.foreground,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search customer...',
                  hintStyle: TextStyle(color: AppColors.mutedForeground),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Customer list (scrollable, max height)
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredCustomers.length,
                itemBuilder: (_, i) {
                  final c = filteredCustomers[i];
                  final id = c['id'] as int;
                  final isSelected = _selectedCustomerId == id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCustomerId = id;
                        _phoneController.text =
                            c['contact_number'] as String? ?? '';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryLight
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.primary,
                            )
                          else
                            const Icon(
                              Icons.radio_button_off,
                              size: 16,
                              color: AppColors.mutedForeground,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${c['name']} — ${c['contact_number']}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.foreground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // New customer: phone number input
          if (_customerMode == 'new') ...[
            const Text(
              'Phone Number',
              style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 6),
            _buildTextField(
              _phoneController,
              'e.g. 09171234567',
              TextInputType.phone,
            ),
            const SizedBox(height: 16),
          ],

          // Type toggle
          const Text(
            'Order Type',
            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildTypeOption('deliver', 'Delivery', Icons.local_shipping),
              const SizedBox(width: 12),
              _buildTypeOption('drop', 'Walk-in', Icons.water_drop),
            ],
          ),
          const SizedBox(height: 16),

          // Quantity with +/- buttons
          const Text(
            'Quantity (gallons)',
            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Minus button
              GestureDetector(
                onTap: () {
                  if (_quantity > AppConstants.minQuantity) {
                    setState(() => _quantity--);
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.remove,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              // Quantity display
              Expanded(
                child: Center(
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ),
              // Plus button
              GestureDetector(
                onTap: () {
                  if (_quantity < AppConstants.maxQuantity) {
                    setState(() => _quantity++);
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gallon type selector
          const Text(
            'Gallon Type',
            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildGallonTypeOption('new', 'New', Icons.water_drop),
              const SizedBox(width: 12),
              _buildGallonTypeOption('old', 'Old', Icons.local_gas_station),
            ],
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Create Order',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(String value, String label, IconData icon) {
    final isSelected = _customerMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _customerMode = value;
          _selectedCustomerId = null;
          _phoneController.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    TextInputType type,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(fontSize: 14, color: AppColors.foreground),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.mutedForeground),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(String value, String label, IconData icon) {
    final isSelected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.mutedForeground,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGallonTypeOption(String value, String label, IconData icon) {
    final isSelected = _gallonType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gallonType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.mutedForeground,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
