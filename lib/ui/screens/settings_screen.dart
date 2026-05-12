import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/barangay_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/services/supabase_sync_service.dart';
import '../theme/app_theme.dart';
import 'package:jj_clover_sms/main.dart' show setThemeMode, themeNotifier;

// ─────────────────────────────────────────────
// Main Settings Screen (inline + nav for Data/About)
// ─────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onTestAlert;

  const SettingsScreen({super.key, this.onTestAlert});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _barangayController = TextEditingController();
  List<Map<String, dynamic>> _barangays = [];
  final Set<String> _selectedDays = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'};

  int _cutoffHour = AppConstants.orderCutOffHour;
  int _cutoffMinute = AppConstants.orderCutOffMinute;
  bool _isLoading = true;
  late final BarangayRepository _barangayRepo;
  late final SettingsRepository _settingsRepo;

  @override
  void initState() {
    super.initState();
    _barangayRepo = context.read<BarangayRepository>();
    _settingsRepo = context.read<SettingsRepository>();
    _loadData();
  }

  Future<void> _loadData() async {
    if (kIsWeb) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final barangays = await _barangayRepo.getBarangays();
      final hour = await _settingsRepo.getCutoffHour();
      final minute = await _settingsRepo.getCutoffMinute();
      if (mounted) {
        setState(() {
          _barangays = barangays;
          _cutoffHour = hour;
          _cutoffMinute = minute;
        });
      }
    } catch (e, st) {
      debugPrint('Failed to load settings: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load settings. Please restart or check logs.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _allWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  static const _dayAbbr = {
    'Monday': 'Mon', 'Tuesday': 'Tue', 'Wednesday': 'Wed',
    'Thursday': 'Thu', 'Friday': 'Fri', 'Saturday': 'Sat',
  };

  // Convert selected days set → zone + delivery_day for DB storage
  static ({String zone, String? deliveryDay}) _daysToZone(Set<String> days) {
    final sorted = _allWeekdays.where(days.contains).toList();
    if (sorted.length == 6) return (zone: 'Zone A', deliveryDay: null);
    if (sorted.length == 3 && days.containsAll(['Monday', 'Wednesday', 'Friday']) && sorted.length == 3) {
      return (zone: 'Zone B', deliveryDay: null);
    }
    return (zone: 'Zone C', deliveryDay: sorted.join(','));
  }

  // Convert zone + delivery_day from DB → selected days set
  static Set<String> _zoneToDays(String zone, String? deliveryDay) {
    if (zone == 'Zone A') return Set.of(_allWeekdays);
    if (zone == 'Zone B') return {'Monday', 'Wednesday', 'Friday'};
    if (deliveryDay != null) {
      return deliveryDay.split(',').map((d) => d.trim()).toSet();
    }
    return {};
  }

  String _formatDaysLabel(Set<String> days) {
    if (days.length == 6) return 'Every day';
    final sorted = _allWeekdays.where(days.contains).map((d) => _dayAbbr[d] ?? d);
    return sorted.join(', ');
  }

  Future<void> _addBarangay() async {
    final name = _barangayController.text.trim();
    if (name.isEmpty) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one delivery day')),
      );
      return;
    }
    final exists = _barangays.any(
      (b) => (b['name'] as String).toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barangay already exists')),
      );
      return;
    }
    final zoneData = _daysToZone(_selectedDays);
    await _barangayRepo.insertBarangay({
      'name': name,
      'delivery_zone': zoneData.zone,
      if (zoneData.deliveryDay != null) 'delivery_day': zoneData.deliveryDay,
    });
    _barangayController.clear();
    setState(() => _selectedDays
      ..clear()
      ..addAll(_allWeekdays));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added successfully')));
    }
    await _loadData();
  }

  Future<void> _removeBarangay(int id) async {
    await _barangayRepo.deleteBarangay(id);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barangay removed ✓')));
    }
  }

  Future<void> _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _cutoffHour, minute: _cutoffMinute),
      helpText: 'SET ORDER CUT-OFF TIME',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.of(context).primary,
            onPrimary: Colors.white,
            surface: AppColors.of(context).card,
            onSurface: AppColors.of(context).foreground,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      await _settingsRepo.setCutoffTime(picked.hour, picked.minute);
      setState(() {
        _cutoffHour = picked.hour;
        _cutoffMinute = picked.minute;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cut-off time updated to ${_formatCutoffTime()}')),
        );
      }
    }
  }

  String _formatCutoffTime() {
    final hour = _cutoffHour > 12 ? _cutoffHour - 12 : (_cutoffHour == 0 ? 12 : _cutoffHour);
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
      return Center(child: CircularProgressIndicator(color: AppColors.of(context).primary));
    }

    final palette = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Text(
                'Settings',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 26),
              ),
            ),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, mode, _) => IconButton(
                onPressed: () async {
                  final nextMode = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                  await setThemeMode(nextMode);
                },
                icon: Icon(
                  mode == ThemeMode.light ? Icons.light_mode : Icons.dark_mode,
                  color: palette.mutedForeground,
                ),
                tooltip: mode == ThemeMode.light ? 'Switch to dark' : 'Switch to light',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Configure your station's dispatch rules.",
          style: TextStyle(fontSize: 14, color: palette.mutedForeground),
        ),
        const SizedBox(height: 24),

        // Order Cut-off Time
        _settingCard(
          context,
          icon: Icons.schedule,
          iconBgColor: palette.primaryLight,
          iconColor: palette.primary,
          title: 'Order Cut-off Time',
          description: "Orders received before this time are added to today's "
              "dispatch. Orders after will be queued for the next trip.",
          trailing: GestureDetector(
            onTap: _showTimePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: palette.muted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatCutoffTime(),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.foreground),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.edit, size: 14, color: palette.primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Walk-in Alert
        _settingCard(
          context,
          icon: Icons.notifications_active,
          iconBgColor: palette.statusAwayLight,
          iconColor: palette.statusAway,
          title: 'Walk-in Alert',
          description: 'When a customer sends a DROP command, a loud alert '
              'will appear on screen until staff acknowledges it.',
          trailing: GestureDetector(
            onTap: widget.onTestAlert,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: palette.statusAway,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Test Alert',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Barangay List
        _buildBarangaySection(),
        const SizedBox(height: 16),

        // Delivery Manifest
        _settingCard(
          context,
          icon: Icons.assignment,
          iconBgColor: palette.statusOperatingLight,
          iconColor: palette.statusOperating,
          title: 'Delivery Manifest',
          description: 'View confirmed orders ready for delivery grouped by day.',
          trailing: GestureDetector(
            onTap: _showDeliveryManifest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: palette.statusOperating,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'View Manifest',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Data & Cloud Sync → nav tile
        _SettingsNavItem(
          icon: Icons.cloud_sync_outlined,
          iconColor: palette.primary,
          title: 'Data & Cloud Sync',
          subtitle: 'Backup data, sync settings',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _DataSyncPage()),
          ),
        ),

        // About → nav tile
        _SettingsNavItem(
          icon: Icons.info_outline,
          iconColor: palette.primary,
          title: 'About',
          subtitle: 'App version and system info',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _AboutPage()),
          ),
        ),
      ],
    );
  }

  void _showDeliveryManifest() {
    final orderProv = context.read<OrderProvider>();
    final customerProv = context.read<CustomerProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).card,
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

  Widget _buildBarangaySection() {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: palette.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.location_city, size: 20, color: palette.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Barangay List', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.foreground)),
                    const SizedBox(height: 4),
                    Text(
                      'Manage the barangays available for customer registration and delivery scheduling.',
                      style: TextStyle(fontSize: 13, color: palette.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.border),
                  ),
                  child: TextField(
                    controller: _barangayController,
                    style: TextStyle(fontSize: 14, color: palette.foreground),
                    onSubmitted: (_) => _addBarangay(),
                    decoration: InputDecoration(
                      hintText: 'e.g., Barangay San Miguel',
                      hintStyle: TextStyle(color: palette.mutedForeground),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addBarangay,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: palette.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Day selection chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _allWeekdays.map((day) {
              final selected = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? palette.primary : palette.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? palette.primary : palette.border),
                  ),
                  child: Text(
                    _dayAbbr[day] ?? day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : palette.mutedForeground,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (_barangays.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No barangays added yet.', style: TextStyle(fontSize: 13, color: palette.mutedForeground)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _barangays.map((b) {
                final name = b['name'] as String;
                final zone = b['delivery_zone'] as String? ?? 'Zone A';
                final deliveryDay = b['delivery_day'] as String?;
                final id = b['id'] as int;
                final days = _zoneToDays(zone, deliveryDay);
                final label = '$name (${_formatDaysLabel(days)})';
                return GestureDetector(
                  onTap: () => _showEditBarangaySheet(b),
                  child: Container(
                    padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6, right: 4),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 12, color: palette.mutedForeground),
                        const SizedBox(width: 4),
                        Text(label, style: TextStyle(fontSize: 12, color: palette.foreground)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeBarangay(id),
                          child: Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(color: palette.muted, shape: BoxShape.circle),
                            child: Icon(Icons.close, size: 12, color: palette.mutedForeground),
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

  void _showEditBarangaySheet(Map<String, dynamic> barangay) {
    final id = barangay['id'] as int;
    final name = barangay['name'] as String;
    final zone = barangay['delivery_zone'] as String? ?? 'Zone A';
    final deliveryDay = barangay['delivery_day'] as String?;
    final editDays = _zoneToDays(zone, deliveryDay);
    final palette = AppColors.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: palette.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Edit $name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: palette.foreground)),
                  const SizedBox(height: 4),
                  Text('Select which days this barangay receives deliveries.', style: TextStyle(fontSize: 13, color: palette.mutedForeground)),
                  const SizedBox(height: 16),
                  // Day chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allWeekdays.map((day) {
                      final selected = editDays.contains(day);
                      return GestureDetector(
                        onTap: () => setSheetState(() {
                          if (selected) { editDays.remove(day); } else { editDays.add(day); }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? palette.primary : palette.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? palette.primary : palette.border),
                          ),
                          child: Text(
                            _dayAbbr[day] ?? day,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : palette.mutedForeground,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (editDays.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Select at least one day', style: TextStyle(fontSize: 12, color: palette.statusMaintenance, fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: editDays.isEmpty ? null : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final zoneData = _daysToZone(editDays);
                        await _barangayRepo.updateBarangay(id, {
                          'name': name,
                          'delivery_zone': zoneData.zone,
                          'delivery_day': zoneData.deliveryDay,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadData();
                        if (!mounted) return;
                        messenger.showSnackBar(SnackBar(content: Text('$name updated')));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: editDays.isEmpty ? palette.muted : palette.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Save Changes',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: editDays.isEmpty ? palette.mutedForeground : Colors.white),
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
}

// ─────────────────────────────────────────────
// Nav item widget (used for Data & Cloud + About)
// ─────────────────────────────────────────────

class _SettingsNavItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsNavItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.foreground)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: palette.mutedForeground)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.mutedForeground, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Data & Cloud Sync sub-page
// ─────────────────────────────────────────────

class _DataSyncPage extends StatelessWidget {
  const _DataSyncPage();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data & Cloud Sync'),
        backgroundColor: palette.card,
        foregroundColor: palette.foreground,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: palette.border),
        ),
      ),
      backgroundColor: palette.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSyncSection(context),
          const SizedBox(height: 16),
          _settingCard(
            context,
            icon: Icons.shield,
            iconBgColor: palette.statusOperatingLight,
            iconColor: palette.statusOperating,
            title: 'Data Privacy',
            description: 'Customer data is stored locally with encryption. '
                'When Cloud Sync is enabled, data is backed up to Supabase. '
                'Deletion requests (RA 10173) propagate to cloud.',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: palette.statusOperatingLight, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield, size: 12, color: palette.statusOperating),
                  const SizedBox(width: 4),
                  Text('Encrypted & RA 10173', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.statusOperating)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSection(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: SupabaseSyncService.instance,
      child: Consumer<SupabaseSyncService>(
        builder: (context, syncService, _) {
          final palette = AppColors.of(context);
          String statusText;
          Color statusColor;
          IconData statusIcon;
          switch (syncService.status) {
            case SyncStatus.idle:
              statusText = 'Idle'; statusColor = palette.mutedForeground; statusIcon = Icons.cloud_off;
              break;
            case SyncStatus.syncing:
              statusText = 'Syncing...'; statusColor = palette.primary; statusIcon = Icons.cloud_sync;
              break;
            case SyncStatus.success:
              statusText = 'Synced'; statusColor = palette.statusOperating; statusIcon = Icons.cloud_done;
              break;
            case SyncStatus.error:
              statusText = 'Error'; statusColor = palette.statusMaintenance; statusIcon = Icons.cloud_off;
              break;
          }

          String lastSyncLabel = 'Never';
          if (syncService.lastSyncedAt != null) {
            final dt = syncService.lastSyncedAt!;
            final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
            final amPm = dt.hour >= 12 ? 'PM' : 'AM';
            final min = dt.minute.toString().padLeft(2, '0');
            lastSyncLabel = '${dt.month}/${dt.day} $hour:$min $amPm';
          }

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: palette.primaryLight, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.cloud_sync, size: 20, color: palette.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cloud Sync', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.foreground)),
                          const SizedBox(height: 4),
                          Text('Back up your data to Supabase cloud. Data syncs automatically when connected.', style: TextStyle(fontSize: 13, color: palette.mutedForeground)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _syncToggle(context, Icons.sync, 'Auto Sync', syncService.autoSyncEnabled, syncService.setAutoSync),
                const SizedBox(height: 8),
                _syncToggle(context, Icons.wifi, 'Sync over Wi-Fi only', syncService.wifiOnly, syncService.setWifiOnly),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      syncService.status == SyncStatus.syncing
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary))
                          : Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(statusText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor)),
                            if (syncService.lastError != null && syncService.status == SyncStatus.error)
                              Text(syncService.lastError!, style: TextStyle(fontSize: 11, color: palette.statusMaintenance), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Last sync', style: TextStyle(fontSize: 10, color: palette.mutedForeground)),
                          Text(lastSyncLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.foreground)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: syncService.status == SyncStatus.syncing
                      ? null
                      : () async {
                          await syncService.syncAll();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(
                                syncService.status == SyncStatus.success
                                    ? 'Data synced to cloud ✓'
                                    : 'Sync failed: ${syncService.lastError ?? "Unknown error"}',
                              )),
                            );
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: syncService.status == SyncStatus.syncing ? palette.muted : palette.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(syncService.status == SyncStatus.syncing ? Icons.hourglass_top : Icons.cloud_upload, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          syncService.status == SyncStatus.syncing ? 'Syncing...' : 'Sync Now',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
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

  Widget _syncToggle(BuildContext context, IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: value ? palette.primary : palette.mutedForeground),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.foreground))),
          Switch(value: value, activeThumbColor: palette.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// About sub-page
// ─────────────────────────────────────────────

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: palette.card,
        foregroundColor: palette.foreground,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: palette.border),
        ),
      ),
      backgroundColor: palette.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _settingCard(
            context,
            icon: Icons.water_drop,
            iconBgColor: palette.primaryLight,
            iconColor: palette.primary,
            title: 'JJ Clover',
            description: 'SMS Booking & Dispatch System\nVersion 1.0.0',
          ),
          const SizedBox(height: 12),
          _settingCard(
            context,
            icon: Icons.phone_android,
            iconBgColor: palette.muted,
            iconColor: palette.mutedForeground,
            title: 'System Info',
            description: 'Built with Flutter. Powered by Supabase for cloud sync and SQLite for local storage.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────

Widget _settingCard(
  BuildContext context, {
  required IconData icon,
  required Color iconBgColor,
  required Color iconColor,
  required String title,
  required String description,
  Widget? trailing,
}) {
  final palette = AppColors.of(context);
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: palette.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.foreground)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(fontSize: 13, color: palette.mutedForeground)),
              if (trailing != null) ...[const SizedBox(height: 12), trailing],
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// Delivery Manifest sheet
// ─────────────────────────────────────────────

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
            .where((o) => o['status'] == 'confirmed' || o['status'] == 'in_transit')
            .toList();

        final Map<String, List<Map<String, dynamic>>> byDay = {};
        for (final o in confirmed) {
          final day = o['delivery_day'] as String? ?? 'Today';
          byDay[day] ??= [];
          byDay[day]!.add(o);
        }

        final totalOrders = confirmed.length;
        final totalGallons = confirmed.fold<int>(0, (sum, o) => sum + ((o['quantity'] as int?) ?? 0));

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: AppColors.of(context).card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.of(context).border, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.assignment, color: AppColors.of(context).primary),
                      const SizedBox(width: 12),
                      Text('Delivery Manifest', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.of(context).foreground)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _SummaryChip(label: '$totalOrders', sub: 'orders', color: AppColors.of(context).primary),
                      const SizedBox(width: 8),
                      _SummaryChip(label: '$totalGallons', sub: 'gallons', color: AppColors.of(context).statusOperating),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: confirmed.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_outlined, size: 48, color: AppColors.of(context).mutedForeground),
                              const SizedBox(height: 12),
                              Text('No confirmed orders yet.', style: TextStyle(fontSize: 14, color: AppColors.of(context).mutedForeground)),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            ...byDay.entries.map((entry) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: AppColors.of(context).primary, borderRadius: BorderRadius.circular(8)),
                                  child: Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                ),
                                const SizedBox(height: 8),
                                ...entry.value.asMap().entries.map((e) {
                                  final o = e.value;
                                  final cid = o['customer_id'] as int?;
                                  final customerName = cid != null ? (customerCache[cid]?['name'] as String?) : null;
                                  return _ManifestItem(
                                    index: e.key + 1,
                                    order: o,
                                    customerName: customerName,
                                    onStart: o['status'] == 'confirmed' ? () => orderProv.updateStatus(o['id'] as int, 'in_transit') : null,
                                    onComplete: o['status'] == 'in_transit' ? () => orderProv.updateStatus(o['id'] as int, 'completed') : null,
                                  );
                                }),
                                const SizedBox(height: 16),
                              ],
                            )),
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

  const _SummaryChip({required this.label, required this.sub, required this.color});

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
            Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
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
    final palette = AppColors.of(context);
    final status = order['status'] as String? ?? '';
    final phone = order['phone_number'] as String? ?? '';
    final qty = order['quantity'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status == 'in_transit' ? palette.statusBusy : palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: palette.muted, shape: BoxShape.circle),
            child: Center(child: Text('$index', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customerName ?? phone, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (customerName != null) Text(phone, style: TextStyle(fontSize: 11, color: palette.mutedForeground)),
                Text('$qty gallon(s)', style: TextStyle(fontSize: 12, color: palette.mutedForeground)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'in_transit' ? palette.statusBusy : palette.statusOperating,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status == 'in_transit' ? 'Delivering' : 'Ready', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
          if (onStart != null || onComplete != null) ...[
            const SizedBox(width: 8),
            if (onStart != null)
              GestureDetector(
                onTap: onStart,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: palette.statusBusy, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                ),
              ),
            if (onComplete != null)
              GestureDetector(
                onTap: onComplete,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: palette.statusOperating, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
