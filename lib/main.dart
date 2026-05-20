// Task 002 — App entry point with runtime permission gate
// Task 003 — Database initialization on startup
// Task 009 — Start SMS background service after permissions granted
// Task 010 — Full dashboard UI with Provider state management
// Task 011 — Provider/MultiProvider setup for real-time UI
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:jj_clover_sms/data/services/default_sms_app_service.dart';
import 'package:jj_clover_sms/data/services/sms_background_service.dart';
import 'package:jj_clover_sms/data/services/system_mode_manager.dart';
import 'package:jj_clover_sms/data/services/push_notification_service.dart';
import 'package:jj_clover_sms/data/services/supabase_sync_service.dart';
import 'package:jj_clover_sms/core/constants/supabase_config.dart';
import 'package:jj_clover_sms/data/providers/order_provider.dart';
import 'package:jj_clover_sms/data/repositories/order_repository.dart';
import 'package:jj_clover_sms/data/repositories/customer_repository.dart';
import 'package:jj_clover_sms/data/repositories/barangay_repository.dart';
import 'package:jj_clover_sms/data/repositories/sms_message_repository.dart';
import 'package:jj_clover_sms/data/repositories/settings_repository.dart';
import 'package:jj_clover_sms/data/repositories/delivery_log_repository.dart';
import 'package:jj_clover_sms/data/repositories/database_runtime_repository.dart';
import 'package:jj_clover_sms/core/security/admin_auth_service.dart';
import 'package:jj_clover_sms/data/repositories/admin_credential_repository.dart';
import 'package:jj_clover_sms/data/repositories/audit_log_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jj_clover_sms/data/providers/customer_provider.dart';
import 'package:jj_clover_sms/ui/theme/app_theme.dart';
import 'package:jj_clover_sms/ui/screens/app_shell.dart';
import 'package:jj_clover_sms/ui/widgets/shared/brand_mascot.dart';

/// Global theme mode — toggled from Settings screen.
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

const String _themeModeSettingKey = 'theme_mode';

/// Loads the saved light/dark preference before the first frame renders.
Future<void> loadPersistedThemeMode() async {
  if (kIsWeb) return;

  try {
    final savedMode = await SettingsRepository().getSetting(
      _themeModeSettingKey,
    );
    themeNotifier.value = _parseThemeMode(savedMode);
  } catch (e) {
    debugPrint('Failed to load theme mode: $e');
  }
}

/// Updates the app theme and persists the choice for the next launch.
Future<void> setThemeMode(ThemeMode mode) async {
  themeNotifier.value = mode;

  if (kIsWeb) return;

  try {
    await SettingsRepository().setSetting(_themeModeSettingKey, mode.name);
  } catch (e) {
    debugPrint('Failed to persist theme mode: $e');
  }
}

ThemeMode _parseThemeMode(String? savedMode) {
  switch (savedMode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return ThemeMode.dark;
  }
}

/// Application entry point.
///
/// Initializes the encrypted database and requests all required
/// runtime permissions before launching the UI.
Future<void> main() async {
  // Ensure Flutter bindings are ready before calling platform channels
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the encrypted SQLCipher database.
  // On first run, this creates all tables and seeds default data
  // (barangays, customers, schedules).
  // Skip on web — SQLCipher is not available in browsers.
  if (!kIsWeb) {
    try {
      await DatabaseRuntimeRepository().ensureReady();
      await loadPersistedThemeMode();
      await SystemModeManager.instance.loadPersistedMode(notify: false);
      await PushNotificationService.instance.initialize();
      debugPrint('Database initialized successfully');
    } catch (e) {
      debugPrint('Database initialization error: $e');
    }

    // Initialize Supabase cloud sync — only when real credentials are set.
    if (SupabaseConfig.isConfigured) {
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
        );
        await SupabaseSyncService.instance.initialize(cloudAvailable: true);
        debugPrint('Supabase initialized successfully');
      } catch (e) {
        debugPrint('Supabase initialization error: $e');
        await SupabaseSyncService.instance.initialize(cloudAvailable: false);
      }
    } else {
      // Load saved sync preferences even without live credentials so the
      // Settings screen reflects the last-known sync state on startup.
      await SupabaseSyncService.instance.initialize(cloudAvailable: false);
      debugPrint('Supabase not configured — skipping cloud sync');
    }
  }

  // Launch the app — permissions are requested after the first frame renders
  runApp(const MyApp());
}

