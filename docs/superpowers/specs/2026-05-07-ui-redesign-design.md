# JJ Clover UI Redesign — Implementation Spec

**Date:** 2026-05-07  
**Branch:** `ui/redesign`  
**Source of truth:** `design.md` (root of repo)  
**Approach:** Full rewrite — preserve business logic, replace all UI code  
**Phasing:** Phase 1 (this branch) then Phase 2 (separate branch)

---

## Decision Summary

| Decision | Choice | Reason |
|---|---|---|
| Strategy | Core widgets + priority screens first | Prove design system before scaling |
| Rewrite vs. patch | Full rewrite | Clean result, design.md is comprehensive enough |
| Phasing | Two branches/PRs | Large scope; safer to review in two chunks |
| Commit style | No Claude attribution | User preference |
| Push | Manual only | User controls when to push |

---

## Phase 1 Scope (this branch)

### Shared widgets — create `lib/ui/widgets/shared/`

All widgets are new files. Existing widget files stay until Phase 2 replaces them.

| Widget | File | Purpose |
|---|---|---|
| `AppPageHeader` | `app_page_header.dart` | Title + subtitle + optional right action |
| `StatusBadge` | `status_badge.dart` | Colored pill for order/station status |
| `FilterChipRow` | `filter_chip_row.dart` | Scrollable filter chips, active/inactive states |
| `MetricCard` | `metric_card.dart` | Dashboard number card |
| `EmptyState` | `empty_state.dart` | Icon + message for empty lists |
| `SettingCard` | `setting_card.dart` | Icon + title + description + action area |
| `BottomSheetHandle` | `bottom_sheet_handle.dart` | Drag handle + optional title |
| `InfoRow` | `info_row.dart` | Label + value row for detail views |
| `CustomerAvatar` | `customer_avatar.dart` | Circular initial avatar |
| `PrimaryActionButton` | `primary_action_button.dart` | Filled blue full-width CTA |
| `DangerActionButton` | `danger_action_button.dart` | Filled red destructive action |

### Screens — full rewrite

**Phase 1 screens:**

1. **Dashboard** (`dashboard_screen.dart`) — greeting, station status banner + grid, 2×2 metrics, today's zones, recent orders
2. **Orders** (`orders_screen.dart`) — summary chips, filter tabs, order cards with inline actions, delivery logs nav

**Phase 1 widget rewrites:**

- `status_toggles.dart` — station mode control (Operating/Away/Busy/Maintenance), used by Dashboard
- `order_card.dart` — order type icon, customer info, status badge, inline action buttons
- `walk_in_alert.dart` — amber overlay with pulsing icon, full-width acknowledge

---

## Phase 2 Scope (separate branch)

Remaining screens after Phase 1 is merged:

- Customers screen + `customer_info_sheet.dart`
- Messages screen
- Chat screen + `chat_bubble.dart`, `chat_header.dart`, `message_input.dart`
- Schedule screen
- Delivery Logs screen
- Settings screen
- Loading screen (new file: `loading_screen.dart`)

---

## Design Token Reference

All tokens already exist in `lib/ui/theme/app_theme.dart`. Use `AppColors.*` — do not hardcode hex.

| Token | Usage |
|---|---|
| `AppColors.background` | Main scaffold background |
| `AppColors.card` | Card/bottom sheet/appbar surface |
| `AppColors.foreground` | Primary text |
| `AppColors.primary` | CTAs, selected nav, active filter chips |
| `AppColors.muted` | Input bg, inactive chips |
| `AppColors.mutedForeground` | Captions, metadata, empty state text |
| `AppColors.border` | Card and input borders |
| `AppColors.statusOperating` / `statusOperatingLight` | Green status + bg |
| `AppColors.statusAway` / `statusAwayLight` | Amber status + bg |
| `AppColors.statusBusy` / `statusBusyLight` | Orange status + bg |
| `AppColors.statusMaintenance` / `statusMaintenanceLight` | Red status + bg |
| `AppColors.primaryLight` | Blue low-emphasis surface |

Typography: use `Theme.of(context).textTheme.*` — never hardcode sizes.

---

## Layout Constants

Define once at the bottom of `lib/ui/theme/app_theme.dart`:

```dart
const double kPagePadding = 16;
const double kCardPadding = 16;
const double kCardRadius = 16;
const double kButtonRadius = 12;
const double kSectionGap = 20;
const double kCompactGap = 8;
```

---

## Shared Widget Specs

### `AppPageHeader`

```dart
AppPageHeader({
  required String title,
  String? subtitle,
  Widget? action,         // trailing icon button
})
```

- Title: `displayLarge` style (26px bold)
- Subtitle: `bodyLarge` style, `mutedForeground` color
- Action: right-aligned, 44×44 tap target minimum

### `StatusBadge`

```dart
StatusBadge({
  required String label,   // 'PENDING', 'CONFIRMED', etc.
  required Color color,    // text + icon color
  required Color bgColor,  // pill background
  IconData? icon,
})
```

- Height: 26px, horizontal padding: 10px
- Font: `labelSmall` (11px, w600), uppercase
- Radius: 100 (fully rounded)

### `FilterChipRow`

```dart
FilterChipRow({
  required List<String> labels,
  required int selectedIndex,
  required ValueChanged<int> onSelected,
})
```

- Horizontal scroll, no clip
- Active: `primary` bg, white text
- Inactive: `muted` bg, `mutedForeground` text
- Height: 36px, radius: 100

### `MetricCard`

```dart
MetricCard({
  required String label,
  required String value,
  Color? valueColor,
})
```

- Card bg: `AppColors.card`, border: `AppColors.border`
- Value: `headlineLarge` (22px, bold)
- Label: `labelSmall`, muted

