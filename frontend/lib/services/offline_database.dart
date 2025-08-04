import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

class OfflineDatabase {
  static Database? _database;
  static const String _databaseName = 'retail_management_offline.db';
  static const int _databaseVersion = 1;
  static const Uuid _uuid = Uuid();

  // Singleton pattern
  static final OfflineDatabase _instance = OfflineDatabase._internal();
  factory OfflineDatabase() => _instance;
  OfflineDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('OfflineDatabase initialization error: $e');
      // Return a mock database or throw a more specific error
      throw Exception('Failed to initialize offline database: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        username TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        business_id INTEGER,
        is_deleted INTEGER DEFAULT 0,
        last_sync TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        quantity INTEGER NOT NULL,
        category_id INTEGER,
        business_id INTEGER NOT NULL,
        image_url TEXT,
        barcode TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_sync TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        business_id INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        last_sync TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        business_id INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        last_sync TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        customer_id INTEGER,
        total_amount REAL NOT NULL,
        payment_method TEXT,
        business_id INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        last_sync TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Sale items table
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        business_id INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        last_sync TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Inventory transactions table
    await db.execute('''
      CREATE TABLE inventory_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        product_id INTEGER NOT NULL,
        transaction_type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        reason TEXT,
        business_id INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        last_sync TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        local_id INTEGER,
        server_id INTEGER,
        data TEXT NOT NULL,
        business_id INTEGER NOT NULL,
        created_at TEXT,
        retry_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending'
      )
    ''');

    // Businesses table
    await db.execute('''
      CREATE TABLE businesses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        owner_id INTEGER,
        is_active INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        last_sync TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_products_business_id ON products(business_id)');
    await db.execute('CREATE INDEX idx_sales_business_id ON sales(business_id)');
    await db.execute('CREATE INDEX idx_customers_business_id ON customers(business_id)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
    await db.execute('CREATE INDEX idx_sync_queue_business_id ON sync_queue(business_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert(table, data);
  }

  Future<int> update(String table, Map<String, dynamic> data, int id) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, int id) async {
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> query(String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  // Business-specific operations
  Future<List<Map<String, dynamic>>> getProductsByBusiness(int businessId) async {
    return await query('products', 
      where: 'business_id = ? AND is_deleted = 0',
      whereArgs: [businessId],
      orderBy: 'name ASC'
    );
  }

  Future<List<Map<String, dynamic>>> getSalesByBusiness(int businessId) async {
    return await query('sales',
      where: 'business_id = ? AND is_deleted = 0',
      whereArgs: [businessId],
      orderBy: 'created_at DESC'
    );
  }

  Future<List<Map<String, dynamic>>> getCustomersByBusiness(int businessId) async {
    return await query('customers',
      where: 'business_id = ? AND is_deleted = 0',
      whereArgs: [businessId],
      orderBy: 'name ASC'
    );
  }

  // Sync queue operations
  Future<void> addToSyncQueue(String table, String operation, int localId, Map<String, dynamic> data, int businessId) async {
    final db = await database;
    await db.insert('sync_queue', {
      'table_name': table,
      'operation': operation,
      'local_id': localId,
      'data': json.encode(data),
      'business_id': businessId,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'retry_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems(int businessId) async {
    return await query('sync_queue',
      where: 'business_id = ? AND status = ?',
      whereArgs: [businessId, 'pending'],
      orderBy: 'created_at ASC'
    );
  }

  Future<void> updateSyncQueueStatus(int id, String status, {int? serverId}) async {
    final db = await database;
    final updateData = {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (serverId != null) {
      updateData['server_id'] = serverId.toString();
    }
    await db.update('sync_queue', updateData, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetryCount(int id) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE sync_queue 
      SET retry_count = retry_count + 1 
      WHERE id = ?
    ''', [id]);
  }

  // Data integrity and conflict resolution
  String generateHash(Map<String, dynamic> data) {
    final sortedData = Map.fromEntries(
      data.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    final jsonString = json.encode(sortedData);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> markAsDeleted(String table, int id) async {
    final db = await database;
    await db.update(table, {
      'is_deleted': 1,
      'updated_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending'
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSyncStatus(String table, int id, String status) async {
    final db = await database;
    await db.update(table, {
      'sync_status': status,
      'last_sync': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  // Database maintenance
  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue', where: 'status = ?', whereArgs: ['completed']);
  }

  Future<void> resetSyncStatus() async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE products SET sync_status = 'pending' WHERE sync_status = 'synced'
    ''');
    await db.rawUpdate('''
      UPDATE sales SET sync_status = 'pending' WHERE sync_status = 'synced'
    ''');
    await db.rawUpdate('''
      UPDATE customers SET sync_status = 'pending' WHERE sync_status = 'synced'
    ''');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
} 