/// Root application widget.
///
/// Task 011 — Wraps the app in MultiProvider for real-time state management.
/// SystemModeManager is provided here so all screens can read/write the
/// current system mode via Provider.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Task 011, 013.2 — SystemModeManager singleton: shared across UI + background service
        ChangeNotifierProvider.value(value: SystemModeManager.instance),
        Provider(create: (_) => OrderRepository()),
        Provider(create: (_) => CustomerRepository()),
        Provider(create: (_) => BarangayRepository()),
        Provider(create: (_) => SmsMessageRepository()),
        Provider(create: (_) => SettingsRepository()),
        Provider(create: (_) => DeliveryLogRepository()),
        Provider(create: (_) => AdminCredentialRepository()),
        Provider<AdminAuthService>(
          create: (ctx) => DefaultAdminAuthService(
            credentialRepository: ctx.read<AdminCredentialRepository>(),
          ),
        ),
        Provider(create: (_) => AuditLogRepository()),
        // Task 011 — OrderProvider: reactive order state for dashboard + order screens
        ChangeNotifierProvider(
          create: (ctx) => OrderProvider(ctx.read<OrderRepository>()),
        ),
        // Task 011 — CustomerProvider: reactive customer state for customer screen + forms
        ChangeNotifierProvider(
          create: (ctx) => CustomerProvider(ctx.read<CustomerRepository>()),
        ),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, mode, child) => MaterialApp(
          title: 'JJ Clover',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const PermissionGate(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

/// Gate screen that requests all required runtime permissions on startup.
///
/// Android requires certain permissions to be explicitly granted by the user
/// at runtime (not just declared in the manifest). This screen handles:
/// - Default SMS app role — for receiving SMS_DELIVER broadcasts
/// - SMS permissions (send, receive, read) — for order processing
/// - Battery optimization exemption — keeps background service alive
///
/// Once all permissions are granted, it navigates to the full dashboard.
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  /// Tracks whether all required permissions have been granted
  bool _permissionsGranted = false;

  /// Tracks whether Android has made this app the default SMS handler.
  bool _isDefaultSmsApp = false;

  /// Tracks whether the permission check is still in progress
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Request permissions after the first frame renders
    // This avoids calling platform channels during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isChecking) {
      _refreshPermissionState();
    }
  }

  /// Requests all runtime permissions required by the app.
  ///
  /// Permission flow:
  /// 1. Request default SMS app role
  /// 2. Request SMS permissions
  /// 3. Request battery optimization exemption (separate system dialog)
  /// 4. Update state based on results
  Future<void> _requestPermissions() async {
    // On web, skip permission requests — go straight to the dashboard.
    // Permissions and SMS are Android-only features.
    if (kIsWeb) {
      setState(() {
        _permissionsGranted = true;
        _isChecking = false;
      });
      return;
    }

    // Step 1: Ask Android to make this app the default SMS handler.
    // Android only routes SMS_DELIVER broadcasts to the current default SMS app.
    var defaultSmsGranted = await DefaultSmsAppService.isDefaultSmsApp();
    if (!defaultSmsGranted) {
      defaultSmsGranted = await DefaultSmsAppService.requestDefaultSmsApp();
      if (!defaultSmsGranted) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        defaultSmsGranted = await DefaultSmsAppService.isDefaultSmsApp();
      }
    }

    // Step 2: Request SMS and notification permissions.
    final statuses = await [
      Permission.sms, // Covers SEND_SMS, RECEIVE_SMS, READ_SMS
      Permission.notification, // For walk-in alerts and dispatch notifications
    ].request();

    // Step 3: Check if SMS and notification permissions were granted
    final smsGranted = statuses[Permission.sms]?.isGranted ?? false;
    final notificationGranted =
        statuses[Permission.notification]?.isGranted ?? false;

    // Step 4: Request battery optimization exemption.
    // This shows a separate system dialog asking the user to allow
    // the app to run unrestricted in the background (bypass Doze mode).
    // Critical for keeping the SMS listener alive when the screen is off.
    final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
    final batteryGranted = batteryStatus.isGranted;

    // Log the results for debugging
    debugPrint('Default SMS app: $defaultSmsGranted');
    // ignore: prefer_const_constructors
    debugPrint('SMS permission: $smsGranted');
    // ignore: prefer_const_constructors
    debugPrint('Notification permission: $notificationGranted');
    // ignore: prefer_const_constructors
    debugPrint('Battery optimization exemption: $batteryGranted');

    // Update state — the UI will show the app or a permission prompt
    final allGranted = defaultSmsGranted && smsGranted;
    setState(() {
      // All critical permissions must be granted for the app to function
      _isDefaultSmsApp = defaultSmsGranted;
      _permissionsGranted = allGranted;
      _isChecking = false;
    });

    // Task 009 — Start SMS background service once permissions are confirmed.
    // The service listens for incoming SMS and processes them as commands.
    // Must start AFTER SMS permissions are granted, otherwise
    // the telephony plugin will fail silently.
    if (allGranted) {
      await SmsBackgroundService.instance.startListening();
      debugPrint('SMS Background Service started after permissions granted');
    }

    // Warn if battery optimization was not granted (non-blocking)
    if (!batteryGranted) {
      debugPrint(
        'WARNING: Battery optimization not exempted. '
        'Background SMS service may be killed by Android.',
      );
    }
  }

  /// Re-checks state after returning from Android settings/default-app screens.
  ///
  /// Some devices update the default SMS role just after the activity resumes,
  /// so this keeps the gate from showing stale "Default SMS App Required" text.
  Future<void> _refreshPermissionState() async {
    if (kIsWeb) return;

    final defaultSmsGranted = await DefaultSmsAppService.isDefaultSmsApp();
    final smsGranted = (await Permission.sms.status).isGranted;
    final allGranted = defaultSmsGranted && smsGranted;

    if (!mounted) return;

    setState(() {
      _isDefaultSmsApp = defaultSmsGranted;
      _permissionsGranted = allGranted;
    });

    if (allGranted) {
      await SmsBackgroundService.instance.startListening();
      debugPrint('SMS Background Service started after permissions granted');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking permissions
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MascotBadge(pose: MascotPose.smsConfirm, size: 96),
              const SizedBox(height: 20),
              // Spinning indicator while permissions are being requested
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Requesting permissions...',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show retry prompt if critical permissions were denied
    if (!_permissionsGranted) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MascotImage(
                  pose: _isDefaultSmsApp
                      ? MascotPose.smsConfirm
                      : MascotPose.checklist,
                  size: 136,
                ),
                const SizedBox(height: 16),
                Text(
                  _isDefaultSmsApp
                      ? 'SMS Permissions Required'
                      : 'Default SMS App Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isDefaultSmsApp
                      ? 'This app needs SMS permissions to process '
                            'customer orders. Please grant the permissions to continue.'
                      : 'Set JJ Clover as the default SMS app so Android can '
                            'deliver customer order messages to it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 24),
                // Retry button — re-requests all permissions
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isChecking = true);
                    _requestPermissions();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                // Open settings button — in case the user permanently denied
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: Text(
                    'Open App Settings',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Task 010 — All permissions granted — show the full dashboard UI
    return const AppShell();
  }
}
