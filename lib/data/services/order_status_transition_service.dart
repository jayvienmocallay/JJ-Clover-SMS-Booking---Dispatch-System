import '../models/order_model.dart';

class OrderStatusTransitionService {
  const OrderStatusTransitionService._();

  static OrderStatus parseStatus(String value) {
    switch (value) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'in_transit':
        return OrderStatus.inTransit;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'rejected':
        return OrderStatus.rejected;
      default:
        return OrderStatus.pending;
    }
  }

  static bool canTransition(OrderStatus current, OrderStatus next) {
    if (current == next) return true;
    switch (current) {
      case OrderStatus.pending:
        return next == OrderStatus.confirmed ||
            next == OrderStatus.rejected ||
            next == OrderStatus.cancelled;
      case OrderStatus.confirmed:
        return next == OrderStatus.inTransit ||
            next == OrderStatus.cancelled ||
            next == OrderStatus.rejected;
      case OrderStatus.inTransit:
        return next == OrderStatus.completed ||
            next == OrderStatus.confirmed ||
            next == OrderStatus.rejected;
      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return false;
    }
  }

  static bool canTransitionDb(String current, String next) {
    return canTransition(parseStatus(current), parseStatus(next));
  }
}
