// Task 010 — App shell with bottom navigation and walk-in alert overlay
// Task 011 — Added tab navigation callback for child screens
// App shell with bottom navigation and walk-in alert overlay
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/services/alarm_service.dart';
import '../theme/app_theme.dart';
import '../widgets/walk_in_alert.dart';
import 'dashboard_screen.dart';
import 'orders_screen.dart';
import 'messages_screen.dart';
import 'customers_screen.dart';
import 'settings_screen.dart';

/// Main app shell that wraps the active screen with bottom navigation
/// and an optional walk-in alert overlay.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  // Current tab index (0=Home, 1=Orders, 2=Messages, 3=Customers, 4=Settings)
  int _currentIndex = 0;

  // Controls visibility of the walk-in alert overlay (for manual test)
  bool _showWalkInAlert = false;

  // Task 011 — Periodic refresh timer for auto-updating when background
  // service inserts new orders via SMS
  late final _refreshTimer = !kIsWeb
      ? Stream.periodic(
          const Duration(seconds: 15),
        ).listen((_) => _autoRefresh())
      : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Task 011 — Initial data load for providers (skip on web)
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<OrderProvider>().loadOrders();
        context.read<CustomerProvider>().loadCustomers();
      });
    }
    // Task 012 — Listen to AlarmService for DROP command alerts
    AlarmService.instance.addListener(_onAlarmChanged);
    unawaited(AlarmService.instance.startUiSync());
  }

  /// Task 012 — Reacts to alarm state changes from the background service
  void _onAlarmChanged() {
    if (mounted) {
      setState(() {
        _showWalkInAlert = AlarmService.instance.isPlaying;
      });
    }
  }

  /// Task 011 — Auto-refresh order and customer data
  void _autoRefresh() {
    if (!mounted || kIsWeb) return;
    context.read<OrderProvider>().loadOrders();
    context.read<CustomerProvider>().loadCustomers();
    unawaited(AlarmService.instance.syncPendingAlert());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      unawaited(AlarmService.instance.syncPendingAlert());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    AlarmService.instance.removeListener(_onAlarmChanged);
    AlarmService.instance.stopUiSync();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Navigates to a specific tab by index
  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  /// Navigation items for bottom nav bar
  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard, label: 'Home'),
    _NavItem(icon: Icons.list_alt, label: 'Orders'),
    _NavItem(icon: Icons.message, label: 'Messages'),
    _NavItem(icon: Icons.people, label: 'Customers'),
    _NavItem(icon: Icons.settings, label: 'Settings'),
  ];

  /// Builds the current screen based on tab index
  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return DashboardScreen(onNavigateToTab: _navigateToTab);
      case 1:
        return const OrdersScreen();
      case 2:
        return const MessagesScreen();
      case 3:
        return const CustomersScreen();
      case 4:
        return SettingsScreen(
          // Task 012 — Test alert triggers AlarmService like a real DROP
          onTestAlert: () =>
              AlarmService.instance.trigger(phone: 'Test Alert', qty: 5),
        );
      default:
        return DashboardScreen(onNavigateToTab: _navigateToTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Stack allows the walk-in alert to overlay on top of the active screen
      body: Stack(
        children: [
          SafeArea(child: _buildScreen()),
          // Walk-in alert overlay — shown on top of everything
          // Triggered by DROP commands or the Test Alert button in Settings
          if (_showWalkInAlert)
            WalkInAlert(
              onAcknowledge: () {
                unawaited(AlarmService.instance.acknowledge());
                setState(() => _showWalkInAlert = false);
              },
            ),
        ],
      ),
      // Bottom navigation bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final isActive = _currentIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple data class for navigation items
class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
