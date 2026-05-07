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
                  const SizedBox(height: kSectionGap),

                  _buildStatusBanner(context, modeManager),
                  const SizedBox(height: 16),

                  Text(
                    'STATION STATUS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const StatusToggles(),
                  const SizedBox(height: kSectionGap),

                  _buildMetricsGrid(context, orderProv, customerProv),
                  const SizedBox(height: kSectionGap),

                  _buildTodayZones(context),
                  const SizedBox(height: kSectionGap),

                  _buildRecentOrders(context, orderProv, customerProv),
                  const SizedBox(height: 16),

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
      padding: const EdgeInsets.symmetric(
          horizontal: kCardPadding, vertical: 12),
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
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: AppColors.primary),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
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
                        color:
                            isToday ? AppColors.primary : AppColors.border,
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
                            style: Theme.of(context).textTheme.bodySmall,
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
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: AppColors.primary),
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
            const EmptyState(
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
    return StatusBadge(label: _statusDisplayLabel(status), color: color, bgColor: bgColor);
  }
}
