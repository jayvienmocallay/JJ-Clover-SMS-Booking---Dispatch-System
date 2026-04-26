// Task 010 — Dashboard screen: main home with greeting, status toggles,
// stats cards, today's zones, and recent orders
// Task 011 — Connected to OrderProvider and CustomerProvider via Consumer
// Main home with greeting, status toggles, stats cards, zones, and recent orders
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../../database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/status_toggles.dart';

class DashboardScreen extends StatefulWidget {
  /// Callback to navigate to a specific tab in AppShell
  final void Function(int tabIndex)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<String> _todayBarangays = [];

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  /// Loads today's scheduled barangays (zone data is static, not in provider)
  Future<void> _loadBarangays() async {
    if (kIsWeb) return;
    final db = DatabaseHelper.instance;
    final today = DeliveryDays.getToday();
    final barangays = await db.getBarangays();
    final todayBarangays = <String>[];

    for (final brgy in barangays) {
      final zone = brgy['delivery_zone'] as String;
      final name = brgy['name'] as String;
      final days = ZoneScheduleMap.getDaysForZone(zone, barangayName: name);
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

  /// Returns a greeting based on the current hour
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Header greeting ---
              Text(
                _getGreeting(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Here's what's happening at JJ Clover today.",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),

              // --- Station Status toggles ---
              const Text(
                'STATION STATUS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              const StatusToggles(),
              const SizedBox(height: 24),

              // --- Stats cards (2x2 grid) ---
              _buildStatsGrid(orderProv, customerProv),
              const SizedBox(height: 24),

              // --- Today's Zones card ---
              _buildTodayZones(),
              const SizedBox(height: 24),

              // --- Recent Orders card ---
              _buildRecentOrders(orderProv, customerProv),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  /// Builds the 2x2 stats grid (Total Gallons, Pending, Confirmed, Customers)
  Widget _buildStatsGrid(
    OrderProvider orderProv,
    CustomerProvider customerProv,
  ) {
    final stats = [
      _StatItem(
        Icons.water_drop,
        'Total Gallons',
        orderProv.totalGallons,
        AppColors.primary,
      ),
      _StatItem(
        Icons.inventory_2,
        'Pending',
        orderProv.pendingCount,
        AppColors.statusAway,
      ),
      _StatItem(
        Icons.local_shipping,
        'Confirmed',
        orderProv.confirmedCount,
        AppColors.statusOperating,
      ),
      _StatItem(
        Icons.people,
        'Customers',
        customerProv.count,
        AppColors.primary,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: stats.map((stat) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(stat.icon, size: 20, color: stat.color),
              const SizedBox(height: 8),
              Text(
                '${stat.value}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              Text(
                stat.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Builds the Today's Zones card showing scheduled barangays
  Widget _buildTodayZones() {
    final today = DeliveryDays.getToday();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with "View schedule" link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Zones ($today)",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              // Task 011 — Tappable "View schedule" navigates to Schedule tab
              // Schedule is not a tab, so we show it in a dialog or we could
              // navigate if we add it. For now, we'll show it in the bottom sheet.
              GestureDetector(
                onTap: () => _showScheduleSheet(context),
                child: const Row(
                  children: [
                    Text(
                      'View schedule',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barangay chips
          if (_todayBarangays.isEmpty)
            const Text(
              'No deliveries scheduled today.',
              style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _todayBarangays.map((brgy) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    brgy,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Shows the full weekly schedule in a bottom sheet
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
                // Handle bar
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
                const Text(
                  'Delivery Schedule',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 16),
                ...DeliveryDays.days.map((day) {
                  final isToday = day == today;
                  final barangays = _getBarangaysForDay(day);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
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
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? AppColors.primary
                                    : AppColors.foreground,
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
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Today',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (barangays.isEmpty)
                          const Text(
                            'No deliveries',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
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
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      b,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                      ),
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

  /// Gets barangays scheduled for a given day
  List<String> _getBarangaysForDay(String day) {
    final result = <String>[];
    // Zone A: Mon-Sat
    if (ZoneScheduleMap.zoneADays.contains(day)) {
      result.addAll(['San Isidro', 'San Jose']);
    }
    // Zone B: Mon/Wed/Fri
    if (ZoneScheduleMap.zoneBDays.contains(day)) {
      result.addAll(['Poblacion', 'Santa Rosa']);
    }
    // Zone C: individual days
    ZoneScheduleMap.zoneCBarangayDays.forEach((brgy, brgyDay) {
      if (brgyDay == day) result.add(brgy);
    });
    return result;
  }

  /// Builds the Recent Orders card showing up to 5 latest orders
  Widget _buildRecentOrders(
    OrderProvider orderProv,
    CustomerProvider customerProv,
  ) {
    final customerCache = <int, Map<String, dynamic>>{};
    for (final c in customerProv.customers) {
      final id = c['id'] as int?;
      if (id != null) customerCache[id] = c;
    }

    final recentOrders = orderProv.todayOrders
        .where((order) => order['type'] != 'unrecognized')
        .take(5)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              // Task 011 — Tappable "View all" navigates to Orders tab
              GestureDetector(
                onTap: () => widget.onNavigateToTab?.call(1),
                child: const Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Order list
          if (recentOrders.isEmpty)
            const Text(
              'No orders today yet.',
              style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: i < recentOrders.length - 1
                    ? const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      )
                    : null,
                child: Row(
                  children: [
                    // Type icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDeliver
                            ? AppColors.primaryLight
                            : AppColors.statusAwayLight,
                        borderRadius: BorderRadius.circular(12),
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
                    // Order info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName ?? phone,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.foreground,
                            ),
                          ),
                          Text(
                            '${isDeliver ? "Delivery" : "Walk-in"} · $quantity gal',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusBgColor(status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getStatusTextColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.statusOperatingLight;
      case 'pending':
        return AppColors.statusAwayLight;
      case 'cancelled':
        return AppColors.statusMaintenanceLight;
      default:
        return AppColors.muted;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.statusOperating;
      case 'pending':
        return AppColors.statusAway;
      case 'cancelled':
        return AppColors.statusMaintenance;
      default:
        return AppColors.mutedForeground;
    }
  }
}

/// Simple data class for stat card items
class _StatItem {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatItem(this.icon, this.label, this.value, this.color);
}
