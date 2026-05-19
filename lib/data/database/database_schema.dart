part of 'database_helper.dart';

Future<void> createDatabaseSchema(Database db, int version) async {
  // Task 001 â€” 1. Barangays Lookup Table (zone mapping from interview)
  // delivery_day stores the fixed weekly day for Zone C barangays (null for A/B).
  await db.execute('''
    CREATE TABLE barangays (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      delivery_zone TEXT NOT NULL,
      delivery_day TEXT
    )
  ''');

  // Task 005 â€” 2. Customers Table (references barangays)
  // Stores registered customer profiles per FR-1.2 in SRS:
  // Phone Number, Name, Full Address, and Barangay (Zone).
  // Task 020 â€” Consent columns provide an RA 10173 audit trail for the
  // moment, channel, and notice version the customer agreed to.
  await db.execute('''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      contact_number TEXT NOT NULL,
      address TEXT,
      barangay_id INTEGER NOT NULL,
      consent_given INTEGER NOT NULL DEFAULT 0,
      consent_timestamp TEXT,
      consent_channel TEXT,
      consent_version TEXT,
      FOREIGN KEY (barangay_id) REFERENCES barangays (id)
    )
  ''');

  await _createCustomerContactNumberIndex(db);

  // Task 005, Task 006 â€” 3. Schedules Table (zone-day mapping per customer)
  await db.execute('''
    CREATE TABLE schedules (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL,
      delivery_day TEXT NOT NULL,
      status TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
    )
  ''');

  // Task 003, Task 005 â€” 4. Orders Table (core order tracking)
  // Tracks all orders with gallon classification and staff assignment
  await db.execute('''
    CREATE TABLE orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER,
      phone_number TEXT NOT NULL,
      type TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      address TEXT,
      status TEXT NOT NULL,
      cancel_reason TEXT,
      created_at TEXT NOT NULL,
      delivery_day TEXT,
      scheduled_for TEXT,
      is_pre_book INTEGER DEFAULT 0,
      staff_id INTEGER,
      source_message_id TEXT,
      source TEXT,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
    )
  ''');

  // Add indexes for query performance
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_orders_phone ON orders(phone_number)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_orders_delivery_day ON orders(delivery_day)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_orders_scheduled_for ON orders(scheduled_for)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_orders_type ON orders(type)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_orders_source ON orders(source)',
  );

  // Task 005 â€” 5. Delivery Logs Table (per-household accountability)
  // Records per-household delivery details for accountability and loss tracking.
  // Each log entry ties a delivery to an order, customer, and staff member.
  await db.execute('''
    CREATE TABLE delivery_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      customer_id INTEGER NOT NULL,
      staff_id INTEGER,
      quantity_delivered INTEGER NOT NULL,
      notes TEXT,
      returned_containers INTEGER,
      payment_method TEXT,
      delivered_at TEXT NOT NULL,
      FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
    )
  ''');

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_delivery_logs_order ON delivery_logs(order_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_delivery_logs_customer ON delivery_logs(customer_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_delivery_logs_delivered ON delivery_logs(delivered_at)',
  );

  await _createSmsMessagesTable(db);
  await _createIncomingSmsReceiptsTable(db);
  await _createAppSettingsTable(db);
  await _createPendingSmsActionsTable(db);
  await _createAuditLogsTable(db);
  await _createDeletionRetryQueueTable(db);
  await _createSupabaseSyncDeletionsTable(db);
  await _createSupabaseSyncUpsertsTable(db);
  await _createSupabaseSyncStateTable(db);

  // Task 006 â€” Seed default data in order: barangays first, then customers, then schedules.
  // Order matters because of foreign key dependencies:
  // schedules -> customers -> barangays
  await seedBarangays(db);
  await seedCustomers(db);
  await seedSchedules(db);
  await _seedSupabaseSyncUpserts(db);
}

