import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/repositories/barangay_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/services/order_creation_service.dart';
import '../theme/app_theme.dart';
import 'shared/bottom_sheet_handle.dart';
import 'shared/customer_avatar.dart';
import 'shared/primary_action_button.dart';

class AddOrderForm extends StatefulWidget {
  const AddOrderForm({super.key});

  @override
  State<AddOrderForm> createState() => _AddOrderFormState();
}

class _AddOrderFormState extends State<AddOrderForm> {
  final _orderCreation = OrderCreationService();
  final _customerRepository = CustomerRepository();
  final _barangayRepository = BarangayRepository();

  String _customerMode = 'existing';
  String _customerSearch = '';
  int? _selectedCustomerId;
  int? _selectedBarangayId;
  bool _consentGiven = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _barangays = [];

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String _type = 'deliver';
  int _quantity = 1;
  String _gallonType = 'new';

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadBarangays() async {
    final rows = await _barangayRepository.getBarangays();
    if (!mounted) return;
    setState(() => _barangays = rows);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final orderProvider = context.read<OrderProvider>();
    final customerProvider = context.read<CustomerProvider>();

    setState(() => _isSubmitting = true);
    try {
      final type = _type == 'deliver' ? OrderType.deliver : OrderType.drop;
      final gallonType = _gallonType == 'new'
          ? GallonType.newGallon
          : GallonType.oldGallon;

      int? customerId;
      String phone = _phoneController.text.trim();
      String? address = _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim();

      if (_customerMode == 'existing') {
        if (_selectedCustomerId == null) {
          throw const OrderCreationException('Please select a customer.');
        }
        final customer = _selectedCustomer();
        customerId = _selectedCustomerId;
        phone = customer?['contact_number'] as String? ?? '';
        address = customer?['address'] as String?;
      } else if (_customerMode == 'create') {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          throw const OrderCreationException('Please enter the customer name.');
        }
        if (phone.isEmpty) {
          throw const OrderCreationException('Please enter the phone number.');
        }
        if (address == null) {
          throw const OrderCreationException('Please enter the delivery address.');
        }
        if (_selectedBarangayId == null) {
          throw const OrderCreationException('Please select a barangay.');
        }
        if (!_consentGiven) {
          throw const OrderCreationException('Please confirm customer consent.');
        }

        customerId = await _customerRepository.insertCustomer({
          'name': name,
          'contact_number': phone,
          'address': address,
          'barangay_id': _selectedBarangayId,
          'consent_given': 1,
          'consent_timestamp': DateTime.now().toIso8601String(),
          'consent_channel': 'manual',
          'consent_version': 'manual-v1',
        });
      }

      await _orderCreation.createManualOrder(
        customerId: customerId,
        phoneNumber: phone,
        type: type,
        quantity: _quantity,
        gallonType: gallonType,
        address: address,
      );

      if (!mounted) return;
      await orderProvider.loadOrders();
      await customerProvider.loadCustomers();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order created ✓')),
      );
    } on OrderCreationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Map<String, dynamic>? _selectedCustomer() {
    final customers = context.read<CustomerProvider>().customers;
    for (final customer in customers) {
      if (customer['id'] == _selectedCustomerId) return customer;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().customers;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filteredCustomers = _filteredCustomers(customers);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BottomSheetHandle(title: 'New Order'),
            const SizedBox(height: 20),
            Text('Customer', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildModeOption('existing', 'Existing', Icons.people),
                const SizedBox(width: 8),
                _buildModeOption('guest', 'Guest', Icons.person_outline),
                const SizedBox(width: 8),
                _buildModeOption('create', 'Create', Icons.person_add),
              ],
            ),
            const SizedBox(height: 16),
            if (_customerMode == 'existing')
              _buildExistingCustomerPicker(filteredCustomers),
            if (_customerMode == 'guest') _buildGuestFields(),
            if (_customerMode == 'create') _buildCreateCustomerFields(),
            const SizedBox(height: 16),
            Text('Order Type', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildTypeOption('deliver', 'Delivery', Icons.local_shipping),
                const SizedBox(width: 12),
                _buildTypeOption('drop', 'Walk-in', Icons.water_drop),
              ],
            ),
            const SizedBox(height: 16),
            Text('Quantity (gallons)', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                _quantityButton(Icons.remove, () {
                  if (_quantity > AppConstants.minQuantity) {
                    setState(() => _quantity--);
                  }
                }),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_quantity',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                ),
                _quantityButton(Icons.add, () {
                  if (_quantity < AppConstants.maxQuantity) {
                    setState(() => _quantity++);
                  }
                }),
              ],
            ),
            const SizedBox(height: 16),
            Text('Gallon Type', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildGallonTypeOption('new', 'New', Icons.water_drop),
                const SizedBox(width: 12),
                _buildGallonTypeOption('old', 'Old', Icons.local_gas_station),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              label: _isSubmitting ? 'Creating...' : 'Create Order',
              onTap: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredCustomers(List<Map<String, dynamic>> customers) {
    if (_customerSearch.isEmpty) return customers;
    return customers.where((c) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      final phone = (c['contact_number'] as String? ?? '').toLowerCase();
      final query = _customerSearch.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  Widget _buildExistingCustomerPicker(List<Map<String, dynamic>> filteredCustomers) {
    final palette = AppColors.of(context);
    return Column(
      children: [
        _textField(
          onChanged: (v) => setState(() => _customerSearch = v),
          hint: 'Search customer...',
          icon: Icons.search,
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 150),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filteredCustomers.length,
            itemBuilder: (_, i) {
              final customer = filteredCustomers[i];
              final id = customer['id'] as int;
              final name = customer['name'] as String? ?? '';
              final isSelected = _selectedCustomerId == id;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedCustomerId = id;
                  _phoneController.text =
                      customer['contact_number'] as String? ?? '';
                  _addressController.text = customer['address'] as String? ?? '';
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? palette.primaryLight : palette.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? palette.primary : palette.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      CustomerAvatar(name: name, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$name — ${customer['contact_number']}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isSelected ? palette.primary : palette.foreground,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, size: 16, color: palette.primary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGuestFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phone Number', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        _textField(
          controller: _phoneController,
          hint: _type == 'drop' ? 'Optional for walk-in' : 'Required for delivery',
          keyboardType: TextInputType.phone,
          digitsOnly: true,
        ),
        if (_type == 'deliver') ...[
          const SizedBox(height: 12),
          Text('Delivery Address', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          _textField(controller: _addressController, hint: 'Required for guest delivery'),
        ],
      ],
    );
  }

  Widget _buildCreateCustomerFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Name', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        _textField(controller: _nameController, hint: 'Customer name'),
        const SizedBox(height: 12),
        Text('Phone Number', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        _textField(
          controller: _phoneController,
          hint: 'e.g. 09171234567',
          keyboardType: TextInputType.phone,
          digitsOnly: true,
        ),
        const SizedBox(height: 12),
        Text('Delivery Address', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        _textField(controller: _addressController, hint: 'Full address'),
        const SizedBox(height: 12),
        Text('Barangay', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        _barangayDropdown(),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consentGiven,
          onChanged: (value) => setState(() => _consentGiven = value ?? false),
          title: Text(
            'Customer consent confirmed',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _barangayDropdown() {
    final palette = AppColors.of(context);
    return DropdownButtonFormField<int>(
      initialValue: _selectedBarangayId,
      items: _barangays.map((barangay) {
        return DropdownMenuItem<int>(
          value: barangay['id'] as int,
          child: Text(barangay['name'] as String? ?? ''),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedBarangayId = value),
      decoration: InputDecoration(
        filled: true,
        fillColor: palette.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kButtonRadius),
          borderSide: BorderSide(color: palette.border),
        ),
      ),
    );
  }

  Widget _buildModeOption(String value, String label, IconData icon) {
    final isSelected = _customerMode == value;
    final palette = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _customerMode = value;
          _selectedCustomerId = null;
          _phoneController.clear();
          _addressController.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? palette.primaryLight : palette.background,
            borderRadius: BorderRadius.circular(kButtonRadius),
            border: Border.all(color: isSelected ? palette.primary : palette.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? palette.primary : palette.mutedForeground),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? palette.primary : palette.mutedForeground,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(String value, String label, IconData icon) {
    final isSelected = _type == value;
    return _choiceBox(
      selected: isSelected,
      label: label,
      icon: icon,
      onTap: () => setState(() => _type = value),
    );
  }

  Widget _buildGallonTypeOption(String value, String label, IconData icon) {
    final isSelected = _gallonType == value;
    return _choiceBox(
      selected: isSelected,
      label: label,
      icon: icon,
      onTap: () => setState(() => _gallonType = value),
    );
  }

  Widget _choiceBox({
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final palette = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? palette.primaryLight : palette.background,
            borderRadius: BorderRadius.circular(kButtonRadius),
            border: Border.all(color: selected ? palette.primary : palette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? palette.primary : palette.mutedForeground),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: selected ? palette.primary : palette.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onTap) {
    final palette = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(kButtonRadius),
          border: Border.all(color: palette.border),
        ),
        child: Icon(icon, size: 18, color: palette.mutedForeground),
      ),
    );
  }

  Widget _textField({
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    bool digitsOnly = false,
  }) {
    final palette = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(kButtonRadius),
        border: Border.all(color: palette.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        inputFormatters: digitsOnly
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ]
            : null,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 18, color: palette.mutedForeground),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
