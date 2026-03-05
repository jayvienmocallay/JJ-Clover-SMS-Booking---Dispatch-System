import 'package:flutter/material.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await DatabaseHelper.instance.database;
    debugPrint('Database opened successfully');
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