### `EmptyState`

```dart
EmptyState({
  required IconData icon,
  required String message,
})
```

- Centered column, icon 48px, muted color
- Message: `bodyMedium`, `mutedForeground`

### `SettingCard`

```dart
SettingCard({
  required IconData icon,
  required String title,
  required String description,
  required Widget action,    // Switch, button, or arrow
  bool isDanger = false,
})
```

- Danger variant: icon + title in `statusMaintenance` color

### `CustomerAvatar`

```dart
CustomerAvatar({
  required String name,
  double size = 40,
})
```

- Circular, `primaryLight` bg, `primary` text
- Initial: first letter of name, `titleLarge` weight

---

## Dashboard Screen Spec

Structure (vertical scroll, 16px padding):

1. `AppPageHeader` — greeting (time-based), subtitle
2. **Active status banner** — full-width card showing current mode with colored left border
3. **Status grid** — 2×2, using rewritten `StatusToggle` widget
4. **Metric grid** — 2×2 `MetricCard` widgets: Total Gallons, Pending, Confirmed, Customers
5. **Today's Zones** — card with compact barangay chips grouped by zone
6. **Recent Orders** — card showing latest 5 non-invalid orders as read-only summary rows (customer name, gallon count, order type icon, `StatusBadge`). Not the full `OrderCard` — no action buttons.
7. Auto-refresh indicator — `labelSmall` muted text near header

---

## Orders Screen Spec

Structure:

1. `AppPageHeader` — "Orders" + subtitle + Delivery Logs icon + Add Order button
2. **Summary chips row** — `Pending N`, `Confirmed N`, `In Transit N` (read-only, not filter)
3. `FilterChipRow` — All / Deliveries / Walk-ins / Invalid
4. Scrollable `OrderCard` list

### `OrderCard` spec

Full rewrite of `lib/ui/widgets/order_card.dart`:

- Type icon (delivery vs. walk-in vs. invalid) — left leading
- Customer name or phone, quantity + gallon type, barangay
- Time received — `labelSmall` muted, right-aligned
- `StatusBadge` — right side
- Rejection/failure reason — `bodySmall` red text when applicable
- Action row (bottom of card):
  - Pending: **Confirm** (green) + **Reject** (red)
  - Confirmed: **Start Delivery** (orange)
  - In Transit: **Mark Delivered** (green)
  - Completed: view log affordance (muted text link)
  - Invalid: no action buttons, show parsed error

---

## Walk-in Alert Spec

Full rewrite of `lib/ui/widgets/walk_in_alert.dart`:

- Dimmed full-screen backdrop (black 60% opacity)
- Centered card, `AppColors.card` bg, amber left border
- Pulsing `Icons.notifications_active` in amber
- Title: "Walk-in Request" — `titleLarge`
- Phone, quantity, time: `InfoRow` widgets
- **Acknowledge** button: `PrimaryActionButton` but amber fill, full-width, min height 52px
- No auto-dismiss

---

## Station Status Toggles Spec

Full rewrite of `lib/ui/widgets/status_toggles.dart`:

2×2 grid of toggle cards:

| Mode | Color | Icon |
|---|---|---|
| Operating | `statusOperating` | `Icons.check_circle` |
| Staff Away | `statusAway` | `Icons.access_time` |
| Full / Busy | `statusBusy` | `Icons.block` |
| Maintenance | `statusMaintenance` | `Icons.build` |

Active card: colored border + colored icon + colored label + light-colored bg.  
Inactive card: border only, muted icon, muted text.

---

## Rules

- All tap targets minimum 44×44px
- No hardcoded colors or font sizes — use theme tokens only
- No inline `TextStyle(...)` calls — use `Theme.of(context).textTheme.*`
- No decorative shadows — use `AppColors.border` + `BorderSide` instead
- Status pills always pair color with text label (never color alone)
- Destructive actions (Reject, Cancel, Delete) always visually separated from primary
- Pull-to-refresh on data-heavy screens
- Bottom sheets respect `MediaQuery.of(context).viewInsets.bottom`

---

## File Structure After Phase 1

```
lib/ui/
  theme/
    app_theme.dart          (existing — add layout constants)
  screens/
    app_shell.dart          (existing — unchanged)
    dashboard_screen.dart   (REWRITTEN)
    orders_screen.dart      (REWRITTEN)
    ... (others unchanged until Phase 2)
  widgets/
    shared/                 (NEW folder)
      app_page_header.dart
      status_badge.dart
      filter_chip_row.dart
      metric_card.dart
      empty_state.dart
      setting_card.dart
      bottom_sheet_handle.dart
      info_row.dart
      customer_avatar.dart
      primary_action_button.dart
      danger_action_button.dart
    order_card.dart         (REWRITTEN)
    status_toggles.dart     (REWRITTEN)
    walk_in_alert.dart      (REWRITTEN)
    chat_bubble.dart        (unchanged until Phase 2)
    chat_header.dart        (unchanged until Phase 2)
    customer_info_sheet.dart(unchanged until Phase 2)
    message_input.dart      (unchanged until Phase 2)
```

---

## Acceptance Criteria (Phase 1)

- [ ] All 11 shared widgets exist and are used by at least one screen
- [ ] Dashboard shows time-based greeting, active status banner, 4 metrics, today's zones, recent orders
- [ ] Orders screen shows summary chips, filter tabs, and correct action buttons per order state
- [ ] Walk-in alert overlays full screen with amber styling and requires tap to dismiss
- [ ] No hardcoded colors or font sizes anywhere in new/rewritten files
- [ ] App compiles and runs without errors on Android target
- [ ] All tap targets ≥ 44×44px
