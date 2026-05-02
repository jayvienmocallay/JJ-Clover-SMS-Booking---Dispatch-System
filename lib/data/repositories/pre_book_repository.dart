import '../../database_helper.dart';

class PreBookRepository {
  Future<Map<String, Map<String, dynamic>>> getPending() {
    return DatabaseHelper.instance.getPreBookPending();
  }

  Future<void> setPending(Map<String, Map<String, dynamic>> pending) {
    return DatabaseHelper.instance.setPreBookPending(pending);
  }
}
