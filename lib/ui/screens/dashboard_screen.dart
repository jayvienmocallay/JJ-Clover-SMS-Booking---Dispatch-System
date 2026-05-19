import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/repositories/barangay_repository.dart';
import '../../data/services/system_mode_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/shared/app_page_header.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/brand_mascot.dart';
import '../widgets/shared/status_badge.dart';
import '../widgets/shared/empty_state.dart';
import '../widgets/shared/section_header.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex, {int? ordersFilterIndex})? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<String> _todayBarangays = [];
  List<Map<String, dynamic>> _barangays = [];
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
      final name = brgy['name'] as String;
      final days = _deliveryDaysForBarangay(brgy);
      if (days.contains(today)) {
        todayBarangays.add(name);
      }
    }

    if (mounted) {
      setState(() {
        _barangays = barangays;
        _todayBarangays = todayBarangays;
      });
    }
  }

  List<String> _deliveryDaysForBarangay(Map<String, dynamic> barangay) {
    final zone = barangay['delivery_zone'] as String? ?? '';
    final name = barangay['name'] as String? ?? '';
    final dbDeliveryDay = barangay['delivery_day'] as String?;
    if (dbDeliveryDay != null && dbDeliveryDay.trim().isNotEmpty) {
      return dbDeliveryDay
          .split(',')
          .map((day) => day.trim())
          .where((day) => day.isNotEmpty)
          .toList();
    }
    return ZoneScheduleMap.getDaysForZone(zone, barangayName: name);
  }

  Future<void> _refresh() async {
    if (kIsWeb) return;
    final orderProv = context.read<OrderProvider>();
    final customerProv = context.read<CustomerProvider>();
    await orderProv.loadOrders();
    await customerProv.loadCustomers();
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
                  const SizedBox(height: 12),
                  _buildDispatchMascotCallout(context, orderProv),
                  const SizedBox(height: kSectionGap),

                  _buildStatusBanner(context, modeManager),
                  const SizedBox(height: kSectionGap),

                  _buildTodayOverview(context, orderProv),
                  const SizedBox(height: kSectionGap),

                  _buildTodayZones(context),
                  const SizedBox(height: kSectionGap),

                  _buildRecentOrders(context, orderProv, customerProv),
                  const SizedBox(height: 16),

                  Text(
                    'Auto-refresh: ${AppConstants.autoRefreshSeconds}s',
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
    BuildContext context,
    SystemModeManager modeManager,
  ) {
    final palette = AppColors.of(context);
    final mode = modeManager.currentMode;
    Color accentColor;
    Color bgColor;
    String label;
    String subtitle;
    IconData icon;

    switch (mode) {
      case SystemMode.operating:
        accentColor = palette.statusOperating;
        bgColor = palette.statusOperatingLight;
        label = 'Station is Operating';
        subtitle = 'Open & accepting orders';
        icon = Icons.verified_user;
        break;
      case SystemMode.staffAway:
        accentColor = palette.statusAway;
        bgColor = palette.statusAwayLight;
        label = 'Staff Away';
        subtitle = 'Staff currently unavailable';
        icon = Icons.access_time;
        break;
      case SystemMode.full:
        accentColor = palette.statusBusy;
        bgColor = palette.statusBusyLight;
        label = 'Full / Busy';
        subtitle = 'No more orders for today';
        icon = Icons.do_not_disturb;
        break;
      case SystemMode.maintenance:
        accentColor = palette.statusMaintenance;
        bgColor = palette.statusMaintenanceLight;
        label = 'Maintenance Mode';
        subtitle = 'System under maintenance';
        icon = Icons.build;
        break;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kCardRadius),
      child: InkWell(
        onTap: () => _showModeSwitcher(context, modeManager),
        borderRadius: BorderRadius.circular(kCardRadius),
        splashColor: accentColor.withValues(alpha: 0.12),
        highlightColor: accentColor.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kCardPadding,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(kCardRadius),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: accentColor.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to change mode',
                      style: TextStyle(
                        fontSize: 11,
                        color: accentColor.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: accentColor.withValues(alpha: 0.8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDispatchMascotCallout(
    BuildContext context,
    OrderProvider orderProv,
  ) {
    final inTransitCount = orderProv.todayOrders
        .where((order) => order['status'] == 'in_transit')
        .length;
    final totalOrders = orderProv.todayOrders
        .where((order) => order['type'] != 'unrecognized')
        .length;
    final hasOrders = totalOrders > 0;

    return MascotCallout(
      pose: MascotPose.deliveryTruck,
      eyebrow: 'Today',
      title: hasOrders
          ? 'Dispatch board is live'
          : 'Ready for the first booking',
      subtitle: hasOrders
          ? '${orderProv.pendingCount} pending, ${orderProv.confirmedCount} confirmed, $inTransitCount on the road.'
          : 'New SMS and walk-in requests will appear here for quick action.',
    );
  }

  void _showModeSwitcher(BuildContext context, SystemModeManager modeManager) {
    final palette = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer<SystemModeManager>(
        builder: (ctx, mgr, _) {
          final modes = [
            (
              mode: SystemMode.operating,
              label: 'Operating',
              subtitle: 'Open & accepting orders',
              icon: Icons.verified_user,
              color: palette.statusOperating,
              bg: palette.statusOperatingLight,
            ),
            (
              mode: SystemMode.staffAway,
              label: 'Staff Away',
              subtitle: 'Out delivering, still accepting',
              icon: Icons.access_time,
              color: palette.statusAway,
              bg: palette.statusAwayLight,
            ),
            (
              mode: SystemMode.full,
              label: 'Full / Busy',
              subtitle: 'No more deliveries today',
              icon: Icons.do_not_disturb,
              color: palette.statusBusy,
              bg: palette.statusBusyLight,
            ),
            (
              mode: SystemMode.maintenance,
              label: 'Maintenance',
              subtitle: 'Station closed',
              icon: Icons.build,
              color: palette.statusMaintenance,
              bg: palette.statusMaintenanceLight,
            ),
          ];

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Station Status',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Select current operating mode',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                ...modes.map((m) {
                  final isActive = mgr.currentMode == m.mode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        mgr.setMode(m.mode);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Mode set to ${m.label} ✓'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? m.bg : palette.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isActive
                                ? m.color.withValues(alpha: 0.5)
                                : palette.border,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? m.color.withValues(alpha: 0.2)
                                    : palette.muted,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                m.icon,
                                size: 18,
                                color: isActive
                                    ? m.color
                                    : palette.mutedForeground,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isActive
                                          ? m.color
                                          : palette.foreground,
                                    ),
                                  ),
                                  Text(
                                    m.subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: palette.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isActive)
                              Icon(
                                Icons.check_circle,
                                color: m.color,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayOverview(BuildContext context, OrderProvider orderProv) {
    final palette = AppColors.of(context);
    final now = DateTime.now();
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final min = now.minute.toString().padLeft(2, '0');
    final timeLabel = 'Updated $hour:$min $amPm';

    final inTransitCount = orderProv.todayOrders
        .where((o) => o['status'] == 'in_transit')
        .length;
    final totalOrders = orderProv.todayOrders
        .where((o) => o['type'] != 'unrecognized')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Today's Overview",
          trailing: Text(
            timeLabel,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _overviewCard(
              context,
              '$totalOrders',
              'Total Orders',
              palette.primary,
              'View all',
              ordersFilterIndex: 0,
            ),
            _overviewCard(
              context,
              '${orderProv.pendingCount}',
              'Pending',
              palette.statusAway,
              'View',
              ordersFilterIndex: 1,
            ),
            _overviewCard(
              context,
              '${orderProv.confirmedCount}',
              'Confirmed',
              palette.statusOperating,
              'View',
              ordersFilterIndex: 2,
            ),
            _overviewCard(
              context,
              '$inTransitCount',
              'In Transit',
              palette.statusBusy,
              'View',
              ordersFilterIndex: 3,
            ),
          ],
        ),
      ],
    );
  }

  Widget _overviewCard(
    BuildContext context,
    String value,
    String label,
    Color color,
    String actionLabel, {
    int? ordersFilterIndex,
  }) {
    return AppCard(
      onTap: () =>
          widget.onNavigateToTab?.call(1, ordersFilterIndex: ordersFilterIndex),
      padding: const EdgeInsets.all(kCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(color: color),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward, size: 12, color: color),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayZones(BuildContext context) {
    final palette = AppColors.of(context);
    final today = DeliveryDays.getToday();
    return AppCard(
      padding: const EdgeInsets.all(kCardPadding + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: "Today's Zones ($today)",
            trailing: InkWell(
              onTap: () => _showScheduleSheet(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'View schedule',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: palette.primary),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 12, color: palette.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_todayBarangays.isEmpty)
            Text(
              'No deliveries scheduled today.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.mutedForeground),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _todayBarangays
                  .map(
                    (brgy) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        brgy,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  void _showScheduleSheet(BuildContext context) {
    final palette = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.card,
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
                      color: palette.border,
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
                      color: palette.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday ? palette.primary : palette.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              day,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: isToday
                                        ? palette.primary
                                        : palette.foreground,
                                  ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Today',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: palette.primary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (barangays.isEmpty)
                          Text(
                            'No deliveries',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: barangays
                                .map(
                                  (b) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.primaryLight,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      b,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: palette.primary),
                                    ),
                                  ),
                                )
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
    return _barangays
        .where((barangay) => _deliveryDaysForBarangay(barangay).contains(day))
        .map((barangay) => barangay['name'] as String? ?? 'Unknown')
        .toList();
  }

  Widget _buildRecentOrders(
    BuildContext context,
    OrderProvider orderProv,
    CustomerProvider customerProv,
  ) {
    final palette = AppColors.of(context);
    final customerCache = <int, Map<String, dynamic>>{};
    for (final c in customerProv.customers) {
      final id = c['id'] as int?;
      if (id != null) customerCache[id] = c;
    }

    final recentOrders = orderProv.todayOrders
        .where((o) => o['type'] != 'unrecognized')
        .take(5)
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(kCardPadding + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Recent Orders',
            trailing: InkWell(
              onTap: () =>
                  widget.onNavigateToTab?.call(1, ordersFilterIndex: 0),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: palette.primary),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 12, color: palette.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (recentOrders.isEmpty)
            const EmptyState(
              icon: Icons.local_shipping,
              mascot: MascotPose.deliveryTruck,
              title: 'Queue is clear',
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
                    ? BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: palette.border),
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
                            ? palette.primaryLight
                            : palette.statusAwayLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDeliver ? Icons.local_shipping : Icons.water_drop,
                        size: 16,
                        color: isDeliver ? palette.primary : palette.statusAway,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName ?? phone,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${isDeliver ? "Delivery" : "Walk-in"} · $quantity gal',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    _orderStatusBadge(context, status),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _statusDisplayLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_transit':
        return 'In Transit';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Widget _orderStatusBadge(BuildContext context, String status) {
    final palette = AppColors.of(context);
    Color color;
    Color bgColor;
    IconData icon;
    switch (status) {
      case 'confirmed':
        color = palette.statusOperating;
        bgColor = palette.statusOperatingLight;
        icon = Icons.check_circle;
        break;
      case 'pending':
        color = palette.statusAway;
        bgColor = palette.statusAwayLight;
        icon = Icons.hourglass_top;
        break;
      case 'in_transit':
        color = palette.statusBusy;
        bgColor = palette.statusBusyLight;
        icon = Icons.local_shipping;
        break;
      case 'cancelled':
      case 'rejected':
        color = palette.statusMaintenance;
        bgColor = palette.statusMaintenanceLight;
        icon = Icons.cancel;
        break;
      default:
        color = palette.statusOperating;
        bgColor = palette.statusOperatingLight;
        icon = Icons.done_all;
    }
    return StatusBadge(
      label: _statusDisplayLabel(status),
      color: color,
      bgColor: bgColor,
      icon: icon,
    );
  }
}