// Task 005 â€” Database migration: v1 â†’ current schema upgrade
/// Handles upgrading the database schema from an older version to the current one.
///
/// v1 â†’ v2 changes:
/// - Added `address` column to customers (FR-1.2: full address)
/// - Added `gallon_type` column to orders (gallon classification: new/old)
/// - Added `staff_id` column to orders (staff assignment & accountability)
/// - Created `delivery_logs` table (per-household delivery tracking)
/// - Seeded schedules if missing from v1
///
/// v2 â†’ v3 changes:
/// - Created `app_settings` table for persisted runtime settings
Future<void> upgradeDatabaseSchema(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  // Migrate from version 1 to version 2
  if (oldVersion < 2) {
    // Add address column to customers table for full delivery address
    await db.execute('ALTER TABLE customers ADD COLUMN address TEXT');

    // Add gallon classification column: 'new' (household) or 'old' (store)

    // Add staff assignment column for delivery accountability
    await db.execute('ALTER TABLE orders ADD COLUMN staff_id INTEGER');

    // Add cancel reason column for rejected orders
    await db.execute('ALTER TABLE orders ADD COLUMN cancel_reason TEXT');

    // Create the delivery_logs table for per-household tracking
    await db.execute('''
      CREATE TABLE delivery_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        customer_id INTEGER NOT NULL,
        staff_id INTEGER,
        quantity_delivered INTEGER NOT NULL,
          notes TEXT,
        delivered_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    // Seed schedules if they were missing in v1 (the critical gap)
    final existingSchedules = await db.query('schedules', limit: 1);
    if (existingSchedules.isEmpty) {
      await seedSchedules(db);
    }

    // Add indexes for query performance (idempotent)
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_phone ON orders(phone_number)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_delivery_day ON orders(delivery_day)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_type ON orders(type)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_delivery_logs_order ON delivery_logs(order_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_delivery_logs_customer ON delivery_logs(customer_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_delivery_logs_delivered ON delivery_logs(delivered_at)',
      );
    } catch (_) {}
  }

  if (oldVersion < 3) {
    await _createAppSettingsTable(db);
  }

  if (oldVersion < 4) {
    await _createSmsMessagesTable(db);
    await _addColumnIfMissing(db, 'orders', 'source_message_id', 'TEXT');
    await _addColumnIfMissing(db, 'sms_messages', 'source_message_id', 'TEXT');
    await _createIncomingSmsReceiptsTable(db);
    await _createSourceMessageIndexes(db);
  }

  if (oldVersion < 5) {
    await _normalizeCustomerContactNumbers(db);
    await _createCustomerContactNumberIndex(db);
  }

  if (oldVersion < 6) {
    await _addColumnIfMissing(db, 'barangays', 'delivery_day', 'TEXT');
    // Populate delivery_day for existing seeded Zone C barangays.
    for (final entry in ZoneScheduleMap.zoneCBarangayDays.entries) {
      await db.rawUpdate(
        'UPDATE barangays SET delivery_day = ? WHERE name = ? AND delivery_day IS NULL',
        [entry.value, entry.key],
      );
    }
  }

  if (oldVersion < 7) {
    // Task 020 â€” RA 10173 consent audit columns and SMS multi-step flow state.
    await _addColumnIfMissing(
      db,
      'customers',
      'consent_given',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(db, 'customers', 'consent_timestamp', 'TEXT');
    await _addColumnIfMissing(db, 'customers', 'consent_channel', 'TEXT');
    await _addColumnIfMissing(db, 'customers', 'consent_version', 'TEXT');
    await _createPendingSmsActionsTable(db);
  }

  if (oldVersion < 8) {
    await _addColumnIfMissing(
      db,
      'delivery_logs',
      'returned_containers',
      'INTEGER',
    );
    await _addColumnIfMissing(db, 'delivery_logs', 'payment_method', 'TEXT');
  }

  if (oldVersion < 9) {
    await _addColumnIfMissing(db, 'orders', 'scheduled_for', 'TEXT');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_scheduled_for '
      'ON orders(scheduled_for)',
    );
  }

  if (oldVersion < 10) {
    await _addColumnIfMissing(db, 'orders', 'source', 'TEXT');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_source ON orders(source)',
    );
  }

  if (oldVersion < 11) {
    await _createAuditLogsTable(db);
    await _createDeletionRetryQueueTable(db);
  }

  if (oldVersion < 12) {
    await _createSupabaseSyncDeletionsTable(db);
  }

  if (oldVersion < 13) {
    await _createSupabaseSyncUpsertsTable(db);
    await _createSupabaseSyncStateTable(db);
    await _seedSupabaseSyncUpserts(db);
  }

  // Create sms_messages table if not exists (for old databases)
  await _createSmsMessagesTable(db);
  await _createIncomingSmsReceiptsTable(db);
  await _createSourceMessageIndexes(db);
  await _createCustomerContactNumberIndex(db);
  await _createPendingSmsActionsTable(db);
  await _createAuditLogsTable(db);
  await _createDeletionRetryQueueTable(db);
  await _createSupabaseSyncDeletionsTable(db);
  await _createSupabaseSyncUpsertsTable(db);
  await _createSupabaseSyncStateTable(db);
}

Future<void> _createAppSettingsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
}

Future<void> _createSmsMessagesTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sms_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone_number TEXT NOT NULL,
      message TEXT NOT NULL,
      direction TEXT NOT NULL,
      related_order_id INTEGER,
      status TEXT,
      source_message_id TEXT,
      sent_at TEXT NOT NULL
    )
  ''');

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_sms_phone ON sms_messages(phone_number)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_sms_direction ON sms_messages(direction)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_sms_sent ON sms_messages(sent_at)',
  );
  await _createSourceMessageIndexes(db);
}

Future<void> _createIncomingSmsReceiptsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS incoming_sms_receipts (
      message_id TEXT PRIMARY KEY,
      phone_number TEXT NOT NULL,
      message TEXT NOT NULL,
      sms_timestamp INTEGER,
      status TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      received_at TEXT NOT NULL,
      claimed_at TEXT,
      completed_at TEXT,
      updated_at TEXT NOT NULL,
      last_error TEXT
    )
  ''');

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_sms_receipts_status ON incoming_sms_receipts(status)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_sms_receipts_phone ON incoming_sms_receipts(phone_number)',
  );
}

Future<void> _createSourceMessageIndexes(Database db) async {
  await _addColumnIfMissing(db, 'orders', 'source_message_id', 'TEXT');
  await _addColumnIfMissing(db, 'orders', 'scheduled_for', 'TEXT');
  await _addColumnIfMissing(db, 'orders', 'source', 'TEXT');
  await _addColumnIfMissing(db, 'sms_messages', 'source_message_id', 'TEXT');

  // Older production builds created this as UNIQUE, which is wrong â€” multiple
  // outgoing SMS log rows legitimately share the same source message. Drop and
  // recreate as a plain index so duplicate logs don't cause constraint errors.
  await db.execute('DROP INDEX IF EXISTS idx_sms_source_message');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_sms_source_message '
    'ON sms_messages(source_message_id) '
    'WHERE source_message_id IS NOT NULL',
  );
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_source_message '
    'ON orders(source_message_id) '
    'WHERE source_message_id IS NOT NULL',
  );
}

Future<void> _createCustomerContactNumberIndex(Database db) async {
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS '
    'idx_customers_contact_number_unique '
    'ON customers(contact_number)',
  );
}

Future<void> _normalizeCustomerContactNumbers(Database db) async {
  final customers = await db.query(
    'customers',
    columns: ['id', 'contact_number'],
    orderBy: 'id ASC',
  );
  final idsByPhone = <String, List<int>>{};
  final normalizedById = <int, String>{};

  for (final customer in customers) {
    final id = customer['id'] as int;
    final currentPhone = customer['contact_number'] as String? ?? '';
    final normalizedPhone = PhoneNumberUtils.normalize(currentPhone);
    normalizedById[id] = normalizedPhone;
    idsByPhone.putIfAbsent(normalizedPhone, () => <int>[]).add(id);
  }

  final duplicates = idsByPhone.entries
      .where((entry) => entry.value.length > 1)
      .map((entry) => '${entry.key}: customer IDs ${entry.value.join(', ')}')
      .toList();

  if (duplicates.isNotEmpty) {
    throw CustomerPhoneIdentityMigrationException(
      'Duplicate customer phone numbers after normalization: '
      '${duplicates.join('; ')}',
    );
  }

  for (final customer in customers) {
    final id = customer['id'] as int;
    final currentPhone = customer['contact_number'] as String? ?? '';
    final normalizedPhone = normalizedById[id]!;
    if (currentPhone != normalizedPhone) {
      await db.update(
        'customers',
        {'contact_number': normalizedPhone},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}

Map<String, dynamic> _normalizeCustomerData(Map<String, dynamic> data) {
  final normalizedData = Map<String, dynamic>.from(data);
  final contactNumber = normalizedData['contact_number'] as String?;
  if (contactNumber != null) {
    normalizedData['contact_number'] = PhoneNumberUtils.normalize(
      contactNumber,
    );
  }
  return normalizedData;
}

bool _isCustomerContactNumberUniqueError(DatabaseException error) {
  final message = error.toString().toLowerCase();
  return error.isUniqueConstraintError('customers.contact_number') ||
      (error.isUniqueConstraintError() &&
          message.contains('customers.contact_number'));
}

Future<void> ensureDatabaseSchemaIntegrity(Database db) async {
  if (DatabaseHelper._schemaIntegrityChecked) return;

  await _normalizeCustomerContactNumbers(db);
  await _createCustomerContactNumberIndex(db);
  await _createAppSettingsTable(db);
  await _createSmsMessagesTable(db);
  await _createIncomingSmsReceiptsTable(db);
  await _addColumnIfMissing(db, 'orders', 'cancel_reason', 'TEXT');
  await _addColumnIfMissing(db, 'orders', 'source_message_id', 'TEXT');
  await _addColumnIfMissing(db, 'orders', 'source', 'TEXT');
  await _addColumnIfMissing(db, 'sms_messages', 'source_message_id', 'TEXT');
  await _createSourceMessageIndexes(db);
  await _addColumnIfMissing(db, 'barangays', 'delivery_day', 'TEXT');
  // Task 020 â€” RA 10173 consent metadata; idempotent on existing v6 DBs.
  await _addColumnIfMissing(
    db,
    'customers',
    'consent_given',
    'INTEGER NOT NULL DEFAULT 0',
  );
  await _addColumnIfMissing(db, 'customers', 'consent_timestamp', 'TEXT');
  await _addColumnIfMissing(db, 'customers', 'consent_channel', 'TEXT');
  await _addColumnIfMissing(db, 'customers', 'consent_version', 'TEXT');
  await _createPendingSmsActionsTable(db);
  await _createAuditLogsTable(db);
  await _createDeletionRetryQueueTable(db);
  await _createSupabaseSyncDeletionsTable(db);
  await _createSupabaseSyncUpsertsTable(db);
  await _createSupabaseSyncStateTable(db);
  await _addColumnIfMissing(
    db,
    'delivery_logs',
    'returned_containers',
    'INTEGER',
  );
  await _addColumnIfMissing(db, 'delivery_logs', 'payment_method', 'TEXT');
  for (final entry in ZoneScheduleMap.zoneCBarangayDays.entries) {
    await db.rawUpdate(
      'UPDATE barangays SET delivery_day = ? WHERE name = ? AND delivery_day IS NULL',
      [entry.value, entry.key],
    );
  }

  DatabaseHelper._schemaIntegrityChecked = true;
}

// Task 020 â€” Tracks in-progress SMS flows (registration, delete-confirm)
// for unregistered or registered numbers. One row per phone number; rows
// expire after [SmsRegistrationCopy.pendingActionTtl] and are pruned at
// each interaction. Survives process restarts so a customer can finish
// a multi-step flow even if the device reboots between SMS messages.
Future<void> _createPendingSmsActionsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pending_sms_actions (
      phone_number TEXT PRIMARY KEY,
      action TEXT NOT NULL,
      step TEXT NOT NULL,
      name TEXT,
      barangay_id INTEGER,
      address TEXT,
      consent_version TEXT,
      consent_given_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (barangay_id) REFERENCES barangays (id) ON DELETE SET NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_pending_sms_updated '
    'ON pending_sms_actions(updated_at)',
  );
}

Future<void> _createAuditLogsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT,
      phone_hash TEXT,
      metadata TEXT,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_audit_logs_action '
    'ON audit_logs(action)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_audit_logs_created '
    'ON audit_logs(created_at)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_audit_logs_phone_hash '
    'ON audit_logs(phone_hash)',
  );
}

Future<void> _createDeletionRetryQueueTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS deletion_retry_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone_number TEXT NOT NULL,
      operation TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      next_attempt_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_deletion_retry_due '
    'ON deletion_retry_queue(status, next_attempt_at)',
  );
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_deletion_retry_active_phone '
    'ON deletion_retry_queue(phone_number, operation) '
    "WHERE status IN ('pending', 'failed')",
  );
}

Future<void> _createSupabaseSyncDeletionsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS supabase_sync_deletions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL,
      row_id INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      next_attempt_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_supabase_sync_deletions_due '
    'ON supabase_sync_deletions(status, next_attempt_at)',
  );
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS '
    'idx_supabase_sync_deletions_active_row '
    'ON supabase_sync_deletions(table_name, row_id) '
    "WHERE status IN ('pending', 'failed')",
  );
}

Future<void> _createSupabaseSyncUpsertsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS supabase_sync_upserts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL,
      row_id INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      next_attempt_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_supabase_sync_upserts_due '
    'ON supabase_sync_upserts(status, next_attempt_at)',
  );
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS '
    'idx_supabase_sync_upserts_active_row '
    'ON supabase_sync_upserts(table_name, row_id) '
    "WHERE status IN ('pending', 'failed')",
  );
}

Future<void> _createSupabaseSyncStateTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS supabase_sync_state (
      table_name TEXT PRIMARY KEY,
      last_remote_id INTEGER NOT NULL DEFAULT 0,
      baseline_uploaded INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL
    )
  ''');
}

