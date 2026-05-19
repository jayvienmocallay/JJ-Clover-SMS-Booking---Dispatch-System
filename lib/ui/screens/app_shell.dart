// Task 010 — App shell with bottom navigation and walk-in alert overlay
// Task 011 — Added tab navigation callback for child screens
// App shell with bottom navigation and walk-in alert overlay
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/customer_provider.dart';
import '../../data/services/alarm_service.dart';
import '../../data/services/app_event_bus.dart';
import '../../data/services/command_handlers/sms_handler_utils.dart';
import '../../data/services/system_mode_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/shared/brand_mascot.dart';
import '../widgets/shared/loading_state.dart';
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
  int _currentIndex = 0;
  int _ordersFilterIndex = 0;
  final List<int> _tabHistory = [];
  bool _showWalkInAlert = false;
  bool _isInitialLoading = true;
  bool _isAutoRefreshing = false;
  bool _autoRefreshPending = false;
  Timer? _autoRefreshTimer;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _orderSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInitialData();
      });
    } else {
      _isInitialLoading = false;
    }

    _messageSubscription = AppEventBus().onMessageReceived.listen((_) {
      unawaited(_autoRefresh());
    });

    _orderSubscription = AppEventBus().onOrderReceived.listen((_) {
      unawaited(_autoRefresh());
    });

    if (!kIsWeb) {
      _autoRefreshTimer = Timer.periodic(
        const Duration(seconds: AppConstants.autoRefreshSeconds),
        (_) => unawaited(_autoRefresh()),
      );
    }

    AlarmService.instance.addListener(_onAlarmChanged);
    unawaited(AlarmService.instance.startUiSync());
  }

  Future<void> _loadInitialData() async {
    final orderProv = context.read<OrderProvider>();
    final customerProv = context.read<CustomerProvider>();
    await orderProv.loadOrders();
    await customerProv.loadCustomers();
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  void _onAlarmChanged() {
    if (mounted) {
      setState(() {
        _showWalkInAlert = AlarmService.instance.isPlaying;
      });
    }
  }

  Future<void> _autoRefresh() async {
    if (!mounted || kIsWeb) return;
    if (_isAutoRefreshing) {
      _autoRefreshPending = true;
      return;
    }

    _isAutoRefreshing = true;
    try {
      await Future.wait([
        context.read<OrderProvider>().loadOrders(),
        context.read<CustomerProvider>().loadCustomers(),
        AlarmService.instance.syncPendingAlert(),
      ]);
    } finally {
      _isAutoRefreshing = false;
      if (_autoRefreshPending && mounted) {
        _autoRefreshPending = false;
        unawaited(_autoRefresh());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      unawaited(_autoRefresh());
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _messageSubscription?.cancel();
    _orderSubscription?.cancel();
    AlarmService.instance.removeListener(_onAlarmChanged);
    AlarmService.instance.stopUiSync();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _navigateToTab(int index, {int? ordersFilterIndex}) {
    if (ordersFilterIndex != null) {
      _ordersFilterIndex = ordersFilterIndex;
    }
    if (_currentIndex == index) {
      if (ordersFilterIndex != null) setState(() {});
      return;
    }
    _setTab(index);
  }

  void _setTab(int index) {
    if (_currentIndex == index) return;
    if (_tabHistory.isEmpty || _tabHistory.last != _currentIndex) {
      _tabHistory.add(_currentIndex);
    }
    setState(() => _currentIndex = index);
  }

  bool get _canPopApp => _tabHistory.isEmpty && _currentIndex == 0;

  void _handleBackNavigation() {
    if (_tabHistory.isNotEmpty) {
      final lastIndex = _tabHistory.removeLast();
      setState(() => _currentIndex = lastIndex);
      return;
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
  }

  Future<void> _acknowledgeWalkInAlert() async {
    final alarm = AlarmService.instance;
    final phone = alarm.customerPhone;
    final reply =
        alarm.replyMessage ?? SystemModeManager.instance.getDropReply();

    if (mounted) {
      setState(() => _showWalkInAlert = false);
    }
    await alarm.acknowledge();

    if (!_canSendWalkInAcknowledgement(phone)) return;
    await SmsHandlerUtils.sendReply(phone!, reply);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Walk-in acknowledged. Customer SMS notification queued.',
        ),
      ),
    );
  }

  bool _canSendWalkInAcknowledgement(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    return RegExp(r'\d').hasMatch(phone);
  }

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard, label: 'Home'),
    _NavItem(icon: Icons.list_alt, label: 'Orders'),
    _NavItem(icon: Icons.message, label: 'Messages'),
    _NavItem(icon: Icons.people, label: 'Customers'),
    _NavItem(icon: Icons.settings, label: 'Settings'),
  ];

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return DashboardScreen(onNavigateToTab: _navigateToTab);
      case 1:
        return OrdersScreen(
          initialFilterIndex: _ordersFilterIndex,
          onFilterChanged: (index) => _ordersFilterIndex = index,
        );
      case 2:
        return const MessagesScreen();
      case 3:
        return const CustomersScreen();
      case 4:
        return SettingsScreen(
          onTestAlert: () =>
              AlarmService.instance.trigger(phone: 'TEST MODE', qty: 5),
        );
      default:
        return DashboardScreen(onNavigateToTab: _navigateToTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: const LoadingState(
          title: 'JJ Clover',
          message: "Preparing today's dispatch board...",
          mascot: MascotPose.waterBottle,
        ),
      );
    }

    return PopScope(
      canPop: _canPopApp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: Stack(
          children: [
            SafeArea(child: _buildScreen()),
            if (_showWalkInAlert)
              WalkInAlert(
                onAcknowledge: () {
                  unawaited(_acknowledgeWalkInAlert());
                },
              ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.of(context).border),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _setTab,
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.of(context).card,
              selectedItemColor: AppColors.of(context).primary,
              unselectedItemColor: AppColors.of(context).mutedForeground,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              iconSize: 22,
              items: _navItems
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
