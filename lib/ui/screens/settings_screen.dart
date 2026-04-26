// Task 010 — Settings screen: cutoff time, walk-in alert test, data privacy
// Task 011 — Added barangay list management and editable cutoff time picker
// Cutoff time, walk-in alert test, barangay management, data privacy settings
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../database_helper.dart';
import '../../data/providers/order_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  /// Callback to trigger the walk-in alert overlay for testing
  final VoidCallback? onTestAlert;

  const SettingsScreen({super.key, this.onTestAlert});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _barangayController = TextEditingController();
  List<Map<String, dynamic>> _barangays = [];
  String _selectedZone = 'Zone A';

  // Editable cutoff time - loaded from persisted settings
  int _cutoffHour = AppConstants.orderCutOffHour;
  int _cutoffMinute = AppConstants.orderCutOffMinute;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (kIsWeb) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final barangays = await DatabaseHelper.instance.getBarangays();
    final hour = await DatabaseHelper.instance.getCutoffHour();
    final minute = await DatabaseHelper.instance.getCutoffMinute();
    if (mounted) {
      setState(() {
        _barangays = barangays;
        _cutoffHour = hour;
        _cutoffMinute = minute;
        _isLoading = false;
      });
    }
  }

  Future<void> _addBarangay() async {
    final name = _barangayController.text.trim();
    if (name.isEmpty) return;

    // Check for duplicates
    final exists = _barangays.any(
      (b) => (b['name'] as String).toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barangay already exists')),
      );
      return;
    }

    await DatabaseHelper.instance.insertBarangay({
      'name': name,
      'delivery_zone': _selectedZone,
    });
    _barangayController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added successfully')),
      );
    }
    await _loadData();
  }

  Future<void> _removeBarangay(int id) async {
    await DatabaseHelper.instance.deleteBarangay(id);
    await _loadData();
  }

  void _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _cutoffHour, minute: _cutoffMinute),
      helpText: 'SET ORDER CUT-OFF TIME',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.card,
              onSurface: AppColors.foreground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await DatabaseHelper.instance.setCutoffTime(picked.hour, picked.minute);
      setState(() {
        _cutoffHour = picked.hour;
        _cutoffMinute = picked.minute;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cut-off time updated to ${_formatCutoffTime()}',
            ),
          ),
        );
      }
    }
  }

  String _formatCutoffTime() {
    final hour = _cutoffHour > 12
        ? _cutoffHour - 12
        : (_cutoffHour == 0 ? 12 : _cutoffHour);
    final amPm = _cutoffHour >= 12 ? 'PM' : 'AM';
    return '$hour:${_cutoffMinute.toString().padLeft(2, '0')} $amPm';
  }

  @override
  void dispose() {
    _barangayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Header ---
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Configure your station's dispatch rules.",
          style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 24),

        // --- Cut-off Time (editable) ---
        _buildSettingCard(
          icon: Icons.schedule,
          iconBgColor: AppColors.primaryLight,
          iconColor: AppColors.primary,
          title: 'Order Cut-off Time',
          description: "Orders received before this time are added to today's "
              "dispatch. Orders after will be queued for the next trip.",
          trailing: GestureDetector(
            onTap: _showTimePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatCutoffTime(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit, size: 14, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- Walk-in Alert Test ---
        _buildSettingCard(
          icon: Icons.notifications_active,
          iconBgColor: AppColors.statusAwayLight,
          iconColor: AppColors.statusAway,
          title: 'Walk-in Alert',
          description: 'When a customer sends a DROP command, a loud alert '
              'will appear on screen until staff acknowledges it.',
          trailing: GestureDetector(
            onTap: widget.onTestAlert,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.statusAway,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Test Alert',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- Barangay List Management ---
        _buildBarangaySection(),
        const SizedBox(height: 16),

        // --- Data Privacy ---
        _buildSettingCard(
          icon: Icons.shield,
          iconBgColor: AppColors.statusOperatingLight,
          iconColor: AppColors.statusOperating,
          title: 'Data Privacy',
          description: 'All customer data is stored locally and encrypted. '
              'No internet connection required for operation.',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.statusOperatingLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, size: 12, color: AppColors.statusOperating),
                SizedBox(width: 4),
                Text(
                  'Encrypted & Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.statusOperating,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- Delivery Manifest ---
        _buildSettingCard(
          icon: Icons.assignment,
          iconBgColor: AppColors.statusOperatingLight,
          iconColor: AppColors.statusOperating,
          title: 'Delivery Manifest',
          description: 'View confirmed orders ready for delivery grouped by day.',
          trailing: GestureDetector(
            onTap: _showDeliveryManifest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.statusOperating,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'View Manifest',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showDeliveryManifest() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<OrderProvider>(),
        child: const _DeliveryManifestSheet(),
      ),
    );
  }

  /// Builds the Barangay List management section
  Widget _buildBarangaySection() {
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
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_city,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Barangay List',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage the barangays available for customer registration and delivery scheduling.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Add barangay input
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _barangayController,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.foreground),
                    onSubmitted: (_) => _addBarangay(),
                    decoration: const InputDecoration(
                      hintText: 'e.g., Barangay San Miguel',
                      hintStyle: TextStyle(color: AppColors.mutedForeground),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Zone selector dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedZone,
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 13, color: AppColors.foreground),
                    dropdownColor: AppColors.card,
                    items: ['Zone A', 'Zone B', 'Zone C']
                        .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedZone = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addBarangay,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barangay chips with remove buttons
          if (_barangays.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No barangays added yet.',
                style:
                    TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _barangays.map((b) {
                final name = b['name'] as String;
                final zone = b['delivery_zone'] as String? ?? '';
                final id = b['id'] as int;
                return Container(
                  padding: const EdgeInsets.only(
                      left: 12, top: 6, bottom: 6, right: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$name ($zone)',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.foreground),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _removeBarangay(id),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.muted,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 12, color: AppColors.mutedForeground),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Builds a consistent settings card
  Widget _buildSettingCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String description,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Setting icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          // Title, description, and trailing widget
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 12),
                  trailing,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Delivery Manifest - shows confirmed orders ready for delivery grouped by day
class _DeliveryManifestSheet extends StatelessWidget {
  const _DeliveryManifestSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProv, _) {
        final confirmed = orderProv.todayOrders
            .where(
              (o) => o['status'] == 'confirmed' || o['status'] == 'in_transit',
            )
            .toList();

        final Map<String, List<Map<String, dynamic>>> byDay = {};
        for (final o in confirmed) {
          final day = o['delivery_day'] as String? ?? 'Today';
          byDay[day] ??= [];
          byDay[day]!.add(o);
        }

        final totalOrders = confirmed.length;
        final totalGallons = confirmed.fold<int>(
          0,
          (sum, o) => sum + ((o['quantity'] as int?) ?? 0),
        );

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.assignment, color: AppColors.primary),
                      SizedBox(width: 12),
                      Text(
                        'Delivery Manifest',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _SummaryChip(
                        label: '$totalOrders',
                        sub: 'orders',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      _SummaryChip(
                        label: '$totalGallons',
                        sub: 'gallons',
                        color: AppColors.statusOperating,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: confirmed.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 48,
                                color: AppColors.statusOperating,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'All deliveries completed!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            ...byDay.entries.map(
                              (entry) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...entry.value.asMap().entries.map(
                                    (e) => _ManifestItem(
                                      index: e.key + 1,
                                      order: e.value,
                                      onStart: e.value['status'] == 'confirmed'
                                          ? () => orderProv.updateStatus(
                                              e.value['id'] as int,
                                              'in_transit',
                                            )
                                          : null,
                                      onComplete:
                                          e.value['status'] == 'in_transit'
                                          ? () => orderProv.updateStatus(
                                              e.value['id'] as int,
                                              'completed',
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(sub, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ManifestItem extends StatelessWidget {
  final int index;
  final Map<String, dynamic> order;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  const _ManifestItem({
    required this.index,
    required this.order,
    this.onStart,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final phone = order['phone_number'] as String? ?? '';
    final qty = order['quantity'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'in_transit'
              ? AppColors.statusBusy
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phone,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$qty gallon(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'in_transit'
                  ? AppColors.statusBusy
                  : AppColors.statusOperating,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status == 'in_transit' ? 'Delivering' : 'Ready',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          if (onStart != null || onComplete != null) ...[
            const SizedBox(width: 8),
            if (onStart != null)
              GestureDetector(
                onTap: onStart,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.statusBusy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            if (onComplete != null)
              GestureDetector(
                onTap: onComplete,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.statusOperating,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
