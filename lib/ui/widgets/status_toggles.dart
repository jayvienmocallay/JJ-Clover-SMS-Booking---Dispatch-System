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
        // Compute aspect ratio dynamically so content fits on small screens.
        final screenWidth = MediaQuery.of(context).size.width;
        final cellWidth = (screenWidth - 32 - 12) / 2;
        // Min cell height ~105px for icon + label + description with padding
        final cellHeight = cellWidth / 1.3 < 105 ? 105.0 : cellWidth / 1.3;
        final aspectRatio = cellWidth / cellHeight;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: _statuses.map((config) {
            final isActive = modeManager.currentMode == config.mode;
            return _StatusButton(
              config: config,
              isActive: isActive,
              onTap: () {
                modeManager.setMode(config.mode);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Mode set to ${config.mode.displayName} ✓'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
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
    return AnimatedContainer(
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
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: config.activeColor.withValues(alpha: 0.15),
          highlightColor: config.activeColor.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status icon — colored when active, muted when inactive
                Icon(
                  config.icon,
                  size: 28,
                  color: isActive ? config.activeColor : AppColors.mutedForeground,
                ),
                const SizedBox(height: 6),
                // Status label
                Text(
                  config.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.foreground : AppColors.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
