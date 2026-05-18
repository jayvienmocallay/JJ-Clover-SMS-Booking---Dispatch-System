import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/phone_number_utils.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/repositories/barangay_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/services/order_creation_service.dart';
import '../theme/app_theme.dart';
import 'shared/bottom_sheet_handle.dart';
import 'shared/primary_action_button.dart';

class AddOrderForm extends StatefulWidget {
  final String? prefilledPhone;

  const AddOrderForm({super.key, this.prefilledPhone});

  @override
  State<AddOrderForm> createState() => _AddOrderFormState();
}

class _AddOrderFormState extends State<AddOrderForm> {
  late final OrderCreationService _orderCreation;
  late final CustomerRepository _customerRepository;
  late final BarangayRepository _barangayRepository;

  int? _selectedCustomerId;
  int? _selectedBarangayId;
  bool _saveCustomerForFutureOrders = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _barangays = [];
  int _phoneLookupSerial = 0;
  String? _autofilledName;
  String? _autofilledAddress;
  int? _autofilledBarangayId;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String _type = 'deliver';
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _customerRepository = context.read<CustomerRepository>();
    _barangayRepository = context.read<BarangayRepository>();
    _orderCreation = OrderCreationService(
      orderRepository: context.read<OrderRepository>(),
    );
    _loadBarangays();
    if (widget.prefilledPhone != null) {
      _phoneController.text = PhoneNumberUtils.normalize(
        widget.prefilledPhone!,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lookupCustomerByPhone(_phoneController.text);
      });
    }
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

      int? customerId = _selectedCustomerId;
      final name = _nameController.text.trim();
      final phone = PhoneNumberUtils.normalize(_phoneController.text);
      String? address = _blankToNull(_addressController.text);

      if (type == OrderType.deliver && phone.isEmpty) {
        throw const OrderCreationException(
          'Delivery orders require a phone number.',
        );
      }
      if (phone.isNotEmpty && !PhoneNumberUtils.isValidMobileNumber(phone)) {
        throw const OrderCreationException(
          'Invalid phone format. Use 09XXXXXXXXX',
        );
      }

      if (phone.isNotEmpty) {
        final existingCustomer = await _customerRepository
            .getCustomerWithBarangayByPhone(phone);
        if (existingCustomer != null) {
          customerId = existingCustomer['id'] as int?;
          address ??= _blankToNull(existingCustomer['address'] as String?);
        }
      }

      if (type == OrderType.deliver && address == null) {
        throw const OrderCreationException(
          'Please enter the delivery address.',
        );
      }

      if (_saveCustomerForFutureOrders && customerId == null) {
        if (name.isEmpty) {
          throw const OrderCreationException('Please enter the customer name.');
        }
        if (phone.isEmpty) {
          throw const OrderCreationException('Please enter the phone number.');
        }
        if (_selectedBarangayId == null) {
          throw const OrderCreationException('Please select a barangay.');
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
        address: address,
      );

      if (!mounted) return;
      await orderProvider.loadOrders();
      await customerProvider.loadCustomers();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order created')));
    } on OrderCreationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BottomSheetHandle(title: 'New Order'),
            const SizedBox(height: 20),
            _buildCustomerInformationSection(),
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
            Text(
              'Quantity (gallons)',
              style: Theme.of(context).textTheme.labelMedium,
            ),
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

  Widget _buildCustomerInformationSection() {
    final savedCustomerFound = _selectedCustomerId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Information',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Text('Phone Number', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        _textField(
          controller: _phoneController,
          onChanged: _handlePhoneChanged,
          hint: _type == 'drop' ? 'Optional for walk-in' : 'Required',
          keyboardType: TextInputType.phone,
          digitsOnly: true,
        ),
        const SizedBox(height: 12),
        Text('Customer Name', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        _textField(controller: _nameController, hint: 'Customer name'),
        const SizedBox(height: 12),
        Text(
          'Delivery Address',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 6),
        _textField(
          controller: _addressController,
          hint: _type == 'deliver' ? 'Required for delivery' : 'Optional',
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: savedCustomerFound || _saveCustomerForFutureOrders,
          onChanged: savedCustomerFound
              ? null
              : (value) {
                  setState(() => _saveCustomerForFutureOrders = value ?? false);
                },
          title: Text(
            'Save this customer for future orders',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_saveCustomerForFutureOrders && !savedCustomerFound) ...[
          Text('Barangay', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          _barangayDropdown(),
        ],
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
          child: Text(
            '${barangay['name']} (${barangay['delivery_zone']})',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedBarangayId = value),
      decoration: InputDecoration(
        hintText: _barangays.isEmpty
            ? 'No barangays. Add them in Settings.'
            : 'Select barangay',
        filled: true,
        fillColor: palette.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kButtonRadius),
          borderSide: BorderSide(color: palette.border),
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
            border: Border.all(
              color: selected ? palette.primary : palette.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? palette.primary : palette.mutedForeground,
              ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  void _handlePhoneChanged(String value) {
    _lookupCustomerByPhone(value);
  }

  Future<void> _lookupCustomerByPhone(String value) async {
    final normalizedPhone = PhoneNumberUtils.normalize(value);
    final lookupSerial = ++_phoneLookupSerial;

    if (!PhoneNumberUtils.isValidMobileNumber(normalizedPhone)) {
      if (!mounted || !_hasAutofilledCustomer) return;
      setState(_clearAutofilledCustomer);
      return;
    }

    final customer = await _customerRepository.getCustomerWithBarangayByPhone(
      normalizedPhone,
    );
    if (!mounted ||
        lookupSerial != _phoneLookupSerial ||
        PhoneNumberUtils.normalize(_phoneController.text) != normalizedPhone) {
      return;
    }

    setState(() {
      if (customer == null) {
        _clearAutofilledCustomer();
      } else {
        _applyAutofilledCustomer(customer);
      }
    });
  }

  bool get _hasAutofilledCustomer {
    return _selectedCustomerId != null ||
        _autofilledName != null ||
        _autofilledAddress != null ||
        _autofilledBarangayId != null;
  }

  void _applyAutofilledCustomer(Map<String, dynamic> customer) {
    final name = customer['name'] as String? ?? '';
    final address = customer['address'] as String? ?? '';

    _selectedCustomerId = customer['id'] as int?;
    _selectedBarangayId = customer['barangay_id'] as int?;
    _saveCustomerForFutureOrders = false;

    _nameController.text = name;
    _addressController.text = address;
    _autofilledName = name;
    _autofilledAddress = address;
    _autofilledBarangayId = _selectedBarangayId;
  }

  void _clearAutofilledCustomer() {
    final hadAutofilledCustomer = _hasAutofilledCustomer;
    _selectedCustomerId = null;
    if (hadAutofilledCustomer) {
      _saveCustomerForFutureOrders = false;
    }
    _selectedBarangayId = _matchesAutofilledBarangay()
        ? null
        : _selectedBarangayId;

    if (_matchesAutofilledValue(_nameController.text, _autofilledName)) {
      _nameController.clear();
    }
    if (_matchesAutofilledValue(_addressController.text, _autofilledAddress)) {
      _addressController.clear();
    }

    _autofilledName = null;
    _autofilledAddress = null;
    _autofilledBarangayId = null;
  }

  bool _matchesAutofilledValue(String currentValue, String? autofilledValue) {
    return autofilledValue != null && currentValue == autofilledValue;
  }

  bool _matchesAutofilledBarangay() {
    return _autofilledBarangayId != null &&
        _selectedBarangayId == _autofilledBarangayId;
  }
}
