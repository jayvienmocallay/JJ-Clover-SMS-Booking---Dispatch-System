// Task 010 — Customers screen: search, list with avatars, add customer
// Task 011 — Connected to CustomerProvider via Consumer for reactive updates
// Search, list with avatars, add customer form
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/phone_number_utils.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/repositories/barangay_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/services/sms_registration_copy.dart';
import '../theme/app_theme.dart';
import '../widgets/shared/app_page_header.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/brand_mascot.dart';
import '../widgets/shared/customer_avatar.dart';
import '../widgets/shared/empty_state.dart';
import '../widgets/shared/search_field.dart';
import 'dart:async' show unawaited;
import '../../core/security/admin_auth_service.dart';
import '../../data/repositories/audit_log_repository.dart';
import '../security/admin_gate.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _search = '';
  late final AdminAuthService _adminAuth;
  late final AuditLogRepository _auditRepo;

  @override
  void initState() {
    super.initState();
    _adminAuth = context.read<AdminAuthService>();
    _auditRepo = context.read<AuditLogRepository>();
  }

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

  Future<void> _deleteCustomer(int customerId, String name) async {
    if (!await requireAdminPassword(
      context,
      reason: 'Admin password required to delete a customer.',
    )) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.of(context).card,
        title: Text(
          'Delete Customer',
          style: TextStyle(color: AppColors.of(context).foreground),
        ),
        content: Text(
          'Delete $name and their orders history?',
          style: TextStyle(color: AppColors.of(context).mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).statusMaintenance,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final customerProvider = context.read<CustomerProvider>();
      final deleted = await customerProvider.deleteCustomer(customerId);
      if (deleted) {
        unawaited(_auditRepo.record(
          action: 'customer_deleted',
          entityType: 'customer',
          entityId: customerId.toString(),
          metadata: {'name': name},
        ));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleted ? '$name deleted' : 'Could not delete $name.',
            ),
          ),
        );
      }
    }
  }

  /// Shows the Add Customer bottom sheet form
  void _showAddCustomerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).card,
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
              AppPageHeader(
                title: 'Customers',
                subtitle: '${customerProv.count} registered customers',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MascotBadge(pose: MascotPose.waterBottle, size: 44),
                    const SizedBox(width: 8),
                    // Task 011 — Add Customer button
                    GestureDetector(
                      onTap: _showAddCustomerSheet,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.of(context).primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_add,
                              size: 16,
                              color: Colors.white,
                            ),
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
              ),
              const SizedBox(height: 20),

              SearchField(
                hintText: 'Search name, phone, or barangay...',
                initialValue: _search,
                onChanged: (val) => setState(() => _search = val),
              ),
              const SizedBox(height: 16),

              // --- Customer list ---
              if (filtered.isEmpty)
                EmptyState(
                  icon: Icons.people,
                  mascot: MascotPose.waterBottle,
                  title: _search.isEmpty
                      ? 'No customers yet'
                      : 'No customers found',
                  message: _search.isEmpty
                      ? 'Registered delivery customers will appear here.'
                      : 'No customers match "$_search".',
                )
              else
                ...filtered.map((c) {
                  final name = c['name'] as String? ?? '';
                  final phone = c['contact_number'] as String? ?? '';
                  final barangay = c['barangay'] as String? ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CustomerAvatar(name: name),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: AppColors.of(context).foreground,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _CustomerMeta(
                                      icon: Icons.phone,
                                      label: phone,
                                    ),
                                    if (barangay.isNotEmpty)
                                      _CustomerMeta(
                                        icon: Icons.location_on,
                                        label: barangay,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit customer (Admin required)',
                            onPressed: () async {
                              if (!await requireAdminPassword(
                                context,
                                reason: 'Admin password required to edit customer information.',
                              )) return;
                              if (!mounted) return;
                              _editCustomer(c);
                            },
                            icon: Icon(
                              Icons.edit,
                              size: 20,
                              color: AppColors.of(context).primary,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete customer (Admin required)',
                            onPressed: () =>
                                _deleteCustomer(c['id'] as int, name),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppColors.of(context).statusMaintenance,
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
    final barangayRepository = context.read<BarangayRepository>();
    Future<List<Map<String, dynamic>>> loadBarangaysFuture() =>
        Future.sync(() => barangayRepository.getBarangays());
    Future<List<Map<String, dynamic>>>? barangaysFuture;
    var isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          barangaysFuture ??= loadBarangaysFuture();
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: barangaysFuture,
            builder: (ctx, snapshot) {
              if (snapshot.hasError) {
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
                            color: AppColors.of(context).border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Edit Customer',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.of(context).foreground,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to load barangays. Please try again.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.of(context).mutedForeground,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                barangaysFuture = loadBarangaysFuture();
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                );
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
                          color: AppColors.of(context).border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Edit Customer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.of(context).foreground,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Full Name',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.of(context).mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      nameController,
                      'Full Name',
                      TextInputType.name,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.of(context).mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      phoneController,
                      'Phone Number',
                      TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Full Address',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.of(context).mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      addressController,
                      'Full Address',
                      TextInputType.streetAddress,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Barangay',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.of(context).mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.of(context).background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.of(context).border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: selectedBarangayId,
                          isExpanded: true,
                          dropdownColor: AppColors.of(context).card,
                          hint: Text(
                            'Select Barangay...',
                            style: TextStyle(
                              color: AppColors.of(context).mutedForeground,
                            ),
                          ),
                          items: barangays
                              .map(
                                (b) => DropdownMenuItem<int?>(
                                  value: b['id'] as int,
                                  child: Text(
                                    '${b['name']} (${b['delivery_zone']})',
                                    style: TextStyle(
                                      color: AppColors.of(context).foreground,
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

                          if (isSaving) return;
                          setSheetState(() => isSaving = true);
                          final updated = await customerProvider
                              .updateCustomer(customerId, {
                                'name': name,
                                'contact_number': phone,
                                'address': address.isNotEmpty ? address : null,
                                'barangay_id': selectedBarangayId,
                              });
                          if (!ctx.mounted) return;
                          setSheetState(() => isSaving = false);

                          if (!updated) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  customerProvider.error ??
                                      'Failed to update customer',
                                ),
                              ),
                            );
                            return;
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('Customer updated')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSaving
                                ? AppColors.of(context).muted
                                : AppColors.of(context).primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: isSaving
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.of(context).primary,
                                      ),
                                    ),
                                  )
                                : const Text(
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
        color: AppColors.of(context).background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        inputFormatters: type == TextInputType.phone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ]
            : null,
        style: TextStyle(fontSize: 14, color: AppColors.of(context).foreground),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.of(context).mutedForeground),
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
class _CustomerMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CustomerMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: palette.mutedForeground),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: palette.mutedForeground),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

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
  bool _isSubmitting = false;
  bool _isLoadingBarangays = false;
  String? _barangayLoadError;
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
    if (kIsWeb || _isLoadingBarangays) return;
    setState(() {
      _isLoadingBarangays = true;
      _barangayLoadError = null;
    });
    try {
      final barangays = await _barangayRepo.getBarangays();
      if (!mounted) return;
      setState(() => _barangays = barangays);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _barangays = [];
        _barangayLoadError = 'Unable to load barangays. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingBarangays = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

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

    if (_isLoadingBarangays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for barangays to load.')),
      );
      return;
    }

    if (_barangayLoadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_barangayLoadError!)),
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

    setState(() => _isSubmitting = true);
    try {
      final existing = await _customerRepo.getCustomerByPhone(phone);
      if (!mounted) return;
      if (existing != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A customer with $phone already exists')),
        );
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

      final customerProv = context.read<CustomerProvider>();
      final navigator = Navigator.of(context);
      final snackBarMsg = '$name added successfully';
      final successSnack = SnackBar(content: Text(snackBarMsg));
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      final created = await customerProv.addCustomer(customerData);
      if (!mounted) return;
      if (!created) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(customerProv.error ?? 'Customer was not created.'),
          ),
        );
        return;
      }
      navigator.pop();
      scaffoldMessenger.showSnackBar(successSnack);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add customer: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: _step == 0
            ? _buildPrivacyConsentStep()
            : _buildCustomerFormStep(),
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
              color: AppColors.of(context).border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.shield, size: 22, color: AppColors.of(context).primary),
            const SizedBox(width: 8),
            Text(
              'Data Privacy Consent',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).foreground,
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
            color: AppColors.of(context).background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.of(context).border),
          ),
          child: SingleChildScrollView(
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
                    color: AppColors.of(context).foreground,
                    height: 1.5,
                  ),
                ),
                const _PolicyBullet(
                  'Processing and delivering your water refill orders',
                ),
                const SizedBox(height: 6),
                const _PolicyBullet(
                  'Contacting you regarding your orders and delivery schedule',
                ),
                const SizedBox(height: 6),
                const _PolicyBullet('Improving our service quality'),
                const SizedBox(height: 6),
                const _PolicyBullet(
                  'Securely backing up records to cloud storage when sync is enabled',
                ),
                const SizedBox(height: 12),
                Text(
                  'Your data will not be shared with third parties without '
                  'your explicit consent. Cloud backup uses encrypted storage '
                  'under the same RA 10173 protections — deletion requests '
                  'also remove your data from cloud. You may request access, '
                  'correction, or deletion of your personal data at any time '
                  'by contacting us.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.of(context).foreground,
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
                      ? AppColors.of(context).primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _privacyConsent
                        ? AppColors.of(context).primary
                        : AppColors.of(context).mutedForeground,
                    width: 1.5,
                  ),
                ),
                child: _privacyConsent
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'I have read and agree to the Data Privacy Policy. '
                  'I consent to the collection and processing of my '
                  'personal information.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).mutedForeground,
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
                color: _privacyConsent
                    ? AppColors.of(context).primary
                    : AppColors.of(context).muted,
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
                        : AppColors.of(context).mutedForeground,
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
              color: AppColors.of(context).border,
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
              child: Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.of(context).mutedForeground,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'New Customer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Name
        Text(
          'Full Name',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.of(context).mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        _buildTextField(_nameController, 'Full Name', TextInputType.name),
        const SizedBox(height: 16),

        // Phone
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.of(context).mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        _buildTextField(_phoneController, 'Phone Number', TextInputType.phone),
        const SizedBox(height: 16),

        // Address
        Text(
          'Full Address',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.of(context).mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        _buildTextField(
          _addressController,
          'Full Address',
          TextInputType.streetAddress,
        ),
        const SizedBox(height: 16),

        // Barangay dropdown
        Text(
          'Barangay',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.of(context).mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        if (_barangayLoadError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.of(context).background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _barangayLoadError!,
                    style: TextStyle(
                      color: AppColors.of(context).mutedForeground,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _isLoadingBarangays ? null : _loadBarangays,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.of(context).background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _selectedBarangayId,
                isExpanded: true,
                dropdownColor: AppColors.of(context).card,
                hint: Text(
                  _isLoadingBarangays
                      ? 'Loading barangays...'
                      : _barangays.isEmpty
                      ? 'No barangays. Add them in Settings.'
                      : 'Select Barangay...',
                  style: TextStyle(
                    color: AppColors.of(context).mutedForeground,
                    fontSize: 14,
                  ),
                ),
                items: _barangays
                    .map(
                      (b) => DropdownMenuItem<int?>(
                        value: b['id'] as int,
                        child: Text(
                          '${b['name']} (${b['delivery_zone']})',
                          style: TextStyle(
                            color: AppColors.of(context).foreground,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _isLoadingBarangays
                    ? null
                    : (val) => setState(() => _selectedBarangayId = val),
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
                onTap: _isSubmitting ? null : _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isSubmitting
                        ? AppColors.of(context).muted
                        : AppColors.of(context).primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _isSubmitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.of(context).primary,
                              ),
                            ),
                          )
                        : const Text(
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
                  color: AppColors.of(context).muted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(context).mutedForeground,
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
        color: AppColors.of(context).background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        inputFormatters: type == TextInputType.phone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ]
            : null,
        style: TextStyle(fontSize: 14, color: AppColors.of(context).foreground),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.of(context).mutedForeground),
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
        Text(
          '  \u2022  ',
          style: TextStyle(fontSize: 13, color: AppColors.of(context).primary),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.of(context).foreground,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
