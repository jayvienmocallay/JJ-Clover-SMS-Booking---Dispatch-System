// Task 010 — Settings screen: cutoff time, walk-in alert test, data privacy
// Task 011 — Added barangay list management and editable cutoff time picker
// Cutoff time, walk-in alert test, barangay management, data privacy settings
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/constants/app_constants.dart';
import '../../database_helper.dart';
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
      'delivery_zone': 'Zone A', // Default zone — can be changed later
    });
    _barangayController.clear();
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
      ],
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
