// Task 010 — Schedule screen: day-by-day barangay delivery schedule
// Day-by-day barangay delivery schedule view
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/barangay_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/app_page_header.dart';
import '../widgets/shared/brand_mascot.dart';
import '../widgets/shared/loading_state.dart';
import '../widgets/shared/status_badge.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<Map<String, dynamic>> _barangays = [];
  bool _isLoading = true;
  late final BarangayRepository _barangayRepo;

  @override
  void initState() {
    super.initState();
    _barangayRepo = context.read<BarangayRepository>();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    if (kIsWeb) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final barangays = await _barangayRepo.getBarangays();
      if (mounted) {
        setState(() {
          _barangays = barangays;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingState(
        title: 'Loading schedule',
        message: 'Checking barangay delivery days...',
        mascot: MascotPose.deliveryTruck,
      );
    }

    final today = DeliveryDays.getToday();

    return RefreshIndicator(
      onRefresh: _loadBarangays,
      color: AppColors.of(context).primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppPageHeader(
            title: 'Delivery Schedule',
            subtitle: 'Zone-to-day mapping for delivery operations.',
          ),
          const SizedBox(height: 20),

          // --- Day cards ---
          ...DeliveryDays.days.map((day) {
            final isToday = day == today;
            final barangays = _getBarangaysForDay(day);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                borderColor: isToday
                    ? AppColors.of(context).primary.withValues(alpha: 0.4)
                    : AppColors.of(context).border,
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
                              ? AppColors.of(context).primary
                              : AppColors.of(context).mutedForeground,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          day,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isToday
                                ? AppColors.of(context).primary
                                : AppColors.of(context).foreground,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: 'Today',
                            color: AppColors.of(context).primary,
                            bgColor: AppColors.of(context).primaryLight,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Barangay chips
                    if (barangays.isEmpty)
                      Text(
                        'No deliveries',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.of(context).mutedForeground,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: barangays.map((brgy) {
                          final name = brgy['name'] as String? ?? 'Unknown';
                          final zone = brgy['delivery_zone'] as String? ?? '';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.of(context).primaryLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$name ($zone)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.of(context).primary,
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
      ),
    );
  }

  List<Map<String, dynamic>> _getBarangaysForDay(String day) {
    return _barangays.where((b) {
      final zone = b['delivery_zone'] as String? ?? '';
      final name = b['name'] as String? ?? '';
      final days = ZoneScheduleMap.getDaysForZone(zone, barangayName: name);
      return days.contains(day);
    }).toList();
  }
}
