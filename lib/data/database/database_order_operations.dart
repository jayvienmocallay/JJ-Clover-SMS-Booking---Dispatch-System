part of 'database_helper.dart';

extension DatabaseOrderOperations on DatabaseHelper {
  Future<int> insertOrder(Map<String, dynamic> orderData) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedData = Map<String, dynamic>.from(orderData);
    final phoneNumber = normalizedData['phone_number'] as String?;
    if (phoneNumber != null) {
      normalizedData['phone_number'] = PhoneNumberUtils.normalize(phoneNumber);
    }
    return await db.insert(
      'orders',
      normalizedData,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> promotePendingUnrecognizedOrder(
    int id,
    Map<String, dynamic> orderData,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedData = Map<String, dynamic>.from(orderData)
      ..remove('id')
      ..remove('created_at');
    final phoneNumber = normalizedData['phone_number'] as String?;
    if (phoneNumber != null) {
      normalizedData['phone_number'] = PhoneNumberUtils.normalize(phoneNumber);
    }
    normalizedData['cancel_reason'] = null;

    return await db.update(
      'orders',
      normalizedData,
      where: 'id = ? AND type = ? AND status = ?',
      whereArgs: [id, 'unrecognized', 'pending'],
    );
  }

  Future<List<Map<String, dynamic>>> getOrders({
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTodayOrders() async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await db.query(
      'orders',
      where: 'date(COALESCE(scheduled_for, created_at)) = ?',
      whereArgs: [today],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getOrderHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? type,
    String? search,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (startDate != null) {
      clauses.add('datetime(o.created_at) >= datetime(?)');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      clauses.add('datetime(o.created_at) < datetime(?)');
      args.add(endDate.toIso8601String());
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      clauses.add('o.status = ?');
      args.add(status);
    }
    if (type != null && type.isNotEmpty && type != 'all') {
      clauses.add('o.type = ?');
      args.add(type);
    }
    final trimmedSearch = search?.trim();
    if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
      final normalized = PhoneNumberUtils.normalize(trimmedSearch);
      clauses.add(
        '(o.phone_number LIKE ? OR o.id = ? OR c.name LIKE ? OR c.contact_number LIKE ?)',
      );
      args.add('%$trimmedSearch%');
      args.add(int.tryParse(trimmedSearch) ?? -1);
      args.add('%$trimmedSearch%');
      args.add('%${normalized.isEmpty ? trimmedSearch : normalized}%');
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    return await db.rawQuery('''
    SELECT o.*, c.name AS customer_name, c.address AS customer_address,
           b.name AS barangay, b.delivery_zone AS delivery_zone
    FROM orders o
    LEFT JOIN customers c ON c.id = o.customer_id
    LEFT JOIN barangays b ON b.id = c.barangay_id
    $where
    ORDER BY datetime(o.created_at) DESC
  ''', args);
  }

  Future<int> updateOrderStatus(
    int id,
    String status, {
    String? reason,
    String? notes,
    DateTime? deliveredAt,
  }) async {
    if (status == 'completed') {
      return completeOrder(id, notes: notes, deliveredAt: deliveredAt);
    }
    final db = await DatabaseHelper.instance.database;
    final currentRows = await db.query(
      'orders',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (currentRows.isEmpty) return 0;
    final currentStatus = currentRows.single['status'] as String? ?? 'pending';
    if (!OrderStatusTransitionService.canTransitionDb(currentStatus, status)) {
      throw StateError(
        'Invalid order status transition: $currentStatus -> $status',
      );
    }
    final data = <String, dynamic>{'status': status};
    if (reason != null && reason.isNotEmpty) data['cancel_reason'] = reason;
    return await db.update('orders', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> completeOrder(
    int id, {
    int? quantityDelivered,
    int? returnedContainers,
    bool cashCollected = false,
    String? notes,
    int? staffId,
    DateTime? deliveredAt,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return await db.transaction<int>((txn) async {
      final orders = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (orders.isEmpty) return 0;
      final order = orders.single;
      final currentStatus = order['status'] as String? ?? 'pending';
      if (!OrderStatusTransitionService.canTransitionDb(
        currentStatus,
        'completed',
      )) {
        throw StateError(
          'Invalid order status transition: $currentStatus -> completed',
        );
      }
      final updated = currentStatus == 'completed'
          ? 1
          : await txn.update(
              'orders',
              {'status': 'completed'},
              where: 'id = ?',
              whereArgs: [id],
            );
      if (updated == 0) return 0;
      final customerId = order['customer_id'] as int?;
      if (customerId == null) return updated;
      final existingLogs = await txn.query(
        'delivery_logs',
        columns: ['id'],
        where: 'order_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existingLogs.isNotEmpty) return updated;
      final logData = <String, dynamic>{
        'order_id': id,
        'customer_id': customerId,
        'quantity_delivered':
            quantityDelivered ?? order['quantity'] as int? ?? 0,
        'delivered_at': (deliveredAt ?? DateTime.now()).toIso8601String(),
      };
      final resolvedStaffId = staffId ?? order['staff_id'] as int?;
      if (resolvedStaffId != null) logData['staff_id'] = resolvedStaffId;
      final deliveryNotes = _nonEmptyString(notes);
      if (deliveryNotes != null) logData['notes'] = deliveryNotes;
      if (returnedContainers != null) {
        logData['returned_containers'] = returnedContainers;
      }
      if (cashCollected) logData['payment_method'] = 'cash';
      await txn.insert('delivery_logs', logData);
      return updated;
    });
  }

  String? _nonEmptyString(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  // Task 005 â€” Delivery Log CRUD operations

  /// Insert a new delivery log entry.
  /// Called when staff confirms a delivery was made to a household.
  Future<int> insertDeliveryLog(Map<String, dynamic> logData) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('delivery_logs', logData);
  }

  /// Get all delivery logs, newest first.
  /// Useful for the shift-end reconciliation view.
  Future<List<Map<String, dynamic>>> getDeliveryLogs() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('delivery_logs', orderBy: 'delivered_at DESC');
  }

  /// Get all delivery logs for a specific order.
  /// Shows which households received gallons from a given order.
  Future<List<Map<String, dynamic>>> getDeliveryLogsForOrder(
    int orderId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'delivery_logs',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'delivered_at DESC',
    );
  }

  /// Get all delivery logs for a specific customer.
  /// Shows the full delivery history for a household (accountability tracking).
  Future<List<Map<String, dynamic>>> getDeliveryLogsForCustomer(
    int customerId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'delivery_logs',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'delivered_at DESC',
    );
  }

  /// Get today's delivery logs for shift-end reconciliation.
  /// Sums up all gallons delivered today for inventory checking.
  Future<List<Map<String, dynamic>>> getTodayDeliveryLogs() async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await db.query(
      'delivery_logs',
      where: 'date(delivered_at) = ?',
      whereArgs: [today],
      orderBy: 'delivered_at DESC',
    );
  }
}
