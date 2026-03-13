// Task 010, Task 012 — Walk-in alert overlay (DROP command alarm UI)
// Full-screen alert with pulsing animation, DROP order details, and acknowledge button
import 'package:flutter/material.dart';
import '../../data/services/alarm_service.dart';
import '../theme/app_theme.dart';

/// Full-screen overlay alert shown when a DROP (walk-in) order arrives.
/// Shows the customer phone, quantity, time, and a large Acknowledge button.
/// Connected to AlarmService — acknowledging stops the audio alarm.
class WalkInAlert extends StatelessWidget {
  final VoidCallback onAcknowledge;

  const WalkInAlert({super.key, required this.onAcknowledge});

  @override
  Widget build(BuildContext context) {
    final alarm = AlarmService.instance;
    final phone = alarm.customerPhone ?? 'Unknown';
    final qty = alarm.quantity ?? 0;
    final time = alarm.triggeredAt;

    // Format time
    String timeStr = '';
    if (time != null) {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final amPm = time.hour >= 12 ? 'PM' : 'AM';
      timeStr = '$hour:${time.minute.toString().padLeft(2, '0')} $amPm';
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing bell icon
              const _PulsingBell(),
              const SizedBox(height: 20),
              // Alert title
              const Text(
                'Walk-in Customer!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              // Alert description
              const Text(
                'A customer is waiting at the station.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),

              // DROP order details card
              if (qty > 0 || phone != 'Unknown')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Phone
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: AppColors.mutedForeground),
                          const SizedBox(width: 8),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground,
                            ),
                          ),
                        ],
                      ),
                      if (qty > 0) ...[
                        const SizedBox(height: 8),
                        // Quantity
                        Row(
                          children: [
                            const Icon(Icons.water_drop, size: 16, color: AppColors.statusAway),
                            const SizedBox(width: 8),
                            Text(
                              '$qty gallon${qty > 1 ? "s" : ""}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // Time
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: AppColors.mutedForeground),
                            const SizedBox(width: 8),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Acknowledge button — large, full-width
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    // Stop the alarm audio
                    AlarmService.instance.acknowledge();
                    // Dismiss the overlay
                    onAcknowledge();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'ACKNOWLEDGE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated pulsing bell icon
class _PulsingBell extends StatefulWidget {
  const _PulsingBell();

  @override
  State<_PulsingBell> createState() => _PulsingBellState();
}

class _PulsingBellState extends State<_PulsingBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: AppColors.statusAwayLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.notifications_active,
          size: 40,
          color: AppColors.statusAway,
        ),
      ),
    );
  }
}
