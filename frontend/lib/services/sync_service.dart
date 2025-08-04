import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'offline_database.dart';
import 'api_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OfflineDatabase _offlineDb = OfflineDatabase();
  final ApiService _apiService = ApiService();
  Timer? _syncTimer;
  bool _isSyncing = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Sync configuration
  static const int _syncIntervalSeconds = 30; // Sync every 30 seconds when online
  static const int _maxRetryAttempts = 3;
  static const Duration _syncTimeout = Duration(seconds: 30);

  // Initialize sync service
  Future<void> initialize() async {
    try {
      // Listen to connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        if (result != ConnectivityResult.none) {
          _startPeriodicSync();
        } else {
          _stopPeriodicSync();
        }
      });

      // Check initial connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        _startPeriodicSync();
      }
    } catch (e) {
      print('SyncService initialization warning: $e');
      // Continue without sync functionality if initialization fails
    }
  }

  // Start periodic sync
  void _startPeriodicSync() {
    _stopPeriodicSync(); // Stop any existing timer
    _syncTimer = Timer.periodic(Duration(seconds: _syncIntervalSeconds), (timer) {
      if (!_isSyncing) {
        syncData();
      }
    });
  }

  // Stop periodic sync
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Main sync method
  Future<void> syncData() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('No internet connection available for sync');
        return;
      }

      // Check if API service is available
      final isConnected = await _apiService.checkConnection();
      if (!isConnected) {
        print('Backend server not available for sync');
        return;
      }

      // Perform bidirectional sync
      await _syncToServer();
      await _syncFromServer();

    } catch (e) {
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Sync local changes to server
  Future<void> _syncToServer() async {
    try {
      // Get all pending sync items
      final pendingItems = await _offlineDb.getPendingSyncItems(1); // Assuming business ID 1 for now
      
      for (final item in pendingItems) {
        await _processSyncItem(item);
      }
    } catch (e) {
      print('Error syncing to server: $e');
    }
  }

  // Process individual sync item
  Future<void> _processSyncItem(Map<String, dynamic> item) async {
    final tableName = item['table_name'];
    final operation = item['operation'];
    final localId = item['local_id'];
    final data = json.decode(item['data']);
    final businessId = item['business_id'];
    final retryCount = item['retry_count'];

    if (retryCount >= _maxRetryAttempts) {
      await _offlineDb.updateSyncQueueStatus(item['id'], 'failed');
      return;
    }

    try {
      switch (operation) {
        case 'create':
          await _createOnServer(tableName, data, businessId, item['id']);
          break;
        case 'update':
          await _updateOnServer(tableName, data, businessId, item['id']);
          break;
        case 'delete':
          await _deleteOnServer(tableName, data, businessId, item['id']);
          break;
      }
    } catch (e) {
      print('Error processing sync item: $e');
      await _offlineDb.incrementRetryCount(item['id']);
    }
  }

  // Create item on server
  Future<void> _createOnServer(String tableName, Map<String, dynamic> data, int businessId, int queueId) async {
    final endpoint = _getEndpointForTable(tableName);
    if (endpoint == null) return;

    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/$endpoint'),
      headers: _apiService.headers,
      body: json.encode(data),
    ).timeout(_syncTimeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final serverId = responseData['id'];
      
      // Update local record with server ID
      await _offlineDb.update(tableName, {'server_id': serverId}, data['id']);
      await _offlineDb.updateSyncStatus(tableName, data['id'], 'synced');
      await _offlineDb.updateSyncQueueStatus(queueId, 'completed', serverId: serverId);
    } else {
      throw Exception('Failed to create on server: ${response.statusCode}');
    }
  }

  // Update item on server
  Future<void> _updateOnServer(String tableName, Map<String, dynamic> data, int businessId, int queueId) async {
    final endpoint = _getEndpointForTable(tableName);
    if (endpoint == null) return;

    final serverId = data['server_id'];
    if (serverId == null) return;

    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/api/$endpoint/$serverId'),
      headers: _apiService.headers,
      body: json.encode(data),
    ).timeout(_syncTimeout);

    if (response.statusCode == 200) {
      await _offlineDb.updateSyncStatus(tableName, data['id'], 'synced');
      await _offlineDb.updateSyncQueueStatus(queueId, 'completed');
    } else {
      throw Exception('Failed to update on server: ${response.statusCode}');
    }
  }

  // Delete item on server
  Future<void> _deleteOnServer(String tableName, Map<String, dynamic> data, int businessId, int queueId) async {
    final endpoint = _getEndpointForTable(tableName);
    if (endpoint == null) return;

    final serverId = data['server_id'];
    if (serverId == null) return;

    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/api/$endpoint/$serverId'),
      headers: _apiService.headers,
    ).timeout(_syncTimeout);

    if (response.statusCode == 200 || response.statusCode == 204) {
      await _offlineDb.updateSyncQueueStatus(queueId, 'completed');
    } else {
      throw Exception('Failed to delete on server: ${response.statusCode}');
    }
  }

  // Sync from server to local
  Future<void> _syncFromServer() async {
    try {
      // Sync products
      await _syncProductsFromServer();
      
      // Sync customers
      await _syncCustomersFromServer();
      
      // Sync sales
      await _syncSalesFromServer();
      
      // Sync categories
      await _syncCategoriesFromServer();
      
    } catch (e) {
      print('Error syncing from server: $e');
    }
  }

  // Sync products from server
  Future<void> _syncProductsFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/products'),
        headers: _apiService.headers,
      ).timeout(_syncTimeout);

      if (response.statusCode == 200) {
        final products = json.decode(response.body);
        for (final product in products) {
          await _upsertProduct(product);
        }
      }
    } catch (e) {
      print('Error syncing products: $e');
    }
  }

  // Sync customers from server
  Future<void> _syncCustomersFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/customers'),
        headers: _apiService.headers,
      ).timeout(_syncTimeout);

      if (response.statusCode == 200) {
        final customers = json.decode(response.body);
        for (final customer in customers) {
          await _upsertCustomer(customer);
        }
      }
    } catch (e) {
      print('Error syncing customers: $e');
    }
  }

  // Sync sales from server
  Future<void> _syncSalesFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/sales'),
        headers: _apiService.headers,
      ).timeout(_syncTimeout);

      if (response.statusCode == 200) {
        final sales = json.decode(response.body);
        for (final sale in sales) {
          await _upsertSale(sale);
        }
      }
    } catch (e) {
      print('Error syncing sales: $e');
    }
  }

  // Sync categories from server
  Future<void> _syncCategoriesFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/categories'),
        headers: _apiService.headers,
      ).timeout(_syncTimeout);

      if (response.statusCode == 200) {
        final categories = json.decode(response.body);
        for (final category in categories) {
          await _upsertCategory(category);
        }
      }
    } catch (e) {
      print('Error syncing categories: $e');
    }
  }

  // Upsert product (insert or update)
  Future<void> _upsertProduct(Map<String, dynamic> product) async {
    final existing = await _offlineDb.query('products', 
      where: 'server_id = ?', 
      whereArgs: [product['id']]
    );

    if (existing.isNotEmpty) {
      // Update existing
      await _offlineDb.update('products', _mapProductData(product), existing.first['id']);
    } else {
      // Insert new
      await _offlineDb.insert('products', _mapProductData(product));
    }
  }

  // Upsert customer
  Future<void> _upsertCustomer(Map<String, dynamic> customer) async {
    final existing = await _offlineDb.query('customers', 
      where: 'server_id = ?', 
      whereArgs: [customer['id']]
    );

    if (existing.isNotEmpty) {
      await _offlineDb.update('customers', _mapCustomerData(customer), existing.first['id']);
    } else {
      await _offlineDb.insert('customers', _mapCustomerData(customer));
    }
  }

  // Upsert sale
  Future<void> _upsertSale(Map<String, dynamic> sale) async {
    final existing = await _offlineDb.query('sales', 
      where: 'server_id = ?', 
      whereArgs: [sale['id']]
    );

    if (existing.isNotEmpty) {
      await _offlineDb.update('sales', _mapSaleData(sale), existing.first['id']);
    } else {
      await _offlineDb.insert('sales', _mapSaleData(sale));
    }
  }

  // Upsert category
  Future<void> _upsertCategory(Map<String, dynamic> category) async {
    final existing = await _offlineDb.query('categories', 
      where: 'server_id = ?', 
      whereArgs: [category['id']]
    );

    if (existing.isNotEmpty) {
      await _offlineDb.update('categories', _mapCategoryData(category), existing.first['id']);
    } else {
      await _offlineDb.insert('categories', _mapCategoryData(category));
    }
  }

  // Data mapping methods
  Map<String, dynamic> _mapProductData(Map<String, dynamic> product) {
    return {
      'server_id': product['id'],
      'name': product['name'],
      'description': product['description'],
      'price': product['price']?.toDouble() ?? 0.0,
      'cost': product['cost']?.toDouble() ?? 0.0,
      'quantity': product['quantity'] ?? 0,
      'category_id': product['category_id'],
      'business_id': product['business_id'] ?? 1,
      'image_url': product['image_url'],
      'barcode': product['barcode'],
      'sync_status': 'synced',
      'last_sync': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _mapCustomerData(Map<String, dynamic> customer) {
    return {
      'server_id': customer['id'],
      'name': customer['name'],
      'email': customer['email'],
      'phone': customer['phone'],
      'address': customer['address'],
      'business_id': customer['business_id'] ?? 1,
      'sync_status': 'synced',
      'last_sync': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _mapSaleData(Map<String, dynamic> sale) {
    return {
      'server_id': sale['id'],
      'customer_id': sale['customer_id'],
      'total_amount': sale['total_amount']?.toDouble() ?? 0.0,
      'payment_method': sale['payment_method'],
      'business_id': sale['business_id'] ?? 1,
      'sync_status': 'synced',
      'last_sync': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _mapCategoryData(Map<String, dynamic> category) {
    return {
      'server_id': category['id'],
      'name': category['name'],
      'description': category['description'],
      'business_id': category['business_id'] ?? 1,
      'sync_status': 'synced',
      'last_sync': DateTime.now().toIso8601String(),
    };
  }

  // Get endpoint for table
  String? _getEndpointForTable(String tableName) {
    switch (tableName) {
      case 'products':
        return 'products';
      case 'customers':
        return 'customers';
      case 'sales':
        return 'sales';
      case 'categories':
        return 'categories';
      default:
        return null;
    }
  }

  // Manual sync trigger
  Future<void> manualSync() async {
    await syncData();
  }

  // Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    final pendingItems = await _offlineDb.getPendingSyncItems(1);
    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected = await _apiService.checkConnection();

    return {
      'isOnline': connectivityResult != ConnectivityResult.none,
      'serverConnected': isConnected,
      'pendingItems': pendingItems.length,
      'lastSync': DateTime.now().toIso8601String(),
      'isSyncing': _isSyncing,
    };
  }

  // Dispose resources
  void dispose() {
    _stopPeriodicSync();
    _connectivitySubscription?.cancel();
  }
} 