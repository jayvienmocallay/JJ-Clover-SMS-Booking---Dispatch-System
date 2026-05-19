part of 'database_helper.dart';

extension DatabaseCustomerOperations on DatabaseHelper {
  Future<List<Map<String, dynamic>>> getBarangays() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('barangays', orderBy: 'name ASC');
  }

  /// Get a single barangay by ID
  Future<Map<String, dynamic>?> getBarangayById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query(
      'barangays',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Insert a new barangay
  Future<int> insertBarangay(Map<String, dynamic> barangayData) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('barangays', barangayData);
  }

  /// Delete a barangay by ID
  Future<int> deleteBarangay(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('barangays', where: 'id = ?', whereArgs: [id]);
  }

  /// Update a barangay's zone and delivery day.
  /// Also re-creates schedules for all customers in this barangay
  /// so their delivery days match the new zone configuration.
  Future<int> updateBarangay(int id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    final updated = await db.update(
      'barangays',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );

    // Re-create schedules for all customers in this barangay
    final zone = data['delivery_zone'] as String?;
    final barangayName = data['name'] as String?;
    final barangayDeliveryDay = data['delivery_day'] as String?;
    if (zone == null) return updated;

    List<String> deliveryDays;
    if (zone == 'Zone C' && barangayDeliveryDay != null) {
      deliveryDays = [barangayDeliveryDay];
    } else {
      deliveryDays = ZoneScheduleMap.getDaysForZone(
        zone,
        barangayName: barangayName,
      );
    }

    // Find all customers in this barangay
    final customers = await db.query(
      'customers',
      columns: ['id'],
      where: 'barangay_id = ?',
      whereArgs: [id],
    );

    for (final customer in customers) {
      final customerId = customer['id'] as int;
      // Delete old schedules
      await db.delete(
        'schedules',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      // Re-create with new days
      for (final day in deliveryDays) {
        await db.insert('schedules', {
          'customer_id': customerId,
          'delivery_day': day,
          'status': 'active',
        });
      }
    }

    return updated;
  }

  /// Delete a customer by ID
  Future<int> deleteCustomer(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // Task 003, Task 005 â€” Customer CRUD operations

  /// Insert a new customer and automatically create schedules based on barangay zone
  Future<int> insertCustomer(Map<String, dynamic> customerData) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedData = _normalizeCustomerData(customerData);
    late final int customerId;
    try {
      customerId = await db.insert('customers', normalizedData);
    } on DatabaseException catch (error) {
      if (_isCustomerContactNumberUniqueError(error)) {
        throw CustomerPhoneAlreadyExistsException(
          normalizedData['contact_number'] as String? ?? '',
        );
      }
      rethrow;
    }

    // Auto-create schedules based on barangay's delivery zone / delivery_day.
    final barangayId = normalizedData['barangay_id'] as int?;
    if (barangayId != null) {
      final barangay = await getBarangayById(barangayId);
      if (barangay != null) {
        final zone = barangay['delivery_zone'] as String;
        final barangayName = barangay['name'] as String;
        final barangayDeliveryDay = barangay['delivery_day'] as String?;

        // For Zone C, use the DB-stored delivery_day so dynamically added
        // barangays (absent from the hardcoded map) also get schedules.
        List<String> deliveryDays;
        if (zone == 'Zone C' && barangayDeliveryDay != null) {
          deliveryDays = [barangayDeliveryDay];
        } else {
          deliveryDays = ZoneScheduleMap.getDaysForZone(
            zone,
            barangayName: barangayName,
          );
        }

        for (final day in deliveryDays) {
          await db.insert('schedules', {
            'customer_id': customerId,
            'delivery_day': day,
            'status': 'active',
          });
        }
      }
    }

    return customerId;
  }

  /// Get all customers (raw)
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('customers', orderBy: 'name ASC');
  }

  /// Get all customers with their barangay info joined.
  /// Includes the address field added in v2 for complete customer profiles.
  Future<List<Map<String, dynamic>>> getCustomersWithBarangay() async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('''
    SELECT c.id, c.name, c.contact_number, c.address,
           c.barangay_id, c.is_muted, c.is_blocked, c.is_spam,
           b.name AS barangay, b.delivery_zone
    FROM customers c
    INNER JOIN barangays b ON c.barangay_id = b.id
    ORDER BY c.name ASC
  ''');
  }

  /// Find a customer by phone number
  Future<Map<String, dynamic>?> getCustomerByPhone(String phoneNumber) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    final result = await db.query(
      'customers',
      where: 'contact_number = ?',
      whereArgs: [normalizedPhone],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Find a customer by phone number with joined barangay and zone details.
  Future<Map<String, dynamic>?> getCustomerWithBarangayByPhone(
    String phoneNumber,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    final result = await db.rawQuery(
      '''
    SELECT c.id, c.name, c.contact_number, c.address,
           c.barangay_id, c.is_muted, c.is_blocked, c.is_spam,
           b.name AS barangay, b.delivery_zone
    FROM customers c
    INNER JOIN barangays b ON c.barangay_id = b.id
    WHERE c.contact_number = ?
    LIMIT 1
  ''',
      [normalizedPhone],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Task 003, Task 006 â€” Schedule CRUD operations

  /// Insert a new schedule record for a customer
  Future<int> insertSchedule(Map<String, dynamic> scheduleData) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('schedules', scheduleData);
  }

  /// Get all schedule records (newest first)
  Future<List<Map<String, dynamic>>> getSchedules() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('schedules', orderBy: 'id DESC');
  }

  /// Get all schedule records for a specific customer.
  /// Returns only 'active' schedules by default.
  /// Used by the ZoneValidator to check if a customer can order today.
  Future<List<Map<String, dynamic>>> getSchedulesForCustomer(
    int customerId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'schedules',
      where: 'customer_id = ? AND status = ?',
      whereArgs: [customerId, 'active'],
    );
  }

  Future<int> updateCustomer(
    int customerId,
    Map<String, dynamic> customerData,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedData = _normalizeCustomerData(customerData);
    late final int updated;
    try {
      updated = await db.update(
        'customers',
        normalizedData,
        where: 'id = ?',
        whereArgs: [customerId],
      );
    } on DatabaseException catch (error) {
      if (_isCustomerContactNumberUniqueError(error)) {
        throw CustomerPhoneAlreadyExistsException(
          normalizedData['contact_number'] as String? ?? '',
        );
      }
      rethrow;
    }
    if (updated == 0) return 0;

    // Re-create schedules if barangay changed so zone validation
    // uses the new barangay's delivery days instead of stale ones.
    final barangayId = normalizedData['barangay_id'] as int?;
    if (barangayId != null) {
      final barangay = await getBarangayById(barangayId);
      if (barangay != null) {
        // Delete old schedules
        await db.delete(
          'schedules',
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );

        // Re-create based on new barangay's zone
        final zone = barangay['delivery_zone'] as String;
        final barangayName = barangay['name'] as String;
        final barangayDeliveryDay = barangay['delivery_day'] as String?;

        List<String> deliveryDays;
        if (zone == 'Zone C' && barangayDeliveryDay != null) {
          deliveryDays = [barangayDeliveryDay];
        } else {
          deliveryDays = ZoneScheduleMap.getDaysForZone(
            zone,
            barangayName: barangayName,
          );
        }

        for (final day in deliveryDays) {
          await db.insert('schedules', {
            'customer_id': customerId,
            'delivery_day': day,
            'status': 'active',
          });
        }
      }
    }

    return updated;
  }

  Future<int> updateCustomerContactFlags(
    int customerId, {
    bool? isMuted,
    bool? isBlocked,
    bool? isSpam,
  }) async {
    final updates = <String, Object?>{};
    if (isMuted != null) updates['is_muted'] = isMuted ? 1 : 0;
    if (isBlocked != null) updates['is_blocked'] = isBlocked ? 1 : 0;
    if (isSpam != null) updates['is_spam'] = isSpam ? 1 : 0;
    if (updates.isEmpty) return 0;

    final db = await DatabaseHelper.instance.database;
    return db.update(
      'customers',
      updates,
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  Future<Map<String, dynamic>?> getBarangayByName(String name) async {
    final db = await DatabaseHelper.instance.database;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final rows = await db.query(
      'barangays',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [trimmed],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// RA 10173 right-to-erasure: permanently removes a customer and the
  /// personal data tied to their phone number. Historical orders are kept
  /// (for inventory accountability) but are anonymized â€” `customer_id` is
  /// nulled out and `phone_number` / `address` are cleared. Schedules and
  /// delivery_logs cascade-delete via FK. SMS history, in-flight pending
  /// flows, and incoming-SMS receipts for this number are also removed.
  ///
  /// Returns true if a customer record was deleted, false if none existed
}
