import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:litrato/database_helper.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Database verification ---
  try {
    final db = await DatabaseHelper.instance.database;
    debugPrint('✅ Database opened successfully');

    // List seeded barangays
    final barangays = await DatabaseHelper.instance.getBarangays();
    debugPrint('✅ Seeded barangays: $barangays');

    // Insert a test customer using a seeded barangay ID
    final barangayId = barangays.first['id'] as int;
    final id = await DatabaseHelper.instance.insertCustomer({
      'name': 'Test Customer',
      'contact_number': '09171234567',
      'barangay_id': barangayId,
    });
    debugPrint('✅ Inserted test customer with id: $id');

    // Query customers with joined barangay info
    final results = await DatabaseHelper.instance.getCustomersWithBarangay();
    debugPrint('✅ Customers in DB: $results');

    // Clean up test data
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    debugPrint('✅ Test customer deleted. Database is working!');
  } catch (e) {
    debugPrint('❌ Database error: $e');
  }
  // --- End verification ---

  // Initialize available cameras
  cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Camera App',
      theme: ThemeData.dark(),
      home: const CameraPreviewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  CameraController? controller;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      controller = CameraController(cameras[0], ResolutionPreset.medium);
      controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Camera Preview')),
      body: CameraPreview(controller!),
    );
  }
}
