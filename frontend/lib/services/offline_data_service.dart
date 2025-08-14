import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'offline_database.dart';
import 'sync_service.dart';
import 'api_service.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale.dart';

class OfflineDataService {
  static final OfflineDataService _instance = OfflineDataService._internal();
  factory OfflineDataService() => _instance;
  OfflineDataService._internal();

  final OfflineDatabase _offlineDb = OfflineDatabase();
  final SyncService _syncService = SyncService();
  final ApiService _apiService = ApiService();

  // Initialize the service
  Future<void> initialize() async {
    try {
      await _syncService.initialize();
    } catch (e) {
      print('OfflineDataService initialization warning: $e');
      // Continue without offline functionality if initialization fails
    }
  }

  // Check if online
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return false;
    
    return await _apiService.checkConnection();
  }

  // PRODUCTS
  Future<List<Product>> getProducts({int? businessId}) async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected) {
        // Try to get from server first
        try {
          final response = await http.get(
            Uri.parse('${ApiService.baseUrl}/api/products'),
            headers: _apiService.headers,
          );

          if (response.statusCode == 200) {
            final products = json.decode(response.body);
            final productList = products.map<Product>((json) => Product.fromJson(json)).toList();
            
            // Cache in local database
            for (final product in productList) {
              await _cacheProduct(product);
            }
            
            return productList;
          }
        } catch (e) {
          print('Failed to fetch products from server: $e');
        }
      }

      // Fallback to local database
      final localProducts = await _offlineDb.getProductsByBusiness(businessId ?? 1);
      return localProducts.map<Product>((json) => Product.fromJson(json)).toList();
    } catch (e) {
      print('Error getting products: $e');
      return [];
    }
  }

  Future<Product?> createProduct(Product product) async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected) {
        // Try to create on server first
        try {
          final response = await http.post(
            Uri.parse('${ApiService.baseUrl}/api/products'),
            headers: _apiService.headers,
            body: json.encode(product.toJson()),
          );

          if (response.statusCode == 201) {
            final createdProduct = Product.fromJson(json.decode(response.body));
            await _cacheProduct(createdProduct);
            return createdProduct;
          }
        } catch (e) {
          print('Failed to create product on server: $e');
        }
      }

      // Create locally and queue for sync
      final productData = product.toJson();
      productData['sync_status'] = 'pending';
      
      final localId = await _offlineDb.insert('products', productData);
      await _offlineDb.addToSyncQueue('products', 'create', localId, productData, product.businessId);
      
      return product.copyWith(id: localId);
    } catch (e) {
      print('Error creating product: $e');
      return null;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected && product.id != null) {
        // Try to update on server first
        try {
          final response = await http.put(
            Uri.parse('${ApiService.baseUrl}/api/products/${product.id}'),
            headers: _apiService.headers,
            body: json.encode(product.toJson()),
          );

          if (response.statusCode == 200) {
            await _cacheProduct(product);
            return true;
          }
        } catch (e) {
          print('Failed to update product on server: $e');
        }
      }

      // Update locally and queue for sync
      final productData = product.toJson();
      productData['sync_status'] = 'pending';
      
      await _offlineDb.update('products', productData, product.id!);
      await _offlineDb.addToSyncQueue('products', 'update', product.id!, productData, product.businessId);
      
      return true;
    } catch (e) {
      print('Error updating product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(int productId, int businessId) async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected) {
        // Try to delete on server first
        try {
          final response = await http.delete(
            Uri.parse('${ApiService.baseUrl}/api/products/$productId'),
            headers: _apiService.headers,
          );

          if (response.statusCode == 200 || response.statusCode == 204) {
            await _offlineDb.markAsDeleted('products', productId);
            return true;
          }
        } catch (e) {
          print('Failed to delete product on server: $e');
        }
      }

      // Mark as deleted locally and queue for sync
      await _offlineDb.markAsDeleted('products', productId);
      await _offlineDb.addToSyncQueue('products', 'delete', productId, {'id': productId}, businessId);
      
      return true;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }

  // CUSTOMERS
  Future<List<Customer>> getCustomers({int? businessId}) async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected) {
        try {
          final response = await http.get(
            Uri.parse('${ApiService.baseUrl}/api/customers'),
            headers: _apiService.headers,
          );

          if (response.statusCode == 200) {
            final customers = json.decode(response.body);
            final customerList = customers.map<Customer>((json) => Customer.fromJson(json)).toList();
            
            for (final customer in customerList) {
              await _cacheCustomer(customer);
            }
            
            return customerList;
          }
        } catch (e) {
          print('Failed to fetch customers from server: $e');
        }
      }

      final localCustomers = await _offlineDb.getCustomersByBusiness(businessId ?? 1);
      return localCustomers.map<Customer>((json) => Customer.fromJson(json)).toList();
    } catch (e) {
      print('Error getting customers: $e');
      return [];
    }
  }

  Future<Customer?> createCustomer(Customer customer) async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected) {
        try {
          final response = await http.post(
            Uri.parse('${ApiService.baseUrl}/api/customers'),
            headers: _apiService.headers,
            body: json.encode(customer.toJson()),
          );

          if (response.statusCode == 201) {
            final createdCustomer = Customer.fromJson(json.decode(response.body));
            await _cacheCustomer(createdCustomer);
            return createdCustomer;
          }
        } catch (e) {
          print('Failed to create customer on server: $e');
        }
      }

      final customerData = customer.toJson();
      customerData['sync_status'] = 'pending';
      
      final localId = await _offlineDb.insert('customers', customerData);
      await _offlineDb.addToSyncQueue('customers', 'create', localId, customerData, customer.businessId);
      
      return customer.copyWith(id: localId.toString());
    } catch (e) {
      print('Error creating customer: $e');
      return null;
    }
  }

  Future<bool> updateCustomer(Customer customer) async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected && customer.id != null) {
        try {
          final customerId = customer.id is int ? customer.id : int.tryParse(customer.id ?? '') ?? 0;
          final response = await http.put(
            Uri.parse('${ApiService.baseUrl}/api/customers/$customerId'),
            headers: _apiService.headers,
            body: json.encode(customer.toJson()),
          );

          if (response.statusCode == 200) {
            await _cacheCustomer(customer);
            return true;
          }
        } catch (e) {
          print('Failed to update customer on server: $e');
        }
      }

      final customerData = customer.toJson();
      customerData['sync_status'] = 'pending';
      
      final customerId = customer.id is int ? customer.id : int.tryParse(customer.id ?? '') ?? 0;
      await _offlineDb.update('customers', customerData, customerId as int);
      await _offlineDb.addToSyncQueue('customers', 'update', customerId as int, customerData, customer.businessId);
      
      return true;
    } catch (e) {
      print('Error updating customer: $e');
      return false;
    }
  }

  Future<bool> deleteCustomer(int customerId, int businessId) async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected) {
        try {
          final response = await http.delete(
            Uri.parse('${ApiService.baseUrl}/api/customers/$customerId'),
            headers: _apiService.headers,
          );

          if (response.statusCode == 200 || response.statusCode == 204) {
            await _offlineDb.markAsDeleted('customers', customerId);
            return true;
          }
        } catch (e) {
          print('Failed to delete customer on server: $e');
        }
      }

      await _offlineDb.markAsDeleted('customers', customerId);
      await _offlineDb.addToSyncQueue('customers', 'delete', customerId, {'id': customerId}, businessId);
      
      return true;
    } catch (e) {
      print('Error deleting customer: $e');
      return false;
    }
  }

  // SALES
  Future<List<Sale>> getSales({int? businessId}) async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected) {
        try {
          final response = await http.get(
            Uri.parse('${ApiService.baseUrl}/api/sales'),
            headers: _apiService.headers,
          );

          if (response.statusCode == 200) {
            final sales = json.decode(response.body);
            final saleList = sales.map<Sale>((json) => Sale.fromJson(json)).toList();
            
            for (final sale in saleList) {
              await _cacheSale(sale);
            }
            
            return saleList;
          }
        } catch (e) {
          print('Failed to fetch sales from server: $e');
        }
      }

      final localSales = await _offlineDb.getSalesByBusiness(businessId ?? 1);
      return localSales.map<Sale>((json) => Sale.fromJson(json)).toList();
    } catch (e) {
      print('Error getting sales: $e');
      return [];
    }
  }

  Future<Sale?> createSale(Sale sale) async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected) {
        try {
          final response = await http.post(
            Uri.parse('${ApiService.baseUrl}/api/sales'),
            headers: _apiService.headers,
            body: json.encode(sale.toJson()),
          );

          if (response.statusCode == 201) {
            final createdSale = Sale.fromJson(json.decode(response.body));
            await _cacheSale(createdSale);
            return createdSale;
          }
        } catch (e) {
          print('Failed to create sale on server: $e');
        }
      }

      final saleData = sale.toJson();
      saleData['sync_status'] = 'pending';
      
      final localId = await _offlineDb.insert('sales', saleData);
      await _offlineDb.addToSyncQueue('sales', 'create', localId, saleData, sale.businessId);
      
      return sale.copyWith(id: localId);
    } catch (e) {
      print('Error creating sale: $e');
      return null;
    }
  }

  // Caching methods
  Future<void> _cacheProduct(Product product) async {
    final productData = product.toJson();
    productData['sync_status'] = 'synced';
    productData['last_sync'] = DateTime.now().toIso8601String();
    
    final existing = await _offlineDb.query('products', 
      where: 'server_id = ?', 
      whereArgs: [product.id]
    );

    if (existing.isNotEmpty) {
      await _offlineDb.update('products', productData, existing.first['id']);
    } else {
      await _offlineDb.insert('products', productData);
    }
  }

  Future<void> _cacheCustomer(Customer customer) async {
    final customerData = customer.toJson();
    customerData['sync_status'] = 'synced';
    customerData['last_sync'] = DateTime.now().toIso8601String();
    
    final customerId = customer.id is int ? customer.id : int.tryParse(customer.id ?? '') ?? 0;
    final existing = await _offlineDb.query('customers', 
      where: 'server_id = ?', 
      whereArgs: [customerId as int]
    );

    if (existing.isNotEmpty) {
      await _offlineDb.update('customers', customerData, existing.first['id']);
    } else {
      await _offlineDb.insert('customers', customerData);
    }
  }

  Future<void> _cacheSale(Sale sale) async {
    final saleData = sale.toJson();
    saleData['sync_status'] = 'synced';
    saleData['last_sync'] = DateTime.now().toIso8601String();
    
    final existing = await _offlineDb.query('sales', 
      where: 'server_id = ?', 
      whereArgs: [sale.id]
    );

    if (existing.isNotEmpty) {
      await _offlineDb.update('sales', saleData, existing.first['id']);
    } else {
      await _offlineDb.insert('sales', saleData);
    }
  }

  // Sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    return await _syncService.getSyncStatus();
  }

  // Manual sync
  Future<void> manualSync() async {
    await _syncService.manualSync();
  }

  // Clear local data
  Future<void> clearLocalData() async {
    await _offlineDb.clearSyncQueue();
  }

  // Get categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final isConnected = await isOnline();
      
      if (isConnected) {
        // Try to get from server first
        try {
          final response = await http.get(
            Uri.parse('${ApiService.baseUrl}/api/categories'),
            headers: _apiService.headers,
          );

          if (response.statusCode == 200) {
            final categories = json.decode(response.body);
            final categoryList = categories.map<Map<String, dynamic>>((json) => json as Map<String, dynamic>).toList();
            
            // Cache in local database
            for (final category in categoryList) {
              await _cacheCategory(category);
            }
            
            return categoryList;
          }
        } catch (e) {
          print('Failed to fetch categories from server: $e');
        }
      }

      // Fallback to local database
      return await _offlineDb.getCategoriesByBusiness(1);
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }



  // Cache category
  Future<void> _cacheCategory(Map<String, dynamic> category) async {
    final categoryData = Map<String, dynamic>.from(category);
    categoryData['sync_status'] = 'synced';
    categoryData['last_sync'] = DateTime.now().toIso8601String();
    
    final existing = await _offlineDb.query('categories', 
      where: 'server_id = ?', 
      whereArgs: [category['id']]
    );

    if (existing.isNotEmpty) {
      await _offlineDb.update('categories', categoryData, existing.first['id']);
    } else {
      await _offlineDb.insert('categories', categoryData);
    }
  }
} 