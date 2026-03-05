import 'package:flutter/material.dart';
import 'package:jj_clover_sms/database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final db = await DatabaseHelper.instance.database;
    debugPrint('Database opened successfully');

    // List seeded barangays
    final barangays = await DatabaseHelper.instance.getBarangays();
    debugPrint('Seeded barangays: $barangays');

    // Insert a test customer using a seeded barangay ID
    final barangayId = barangays.first['id'] as int;
    final id = await DatabaseHelper.instance.insertCustomer({
      'name': 'Test Customer',
      'contact_number': '09171234567',
      'barangay_id': barangayId,
    });
    debugPrint('Inserted test customer with id: $id');

    // Query customers with joined barangay info
    final results = await DatabaseHelper.instance.getCustomersWithBarangay();
    debugPrint('Customers in DB: $results');

    // Clean up test data
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    debugPrint('Test customer deleted. Database is working!');
  } catch (e) {
    debugPrint('Database error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JJ Clover',
      theme: ThemeData.dark(),
      home: const Scaffold(body: Center(child: Text('JJ Clover SMS Dispatch'))),
      debugShowCheckedModeBanner: false,
    );
  }
}
