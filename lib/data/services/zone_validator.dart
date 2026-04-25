import '../models/customer_model.dart';
import '../models/schedule_model.dart';
import '../../core/constants/app_constants.dart';

enum ValidationResult { valid, invalidDay, unregistered }

class ValidationResponse {
  final ValidationResult result;
  final String? message;
  final Customer? customer;
  final String? correctDay;

  ValidationResponse({
    required this.result,
    this.message,
    this.customer,
    this.correctDay,
  });
}

class ZoneValidator {
  static ValidationResponse validate({
    required Customer customer,
    required List<Schedule> schedules,
    required String currentDay,
  }) {
    final customerSchedules = schedules
        .where((s) => s.customerId == customer.id)
        .toList();

    if (customerSchedules.isEmpty) {
      return ValidationResponse(
        result: ValidationResult.invalidDay,
        message: 'No schedule found for customer.',
        customer: customer,
      );
    }

    final allowedDays = customerSchedules.map((s) => s.deliveryDay).toList();

    if (allowedDays.contains(currentDay)) {
      return ValidationResponse(
        result: ValidationResult.valid,
        message: 'Zone validated successfully.',
        customer: customer,
      );
    }

    final correctDay = allowedDays.isNotEmpty ? allowedDays.first : 'Unknown';
    return ValidationResponse(
      result: ValidationResult.invalidDay,
      message:
          'Sorry, we are serving ${DeliveryDays.getToday()} zones today. '
          'Your area (${customer.deliveryZone}) is scheduled for $correctDay. '
          'Would you like to pre-book? Reply YES.',
      customer: customer,
      correctDay: correctDay,
    );
  }

  static ValidationResponse checkCustomer({required Customer? customer}) {
    if (customer == null) {
      return ValidationResponse(
        result: ValidationResult.unregistered,
        message: 'Unknown number. Please register first or call the station.',
      );
    }
    return ValidationResponse(
      result: ValidationResult.valid,
      customer: customer,
    );
  }
}
