import '../../database_helper.dart';

class SettingsRepository {
  Future<String?> getSetting(String key) {
    return DatabaseHelper.instance.getSetting(key);
  }

  Future<void> setSetting(String key, String value) {
    return DatabaseHelper.instance.setSetting(key, value);
  }

  Future<void> deleteSetting(String key) {
    return DatabaseHelper.instance.deleteSetting(key);
  }

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
