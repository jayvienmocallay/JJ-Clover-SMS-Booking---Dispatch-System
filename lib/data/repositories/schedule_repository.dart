import '../../database_helper.dart';

class ScheduleRepository {
  Future<int> insertSchedule(Map<String, dynamic> scheduleData) {
    return DatabaseHelper.instance.insertSchedule(scheduleData);
  }

  Future<List<Map<String, dynamic>>> getSchedules() {
    return DatabaseHelper.instance.getSchedules();
  }

  Future<List<Map<String, dynamic>>> getSchedulesForCustomer(int customerId) {
    return DatabaseHelper.instance.getSchedulesForCustomer(customerId);
  }
}
