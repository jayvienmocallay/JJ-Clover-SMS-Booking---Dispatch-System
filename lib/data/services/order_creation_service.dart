import '../../core/constants/app_constants.dart';
import '../../core/utils/phone_number_utils.dart';
import '../models/order_model.dart';
import '../repositories/order_repository.dart';
import 'system_mode_manager.dart';

class OrderCreationException implements Exception {
  final String message;
  const OrderCreationException(this.message);

  @override
  String toString() => message;
}

class OrderCreationService {
  OrderCreationService({OrderRepository? orderRepository})
    : _orders = orderRepository ?? OrderRepository();

  final OrderRepository _orders;

  Future<int> createOrderFromModel(
    Order order, {
    required String source,
    bool validateSystemMode = true,
  }) async {
    final normalizedPhone = PhoneNumberUtils.normalize(order.phoneNumber);
    _validateQuantity(order.quantity);
    _validateType(order.type);
    _validateMode(order.type, validateSystemMode: validateSystemMode);

    if (order.type == OrderType.deliver) {
      _validateDelivery(order.customerId, normalizedPhone, order.address);
    }

    final data = order.toMap();
    data['phone_number'] = normalizedPhone;
    data['source'] = source;
    data['scheduled_for'] ??=
        order.scheduledFor?.toIso8601String() ??
        DateTime(
          order.createdAt.year,
          order.createdAt.month,
          order.createdAt.day,
        ).toIso8601String();
    return _orders.insertOrder(data);
  }

  Future<int> promotePendingUnrecognizedOrderFromModel(
    int id,
    Order order, {
    required String source,
    bool validateSystemMode = true,
  }) async {
    final normalizedPhone = PhoneNumberUtils.normalize(order.phoneNumber);
    _validateQuantity(order.quantity);
    _validateType(order.type);
    _validateMode(order.type, validateSystemMode: validateSystemMode);

    if (order.type == OrderType.deliver) {
      _validateDelivery(order.customerId, normalizedPhone, order.address);
    }

    final data = order.toMap();
    data.remove('id');
    data.remove('created_at');
    data['phone_number'] = normalizedPhone;
    data['source'] = source;
    data['cancel_reason'] = null;
    data['scheduled_for'] ??=
        order.scheduledFor?.toIso8601String() ??
        DateTime(
          order.createdAt.year,
          order.createdAt.month,
          order.createdAt.day,
        ).toIso8601String();

    final updated = await _orders.promotePendingUnrecognizedOrder(id, data);
    return updated == 0 ? 0 : id;
  }

  Future<int> createManualOrder({
    required String phoneNumber,
    required OrderType type,
    required int quantity,
    int? customerId,
    String? address,
    String? deliveryDay,
    DateTime? scheduledFor,
  }) async {
    final now = DateTime.now();
    final order = Order(
      customerId: customerId,
      phoneNumber: PhoneNumberUtils.normalize(phoneNumber),
      type: type,
      quantity: quantity,
      address: _blankToNull(address),
      status: OrderStatus.pending,
      createdAt: now,
      deliveryDay: deliveryDay,
      scheduledFor: scheduledFor ?? now,
      source: 'manual',
    );
    return createOrderFromModel(order, source: 'manual');
  }

  void _validateQuantity(int quantity) {
    if (quantity < AppConstants.minQuantity ||
        quantity > AppConstants.maxQuantity) {
      throw const OrderCreationException(
        'Quantity is outside the allowed range.',
      );
    }
  }

  void _validateType(OrderType type) {
    if (type == OrderType.unrecognized) {
      throw const OrderCreationException(
        'Invalid SMS messages cannot be manually created as orders.',
      );
    }
  }

  void _validateMode(OrderType type, {required bool validateSystemMode}) {
    if (!validateSystemMode) return;
    final mode = SystemModeManager.instance;
    if (type == OrderType.deliver && !mode.canAcceptDelivery()) {
      throw OrderCreationException(mode.getDeliveryReply());
    }
    if (type == OrderType.drop && !mode.canAcceptDrop()) {
      throw OrderCreationException(mode.getDropReply());
    }
  }

  void _validateDelivery(int? customerId, String phoneNumber, String? address) {
    if (phoneNumber.isEmpty) {
      throw const OrderCreationException(
        'Delivery orders require a phone number.',
      );
    }
    if (customerId == null && _blankToNull(address) == null) {
      throw const OrderCreationException(
        'Guest delivery orders require an address.',
      );
    }
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
