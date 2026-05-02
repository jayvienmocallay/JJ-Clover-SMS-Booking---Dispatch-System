import '../../database_helper.dart';

class DatabaseRuntimeRepository {
  Future<void> ensureReady() async {
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.ensureSchedulesSeeded();
  }
}
