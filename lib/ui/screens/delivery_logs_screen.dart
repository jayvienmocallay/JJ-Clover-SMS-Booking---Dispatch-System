// Task 011 — Dedicated Delivery Logs screen: filterable list with shift-end stats
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/delivery_log_model.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/repositories/delivery_log_repository.dart';
import '../theme/app_theme.dart';

class DeliveryLogsScreen extends StatefulWidget {
  const DeliveryLogsScreen({super.key});

  @override
  State<DeliveryLogsScreen> createState() => _DeliveryLogsScreenState();
}

class _DeliveryLogsScreenState extends State<DeliveryLogsScreen> {
  bool _loading = true;
  List<DeliveryLog> _allLogs = [];
  // 'today' | 'week' | 'all'
  String _filter = 'today';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLogs());
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final rawLogs = await context.read<DeliveryLogRepository>().getDeliveryLogs();
    setState(() {
      _allLogs = rawLogs.map(DeliveryLog.fromMap).toList();
      _loading = false;
    });
  }

  List<DeliveryLog> get _filteredLogs {
    final now = DateTime.now();
    return _allLogs.where((log) {
      switch (_filter) {
        case 'today':
          return log.deliveredAt.year == now.year &&
              log.deliveredAt.month == now.month &&
              log.deliveredAt.day == now.day;
        case 'week':
          return log.deliveredAt.isAfter(now.subtract(const Duration(days: 7)));
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final customerProv = context.watch<CustomerProvider>();
    final customerCache = <int, String>{};
    for (final c in customerProv.customers) {
      final id = c['id'] as int?;
      final name = c['name'] as String?;
      if (id != null && name != null) customerCache[id] = name;
    }

    final logs = _filteredLogs;
    final totalGallons =
        logs.fold<int>(0, (sum, l) => sum + l.quantityDelivered);

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).card,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.of(context).foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Delivery Logs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.of(context).foreground,
          ),
        ),
        elevation: 0,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.of(context).primary),
            )
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- Stats ---
                  Row(
                    children: [
                      _StatCard(
                        label: 'Deliveries',
                        value: '${logs.length}',
                        icon: Icons.local_shipping,
                        iconBg: AppColors.of(context).primaryLight,
                        iconColor: AppColors.of(context).primary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Gallons',
                        value: '$totalGallons',
                        icon: Icons.water_drop,
                        iconBg: AppColors.of(context).statusOperatingLight,
                        iconColor: AppColors.of(context).statusOperating,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // --- Filter chips ---
                  Row(
                    children: [
                      _FilterChip(
                        label: 'Today',
                        selected: _filter == 'today',
                        onTap: () => setState(() => _filter = 'today'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'This Week',
                        selected: _filter == 'week',
                        onTap: () => setState(() => _filter = 'week'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'All Time',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // --- Log list ---
                  if (logs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 48,
                              color: AppColors.of(context).mutedForeground,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _filter == 'today'
                                  ? 'No deliveries recorded today.'
                                  : 'No delivery logs found.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.of(context).mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...logs.map(
                      (log) => _DeliveryLogCard(
                        log: log,
                        customerName: customerCache[log.customerId],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.of(context).card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.of(context).border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.of(context).foreground,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.of(context).primary : AppColors.of(context).muted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.of(context).mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _DeliveryLogCard extends StatelessWidget {
  final DeliveryLog log;
  final String? customerName;

  const _DeliveryLogCard({required this.log, this.customerName});

  @override
  Widget build(BuildContext context) {
    final qty = log.quantityDelivered;
    final gallonText =
        '$qty gallon${qty > 1 ? "s" : ""}${log.gallonType?.isNotEmpty == true ? " (${log.gallonType})" : ""}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.of(context).statusOperatingLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.check_circle,
              size: 18,
              color: AppColors.of(context).statusOperating,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName ?? 'Walk-in',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(context).foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  gallonText,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.of(context).mutedForeground,
                  ),
                ),
                if (log.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.of(context).mutedForeground,
                    ),
                  ),
                ],
                if (log.returnedContainers != null ||
                    log.paymentMethod != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (log.returnedContainers != null) ...[
                        Icon(
                          Icons.replay,
                          size: 11,
                          color: AppColors.of(context).mutedForeground,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${log.returnedContainers} returned',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.of(context).mutedForeground,
                          ),
                        ),
                        if (log.paymentMethod != null)
                          const SizedBox(width: 10),
                      ],
                      if (log.paymentMethod != null) ...[
                        Icon(
                          Icons.payments_outlined,
                          size: 11,
                          color: AppColors.of(context).mutedForeground,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          log.paymentMethod!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.of(context).mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatDateTime(log.deliveredAt),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.of(context).mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final displayHour = hour == 0 ? 12 : hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$displayHour:$minute $period';
    if (isToday) return timeStr;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, $timeStr';
  }
}
