// Task 010 — Status Toggle section: 4 large color-coded buttons
// 2x2 grid of mode toggle buttons with glow effect
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/system_mode_manager.dart';
import '../theme/app_theme.dart';

/// Data class holding the visual properties for each status button
class _StatusConfig {
  final SystemMode mode;
  final String label;
  final String description;
  final IconData icon;
  final Color activeColor;
  final Color activeBgColor;

  const _StatusConfig({
    required this.mode,
    required this.label,
    required this.description,
    required this.icon,
    required this.activeColor,
    required this.activeBgColor,
  });
}

/// 2x2 grid of large status toggle buttons.
/// Tapping a button sets the system mode via [SystemModeManager].
class StatusToggles extends StatelessWidget {
  const StatusToggles({super.key});

  // Configuration for all 4 status modes
  static const List<_StatusConfig> _statuses = [
    _StatusConfig(
      mode: SystemMode.operating,
      label: 'Operating',
      description: 'Open & accepting orders',
      icon: Icons.check_circle_outline,
      activeColor: AppColors.statusOperating,
      activeBgColor: AppColors.statusOperatingLight,
    ),
    _StatusConfig(
      mode: SystemMode.staffAway,
      label: 'Staff Away',
      description: 'Out delivering, accepting orders',
      icon: Icons.schedule,
      activeColor: AppColors.statusAway,
      activeBgColor: AppColors.statusAwayLight,
    ),
    _StatusConfig(
      mode: SystemMode.full,
      label: 'Full / Busy',
      description: 'No more deliveries today',
      icon: Icons.cancel_outlined,
      activeColor: AppColors.statusBusy,
      activeBgColor: AppColors.statusBusyLight,
    ),
    _StatusConfig(
      mode: SystemMode.maintenance,
      label: 'Maintenance',
      description: 'Station closed',
      icon: Icons.build_outlined,
      activeColor: AppColors.statusMaintenance,
      activeBgColor: AppColors.statusMaintenanceLight,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<SystemModeManager>(
      builder: (context, modeManager, _) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: _statuses.map((config) {
            final isActive = modeManager.currentMode == config.mode;
            return _StatusButton(
              config: config,
              isActive: isActive,
              onTap: () => modeManager.setMode(config.mode),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Individual status toggle button with glow effect when active
class _StatusButton extends StatelessWidget {
  final _StatusConfig config;
  final bool isActive;
  final VoidCallback onTap;

  const _StatusButton({
    required this.config,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isActive ? config.activeBgColor : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? config.activeColor : AppColors.border,
            width: 2,
          ),
          // Glow effect when active
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: config.activeColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: config.activeColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status icon — colored when active, muted when inactive
            Icon(
              config.icon,
              size: 32,
              color: isActive ? config.activeColor : AppColors.mutedForeground,
            ),
            const SizedBox(height: 8),
            // Status label
            Text(
              config.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.foreground : AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 2),
            // Status description
            Text(
              config.description,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
