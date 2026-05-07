# JJ Clover UI Redesign — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the Dashboard and Orders screens plus all 11 shared UI widgets to match the JJ Clover design spec (`design.md`), on the `ui/redesign` branch.

**Architecture:** Full rewrite — preserve all business logic (providers, state, callbacks), replace all inline `TextStyle`/`BoxDecoration`/`Container` UI code with shared widgets and theme tokens. New shared widgets live in `lib/ui/widgets/shared/`. Existing widget files (`order_card.dart`, `status_toggles.dart`, `walk_in_alert.dart`) are replaced in-place.

**Tech Stack:** Flutter (Android-first), Provider for state, `AppColors` + `Theme.of(context).textTheme` for all styling. No hardcoded hex or font sizes in new code.

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Create | `lib/ui/widgets/shared/status_badge.dart` | Colored pill badge (order + station status) |
| Create | `lib/ui/widgets/shared/app_page_header.dart` | Page title + subtitle + optional action |
| Create | `lib/ui/widgets/shared/metric_card.dart` | Dashboard stat card with value + label |
| Create | `lib/ui/widgets/shared/filter_chip_row.dart` | Scrollable filter chip row |
| Create | `lib/ui/widgets/shared/empty_state.dart` | Centered icon + message for empty lists |
| Create | `lib/ui/widgets/shared/info_row.dart` | Icon + text label row (used in alerts) |
| Create | `lib/ui/widgets/shared/customer_avatar.dart` | Circular initial avatar |
| Create | `lib/ui/widgets/shared/primary_action_button.dart` | Full-width CTA button |
| Create | `lib/ui/widgets/shared/danger_action_button.dart` | Full-width destructive button |
| Create | `lib/ui/widgets/shared/bottom_sheet_handle.dart` | Drag handle + optional title |
| Create | `lib/ui/widgets/shared/setting_card.dart` | Settings row card (used in Phase 2) |
| Modify | `lib/ui/theme/app_theme.dart` | Add layout constants |
| Rewrite | `lib/ui/widgets/status_toggles.dart` | Station mode 2×2 grid |
| Rewrite | `lib/ui/widgets/order_card.dart` | Order card using StatusBadge, theme text |
| Rewrite | `lib/ui/widgets/walk_in_alert.dart` | Amber alert overlay using InfoRow |
| Rewrite | `lib/ui/screens/dashboard_screen.dart` | Dashboard using all shared widgets |
| Rewrite | `lib/ui/screens/orders_screen.dart` | Orders screen using shared widgets |

---

## Task 1: Create branch and add layout constants

**Files:**
- Modify: `lib/ui/theme/app_theme.dart`

- [ ] **Step 1: Create the feature branch**

```bash
git checkout -b ui/redesign
```

Expected: `Switched to a new branch 'ui/redesign'`

- [ ] **Step 2: Add layout constants to app_theme.dart**

Open `lib/ui/theme/app_theme.dart`. After the closing `}` of the `AppTheme` class (line 161), add:

```dart
// Layout constants — used across all screens and widgets
const double kPagePadding = 16;
const double kCardPadding = 16;
const double kCardRadius = 16;
const double kButtonRadius = 12;
const double kSectionGap = 20;
const double kCompactGap = 8;
```

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/ui/theme/app_theme.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/ui/theme/app_theme.dart
git commit -m "feat: add layout constants to app_theme"
```

---

## Task 2: Create `StatusBadge` shared widget

**Files:**
- Create: `lib/ui/widgets/shared/status_badge.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/ui/widgets/shared/status_badge.dart
import 'package:flutter/material.dart';

