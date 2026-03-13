// Task 010 — Schedule screen: day-by-day barangay delivery schedule
// Day-by-day barangay delivery schedule view
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../theme/app_theme.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DeliveryDays.getToday();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Header ---
        const Text(
          'Delivery Schedule',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Zone-to-day mapping for delivery operations.',
          style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 20),

        // --- Day cards ---
        ...DeliveryDays.days.map((day) {
          final isToday = day == today;
          // Get all barangays scheduled for this day
          final barangays = _getBarangaysForDay(day);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isToday
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day header
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: isToday
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? AppColors.primary
                              : AppColors.foreground,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        const Text(
                          '(Today)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Barangay chips
                  if (barangays.isEmpty)
                    const Text(
                      'No deliveries',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.mutedForeground,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: barangays.map((brgy) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            brgy,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Gets all barangay names that have delivery on the given day
  /// by checking ZoneScheduleMap for each zone
  List<String> _getBarangaysForDay(String day) {
    final barangays = <String>[];

    // Zone A: Mon-Sat
    if (ZoneScheduleMap.zoneADays.contains(day)) {
      barangays.addAll(['San Isidro', 'San Jose']);
    }
    // Zone B: Mon/Wed/Fri
    if (ZoneScheduleMap.zoneBDays.contains(day)) {
      barangays.addAll(['Poblacion', 'Santa Rosa']);
    }
    // Zone C: check each barangay's specific day
    ZoneScheduleMap.zoneCBarangayDays.forEach((brgy, brgyDay) {
      if (brgyDay == day) {
        barangays.add(brgy);
      }
    });

    return barangays;
  }
}
