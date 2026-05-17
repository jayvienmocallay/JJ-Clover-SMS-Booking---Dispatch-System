// Task 011 — Dedicated Delivery Logs screen: filterable list with shift-end stats
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/delivery_log_model.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/repositories/delivery_log_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/brand_mascot.dart';
import '../widgets/shared/empty_state.dart';
import '../widgets/shared/loading_state.dart';
import '../widgets/shared/metric_card.dart';
import '../widgets/shared/status_badge.dart';

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
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final rawLogs = await context
          .read<DeliveryLogRepository>()
          .getDeliveryLogs();
      if (!mounted) return;
      setState(() => _allLogs = rawLogs.map(DeliveryLog.fromMap).toList());
    } catch (e, st) {
      debugPrint('Failed to load delivery logs: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to load delivery logs. Please restart or check logs.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    final totalGallons = logs.fold<int>(
      0,
      (sum, l) => sum + l.quantityDelivered,
    );

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
          ? const LoadingState(
              title: 'Loading delivery logs',
              message: 'Gathering completed deliveries...',
              mascot: MascotPose.checklist,
            )
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- Stats ---
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Deliveries',
                          value: '${logs.length}',
                          valueColor: AppColors.of(context).primary,
                          icon: Icons.local_shipping,
                          iconBgColor: AppColors.of(context).primaryLight,
                          iconColor: AppColors.of(context).primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
                          label: 'Gallons',
                          value: '$totalGallons',
                          valueColor: AppColors.of(context).statusOperating,
                          icon: Icons.water_drop,
                          iconBgColor: AppColors.of(
                            context,
                          ).statusOperatingLight,
                          iconColor: AppColors.of(context).statusOperating,
                        ),
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
                    EmptyState(
                      icon: Icons.receipt_long,
                      mascot: MascotPose.checklist,
                      title: 'No logs yet',
                      message: _filter == 'today'
                          ? 'No deliveries recorded today.'
                          : 'No delivery logs found.',
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
          color: selected
              ? AppColors.of(context).primary
              : AppColors.of(context).muted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : AppColors.of(context).mutedForeground,
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
    final quantityText = '$qty gallon${qty > 1 ? "s" : ""}';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
                  quantityText,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.of(context).mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge(
                  label: 'Delivered',
                  icon: Icons.check,
                  color: AppColors.of(context).statusOperating,
                  bgColor: AppColors.of(context).statusOperatingLight,
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
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final displayHour = hour == 0 ? 12 : hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$displayHour:$minute $period';
    if (isToday) return timeStr;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, $timeStr';
  }
}
