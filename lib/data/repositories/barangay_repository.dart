import '../../database_helper.dart';

class BarangayRepository {
  Future<List<Map<String, dynamic>>> getBarangays() {
    return DatabaseHelper.instance.getBarangays();
  }

  Future<int> insertBarangay(Map<String, dynamic> data) {
    return DatabaseHelper.instance.insertBarangay(data);
  }

  Future<int> deleteBarangay(int id) {
    return DatabaseHelper.instance.deleteBarangay(id);
  }

  Future<int> updateBarangay(int id, Map<String, dynamic> data) {
    return DatabaseHelper.instance.updateBarangay(id, data);
  }
}