/// Colored pill badge for order and station statuses.
/// Label is auto-uppercased. Pair with a text label — never use color alone.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bgColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/widgets/shared/status_badge.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/widgets/shared/status_badge.dart
git commit -m "feat: add StatusBadge shared widget"
```

---

## Task 3: Create `AppPageHeader` shared widget

**Files:**
- Create: `lib/ui/widgets/shared/app_page_header.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/ui/widgets/shared/app_page_header.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Standard page header: large title, optional subtitle, optional trailing action.
/// Action widget is constrained to 44×44 for tap target compliance.
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 26,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 12),
          // action can be a single icon button or a Row of buttons.
          // Individual buttons inside must maintain ≥44×44 tap targets.
          action!,
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/widgets/shared/app_page_header.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/widgets/shared/app_page_header.dart
git commit -m "feat: add AppPageHeader shared widget"
```

---

## Task 4: Create `MetricCard` shared widget

**Files:**
- Create: `lib/ui/widgets/shared/metric_card.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/ui/widgets/shared/metric_card.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Dashboard stat card: large value + label row.
/// Used in 2×2 GridView — caller controls aspect ratio.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kCardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/widgets/shared/metric_card.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/widgets/shared/metric_card.dart
git commit -m "feat: add MetricCard shared widget"
```

---

## Task 5: Create `FilterChipRow` shared widget

**Files:**
- Create: `lib/ui/widgets/shared/filter_chip_row.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/ui/widgets/shared/filter_chip_row.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Horizontally scrollable row of filter chips.
/// Selected chip uses primary color; unselected uses muted.
class FilterChipRow extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FilterChipRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i == selectedIndex;
          return Padding(
            padding: EdgeInsets.only(right: i < labels.length - 1 ? kCompactGap : 0),
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.muted,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isActive ? Colors.white : AppColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/widgets/shared/filter_chip_row.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/widgets/shared/filter_chip_row.dart
git commit -m "feat: add FilterChipRow shared widget"
```

---

## Task 6: Create `EmptyState` shared widget

**Files:**
- Create: `lib/ui/widgets/shared/empty_state.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/ui/widgets/shared/empty_state.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Centered empty state: icon + message. No illustrations.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: AppColors.mutedForeground.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/widgets/shared/empty_state.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/widgets/shared/empty_state.dart
git commit -m "feat: add EmptyState shared widget"
```

---

## Task 7: Create `InfoRow` shared widget

**Files:**
- Create: `lib/ui/widgets/shared/info_row.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/ui/widgets/shared/info_row.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Icon + label row for detail views and alert overlays.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? AppColors.mutedForeground,
        ),
        const SizedBox(width: kCompactGap),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/widgets/shared/info_row.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/widgets/shared/info_row.dart
git commit -m "feat: add InfoRow shared widget"
```

---

## Task 8: Create `CustomerAvatar` shared widget

**Files:**
- Create: `lib/ui/widgets/shared/customer_avatar.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/ui/widgets/shared/customer_avatar.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Circular avatar showing the first letter of a customer's name.
class CustomerAvatar extends StatelessWidget {
  final String name;
  final double size;

