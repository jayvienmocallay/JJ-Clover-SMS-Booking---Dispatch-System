// Task 010 — Settings screen: cutoff time, walk-in alert test, data privacy
// Task 011 — Added barangay list management and editable cutoff time picker
// Cutoff time, walk-in alert test, barangay management, data privacy settings
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../database_helper.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/services/supabase_sync_service.dart';
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
  String? _selectedDay; // Required when _selectedZone == 'Zone C'

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

    if (_selectedZone == 'Zone C' && _selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery day for Zone C')),
      );
      return;
    }

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

    final barangayData = {
      'name': name,
      'delivery_zone': _selectedZone,
      if (_selectedZone == 'Zone C' && _selectedDay != null)
        'delivery_day': _selectedDay,
    };

    await DatabaseHelper.instance.insertBarangay(barangayData);
    _barangayController.clear();
    setState(() => _selectedDay = null);
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barangay removed ✓')),
      );
    }
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

        // --- Cloud Sync ---
        _buildSyncSection(),
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
    final orderProv = context.read<OrderProvider>();
    final customerProv = context.read<CustomerProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: orderProv),
          ChangeNotifierProvider.value(value: customerProv),
        ],
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
                      if (v != null) setState(() { _selectedZone = v; _selectedDay = null; });
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
          if (_selectedZone == 'Zone C') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                const Text(
                  'Delivery day:',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.mutedForeground),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDay == null
                            ? AppColors.statusMaintenance
                            : AppColors.border,
                      ),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedDay,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: AppColors.card,
                      hint: const Text(
                        'Select day...',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground),
                      ),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.foreground),
                      items: [
                        'Monday', 'Tuesday', 'Wednesday',
                        'Thursday', 'Friday', 'Saturday',
                      ]
                          .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (d) =>
                          setState(() => _selectedDay = d),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
                final deliveryDay = b['delivery_day'] as String?;
                final id = b['id'] as int;

                // Build display label
                String label = '$name ($zone';
                if (zone == 'Zone C' && deliveryDay != null) {
                  label += ' · $deliveryDay';
                }
                label += ')';

                return GestureDetector(
                  onTap: () => _showEditBarangaySheet(b),
                  child: Container(
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
                        const Icon(Icons.edit, size: 12, color: AppColors.mutedForeground),
                        const SizedBox(width: 4),
                        Text(
                          label,
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
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Shows a bottom sheet to edit a barangay's zone and delivery day
  void _showEditBarangaySheet(Map<String, dynamic> barangay) {
    final id = barangay['id'] as int;
    final name = barangay['name'] as String;
    String editZone = barangay['delivery_zone'] as String? ?? 'Zone A';
    String? editDay = barangay['delivery_day'] as String?;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Determine which days apply for the selected zone
            List<String> scheduleDays;
            if (editZone == 'Zone A') {
              scheduleDays = ZoneScheduleMap.zoneADays;
            } else if (editZone == 'Zone B') {
              scheduleDays = ZoneScheduleMap.zoneBDays;
            } else if (editZone == 'Zone C' && editDay != null) {
              scheduleDays = [editDay!];
            } else {
              scheduleDays = [];
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
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

                  // Title
                  Text(
                    'Edit $name',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Zone selector
                  const Text(
                    'Delivery Zone',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButton<String>(
                      value: editZone,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: AppColors.card,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                      items: ['Zone A', 'Zone B', 'Zone C']
                          .map((z) =>
                              DropdownMenuItem(value: z, child: Text(z)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() {
                            editZone = v;
                            if (v != 'Zone C') editDay = null;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Day selector (for Zone C)
                  if (editZone == 'Zone C') ...[
                    const Text(
                      'Delivery Day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: editDay == null
                              ? AppColors.statusMaintenance
                              : AppColors.border,
                        ),
                      ),
                      child: DropdownButton<String>(
                        value: editDay,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: AppColors.card,
                        hint: const Text(
                          'Select day...',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.foreground,
                        ),
                        items: [
                          'Monday', 'Tuesday', 'Wednesday',
                          'Thursday', 'Friday', 'Saturday',
                        ]
                            .map((d) =>
                                DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (d) =>
                            setSheetState(() => editDay = d),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Schedule preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Schedule',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: scheduleDays.map((day) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                day,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (scheduleDays.isEmpty)
                          const Text(
                            'Select a delivery day above',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () async {
                        if (editZone == 'Zone C' && editDay == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a delivery day for Zone C'),
                            ),
                          );
                          return;
                        }

                        await DatabaseHelper.instance.updateBarangay(id, {
                          'name': name,
                          'delivery_zone': editZone,
                          'delivery_day': editZone == 'Zone C' ? editDay : null,
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name updated')),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Save Changes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSyncSection() {
    return ChangeNotifierProvider.value(
      value: SupabaseSyncService.instance,
      child: Consumer<SupabaseSyncService>(
        builder: (context, syncService, _) {
          String statusText;
          Color statusColor;
          IconData statusIcon;
          switch (syncService.status) {
            case SyncStatus.idle:
              statusText = 'Idle';
              statusColor = AppColors.mutedForeground;
              statusIcon = Icons.cloud_off;
              break;
            case SyncStatus.syncing:
              statusText = 'Syncing...';
              statusColor = AppColors.primary;
              statusIcon = Icons.cloud_sync;
              break;
            case SyncStatus.success:
              statusText = 'Synced';
              statusColor = AppColors.statusOperating;
              statusIcon = Icons.cloud_done;
              break;
            case SyncStatus.error:
              statusText = 'Error';
              statusColor = AppColors.statusMaintenance;
              statusIcon = Icons.cloud_off;
              break;
          }

          String lastSyncLabel = 'Never';
          if (syncService.lastSyncedAt != null) {
            final dt = syncService.lastSyncedAt!;
            final hour = dt.hour > 12
                ? dt.hour - 12
                : (dt.hour == 0 ? 12 : dt.hour);
            final amPm = dt.hour >= 12 ? 'PM' : 'AM';
            final min = dt.minute.toString().padLeft(2, '0');
            lastSyncLabel = '${dt.month}/${dt.day} $hour:$min $amPm';
          }

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
                      child: const Icon(Icons.cloud_sync,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cloud Sync',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Back up your data to Supabase cloud. '
                            'Data syncs automatically when connected.',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Auto Sync toggle
                _buildSyncToggle(
                  icon: Icons.sync,
                  label: 'Auto Sync',
                  value: syncService.autoSyncEnabled,
                  onChanged: (v) => syncService.setAutoSync(v),
                ),
                const SizedBox(height: 8),

                // WiFi Only toggle
                _buildSyncToggle(
                  icon: Icons.wifi,
                  label: 'Sync over Wi-Fi only',
                  value: syncService.wifiOnly,
                  onChanged: (v) => syncService.setWifiOnly(v),
                ),
                const SizedBox(height: 12),

                // Status row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      syncService.status == SyncStatus.syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                            if (syncService.lastError != null &&
                                syncService.status == SyncStatus.error)
                              Text(
                                syncService.lastError!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.statusMaintenance,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Last sync',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          Text(
                            lastSyncLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Manual sync button
                GestureDetector(
                  onTap: syncService.status == SyncStatus.syncing
                      ? null
                      : () async {
                          await syncService.syncAll();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  syncService.status == SyncStatus.success
                                      ? 'Data synced to cloud ✓'
                                      : 'Sync failed: ${syncService.lastError ?? "Unknown error"}',
                                ),
                              ),
                            );
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: syncService.status == SyncStatus.syncing
                          ? AppColors.muted
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          syncService.status == SyncStatus.syncing
                              ? Icons.hourglass_top
                              : Icons.cloud_upload,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          syncService.status == SyncStatus.syncing
                              ? 'Syncing...'
                              : 'Sync Now',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSyncToggle({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: value ? AppColors.primary : AppColors.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
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
    return Consumer2<OrderProvider, CustomerProvider>(
      builder: (context, orderProv, customerProv, _) {
        final customerCache = <int, Map<String, dynamic>>{};
        for (final c in customerProv.customers) {
          final id = c['id'] as int?;
          if (id != null) customerCache[id] = c;
        }

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
                                Icons.assignment_outlined,
                                size: 48,
                                color: AppColors.mutedForeground,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No confirmed orders yet.',
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
                                    (e) {
                                      final o = e.value;
                                      final cid = o['customer_id'] as int?;
                                      final customerName = cid != null
                                          ? (customerCache[cid]?['name'] as String?)
                                          : null;
                                      return _ManifestItem(
                                        index: e.key + 1,
                                        order: o,
                                        customerName: customerName,
                                        onStart: o['status'] == 'confirmed'
                                            ? () => orderProv.updateStatus(
                                                o['id'] as int,
                                                'in_transit',
                                              )
                                            : null,
                                        onComplete: o['status'] == 'in_transit'
                                            ? () => orderProv.updateStatus(
                                                o['id'] as int,
                                                'completed',
                                              )
                                            : null,
                                      );
                                    },
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
  final String? customerName;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  const _ManifestItem({
    required this.index,
    required this.order,
    this.customerName,
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
                  customerName ?? phone,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (customerName != null)
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
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
