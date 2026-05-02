// Task 010 — Customers screen: search, list with avatars, add customer
// Task 011 — Connected to CustomerProvider via Consumer for reactive updates
// Search, list with avatars, add customer form
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../core/utils/phone_number_utils.dart';
import '../../data/models/delivery_log_model.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/repositories/barangay_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/delivery_log_repository.dart';
import '../../data/services/sms_registration_copy.dart';
import '../theme/app_theme.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _search = '';

  /// Filters customers by name, phone, or barangay
  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> customers) {
    if (_search.isEmpty) return customers;
    final q = _search.toLowerCase();
    return customers.where((c) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      final phone = (c['contact_number'] as String? ?? '').toLowerCase();
      final barangay = (c['barangay'] as String? ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q) || barangay.contains(q);
    }).toList();
  }

  void _showDeliveryHistory(int customerId, String name) async {
    final rawLogs = await context
        .read<DeliveryLogRepository>()
        .getDeliveryLogsForCustomer(customerId);
    final logs = rawLogs.map(DeliveryLog.fromMap).toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.35,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            Row(
              children: [
                const Icon(
                  Icons.history,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$name — Delivery History',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${logs.length} delivery${logs.length != 1 ? "ies" : ""} · '
              '${logs.fold<int>(0, (s, l) => s + l.quantityDelivered)} gallons total',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            if (logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No deliveries recorded for this customer.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              )
            else
              ...logs.map((log) {
                final qty = log.quantityDelivered;
                final now = DateTime.now();
                final dt = log.deliveredAt;
                final isToday = dt.year == now.year &&
                    dt.month == now.month &&
                    dt.day == now.day;
                final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
                final displayHour = hour == 0 ? 12 : hour;
                final minute = dt.minute.toString().padLeft(2, '0');
                final period = dt.hour >= 12 ? 'PM' : 'AM';
                final timeStr = '$displayHour:$minute $period';
                const months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                ];
                final dateStr = isToday
                    ? 'Today, $timeStr'
                    : '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $timeStr';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.statusOperatingLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.statusOperating,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$qty gallon${qty > 1 ? "s" : ""}'
                              '${log.gallonType?.isNotEmpty == true ? " (${log.gallonType})" : ""}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.foreground,
                              ),
                            ),
                            if (log.notes?.isNotEmpty == true)
                              Text(
                                log.notes!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            if (log.returnedContainers != null ||
                                log.paymentMethod != null)
                              Text(
                                [
                                  if (log.returnedContainers != null)
                                    '${log.returnedContainers} returned',
                                  if (log.paymentMethod != null)
                                    log.paymentMethod!,
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
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

  Future<void> _deleteCustomer(int customerId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Delete Customer',
          style: TextStyle(color: AppColors.foreground),
        ),
        content: Text(
          'Delete $name and their orders history?',
          style: const TextStyle(color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusMaintenance,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<CustomerProvider>().deleteCustomer(customerId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$name deleted')));
      }
    }
  }

  /// Shows the Add Customer bottom sheet form
  void _showAddCustomerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<CustomerProvider>(),
        child: const _AddCustomerForm(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
      builder: (context, customerProv, _) {
        final filtered = _filtered(customerProv.customers);

        return RefreshIndicator(
          onRefresh: () async {
            if (kIsWeb) return;
            await customerProv.loadCustomers();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Header ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customers',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${customerProv.count} registered customers',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  // Task 011 — Add Customer button
                  GestureDetector(
                    onTap: _showAddCustomerSheet,
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
                          Icon(Icons.person_add, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Add',
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

              // --- Search bar ---
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _search = val),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search by name, phone, or barangay...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.mutedForeground,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Customer list ---
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people,
                        size: 48,
                        color: AppColors.mutedForeground.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No customers found.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filtered.map((c) {
                  final name = c['name'] as String? ?? '';
                  final phone = c['contact_number'] as String? ?? '';
                  final barangay = c['barangay'] as String? ?? '';
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          // Avatar with initial
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Name + phone + barangay
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: AppColors.foreground,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone,
                                      size: 12,
                                      color: AppColors.mutedForeground,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      phone,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.location_on,
                                      size: 12,
                                      color: AppColors.mutedForeground,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        barangay,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.mutedForeground,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Delivery history button
                          GestureDetector(
                            onTap: () =>
                                _showDeliveryHistory(c['id'] as int, name),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.receipt_long,
                                size: 20,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          // Edit button
                          GestureDetector(
                            onTap: () => _editCustomer(c),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.edit,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          // Delete button
                          GestureDetector(
                            onTap: () => _deleteCustomer(c['id'] as int, name),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.statusMaintenance,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _editCustomer(Map<String, dynamic> customer) {
    final nameController = TextEditingController(
      text: customer['name'] as String? ?? '',
    );
    final phoneController = TextEditingController(
      text: customer['contact_number'] as String? ?? '',
    );
    final addressController = TextEditingController(
      text: customer['address'] as String? ?? '',
    );
    final customerId = customer['id'] as int;
    final currentBarangayId = customer['barangay_id'] as int?;
    int? selectedBarangayId = currentBarangayId;
    final List<Map<String, dynamic>> barangays = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: context.read<BarangayRepository>().getBarangays(),
            builder: (ctx, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              barangays.clear();
              barangays.addAll(snapshot.data!);

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
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
                      'Edit Customer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Full Name',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      nameController,
                      'Full Name',
                      TextInputType.name,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      phoneController,
                      'Phone Number',
                      TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Full Address',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      addressController,
                      'Full Address',
                      TextInputType.streetAddress,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Barangay',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: selectedBarangayId,
                          isExpanded: true,
                          dropdownColor: AppColors.card,
                          hint: const Text(
                            'Select Barangay...',
                            style: TextStyle(color: AppColors.mutedForeground),
                          ),
                          items: barangays
                              .map(
                                (b) => DropdownMenuItem<int?>(
                                  value: b['id'] as int,
                                  child: Text(
                                    '${b['name']} (${b['delivery_zone']})',
                                    style: const TextStyle(
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setSheetState(() => selectedBarangayId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () async {
                          final name = nameController.text.trim();
                          final phone = phoneController.text.trim();
                          final address = addressController.text.trim();

                          if (name.isEmpty ||
                              phone.isEmpty ||
                              selectedBarangayId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Name, phone, and barangay are required',
                                ),
                              ),
                            );
                            return;
                          }

                          if (!PhoneNumberUtils.isAcceptedCustomerPhone(
                            phone,
                          )) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Invalid phone format. Use 09XXXXXXXXX',
                                ),
                              ),
                            );
                            return;
                          }

                          final customerProvider = context
                              .read<CustomerProvider>();
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );

                          try {
                            await customerProvider.updateCustomer(customerId, {
                              'name': name,
                              'contact_number': phone,
                              'address': address.isNotEmpty ? address : null,
                              'barangay_id': selectedBarangayId,
                            });
                          } on CustomerPhoneAlreadyExistsException {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'A customer with $phone already exists',
                                ),
                              ),
                            );
                            return;
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Save Changes',
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
            },
          );
        },
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
}

/// Add Customer bottom sheet — 2-step flow:
/// Step 1: Data Privacy Consent (RA 10173)
/// Step 2: Customer details form
class _AddCustomerForm extends StatefulWidget {
  const _AddCustomerForm();

  @override
  State<_AddCustomerForm> createState() => _AddCustomerFormState();
}

class _AddCustomerFormState extends State<_AddCustomerForm> {
  // Step tracking: 0 = privacy consent, 1 = customer form
  int _step = 0;
  bool _privacyConsent = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  int? _selectedBarangayId;
  List<Map<String, dynamic>> _barangays = [];
  late final BarangayRepository _barangayRepo;
  late final CustomerRepository _customerRepo;

  @override
  void initState() {
    super.initState();
    _barangayRepo = context.read<BarangayRepository>();
    _customerRepo = context.read<CustomerRepository>();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    if (kIsWeb) return;
    final barangays = await _barangayRepo.getBarangays();
    if (mounted) setState(() => _barangays = barangays);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    if (!PhoneNumberUtils.isAcceptedCustomerPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone format. Use 09XXXXXXXXX')),
      );
      return;
    }

    if (_selectedBarangayId == null) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Please select a barangay')),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final existing = await _customerRepo.getCustomerByPhone(phone);
    if (existing != null) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('A customer with $phone already exists')),
        );
      }
      return;
    }

    // Task 020 — Record RA 10173 consent metadata so UI- and SMS-registered
    // customers carry the same audit trail (channel + version + timestamp).
    final customerData = {
      'name': name,
      'contact_number': phone,
      'address': address.isNotEmpty ? address : null,
      'barangay_id': _selectedBarangayId,
      'consent_given': 1,
      'consent_timestamp': DateTime.now().toIso8601String(),
      'consent_channel': SmsRegistrationCopy.channelAppUi,
      'consent_version': SmsRegistrationCopy.consentVersion,
    };

    // ignore: use_build_context_synchronously
    final customerProv = context.read<CustomerProvider>();
    // ignore: use_build_context_synchronously
    final navigator = Navigator.of(context);
    final snackBarMsg = '$name added successfully';
    // ignore: use_build_context_synchronously
    final successSnack = SnackBar(content: Text(snackBarMsg));

    // ignore: use_build_context_synchronously
    await customerProv.addCustomer(customerData);
    if (!mounted) return;
    navigator.pop();
    scaffoldMessenger.showSnackBar(successSnack);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: _step == 0 ? _buildPrivacyConsentStep() : _buildCustomerFormStep(),
      ),
    );
  }

  /// Step 1: Data Privacy Consent (RA 10173)
  Widget _buildPrivacyConsentStep() {
    return Column(
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
        const Row(
          children: [
            Icon(Icons.shield, size: 22, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Data Privacy Consent',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Privacy policy text
        Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In compliance with the Data Privacy Act of 2012 '
                  '(Republic Act No. 10173), we are committed to protecting '
                  'the personal information of our customers.\n\n'
                  'By providing your personal details (name, phone number, '
                  'address, and barangay), you consent to the collection, '
                  'storage, and use of this information solely for the '
                  'purpose of:\n',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.foreground,
                    height: 1.5,
                  ),
                ),
                _PolicyBullet(
                  'Processing and delivering your water refill orders',
                ),
                SizedBox(height: 6),
                _PolicyBullet(
                  'Contacting you regarding your orders and delivery schedule',
                ),
                SizedBox(height: 6),
                _PolicyBullet('Improving our service quality'),
                SizedBox(height: 6),
                _PolicyBullet(
                  'Securely backing up records to cloud storage when sync is enabled',
                ),
                SizedBox(height: 12),
                Text(
                  'Your data will not be shared with third parties without '
                  'your explicit consent. Cloud backup uses encrypted storage '
                  'under the same RA 10173 protections — deletion requests '
                  'also remove your data from cloud. You may request access, '
                  'correction, or deletion of your personal data at any time '
                  'by contacting us.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.foreground,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Consent checkbox
        GestureDetector(
          onTap: () => setState(() => _privacyConsent = !_privacyConsent),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _privacyConsent
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _privacyConsent
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                    width: 1.5,
                  ),
                ),
                child: _privacyConsent
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'I have read and agree to the Data Privacy Policy. '
                  'I consent to the collection and processing of my '
                  'personal information.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Continue button
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: _privacyConsent ? () => setState(() => _step = 1) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _privacyConsent ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _privacyConsent
                        ? Colors.white
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Step 2: Customer details form
  Widget _buildCustomerFormStep() {
    return Column(
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
        Row(
          children: [
            // Back button to return to privacy consent
            GestureDetector(
              onTap: () => setState(() => _step = 0),
              child: const Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'New Customer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Name
        const Text(
          'Full Name',
          style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 6),
        _buildTextField(_nameController, 'Full Name', TextInputType.name),
        const SizedBox(height: 16),

        // Phone
        const Text(
          'Phone Number',
          style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 6),
        _buildTextField(_phoneController, 'Phone Number', TextInputType.phone),
        const SizedBox(height: 16),

        // Address
        const Text(
          'Full Address',
          style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 6),
        _buildTextField(
          _addressController,
          'Full Address',
          TextInputType.streetAddress,
        ),
        const SizedBox(height: 16),

        // Barangay dropdown
        const Text(
          'Barangay',
          style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedBarangayId,
              isExpanded: true,
              dropdownColor: AppColors.card,
              hint: Text(
                _barangays.isEmpty
                    ? 'No barangays. Add them in Settings.'
                    : 'Select Barangay...',
                style: const TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 14,
                ),
              ),
              items: _barangays
                  .map(
                    (b) => DropdownMenuItem<int?>(
                      value: b['id'] as int,
                      child: Text(
                        '${b['name']} (${b['delivery_zone']})',
                        style: const TextStyle(
                          color: AppColors.foreground,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedBarangayId = val),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            // Save button
            Expanded(
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
                      'Save Customer',
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
            const SizedBox(width: 12),
            // Cancel button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
}

/// Bullet point widget for the privacy policy text
class _PolicyBullet extends StatelessWidget {
  final String text;
  const _PolicyBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '  \u2022  ',
          style: TextStyle(fontSize: 13, color: AppColors.primary),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.foreground,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
