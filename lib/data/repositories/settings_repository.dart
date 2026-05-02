import '../../database_helper.dart';

class SettingsRepository {
  Future<int> getCutoffHour() {
    return DatabaseHelper.instance.getCutoffHour();
  }

  Future<int> getCutoffMinute() {
    return DatabaseHelper.instance.getCutoffMinute();
  }

  Future<void> setCutoffTime(int hour, int minute) {
    return DatabaseHelper.instance.setCutoffTime(hour, minute);
  }
}