Future<void> _seedSupabaseSyncUpserts(Database db) async {
  const syncTables = ['barangays', 'customers', 'orders', 'sms_messages'];
  final nowIso = DateTime.now().toIso8601String();
  for (final table in syncTables) {
    final exists = await _tableExists(db, table);
    if (!exists) continue;
    final rows = await db.query(table, columns: ['id']);
    for (final row in rows) {
      final rowId = (row['id'] as num?)?.toInt();
      if (rowId == null) continue;
      await db.insert('supabase_sync_upserts', {
        'table_name': table,
        'row_id': rowId,
        'status': 'pending',
        'attempts': 0,
        'next_attempt_at': nowIso,
        'created_at': nowIso,
        'updated_at': nowIso,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}

Future<bool> _tableExists(Database db, String table) async {
  _assertSafeIdentifier(table);
  final rows = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: 'type = ? AND name = ?',
    whereArgs: ['table', table],
    limit: 1,
  );
  return rows.isNotEmpty;
}

final _safeIdentifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

void _assertSafeIdentifier(String name) {
  if (!_safeIdentifier.hasMatch(name)) {
    throw ArgumentError('Unsafe SQL identifier: $name');
  }
}

Future<void> _addColumnIfMissing(
  Database db,
  String table,
  String column,
  String definition,
) async {
  _assertSafeIdentifier(table);
  _assertSafeIdentifier(column);
  final columns = await db.rawQuery('PRAGMA table_info($table)');
  final exists = columns.any((row) => row['name'] == column);
  if (!exists) {
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }
}

DateTime? _tryParseDate(String? value) {
  if (value == null) return null;
  return DateTime.tryParse(value);
}
