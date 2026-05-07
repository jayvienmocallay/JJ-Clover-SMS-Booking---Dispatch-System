import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/system_mode_manager.dart';
import '../theme/app_theme.dart';

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

/// 2×2 grid of station mode toggle cards.
class StatusToggles extends StatelessWidget {
  const StatusToggles({super.key});

  static const List<_StatusConfig> _statuses = [
    _StatusConfig(
      mode: SystemMode.operating,
      label: 'Operating',
      description: 'Open & accepting orders',
      icon: Icons.check_circle,
      activeColor: AppColors.statusOperating,
      activeBgColor: AppColors.statusOperatingLight,
    ),
    _StatusConfig(
      mode: SystemMode.staffAway,
      label: 'Staff Away',
      description: 'Out delivering, accepting orders',
      icon: Icons.access_time,
      activeColor: AppColors.statusAway,
      activeBgColor: AppColors.statusAwayLight,
    ),
    _StatusConfig(
      mode: SystemMode.full,
      label: 'Full / Busy',
      description: 'No more deliveries today',
      icon: Icons.block,
      activeColor: AppColors.statusBusy,
      activeBgColor: AppColors.statusBusyLight,
    ),
    _StatusConfig(
      mode: SystemMode.maintenance,
      label: 'Maintenance',
      description: 'Station closed',
      icon: Icons.build,
      activeColor: AppColors.statusMaintenance,
      activeBgColor: AppColors.statusMaintenanceLight,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<SystemModeManager>(
      builder: (context, modeManager, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final cellWidth = (screenWidth - 32 - 12) / 2;
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

class _StatusButton extends StatelessWidget {
  final _StatusConfig config;
  final bool isActive;
  final VoidCallback onTap;

  const _StatusButton({
    required this.config,
    required this.isActive,
    required this.onTap,
  });

  Color _activeBg(AppPalette p) {
    switch (config.mode) {
      case SystemMode.operating: return p.statusOperatingLight;
      case SystemMode.staffAway: return p.statusAwayLight;
      case SystemMode.full: return p.statusBusyLight;
      case SystemMode.maintenance: return p.statusMaintenanceLight;
    }
  }

  Color _activeColor(AppPalette p) {
    switch (config.mode) {
      case SystemMode.operating: return p.statusOperating;
      case SystemMode.staffAway: return p.statusAway;
      case SystemMode.full: return p.statusBusy;
      case SystemMode.maintenance: return p.statusMaintenance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final accent = _activeColor(palette);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isActive ? _activeBg(palette) : palette.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(
          color: isActive ? accent : palette.border,
          width: isActive ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: accent.withValues(alpha: 0.15),
          highlightColor: accent.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  config.icon,
                  size: 28,
                  color: isActive ? accent : palette.mutedForeground,
                ),
                const SizedBox(height: 6),
                Text(
                  config.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? palette.foreground
                        : palette.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  config.description,
                  style: Theme.of(context).textTheme.labelSmall,
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