  const CustomerAvatar({
    super.key,
    required this.name,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/widgets/shared/customer_avatar.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/widgets/shared/customer_avatar.dart
git commit -m "feat: add CustomerAvatar shared widget"
```

---

## Task 9: Create `PrimaryActionButton` and `DangerActionButton`

**Files:**
- Create: `lib/ui/widgets/shared/primary_action_button.dart`
- Create: `lib/ui/widgets/shared/danger_action_button.dart`

- [ ] **Step 1: Create PrimaryActionButton**

```dart
// lib/ui/widgets/shared/primary_action_button.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Full-width CTA button. Pass [backgroundColor] to override (e.g. amber for alerts).
/// [minHeight] defaults to 48; walk-in alert uses 52.
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double minHeight;

  const PrimaryActionButton({
    super.key,
    required this.label,
    this.onTap,
    this.backgroundColor,
    this.minHeight = 48,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(kButtonRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.15),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minHeight),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create DangerActionButton**

```dart
// lib/ui/widgets/shared/danger_action_button.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'primary_action_button.dart';

/// Full-width destructive action button. Red background.
class DangerActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const DangerActionButton({
    super.key,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryActionButton(
      label: label,
      onTap: onTap,
      backgroundColor: AppColors.statusMaintenance,
    );
  }
}
```

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/ui/widgets/shared/primary_action_button.dart lib/ui/widgets/shared/danger_action_button.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/ui/widgets/shared/primary_action_button.dart lib/ui/widgets/shared/danger_action_button.dart
git commit -m "feat: add PrimaryActionButton and DangerActionButton shared widgets"
```

---

## Task 10: Create `BottomSheetHandle` and `SettingCard`

**Files:**
- Create: `lib/ui/widgets/shared/bottom_sheet_handle.dart`
- Create: `lib/ui/widgets/shared/setting_card.dart`

- [ ] **Step 1: Create BottomSheetHandle**

```dart
// lib/ui/widgets/shared/bottom_sheet_handle.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Drag handle bar + optional title for bottom sheets.
class BottomSheetHandle extends StatelessWidget {
  final String? title;

  const BottomSheetHandle({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: 16),
          Text(
            title!,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: Create SettingCard**

```dart
// lib/ui/widgets/shared/setting_card.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Settings row: icon + title + description + trailing action.
/// Set [isDanger] for destructive settings (red accent).
class SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget action;
  final bool isDanger;

  const SettingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isDanger
        ? AppColors.statusMaintenance
        : AppColors.foreground;
    return Container(
      padding: const EdgeInsets.all(kCardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(
          color: isDanger
              ? AppColors.statusMaintenance.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: accentColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          action,
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/ui/widgets/shared/bottom_sheet_handle.dart lib/ui/widgets/shared/setting_card.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/ui/widgets/shared/bottom_sheet_handle.dart lib/ui/widgets/shared/setting_card.dart
git commit -m "feat: add BottomSheetHandle and SettingCard shared widgets"
```

---

## Task 11: Rewrite `status_toggles.dart`

**Files:**
- Rewrite: `lib/ui/widgets/status_toggles.dart`

Changes from existing: update icons to spec, remove glow shadows (spec: no decorative shadows), switch from inline `TextStyle` to `textTheme.*`.

- [ ] **Step 1: Replace the file contents**

```dart
// lib/ui/widgets/status_toggles.dart
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

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isActive ? config.activeBgColor : AppColors.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(
          color: isActive ? config.activeColor : AppColors.border,
          width: isActive ? 2 : 1,
        ),
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
                Icon(
                  config.icon,
                  size: 28,
                  color: isActive
                      ? config.activeColor
                      : AppColors.mutedForeground,
                ),
                const SizedBox(height: 6),
                Text(
                  config.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.foreground
                        : AppColors.mutedForeground,
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
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/widgets/status_toggles.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/widgets/status_toggles.dart
git commit -m "refactor: rewrite StatusToggles with design spec icons and theme text"
```

---

## Task 12: Rewrite `order_card.dart`

**Files:**
- Rewrite: `lib/ui/widgets/order_card.dart`

Changes: use shared `StatusBadge`, switch to `textTheme.*`, add gallon type to quantity badge, preserve all callbacks and business logic.

- [ ] **Step 1: Replace the file contents**

```dart
// lib/ui/widgets/order_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../theme/app_theme.dart';
import 'shared/status_badge.dart';

/// Order card with type icon, customer info, status badge, and action buttons.
/// Preserves all provider callbacks — UI only rewrite.
class OrderCard extends StatelessWidget {
  final Order order;
  final String? customerName;
  final String? phone;
  final String? barangay;
  final String? address;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final VoidCallback? onStartDelivery;
  final VoidCallback? onComplete;

  const OrderCard({
    super.key,
    required this.order,
    this.customerName,
    this.phone,
    this.barangay,
    this.address,
    this.onConfirm,
    this.onReject,
    this.onStartDelivery,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isDeliver = order.type == OrderType.deliver;
    final isInvalid = order.type == OrderType.unrecognized;

    final typeColor = isInvalid
        ? AppColors.statusMaintenance
        : isDeliver
        ? AppColors.primary
        : AppColors.statusAway;
    final typeBgColor = isInvalid
        ? AppColors.statusMaintenanceLight
        : isDeliver
        ? AppColors.primaryLight
        : AppColors.statusAwayLight;
    final typeIcon = isInvalid
        ? Icons.sms_failed
        : isDeliver
        ? Icons.local_shipping
        : Icons.water_drop;

    return Container(
      padding: const EdgeInsets.all(kCardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(
          color: isInvalid
              ? AppColors.statusMaintenance.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + info + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, size: 20, color: typeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName ?? order.phoneNumber,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (phone != null)
                      Text(
                        phone!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (!isInvalid && (address != null || barangay != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [address, barangay].whereType<String>().join(' · '),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Quantity + gallon type + pre-book + time
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${order.quantity} gal · ${order.gallonType == GallonType.newGallon ? "New" : "Old"}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          if (order.isPreBook) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 10,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Pre-booked${order.deliveryDay != null ? " (${order.deliveryDay})" : ""}',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          Text(
                            _formatTime(order.createdAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              _buildStatusBadge(),
            ],
          ),

          // Rejection/failure reason
          if ((order.status == OrderStatus.cancelled ||
                  order.status == OrderStatus.rejected ||
                  order.type == OrderType.unrecognized) &&
              order.cancelReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusMaintenanceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Reason: ${order.cancelReason}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.statusMaintenance,
                  ),
                ),
              ),
            ),

          // Completed: view delivery log link
          if (order.status == OrderStatus.completed && order.id != null)
            _ActionSection(
              child: InkWell(
                onTap: () => _showDeliveryLogs(context, order.id!),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'View Delivery Log',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Pending: Confirm + Reject
          if (order.status == OrderStatus.pending &&
              (onConfirm != null || onReject != null))
            _ActionSection(
              child: Row(
                children: [
                  if (onConfirm != null)
                    Expanded(
                      child: _ActionButton(
                        label: 'Confirm',
                        icon: Icons.check,
                        color: AppColors.statusOperating,
                        onTap: onConfirm!,
                      ),
                    ),
                  if (onConfirm != null && onReject != null)
                    const SizedBox(width: 8),
                  if (onReject != null)
                    Expanded(
                      child: _ActionButton(
                        label: 'Reject',
                        icon: Icons.close,
                        color: AppColors.statusMaintenance,
                        onTap: onReject!,
                      ),
                    ),
                ],
              ),
            ),

          // Confirmed: Start Delivery
          if (order.status == OrderStatus.confirmed && onStartDelivery != null)
            _ActionSection(
              child: _ActionButton(
                label: 'Start Delivery',
                icon: Icons.local_shipping,
                color: AppColors.statusBusy,
                onTap: onStartDelivery!,
              ),
            ),

          // In Transit: Mark Delivered
          if (order.status == OrderStatus.inTransit && onComplete != null)
            _ActionSection(
              child: _ActionButton(
                label: 'Mark Delivered',
                icon: Icons.check_circle,
                color: AppColors.statusOperating,
                onTap: onComplete!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    Color bgColor;
    switch (order.status) {
      case OrderStatus.pending:
        color = AppColors.statusAway;
        bgColor = AppColors.statusAwayLight;
        break;
      case OrderStatus.confirmed:
        color = AppColors.statusOperating;
        bgColor = AppColors.statusOperatingLight;
        break;
      case OrderStatus.inTransit:
        color = AppColors.statusBusy;
        bgColor = AppColors.statusBusyLight;
        break;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        color = AppColors.statusMaintenance;
        bgColor = AppColors.statusMaintenanceLight;
        break;
      case OrderStatus.completed:
        color = AppColors.statusOperating;
        bgColor = AppColors.statusOperatingLight;
        break;
    }
    return StatusBadge(
      label: order.status.displayLabel,
      color: color,
      bgColor: bgColor,
    );
  }

  Future<void> _showDeliveryLogs(BuildContext context, int orderId) async {
    if (kIsWeb) return;
    final logs = await context
        .read<OrderRepository>()
        .getDeliveryLogsForOrder(orderId);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delivery Log',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No delivery logs recorded.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              )
            else
              ...logs.map((log) {
                final qty = log['quantity_delivered'] as int? ?? 0;
                final gType = log['gallon_type'] as String? ?? '';
                final notes = log['notes'] as String? ?? '';
                final deliveredAt = log['delivered_at'] as String? ?? '';
                String timeStr = '';
                try {
                  timeStr = _formatTime(DateTime.parse(deliveredAt));
                } catch (_) {}
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: AppColors.statusOperating,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$qty gallon${qty > 1 ? "s" : ""} delivered${gType.isNotEmpty ? " ($gType)" : ""}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (notes.isNotEmpty)
                              Text(
                                notes,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        timeStr,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final displayHour = hour == 0 ? 12 : hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:$minute $period';
  }
}

class _ActionSection extends StatelessWidget {
  final Widget child;
  const _ActionSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      margin: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: child,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(kButtonRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/widgets/order_card.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/widgets/order_card.dart
git commit -m "refactor: rewrite OrderCard with StatusBadge and theme text styles"
```

---

## Task 13: Rewrite `walk_in_alert.dart`

**Files:**
- Rewrite: `lib/ui/widgets/walk_in_alert.dart`

Changes: amber left border on card, title "Walk-in Request", use `InfoRow` for details, Acknowledge button amber fill + 52px height.

- [ ] **Step 1: Replace the file contents**

```dart
// lib/ui/widgets/walk_in_alert.dart
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
            border: Border(
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
                // Details card
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
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/widgets/walk_in_alert.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/widgets/walk_in_alert.dart
git commit -m "refactor: rewrite WalkInAlert with amber styling and InfoRow"
```

---

## Task 14: Rewrite `dashboard_screen.dart`

**Files:**
- Rewrite: `lib/ui/screens/dashboard_screen.dart`

Changes: Use `AppPageHeader`, add active status banner, use `MetricCard` for 2×2 grid, use `StatusBadge` in recent orders, use `textTheme.*` everywhere. Preserve all provider/state logic.

- [ ] **Step 1: Replace the file contents**

```dart
// lib/ui/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/repositories/barangay_repository.dart';
import '../../data/services/system_mode_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/shared/app_page_header.dart';
import '../widgets/shared/metric_card.dart';
import '../widgets/shared/status_badge.dart';
import '../widgets/shared/empty_state.dart';
import '../widgets/status_toggles.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<String> _todayBarangays = [];
  late final BarangayRepository _barangayRepo;

  @override
  void initState() {
    super.initState();
    _barangayRepo = context.read<BarangayRepository>();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    if (kIsWeb) return;
    final today = DeliveryDays.getToday();
    final barangays = await _barangayRepo.getBarangays();
    final todayBarangays = <String>[];

    for (final brgy in barangays) {
      final zone = brgy['delivery_zone'] as String;
      final name = brgy['name'] as String;
      final dbDeliveryDay = brgy['delivery_day'] as String?;

      List<String> days;
      if (zone == 'Zone C' && dbDeliveryDay != null) {
        days = [dbDeliveryDay];
      } else {
        days = ZoneScheduleMap.getDaysForZone(zone, barangayName: name);
      }
      if (days.contains(today)) {
        todayBarangays.add(name);
      }
    }

    if (mounted) setState(() => _todayBarangays = todayBarangays);
  }

  Future<void> _refresh() async {
    if (kIsWeb) return;
    await context.read<OrderProvider>().loadOrders();
    await context.read<CustomerProvider>().loadCustomers();
    await _loadBarangays();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 18) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Consumer2<OrderProvider, CustomerProvider>(
        builder: (context, orderProv, customerProv, _) {
          return Consumer<SystemModeManager>(
            builder: (context, modeManager, _) {
              return ListView(
                padding: const EdgeInsets.all(kPagePadding),
                children: [
                  AppPageHeader(
                    title: _getGreeting(),
                    subtitle: "Here's what's happening at JJ Clover today.",
                  ),
                  const SizedBox(height: 20),

                  // Active status banner
                  _buildStatusBanner(context, modeManager),
                  const SizedBox(height: 16),

                  // Station status label
                  Text(
                    'STATION STATUS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const StatusToggles(),
                  const SizedBox(height: kSectionGap),

                  // Metrics 2×2 grid
                  _buildMetricsGrid(context, orderProv, customerProv),
                  const SizedBox(height: kSectionGap),

                  // Today's Zones
                  _buildTodayZones(context),
                  const SizedBox(height: kSectionGap),

                  // Recent Orders
                  _buildRecentOrders(context, orderProv, customerProv),
                  const SizedBox(height: 16),

                  // Auto-refresh indicator
                  Text(
                    'Auto-refresh: 15s',
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(
      BuildContext context, SystemModeManager modeManager) {
    final mode = modeManager.currentMode;
    Color accentColor;
    Color bgColor;
    String label;
    IconData icon;

    switch (mode) {
      case SystemMode.operating:
        accentColor = AppColors.statusOperating;
        bgColor = AppColors.statusOperatingLight;
        label = 'Operating';
        icon = Icons.check_circle;
        break;
      case SystemMode.staffAway:
        accentColor = AppColors.statusAway;
        bgColor = AppColors.statusAwayLight;
        label = 'Staff Away';
        icon = Icons.access_time;
        break;
      case SystemMode.full:
        accentColor = AppColors.statusBusy;
        bgColor = AppColors.statusBusyLight;
        label = 'Full / Busy';
        icon = Icons.block;
        break;
      case SystemMode.maintenance:
        accentColor = AppColors.statusMaintenance;
        bgColor = AppColors.statusMaintenanceLight;
        label = 'Maintenance';
        icon = Icons.build;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kCardPadding, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: 10),
          Text(
            'Station is currently: $label',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, OrderProvider orderProv,
      CustomerProvider customerProv) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = (screenWidth - 32 - 12) / 2;
    const minHeight = 100.0;
    final cellHeight =
        cellWidth / 1.4 < minHeight ? minHeight : cellWidth / 1.4;
    final aspectRatio = cellWidth / cellHeight;

    final metrics = [
      (
        label: 'Total Gallons',
        value: '${orderProv.totalGallons}',
        color: AppColors.primary,
      ),
      (
        label: 'Pending',
        value: '${orderProv.pendingCount}',
        color: AppColors.statusAway,
      ),
      (
        label: 'Confirmed',
        value: '${orderProv.confirmedCount}',
        color: AppColors.statusOperating,
      ),
      (
        label: 'Customers',
        value: '${customerProv.count}',
        color: AppColors.primary,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: metrics
          .map((m) => MetricCard(
                label: m.label,
                value: m.value,
                valueColor: m.color,
              ))
          .toList(),
    );
  }

  Widget _buildTodayZones(BuildContext context) {
    final today = DeliveryDays.getToday();
    return Container(
      padding: const EdgeInsets.all(kCardPadding + 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Zones ($today)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              InkWell(
                onTap: () => _showScheduleSheet(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'View schedule',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.primary,
                                ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward,
                          size: 12, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_todayBarangays.isEmpty)
            Text(
              'No deliveries scheduled today.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _todayBarangays
                  .map((brgy) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          brgy,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  void _showScheduleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) {
        final today = DeliveryDays.getToday();
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delivery Schedule',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                ...DeliveryDays.days.map((day) {
                  final isToday = day == today;
                  final barangays = _getBarangaysForDay(day);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(kCardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              day,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: isToday
                                        ? AppColors.primary
                                        : AppColors.foreground,
                                  ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Today',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.primary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (barangays.isEmpty)
                          Text(
                            'No deliveries',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: barangays
                                .map((b) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        b,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.primary,
                                            ),
                                      ),
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _getBarangaysForDay(String day) {
    final result = <String>[];
    if (ZoneScheduleMap.zoneADays.contains(day)) {
      result.addAll(['San Isidro', 'San Jose']);
    }
    if (ZoneScheduleMap.zoneBDays.contains(day)) {
      result.addAll(['Poblacion', 'Santa Rosa']);
    }
    ZoneScheduleMap.zoneCBarangayDays.forEach((brgy, brgyDay) {
      if (brgyDay == day) result.add(brgy);
    });
    return result;
  }

  Widget _buildRecentOrders(BuildContext context, OrderProvider orderProv,
      CustomerProvider customerProv) {
    final customerCache = <int, Map<String, dynamic>>{};
    for (final c in customerProv.customers) {
      final id = c['id'] as int?;
      if (id != null) customerCache[id] = c;
    }

    final recentOrders = orderProv.todayOrders
        .where((o) => o['type'] != 'unrecognized')
        .take(5)
        .toList();

    return Container(
      padding: const EdgeInsets.all(kCardPadding + 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              InkWell(
                onTap: () => widget.onNavigateToTab?.call(1),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'View all',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.primary,
                                ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward,
                          size: 12, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentOrders.isEmpty)
            EmptyState(
              icon: Icons.local_shipping,
              message: 'No orders today yet.',
            )
          else
            ...List.generate(recentOrders.length, (i) {
              final order = recentOrders[i];
              final type = order['type'] as String? ?? 'deliver';
              final quantity = order['quantity'] as int? ?? 0;
              final status = order['status'] as String? ?? 'pending';
              final phone = order['phone_number'] as String? ?? '';
              final customerId = order['customer_id'] as int?;
              final customerName = customerId != null
                  ? (customerCache[customerId]?['name'] as String?)
                  : null;
              final isDeliver = type == 'deliver';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: i < recentOrders.length - 1
                    ? const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      )
                    : null,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDeliver
                            ? AppColors.primaryLight
                            : AppColors.statusAwayLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDeliver ? Icons.local_shipping : Icons.water_drop,
                        size: 16,
                        color: isDeliver
                            ? AppColors.primary
                            : AppColors.statusAway,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName ?? phone,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${isDeliver ? "Delivery" : "Walk-in"} · $quantity gal',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    _orderStatusBadge(status),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _orderStatusBadge(String status) {
    Color color;
    Color bgColor;
    switch (status) {
      case 'confirmed':
        color = AppColors.statusOperating;
        bgColor = AppColors.statusOperatingLight;
        break;
      case 'pending':
        color = AppColors.statusAway;
        bgColor = AppColors.statusAwayLight;
        break;
      case 'in_transit':
        color = AppColors.statusBusy;
        bgColor = AppColors.statusBusyLight;
        break;
      case 'cancelled':
      case 'rejected':
        color = AppColors.statusMaintenance;
        bgColor = AppColors.statusMaintenanceLight;
        break;
      default:
        color = AppColors.statusOperating;
        bgColor = AppColors.statusOperatingLight;
    }
    return StatusBadge(label: status, color: color, bgColor: bgColor);
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/screens/dashboard_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/screens/dashboard_screen.dart
git commit -m "refactor: rewrite DashboardScreen with shared widgets and active status banner"
```

---

## Task 15: Rewrite `orders_screen.dart`

**Files:**
- Rewrite: `lib/ui/screens/orders_screen.dart`

Changes: Use `AppPageHeader`, add summary chips row, replace `_FilterTab` with `FilterChipRow`, use `EmptyState`, use `BottomSheetHandle` + `PrimaryActionButton` + `CustomerAvatar` in `_AddOrderForm`. Preserve all provider callbacks and form logic.

- [ ] **Step 1: Replace the file contents**

```dart
// lib/ui/screens/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/order_card.dart';
import '../widgets/shared/app_page_header.dart';
import '../widgets/shared/filter_chip_row.dart';
import '../widgets/shared/empty_state.dart';
import '../widgets/shared/bottom_sheet_handle.dart';
import '../widgets/shared/primary_action_button.dart';
import '../widgets/shared/customer_avatar.dart';
import 'delivery_logs_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  // Filter index: 0=All, 1=Deliveries, 2=Walk-ins, 3=Invalid
  int _filterIndex = 0;

  static const _filterTypes = ['all', 'deliver', 'drop', 'unrecognized'];
  static const _filterLabels = ['All', 'Deliveries', 'Walk-ins', 'Invalid'];

  List<Map<String, dynamic>> _filterOrders(
      List<Map<String, dynamic>> orders) {
    final type = _filterTypes[_filterIndex];
    if (type == 'all') return orders;
    return orders.where((o) => o['type'] == type).toList();
  }

  void _showAddOrderSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<OrderProvider>(),
        child: ChangeNotifierProvider.value(
          value: context.read<CustomerProvider>(),
          child: const _AddOrderForm(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrderProvider, CustomerProvider>(
      builder: (context, orderProv, customerProv, _) {
        final filtered = _filterOrders(orderProv.todayOrders);
        final customerCache = <int, Map<String, dynamic>>{};
        for (final c in customerProv.customers) {
          final id = c['id'] as int?;
          if (id != null) customerCache[id] = c;
        }

        final inTransitCount = orderProv.todayOrders
            .where((o) => o['status'] == 'in_transit')
            .length;

        return RefreshIndicator(
          onRefresh: () async {
            if (kIsWeb) return;
            await orderProv.loadOrders();
          },
          child: ListView(
            padding: const EdgeInsets.all(kPagePadding),
            children: [
              // Header with Delivery Logs icon + Add Order button
              AppPageHeader(
                title: 'Orders',
                subtitle: "Manage today's delivery and walk-in orders.",
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DeliveryLogsScreen()),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(kButtonRadius),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          size: 20,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showAddOrderSheet,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(kButtonRadius),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Add',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSectionGap),

              // Read-only summary chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SummaryChip(
                        label: 'Pending ${orderProv.pendingCount}',
                        color: AppColors.statusAway),
                    const SizedBox(width: 8),
                    _SummaryChip(
                        label: 'Confirmed ${orderProv.confirmedCount}',
                        color: AppColors.statusOperating),
                    const SizedBox(width: 8),
                    _SummaryChip(
                        label: 'In Transit $inTransitCount',
                        color: AppColors.statusBusy),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Filter chips
              FilterChipRow(
                labels: _filterLabels,
                selectedIndex: _filterIndex,
                onSelected: (i) => setState(() => _filterIndex = i),
              ),
              const SizedBox(height: 16),

              // Order list
              if (filtered.isEmpty)
                EmptyState(
                  icon: Icons.local_shipping,
                  message: _filterIndex == 0
                      ? 'No orders today.'
                      : 'No ${_filterLabels[_filterIndex].toLowerCase()} orders.',
                )
              else
                ...filtered.map((orderMap) {
                  final order = Order.fromMap(orderMap);
                  final customer = order.customerId != null
                      ? customerCache[order.customerId]
                      : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OrderCard(
                      order: order,
                      customerName: customer?['name'] as String?,
                      phone: order.phoneNumber,
                      barangay: customer?['barangay'] as String?,
                      address: order.address ??
                          (customer?['address'] as String?),
                      onConfirm: order.type != OrderType.unrecognized &&
                              order.status == OrderStatus.pending
                          ? () async {
                              await orderProv.updateStatus(
                                  order.id!, 'confirmed');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Order confirmed ✓')),
                                );
                              }
                            }
                          : null,
                      onReject: order.type != OrderType.unrecognized &&
                              order.status == OrderStatus.pending
                          ? () => _showRejectDialog(order.id!, orderProv)
                          : null,
                      onStartDelivery:
                          order.type != OrderType.unrecognized &&
                                  order.status == OrderStatus.confirmed
                              ? () async {
                                  await orderProv.updateStatus(
                                      order.id!, 'in_transit');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                            content:
                                                Text('Delivery started ✓')));
                                  }
                                }
                              : null,
                      onComplete: order.type != OrderType.unrecognized &&
                              order.status == OrderStatus.inTransit
                          ? () async {
                              await orderProv.updateStatus(
                                  order.id!, 'completed');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Order completed ✓')),
                                );
                              }
                            }
                          : null,
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _showRejectDialog(int orderId, OrderProvider orderProv) {
    String? reason;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Reject Order',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject this order?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => reason = v,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kButtonRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusMaintenance,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await orderProv.updateStatus(orderId, 'cancelled',
                  reason: reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order rejected ✓')),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

/// Read-only colored chip showing a count label (not a filter).
class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Add Order bottom sheet form. Preserves all existing form logic.
class _AddOrderForm extends StatefulWidget {
  const _AddOrderForm();

  @override
  State<_AddOrderForm> createState() => _AddOrderFormState();
}

class _AddOrderFormState extends State<_AddOrderForm> {
  String _customerMode = 'existing';
  String _customerSearch = '';
  int? _selectedCustomerId;

  final _phoneController = TextEditingController();
  String _type = 'deliver';
  int _quantity = 1;
  String _gallonType = 'new';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_customerMode == 'existing' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a customer')));
      return;
    }

    String phone;
    if (_customerMode == 'existing' && _selectedCustomerId != null) {
      final customers = context.read<CustomerProvider>().customers;
      final match = customers.where((c) => c['id'] == _selectedCustomerId);
      phone = match.isNotEmpty
          ? (match.first['contact_number'] as String? ?? '')
          : '';
    } else {
      phone = _phoneController.text.trim();
    }

    if (_customerMode == 'new' && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a phone number')));
      return;
    }

    await context.read<OrderProvider>().addOrder({
      'customer_id': _selectedCustomerId,
      'phone_number': phone,
      'type': _type,
      'quantity': _quantity,
      'gallon_type': _gallonType,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'is_pre_book': 0,
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.read<CustomerProvider>().customers;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final filteredCustomers = _customerSearch.isEmpty
        ? customers
        : customers.where((c) {
            final name = (c['name'] as String? ?? '').toLowerCase();
            final phone =
                (c['contact_number'] as String? ?? '').toLowerCase();
            return name.contains(_customerSearch.toLowerCase()) ||
                phone.contains(_customerSearch.toLowerCase());
          }).toList();

    return Padding(
      padding:
          EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BottomSheetHandle(title: 'New Order'),
          const SizedBox(height: 20),

          // Customer mode toggle
          Text(
            'Customer',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildModeOption('existing', 'Existing', Icons.people),
              const SizedBox(width: 12),
              _buildModeOption('new', 'New / Manual', Icons.person_add),
            ],
          ),
          const SizedBox(height: 16),

          // Existing customer list
          if (_customerMode == 'existing') ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(kButtonRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _customerSearch = v),
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Search customer...',
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: AppColors.mutedForeground),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredCustomers.length,
                itemBuilder: (_, i) {
                  final c = filteredCustomers[i];
                  final id = c['id'] as int;
                  final name = c['name'] as String? ?? '';
                  final isSelected = _selectedCustomerId == id;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedCustomerId = id;
                      _phoneController.text =
                          c['contact_number'] as String? ?? '';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryLight
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          CustomerAvatar(name: name, size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$name — ${c['contact_number']}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.foreground,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // New customer phone input
          if (_customerMode == 'new') ...[
            Text(
              'Phone Number',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            _buildTextField(
                _phoneController, 'e.g. 09171234567', TextInputType.phone),
            const SizedBox(height: 16),
          ],

          // Order type
          Text(
            'Order Type',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildTypeOption('deliver', 'Delivery', Icons.local_shipping),
              const SizedBox(width: 12),
              _buildTypeOption('drop', 'Walk-in', Icons.water_drop),
            ],
          ),
          const SizedBox(height: 16),

          // Quantity
          Text(
            'Quantity (gallons)',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_quantity > AppConstants.minQuantity) {
                    setState(() => _quantity--);
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(kButtonRadius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.remove,
                      size: 18, color: AppColors.mutedForeground),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_quantity',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (_quantity < AppConstants.maxQuantity) {
                    setState(() => _quantity++);
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(kButtonRadius),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: const Icon(Icons.add,
                      size: 18, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gallon type
          Text(
            'Gallon Type',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildGallonTypeOption('new', 'New', Icons.water_drop),
              const SizedBox(width: 12),
              _buildGallonTypeOption('old', 'Old', Icons.local_gas_station),
            ],
          ),
          const SizedBox(height: 24),

          PrimaryActionButton(label: 'Create Order', onTap: _submit),
        ],
      ),
    );
  }

  Widget _buildModeOption(String value, String label, IconData icon) {
    final isSelected = _customerMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _customerMode = value;
          _selectedCustomerId = null;
          _phoneController.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.background,
            borderRadius: BorderRadius.circular(kButtonRadius),
            border: Border.all(
              color:
                  isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String hint, TextInputType type) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(kButtonRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        inputFormatters: type == TextInputType.phone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ]
            : null,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTypeOption(String value, String label, IconData icon) {
    final isSelected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.background,
            borderRadius: BorderRadius.circular(kButtonRadius),
            border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.mutedForeground),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGallonTypeOption(String value, String label, IconData icon) {
    final isSelected = _gallonType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gallonType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.background,
            borderRadius: BorderRadius.circular(kButtonRadius),
            border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.mutedForeground),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/ui/screens/orders_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Full project analyze**

```bash
flutter analyze
```

Expected: `No issues found!` If warnings appear, fix them before committing.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/screens/orders_screen.dart
git commit -m "refactor: rewrite OrdersScreen with shared widgets and summary chips"
```

---

## Acceptance Checklist

Run these checks before calling Phase 1 complete:

- [ ] `flutter analyze` passes with no errors
- [ ] All 11 files exist in `lib/ui/widgets/shared/`
- [ ] App launches on Android device/emulator without crash
- [ ] Dashboard shows: greeting, active status banner, 2×2 metrics, today's zones, recent orders
- [ ] Orders shows: summary chips (Pending N / Confirmed N / In Transit N), 4 filter chips, order cards with correct action buttons per status
- [ ] Walk-in alert: amber left border, amber Acknowledge button, InfoRow details
- [ ] Station toggles: correct icons (check_circle / access_time / block / build), no glow shadows
- [ ] No hardcoded hex colors or font sizes in any new/rewritten file
- [ ] All tap targets visually sized ≥ 44×44px
- [ ] `SettingCard` exists (will be used in Phase 2 Settings screen)
- [ ] `DangerActionButton` exists (will be used in Phase 2 Customers/Settings screens — no Phase 1 usage is expected)

---

## Notes for Phase 2

Phase 2 (separate branch) will rewrite:
- `customers_screen.dart` — use `CustomerAvatar`, `AppPageHeader`, zone badges
- `messages_screen.dart` — use `AppPageHeader`, `EmptyState`
- `chat_screen.dart` — rewrite `chat_bubble.dart`, `chat_header.dart`, `message_input.dart`
- `schedule_screen.dart` — today highlight with primary border
- `delivery_logs_screen.dart` — shift-end summary, `FilterChipRow`
- `settings_screen.dart` — `SettingCard` for all settings rows, grouped by category
- `loading_screen.dart` — new file, water drop + JJ Clover brand + spinner
