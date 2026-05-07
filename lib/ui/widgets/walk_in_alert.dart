import 'package:flutter/material.dart';
import '../../data/services/alarm_service.dart';
import '../theme/app_theme.dart';
import 'shared/info_row.dart';
import 'shared/primary_action_button.dart';

/// Full-screen amber alert overlay for walk-in DROP orders.
/// Requires explicit tap to dismiss — no auto-dismiss.
class WalkInAlert extends StatelessWidget {
  final VoidCallback onAcknowledge;

  const WalkInAlert({super.key, required this.onAcknowledge});

  @override
  Widget build(BuildContext context) {
    final alarm = AlarmService.instance;
    final phone = alarm.customerPhone ?? 'Unknown';
    final qty = alarm.quantity ?? 0;
    final time = alarm.triggeredAt;

    String timeStr = '';
    if (time != null) {
      final hour = time.hour > 12
          ? time.hour - 12
          : (time.hour == 0 ? 12 : time.hour);
      final amPm = time.hour >= 12 ? 'PM' : 'AM';
      timeStr = '$hour:${time.minute.toString().padLeft(2, '0')} $amPm';
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: const Border(
              left: BorderSide(color: AppColors.statusAway, width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulsingBell(),
                const SizedBox(height: 20),
                Text(
                  'Walk-in Request',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(kCardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(kCardRadius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoRow(
                        icon: Icons.phone,
                        label: phone,
                      ),
                      if (qty > 0) ...[
                        const SizedBox(height: 10),
                        InfoRow(
                          icon: Icons.water_drop,
                          label: '$qty gallon${qty > 1 ? "s" : ""}',
                          iconColor: AppColors.statusAway,
                        ),
                      ],
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        InfoRow(
                          icon: Icons.access_time,
                          label: timeStr,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryActionButton(
                  label: 'ACKNOWLEDGE',
                  onTap: onAcknowledge,
                  backgroundColor: AppColors.statusAway,
                  minHeight: 52,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
