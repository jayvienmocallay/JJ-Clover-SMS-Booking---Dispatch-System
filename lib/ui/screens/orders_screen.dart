import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/order_card.dart';
import '../widgets/shared/app_page_header.dart';
import '../widgets/shared/filter_chip_row.dart';
import '../widgets/shared/empty_state.dart';
import '../widgets/shared/bottom_sheet_handle.dart';
import '../widgets/shared/primary_action_button.dart';
import '../widgets/shared/customer_avatar.dart';
import 'delivery_logs_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _filterIndex = 0;

  static const _filterTypes = ['all', 'deliver', 'drop', 'unrecognized'];
  static const _filterLabels = ['All', 'Deliveries', 'Walk-ins', 'Invalid'];

  List<Map<String, dynamic>> _filterOrders(
      List<Map<String, dynamic>> orders) {
    final type = _filterTypes[_filterIndex];
    if (type == 'all') return orders;
    return orders.where((o) => o['type'] == type).toList();
  }

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
        final customerCache = <int, Map<String, dynamic>>{};
        for (final c in customerProv.customers) {
          final id = c['id'] as int?;
          if (id != null) customerCache[id] = c;
        }

        final inTransitCount = orderProv.todayOrders
            .where((o) => o['status'] == 'in_transit')
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
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DeliveryLogsScreen()),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(kButtonRadius),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          size: 20,
                          color: AppColors.mutedForeground,
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
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(kButtonRadius),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add,
                                size: 16, color: Colors.white),
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

              // Read-only summary chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SummaryChip(
                      label: 'Pending ${orderProv.pendingCount}',
                      color: AppColors.statusAway,
                    ),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      label: 'Confirmed ${orderProv.confirmedCount}',
                      color: AppColors.statusOperating,
                    ),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      label: 'In Transit $inTransitCount',
                      color: AppColors.statusBusy,
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
                      address: order.address ??
                          (customer?['address'] as String?),
                      onConfirm: order.type != OrderType.unrecognized &&
                              order.status == OrderStatus.pending
                          ? () async {
                              final prov = orderProv;
                              await prov.updateStatus(
                                  order.id!, 'confirmed');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Order confirmed ✓')),
                                );
                              }
                            }
                          : null,
                      onReject: order.type != OrderType.unrecognized &&
                              order.status == OrderStatus.pending
                          ? () => _showRejectDialog(order.id!, orderProv)
                          : null,
                      onStartDelivery:
                          order.type != OrderType.unrecognized &&
                                  order.status == OrderStatus.confirmed
                              ? () async {
                                  final prov = orderProv;
                                  await prov.updateStatus(
                                      order.id!, 'in_transit');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                            content:
                                                Text('Delivery started ✓')));
                                  }
                                }
                              : null,
                      onComplete: order.type != OrderType.unrecognized &&
                              order.status == OrderStatus.inTransit
                          ? () async {
                              final prov = orderProv;
                              await prov.updateStatus(
                                  order.id!, 'completed');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Order completed ✓')),
                                );
                              }
                            }
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

  void _showRejectDialog(int orderId, OrderProvider orderProv) {
    String? reason;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Reject Order',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject this order?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => reason = v,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                filled: true,
                fillColor: AppColors.background,
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
              backgroundColor: AppColors.statusMaintenance,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prov = orderProv;
              await prov.updateStatus(orderId, 'cancelled',
                  reason: reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order rejected ✓')),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
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

class _AddOrderForm extends StatefulWidget {
  const _AddOrderForm();

  @override
  State<_AddOrderForm> createState() => _AddOrderFormState();
}

class _AddOrderFormState extends State<_AddOrderForm> {
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
    if (_customerMode == 'existing' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a customer')));
      return;
    }

    String phone;
    if (_customerMode == 'existing' && _selectedCustomerId != null) {
      final customers = context.read<CustomerProvider>().customers;
      final match = customers.where((c) => c['id'] == _selectedCustomerId);
      phone = match.isNotEmpty
          ? (match.first['contact_number'] as String? ?? '')
          : '';
    } else {
      phone = _phoneController.text.trim();
    }

    if (_customerMode == 'new' && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a phone number')));
      return;
    }

    final orderProv = context.read<OrderProvider>();
    await orderProv.addOrder({
      'customer_id': _selectedCustomerId,
      'phone_number': phone,
      'type': _type,
      'quantity': _quantity,
      'gallon_type': _gallonType,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'is_pre_book': 0,
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.read<CustomerProvider>().customers;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final filteredCustomers = _customerSearch.isEmpty
        ? customers
        : customers.where((c) {
            final name = (c['name'] as String? ?? '').toLowerCase();
            final phone =
                (c['contact_number'] as String? ?? '').toLowerCase();
            return name.contains(_customerSearch.toLowerCase()) ||
                phone.contains(_customerSearch.toLowerCase());
          }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BottomSheetHandle(title: 'New Order'),
          const SizedBox(height: 20),

          Text('Customer',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildModeOption('existing', 'Existing', Icons.people),
              const SizedBox(width: 12),
              _buildModeOption('new', 'New / Manual', Icons.person_add),
            ],
          ),
          const SizedBox(height: 16),

          if (_customerMode == 'existing') ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(kButtonRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _customerSearch = v),
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Search customer...',
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: AppColors.mutedForeground),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredCustomers.length,
                itemBuilder: (_, i) {
                  final c = filteredCustomers[i];
                  final id = c['id'] as int;
                  final name = c['name'] as String? ?? '';
                  final isSelected = _selectedCustomerId == id;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedCustomerId = id;
                      _phoneController.text =
                          c['contact_number'] as String? ?? '';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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
                          CustomerAvatar(name: name, size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$name — ${c['contact_number']}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.foreground,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_customerMode == 'new') ...[
            Text('Phone Number',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            _buildTextField(
                _phoneController, 'e.g. 09171234567', TextInputType.phone),
            const SizedBox(height: 16),
          ],

          Text('Order Type',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildTypeOption('deliver', 'Delivery', Icons.local_shipping),
              const SizedBox(width: 12),
              _buildTypeOption('drop', 'Walk-in', Icons.water_drop),
            ],
          ),
          const SizedBox(height: 16),

          Text('Quantity (gallons)',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
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
                    borderRadius: BorderRadius.circular(kButtonRadius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.remove,
                      size: 18, color: AppColors.mutedForeground),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_quantity',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
              ),
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
                    borderRadius: BorderRadius.circular(kButtonRadius),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: const Icon(Icons.add,
                      size: 18, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Gallon Type',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildGallonTypeOption('new', 'New', Icons.water_drop),
              const SizedBox(width: 12),
              _buildGallonTypeOption('old', 'Old', Icons.local_gas_station),
            ],
          ),
          const SizedBox(height: 24),

          PrimaryActionButton(label: 'Create Order', onTap: _submit),
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
            borderRadius: BorderRadius.circular(kButtonRadius),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.mutedForeground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
      TextEditingController ctrl, String hint, TextInputType type) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(kButtonRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        inputFormatters: type == TextInputType.phone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ]
            : null,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            borderRadius: BorderRadius.circular(kButtonRadius),
            border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.mutedForeground),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            borderRadius: BorderRadius.circular(kButtonRadius),
            border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.mutedForeground),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
