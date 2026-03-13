// Task 004 — Zone Validator: schedule-based delivery day validation
// Task 007 — Zone A/B/C logic with next-day finder for pre-book offers
import '../models/customer_model.dart';
import '../models/schedule_model.dart';
import '../../core/constants/app_constants.dart';

/// The possible outcomes of a zone/schedule validation check.
enum ValidationResult {
  /// Customer is allowed to order today
  valid,

  /// Customer's zone is not scheduled for today
  invalidDay,

  /// Phone number not found in the customer database
  unregistered,
}

/// Contains the full result of a validation check, including
/// the outcome, a human-readable message, and context for follow-up actions.
class ValidationResponse {
  /// The validation outcome (valid, invalidDay, or unregistered)
  final ValidationResult result;

  /// Human-readable message to send back via SMS
  final String? message;

  /// The customer object if found in the database
  final Customer? customer;

  /// The next correct delivery day (used when result is invalidDay)
  /// so the pre-book handler knows which day to schedule for
  final String? correctDay;

  ValidationResponse({
    required this.result,
    this.message,
    this.customer,
    this.correctDay,
  });
}

/// Validates whether a customer is allowed to place a DELIVER order
/// based on their zone, barangay, and the current day's schedule.
///
/// Zone-specific behavior (from Scope & Zone Mapping document):
/// - **Zone A** (station vicinity): Can order any operating day (Mon–Sat).
///   These customers are near the station and can walk in or get same-day delivery.
/// - **Zone B** (near barangays): Pedicab delivery on specific scheduled days
///   (Mon/Wed/Fri). Orders on non-scheduled days are rejected with pre-book offer.
/// - **Zone C** (far/mountain): Weekly delivery — one specific day per barangay.
///   Orders on other days are rejected with the correct day and pre-book offer.
class ZoneValidator {
  /// Validates a customer's DELIVER request against today's schedule.
  ///
  /// [customer] — the registered customer placing the order
  /// [schedules] — the customer's active schedule records from the database
  /// [currentDay] — today's day name (e.g., 'Monday')
  ///
  /// Returns a [ValidationResponse] with the result and appropriate SMS message.
  static ValidationResponse validate({
    required Customer customer,
    required List<Schedule> schedules,
    required String currentDay,
  }) {
    // Filter schedules to only this customer's records
    final customerSchedules = schedules
        .where((s) => s.customerId == customer.id)
        .toList();

    // If the customer has no schedule records at all, they can't order
    if (customerSchedules.isEmpty) {
      return ValidationResponse(
        result: ValidationResult.invalidDay,
        message: 'No schedule found for customer.',
        customer: customer,
      );
    }

    // Extract the list of days this customer is allowed to receive deliveries
    final allowedDays = customerSchedules.map((s) => s.deliveryDay).toList();

    // --- Zone A: Station vicinity — always valid on any operating day ---
    // Zone A customers have Mon–Sat in their schedule, so this check
    // will naturally pass on any weekday. Sunday is not in their schedule.
    // No special bypass needed — the schedule data handles it.

    // --- Zone B & C: Check if today is in the customer's allowed days ---
    if (allowedDays.contains(currentDay)) {
      // Today matches the customer's schedule — order is valid
      return ValidationResponse(
        result: ValidationResult.valid,
        message: 'Zone validated successfully.',
        customer: customer,
      );
    }

    // --- Today is NOT in the customer's schedule ---
    // Find the next upcoming delivery day to suggest in the reply.
    // This helps the customer know when to order or pre-book.
    final nextDay = _findNextDeliveryDay(allowedDays, currentDay);

    return ValidationResponse(
      result: ValidationResult.invalidDay,
      message:
          'Sorry, we are serving ${DeliveryDays.getToday()} zones today. '
          'Your area (${customer.deliveryZone}) is scheduled for $nextDay. '
          'Would you like to pre-book? Reply YES.',
      customer: customer,
      // Store the next delivery day so _handleYes can use it for pre-booking
      correctDay: nextDay,
    );
  }

  /// Checks if a customer exists in the database.
  ///
  /// This is the first step in the validation pipeline — if the phone number
  /// is not registered, we reject immediately with a registration prompt.
  static ValidationResponse checkCustomer({required Customer? customer}) {
    if (customer == null) {
      return ValidationResponse(
        result: ValidationResult.unregistered,
        message: 'Unknown number. Please register first or call the station.',
      );
    }
    // Customer exists — return valid so the caller can proceed to schedule check
    return ValidationResponse(
      result: ValidationResult.valid,
      customer: customer,
    );
  }

  /// Finds the next upcoming delivery day from the allowed days list,
  /// starting from the current day and moving forward through the week.
  ///
  /// Example: If today is Wednesday and allowed days are [Monday, Friday],
  /// this returns 'Friday' (the next one coming up, not Monday which already passed).
  static String _findNextDeliveryDay(
    List<String> allowedDays,
    String currentDay,
  ) {
    // Get today's index in the week (0=Monday, 6=Sunday)
    final todayIndex = DeliveryDays.days.indexOf(currentDay);

    // If we can't find today in the list, fall back to the first allowed day
    if (todayIndex == -1) {
      return allowedDays.isNotEmpty ? allowedDays.first : 'Unknown';
    }

    // Search forward through the week starting from tomorrow
    // Wrap around using modulo to check all 7 days
    for (int offset = 1; offset <= 7; offset++) {
      // Calculate the day index, wrapping around at the end of the week
      final checkIndex = (todayIndex + offset) % 7;
      final checkDay = DeliveryDays.days[checkIndex];

      // If this day is in the customer's allowed days, it's the next delivery
      if (allowedDays.contains(checkDay)) {
        return checkDay;
      }
    }

    // Fallback — should not reach here if schedule has at least one day
    return allowedDays.isNotEmpty ? allowedDays.first : 'Unknown';
  }
}
