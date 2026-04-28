import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:retail_management/models/user.dart';
import 'package:retail_management/models/product.dart';
import 'package:retail_management/models/customer.dart';
import 'package:retail_management/models/sale.dart';
import 'package:retail_management/models/inventory_transaction.dart';
import 'package:retail_management/utils/type_converter.dart';
import 'package:retail_management/services/network_service.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:retail_management/services/notification_service.dart';
import 'package:toast/toast.dart';

class ApiService {
  static const String baseUrl = 'https://api.kismayoict.com';
  String? _token;
  final NetworkService _networkService = NetworkService();
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Map<String, String> get headers => _headers;

  void setToken(String token) {
    _token = token;
     // Debug log
  }

  void clearToken() {
    _token = null;
     // Debug log
  }

  String? get token => _token;

  /// Execute HTTP request with network error handling and retry logic
  Future<http.Response> _executeRequest(
    Future<http.Response> Function() request, {
    BuildContext? context,
  }) async {
    return await _networkService.executeRequest(
      request,
      maxRetries: 1,
      retryDelay: const Duration(seconds: 2),
      context: context,
    );
  }

  // Health check
  Future<bool> checkConnection({BuildContext? context}) async {
    try {
      final response = await _executeRequest(
        () => http.get(
          Uri.parse('$baseUrl/api/health'),
          headers: _headers,
        ),
        context: context,
      );
      return response.statusCode == 200;
    } catch (e) {
            return false;
    }
  }

  // Authentication
  Future<Map<String, dynamic>> login(String email, String password, {BuildContext? context}) async {
    try {
      final response = await _executeRequest(
        () => http.post(
          Uri.parse('$baseUrl/api/auth/login'),
          headers: _headers,
          body: json.encode({
            'email': email,
            'password': password,
          }),
        ),
        context: context,
      );

                  if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to login');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<Map<String, dynamic>> loginWithUsername(String username, String password, {BuildContext? context}) async {
    try {
      final response = await _executeRequest(
        () => http.post(
          Uri.parse('$baseUrl/api/auth/login'),
          headers: _headers,
          body: json.encode({
            'username': username,
            'password': password,
          }),
        ),
        context: context,
      );

                  if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to login');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<Map<String, dynamic>> loginWithIdentifier(String identifier, String password, {BuildContext? context}) async {
    try {
      final response = await _executeRequest(
        () => http.post(
          Uri.parse('$baseUrl/api/auth/login'),
          headers: _headers,
          body: json.encode({
            'identifier': identifier,
            'password': password,
          }),
        ),
        context: context,
      );

                  if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to login');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
    String role,
    {String? adminCode, String? businessId, BuildContext? context}
  ) async {
    try {
      final body = {
        'username': username,
        'email': email,
        'password': password,
        'role': role,
      };
      
      // Add admin code if provided (for superadmin registration)
      if (adminCode != null) {
        body['adminCode'] = adminCode;
      }
      
      // Add business ID if provided (for non-superadmin registration)
      if (businessId != null) {
        body['businessId'] = businessId;
      }

      final response = await _executeRequest(
        () => http.post(
          Uri.parse('$baseUrl/api/auth/register'),
          headers: _headers,
          body: json.encode(body),
        ),
        context: context,
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to register');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<User> getProfile({BuildContext? context}) async {
    try {
      final response = await _executeRequest(
        () => http.get(
          Uri.parse('$baseUrl/api/auth/me'),
          headers: _headers,
        ),
        context: context,
      );

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get profile: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<User> updateProfile({
    String? username,
    String? email,
    String? currentPassword,
    String? newPassword,
    String? language,
  }) async {
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (email != null) data['email'] = email;
    if (currentPassword != null) data['currentPassword'] = currentPassword;
    if (newPassword != null) data['newPassword'] = newPassword;
    if (language != null) data['language'] = language;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/auth/profile'),
        headers: _headers,
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update profile: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Products
  // Paginated queries
  Future<Map<String, dynamic>> getProductsPaged({int page = 1, int limit = 50, String? search, int? categoryId, bool lowStock = false, BuildContext? context}) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category_id'] = categoryId.toString();
    if (lowStock) params['low_stock'] = 'true';
    final uri = Uri.parse('$baseUrl/api/products/paged').replace(queryParameters: params);
    final response = await _executeRequest(() => http.get(uri, headers: _headers), context: context);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List).map((j) => Product.fromJson(Map<String, dynamic>.from(j))).toList();
      return {
        'items': items,
        'total': data['total'] ?? 0,
        'page': data['page'] ?? page,
        'limit': data['limit'] ?? limit,
      };
    }
    throw Exception('Failed to get products (paged): ${response.body}');
  }

  Future<Map<String, dynamic>> getAllProductsPaged({int page = 1, int limit = 50, String? search, int? categoryId, bool lowStock = false, int? deleted, BuildContext? context}) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category_id'] = categoryId.toString();
    if (lowStock) params['low_stock'] = 'true';
    if (deleted != null) params['deleted'] = deleted.toString(); // 0,1 or omit for all
    final uri = Uri.parse('$baseUrl/api/products/all/paged').replace(queryParameters: params);
    final response = await _executeRequest(() => http.get(uri, headers: _headers), context: context);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List).map((j) => Product.fromJson(Map<String, dynamic>.from(j))).toList();
      return {
        'items': items,
        'total': data['total'] ?? 0,
        'page': data['page'] ?? page,
        'limit': data['limit'] ?? limit,
      };
    }
    throw Exception('Failed to get all products (paged): ${response.body}');
  }

  Future<Map<String, dynamic>> bulkImportProducts({Uint8List? webBytes, String? webFilename, File? file, bool dryRun = true, String upsertBy = 'sku', bool categoryCreate = true, BuildContext? context}) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/products/bulk-import'),
      );
      final multipartHeaders = Map<String, String>.from(_headers);
      multipartHeaders.remove('Content-Type');
      request.headers.addAll(multipartHeaders);

      final options = {
        'dryRun': dryRun,
        'upsertBy': upsertBy,
        'category_create': categoryCreate,
      };
      request.fields['options'] = json.encode(options);

      if (kIsWeb && webBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            webBytes,
            filename: webFilename ?? 'products.xlsx',
          ),
        );
      } else if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path),
        );
      } else {
        throw Exception('No Excel file provided');
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Bulk import failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stack) {
                  rethrow;
    }
  }

  Future<List<Product>> getProducts({BuildContext? context}) async {
    try {
            final response = await _executeRequest(
        () => http.get(
          Uri.parse('$baseUrl/api/products'),
          headers: _headers,
        ),
        context: context,
      );

                  if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
                // Debug: Print first product's raw JSON
        if (data.isNotEmpty) {
                            }
        
        final products = data.map((json) => Product.fromJson(json)).toList();
                // Debug: Print first product's parsed data
        if (products.isNotEmpty) {
          final firstProduct = products.first;
                                                }
        
                return products;
      } else {
                        throw Exception('Failed to get products: ${response.body}');
      }
    } catch (e) {
                  rethrow;
    }
  }

  // Get all products including deleted ones (for inventory management)
  Future<List<Product>> getAllProducts() async {
    try {
            final response = await http.get(
        Uri.parse('$baseUrl/api/products/all'),
        headers: _headers,
      );

                  if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
                // Debug: Print first product's raw JSON
        if (data.isNotEmpty) {
                                      }
        
        final products = data.map((json) => Product.fromJson(json)).toList();
                // Debug: Print first product's parsed data
        if (products.isNotEmpty) {
          final firstProduct = products.first;
                                                          }
        
                return products;
      } else {
                        throw Exception('Failed to get all products: ${response.body}');
      }
    } catch (e) {
                  rethrow;
    }
  }

  Future<Product> getProduct(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/products/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return Product.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get product: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<Product> createProduct(Map<String, dynamic> productData, {File? imageFile, Uint8List? webImageBytes, String? webImageName}) async {
        try {
      if ((kIsWeb && webImageBytes != null) || imageFile != null) {
        // Multipart request for image upload
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/products'),
        );
        final multipartHeaders = Map<String, String>.from(_headers);
        multipartHeaders.remove('Content-Type');
        request.headers.addAll(multipartHeaders);
        productData.forEach((key, value) {
          // Send all values including null to allow clearing fields like category_id
          request.fields[key] = value?.toString() ?? '';
        });
        if (kIsWeb && webImageBytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'image',
              webImageBytes,
              filename: webImageName ?? 'upload.png',
            ),
          );
        } else if (imageFile != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'image',
              imageFile.path,
            ),
          );
        }
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
                if (response.statusCode == 201) {
          final data = json.decode(response.body);
          return await getProduct(data['productId']);
        } else {
                    throw Exception('Failed to create product: ${response.body}');
        }
      } else {
        // Regular JSON request without image
        final response = await http.post(
          Uri.parse('$baseUrl/api/products'),
          headers: _headers,
          body: json.encode(productData),
        );
                if (response.statusCode == 201) {
          final data = json.decode(response.body);
          return await getProduct(data['productId']);
        } else {
                    throw Exception('Failed to create product: ${response.body}');
        }
      }
    } catch (e, stack) {
                  rethrow;
    }
  }

  Future<void> updateProduct(int id, Map<String, dynamic> productData, {File? imageFile, Uint8List? webImageBytes, String? webImageName}) async {
        try {
      if ((kIsWeb && webImageBytes != null) || imageFile != null) {
        var request = http.MultipartRequest(
          'PUT',
          Uri.parse('$baseUrl/api/products/$id'),
        );
        final multipartHeaders = Map<String, String>.from(_headers);
        multipartHeaders.remove('Content-Type');
        request.headers.addAll(multipartHeaders);
        productData.forEach((key, value) {
          // Send all values including null to allow clearing fields like category_id
          request.fields[key] = value?.toString() ?? '';
        });
        if (kIsWeb && webImageBytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'image',
              webImageBytes,
              filename: webImageName ?? 'upload.png',
            ),
          );
        } else if (imageFile != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'image',
              imageFile.path,
            ),
          );
        }
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
                if (response.statusCode != 200) {
                    throw Exception('Failed to update product: ${response.body}');
        }
      } else {
        final response = await http.put(
          Uri.parse('$baseUrl/api/products/$id'),
          headers: _headers,
          body: json.encode(productData),
        );
                if (response.statusCode != 200) {
                    throw Exception('Failed to update product: ${response.body}');
        }
      }
    } catch (e, stack) {
                  rethrow;
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/products/$id'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete product: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<void> restoreProduct(int id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/products/$id/restore'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to restore product: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Customers
  Future<List<Customer>> getCustomers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/customers'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Customer.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get customers: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<Customer> createCustomer(Map<String, dynamic> customerData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/customers'),
        headers: _headers,
        body: json.encode(customerData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return Customer.fromJson(data);
      } else {
        throw Exception('Failed to create customer: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Sales
  Future<List<Sale>> getSales() async {
    try {
            final response = await http.get(
        Uri.parse('$baseUrl/api/sales'),
        headers: _headers,
      );

            if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
                return data.map((json) => Sale.fromJson(json)).toList();
      } else {
                throw Exception('Failed to get sales: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sales'),
        headers: _headers,
        body: json.encode(saleData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to create sale: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<Map<String, dynamic>> getSale(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sales/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return TypeConverter.safeToMap(json.decode(response.body));
      } else {
        throw Exception('Failed to get sale: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Inventory
  // Get enhanced inventory transactions for PDF export
  Future<List<Map<String, dynamic>>> getInventoryTransactionsForPdf([Map<String, dynamic>? filters]) async {
    try {
      final queryParams = <String, String>{};
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            queryParams[key] = value.toString();
          }
        });
      }
            final uri = Uri.parse('$baseUrl/api/inventory/transactions/pdf').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return TypeConverter.safeToList(data);
      } else {
        throw Exception('Failed to get enhanced inventory transactions: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<Map<String, dynamic>> getInventoryTransactions([Map<String, dynamic>? filters]) async {
    try {
      final queryParams = <String, String>{};
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            queryParams[key] = value.toString();
          }
        });
      }
            final uri = Uri.parse('$baseUrl/api/inventory/transactions').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to get inventory transactions: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<InventoryTransaction> createInventoryTransaction(Map<String, dynamic> transactionData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/inventory/transactions'),
        headers: _headers,
        body: json.encode(transactionData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return InventoryTransaction.fromJson(data);
      } else {
        throw Exception('Failed to create inventory transaction: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Reports
  Future<Map<String, dynamic>> getSalesReport({
    String? startDate,
    String? endDate,
    String groupBy = 'day',
    String? userId,
  }) async {
    try {
      final queryParams = <String, String>{'group_by': groupBy};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (userId != null && userId != 'all') queryParams['user_id'] = userId;
            final uri = Uri.parse('$baseUrl/api/sales/report').replace(queryParameters: queryParams);
      
                                    final response = await http.get(uri, headers: _headers);

                  if (response.statusCode == 200) {
        return TypeConverter.safeToMap(json.decode(response.body));
      } else {
        throw Exception('Failed to get sales report: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<Map<String, dynamic>> getInventoryReport({
    String? startDate, 
    String? endDate, 
    int? categoryId, 
    int? productId
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      if (productId != null) queryParams['product_id'] = productId.toString();
      
      final uri = Uri.parse('$baseUrl/api/inventory/value-report').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        return TypeConverter.safeToMap(json.decode(response.body));
      } else {
        throw Exception('Failed to get inventory report: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Get business details for PDF generation
  Future<Map<String, dynamic>> getBusinessDetails(int businessId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/business/$businessId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TypeConverter.safeToMap(data['data'] ?? {});
      } else {
        throw Exception('Failed to get business details: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Get all businesses (for superadmin)
  Future<List<Map<String, dynamic>>> getBusinesses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/businesses'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['businesses'] ?? []);
      } else {
                throw Exception('Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Get businesses assigned to a specific store
  Future<List<Map<String, dynamic>>> getBusinessesAssignedToStore(int storeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/stores/$storeId/businesses'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['businesses'] ?? []);
      } else {
                throw Exception('Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/categories'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return TypeConverter.safeToList(data);
      } else {
        throw Exception('Failed to get categories: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> categoryData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/categories'),
        headers: _headers,
        body: json.encode(categoryData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to create category: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<void> updateCategory(int id, Map<String, dynamic> categoryData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/categories/$id'),
        headers: _headers,
        body: json.encode(categoryData),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update category: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/categories/$id'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete category: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTopProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sales/top-products'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return TypeConverter.safeToList(data);
      } else {
        throw Exception('Failed to get top products: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Credit Report
  // If this endpoint fails, the frontend will fallback to using the creditSummary from the main sales report.
  Future<Map<String, dynamic>> getCreditReport({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      final uri = Uri.parse('$baseUrl/api/sales/credit-report').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        return TypeConverter.safeToMap(json.decode(response.body));
      } else {
        throw Exception('Failed to get credit report: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Get all transactions for a specific customer (for invoice generation)
  Future<Map<String, dynamic>> getCustomerTransactions({
    required int customerId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      String url = '$baseUrl/api/sales/customer/$customerId/all-transactions';
      List<String> queryParams = [];
      
      if (startDate != null) {
        queryParams.add('start_date=$startDate');
      }
      if (endDate != null) {
        queryParams.add('end_date=$endDate');
      }
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get customer transactions: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Get credit customers
  Future<List<Map<String, dynamic>>> getCreditCustomers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sales/credit-customers'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['customers'] ?? []);
      } else {
        throw Exception('Failed to get credit customers: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Get customer credit transactions (credit sales and payment history)
  Future<Map<String, dynamic>> getCustomerCreditTransactions(int customerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sales/customer/$customerId/credit-transactions'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return TypeConverter.safeToMap(json.decode(response.body));
      } else {
        throw Exception('Failed to get customer credit transactions: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Pay a credit sale (partial payments supported)
  Future<Map<String, dynamic>> payCreditSale(int saleId, double amount, {required String paymentMethod}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/sales/$saleId/pay'),
      headers: _headers,
      body: json.encode({'amount': amount, 'payment_method': paymentMethod}),
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to pay credit sale');
    }
    return TypeConverter.safeToMap(json.decode(response.body));
  }

  // Cancel/Refund a sale transaction
  Future<Map<String, dynamic>> cancelSale(int saleId, String reason, {String? refundMethod}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/sales/$saleId/cancel'),
      headers: _headers,
      body: json.encode({
        'reason': reason,
        if (refundMethod != null) 'refund_method': refundMethod,
      }),
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to cancel sale');
    }
    return TypeConverter.safeToMap(json.decode(response.body));
  }

  // Get sale items for a specific sale
  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sales/$saleId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        return items.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception('Failed to get sale items: ${response.body}');
      }
    } catch (e) {
            rethrow;
    }
  }

  // --- ACCOUNTING: EXPENSES ---
  Future<List<Map<String, dynamic>>> getExpenses({String? startDate, String? endDate, String? category, String? vendor}) async {
    final query = <String, String>{};
    if (startDate != null) query['start_date'] = startDate;
    if (endDate != null) query['end_date'] = endDate;
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (vendor != null && vendor.isNotEmpty) query['vendor'] = vendor;
    final uri = Uri.parse('$baseUrl/api/admin/accounting/expenses').replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _headers);
    
    if (response.statusCode == 200) {
      return TypeConverter.safeToList(json.decode(response.body));
    } else {
      throw Exception('Failed to load expenses');
    }
  }

  Future<void> addExpense(Map<String, dynamic> expense) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/accounting/expenses'),
      headers: _headers,
      body: json.encode(expense),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add expense');
    }
  }

  Future<void> updateExpense(int id, Map<String, dynamic> expense) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/admin/accounting/expenses/$id'),
      headers: _headers,
      body: json.encode(expense),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update expense');
    }
  }

  Future<void> deleteExpense(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/admin/accounting/expenses/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete expense');
    }
  }

  // --- ACCOUNTING: EXPENSES SUMMARY ---
  Future<Map<String, dynamic>> getExpensesSummary({String? startDate, String? endDate}) async {
    final params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final uri = Uri.parse('$baseUrl/api/admin/accounting/expenses/summary').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToMap(json.decode(response.body));
    } else {
      throw Exception('Failed to load expenses summary');
    }
  }

  // --- ACCOUNTING: EXPENSE CATEGORIES ---
  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/accounting/expense-categories'), headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToList(json.decode(response.body));
    } else {
      throw Exception('Failed to load expense categories');
    }
  }

  // --- ACCOUNTING: VENDORS ---
  Future<List<Map<String, dynamic>>> getVendors() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/accounting/vendors'), headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToList(json.decode(response.body));
    } else {
      throw Exception('Failed to load vendors');
    }
  }

  Future<void> addVendor(Map<String, dynamic> vendor) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/accounting/vendors'),
      headers: _headers,
      body: json.encode(vendor),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add vendor');
    }
  }

  Future<void> updateVendor(int id, Map<String, dynamic> vendor) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/admin/accounting/vendors/$id'),
      headers: _headers,
      body: json.encode(vendor),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update vendor');
    }
  }

  Future<void> deleteVendor(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/admin/accounting/vendors/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete vendor');
    }
  }

  // --- ACCOUNTING: PAYABLES ---
  Future<List<Map<String, dynamic>>> getPayables() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/accounting/payables'), headers: _headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load payables');
    }
  }

  Future<void> addPayable(Map<String, dynamic> payable) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/accounting/payables'),
      headers: _headers,
      body: json.encode(payable),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add payable');
    }
  }

  Future<void> updatePayable(int id, Map<String, dynamic> payable) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/admin/accounting/payables/$id'),
      headers: _headers,
      body: json.encode(payable),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update payable');
    }
  }

  Future<void> deletePayable(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/admin/accounting/payables/$id'),
      headers: _headers,
    );
    if (response.statusCode != 0) {
      throw Exception('Failed to delete payable');
    }
  }

  // --- ACCOUNTING: CASH FLOWS ---
  Future<List<Map<String, dynamic>>> getCashFlows() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/accounting/cash-flows'), headers: _headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load cash flows');
    }
  }

  Future<void> addCashFlow(Map<String, dynamic> cashFlow) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/accounting/cash-flows'),
      headers: _headers,
      body: json.encode(cashFlow),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add cash flow');
    }
  }

  // --- ACCOUNTING: REPORTS ---
  Future<Map<String, dynamic>> getProfitLoss() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/accounting/profit-loss'), headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToMap(json.decode(response.body));
    } else {
      throw Exception('Failed to load profit & loss report');
    }
  }

  Future<Map<String, dynamic>> getBalanceSheet() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/accounting/balance-sheet'), headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToMap(json.decode(response.body));
    } else {
      throw Exception('Failed to load balance sheet');
    }
  }

  Future<List<Map<String, dynamic>>> getGeneralLedger() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/accounting/general-ledger'), headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToList(json.decode(response.body));
    } else {
      throw Exception('Failed to load general ledger');
    }
  }

  Future<Map<String, dynamic>> getCashFlowReport() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/accounting/cash-flow-report'), headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToMap(json.decode(response.body));
    } else {
      throw Exception('Failed to load cash flow report');
    }
  }

  // --- ADVANCED REPORTS (QuickBooks-style) ---
  Future<List<Map<String, dynamic>>> getProductProfitReport({String? startDate, String? endDate}) async {
    final params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final uri = Uri.parse('$baseUrl/api/admin/accounting/reports/product-profit').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToList(json.decode(response.body));
    } else {
      throw Exception('Failed to load product profit report');
    }
  }

  Future<List<Map<String, dynamic>>> getPeriodProfitReport({String? startDate, String? endDate, String groupBy = 'day'}) async {
    final params = <String, String>{'group_by': groupBy};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final uri = Uri.parse('$baseUrl/api/admin/accounting/reports/period-profit').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToList(json.decode(response.body));
    } else {
      throw Exception('Failed to load period profit report');
    }
  }

  Future<List<Map<String, dynamic>>> getTopProductsReport({String? startDate, String? endDate, int limit = 10}) async {
    final params = <String, String>{'limit': limit.toString()};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final uri = Uri.parse('$baseUrl/api/admin/accounting/reports/top-products').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToList(json.decode(response.body));
    } else {
      throw Exception('Failed to load top products report');
    }
  }

  Future<List<Map<String, dynamic>>> getDetailedTransactionsReport({String? startDate, String? endDate, String? productId, String? customerId, String? vendorId, String? type}) async {
    final params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (productId != null) params['product_id'] = productId;
    if (customerId != null) params['customer_id'] = customerId;
    if (vendorId != null) params['vendor_id'] = vendorId;
    if (type != null) params['type'] = type;
    final uri = Uri.parse('$baseUrl/api/admin/accounting/reports/transactions').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return TypeConverter.safeToList(json.decode(response.body));
    } else {
      throw Exception('Failed to load detailed transactions report');
    }
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/admin/users?limit=1000'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['users'] ?? []);
    } else {
      throw Exception('Failed to get users: ${response.body}');
    }
  }

  // --- DAMAGED PRODUCTS ---
  Future<List<Map<String, dynamic>>> getDamagedProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/damaged-products'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to get damaged products: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getDamagedProduct(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/damaged-products/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get damaged product: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> reportDamagedProduct(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/damaged-products'),
      headers: _headers,
      body: json.encode(data),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to report damaged product: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateDamagedProduct(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/damaged-products/$id'),
      headers: _headers,
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update damaged product: ${response.body}');
    }
  }

  Future<void> deleteDamagedProduct(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/damaged-products/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete damaged product: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getDamagedProductsReport({String? startDate, String? endDate, String? damageType, String? cashierId}) async {
    final params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (damageType != null) params['damage_type'] = damageType;
    if (cashierId != null) params['user_id'] = cashierId;
    
    final uri = Uri.parse('$baseUrl/api/damaged-products/reports/summary').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get damaged products report: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getDamagedProductsByProduct(int productId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/damaged-products/product/$productId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to get damaged products by product: ${response.body}');
    }
  }

  // --- STATIC GENERIC HTTP METHODS FOR CUSTOM ENDPOINTS ---
  static Future<dynamic> getStatic(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: ApiService()._headers,
    );
    return json.decode(response.body);
  }

  static Future<dynamic> postStatic(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: ApiService()._headers,
      body: json.encode(body),
    );
    return json.decode(response.body);
  }

  static Future<dynamic> putStatic(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: ApiService()._headers,
      body: json.encode(body),
    );
    return json.decode(response.body);
  }

  static Future<dynamic> patchStatic(String path, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: ApiService()._headers,
      body: json.encode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
    return json.decode(response.body);
  }

  // =====================================================
  // STORE MANAGEMENT API METHODS
  // =====================================================

  // Get all stores
  Future<List<Map<String, dynamic>>> getStores({
    int limit = 10,
    int offset = 0,
    String search = '',
    String storeType = '',
    bool? isActive,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    
    if (search.isNotEmpty) queryParams['search'] = search;
    if (storeType.isNotEmpty) queryParams['store_type'] = storeType;
    if (isActive != null) queryParams['is_active'] = isActive.toString();
    
    final uri = Uri.parse('$baseUrl/api/stores').replace(queryParameters: queryParams);
    
            final response = await http.get(uri, headers: _headers);
    
            if (response.statusCode == 200) {
      final data = json.decode(response.body);
            return List<Map<String, dynamic>>.from(data['stores'] ?? []);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get store details by ID
  Future<Map<String, dynamic>> getStoreDetails(int storeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/stores/$storeId'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Create a new store (superadmin only)
  Future<Map<String, dynamic>> createStore(Map<String, dynamic> storeData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/stores'),
      headers: _headers,
      body: json.encode(storeData),
    );
    
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Update store (superadmin only)
  Future<Map<String, dynamic>> updateStore(int storeId, Map<String, dynamic> storeData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/stores/$storeId'),
      headers: _headers,
      body: json.encode(storeData),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Assign business to store (superadmin only)
  Future<Map<String, dynamic>> assignBusinessToStore(int storeId, int businessId, {String? notes}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/stores/$storeId/assign-business'),
      headers: _headers,
      body: json.encode({
        'business_id': businessId,
        'notes': notes,
      }),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Remove business from store (superadmin only)
  Future<Map<String, dynamic>> removeBusinessFromStore(int storeId, int businessId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/stores/$storeId/assign-business/$businessId'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get businesses assigned to a store
  Future<List<Map<String, dynamic>>> getStoreBusinesses(int storeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/stores/$storeId/businesses'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Reset all business assignments for a store (superadmin only)
  Future<Map<String, dynamic>> resetStoreBusinesses(int storeId, {String? reason}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/stores/$storeId/reset-businesses'),
      headers: _headers,
      body: json.encode({
        'reason': reason,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get all assignments for superadmin management
  Future<List<Map<String, dynamic>>> getAllStoreBusinessAssignments() async {
            final response = await http.get(
      Uri.parse('$baseUrl/api/stores/assignments/all'),
      headers: _headers,
    );

            if (response.statusCode == 200) {
      final data = json.decode(response.body);
            final assignments = List<Map<String, dynamic>>.from(data['assignments']);
            if (assignments.isNotEmpty) {
              }
      return assignments;
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Reset store and all its data (superadmin only)
  Future<Map<String, dynamic>> resetStore(int storeId, {String? reason}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/stores/$storeId/reset'),
      headers: _headers,
      body: json.encode({
        'reason': reason,
        'confirmReset': true,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // =====================================================
  // STORE TRANSFER API METHODS
  // =====================================================

  // Get all store transfers
  Future<List<Map<String, dynamic>>> getStoreTransfers({
    int limit = 10,
    int offset = 0,
    String search = '',
    String status = '',
    String transferType = '',
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    
    if (search.isNotEmpty) queryParams['search'] = search;
    if (status.isNotEmpty) queryParams['status'] = status;
    if (transferType.isNotEmpty) queryParams['transfer_type'] = transferType;
    
    final uri = Uri.parse('$baseUrl/api/store-transfers').replace(queryParameters: queryParams);
    
            final response = await http.get(uri, headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['transfers'] ?? []);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get transfer details by ID
  Future<Map<String, dynamic>> getTransferDetails(int transferId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/store-transfers/$transferId'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Create a new transfer request
  Future<Map<String, dynamic>> createTransfer(Map<String, dynamic> transferData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/store-transfers'),
      headers: _headers,
      body: json.encode(transferData),
    );
    
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Approve transfer
  Future<Map<String, dynamic>> approveTransfer(int transferId, List<Map<String, dynamic>> approvedQuantities) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/store-transfers/$transferId/approve'),
      headers: _headers,
      body: json.encode({
        'approved_quantities': approvedQuantities,
      }),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Reject transfer
  Future<Map<String, dynamic>> rejectTransfer(int transferId, String rejectionReason) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/store-transfers/$transferId/reject'),
      headers: _headers,
      body: json.encode({
        'rejection_reason': rejectionReason,
      }),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // =====================================================
  // STORE INVENTORY API METHODS
  // =====================================================

  // Add products to store inventory (with increment tracking)
  Future<Map<String, dynamic>> addProductsToStore(int storeId, int businessId, List<Map<String, dynamic>> products) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/store-inventory/$storeId/add-products'),
      headers: _headers,
      body: json.encode({
        'business_id': businessId,
        'products': products,
      }),
    );
    
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Transfer products from store to business
  Future<Map<String, dynamic>> transferStoreToBusiness(int storeId, int toBusinessId, List<Map<String, dynamic>> products, {String? notes}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/store-inventory/$storeId/transfer-to-business'),
      headers: _headers,
      body: json.encode({
        'to_business_id': toBusinessId,
        'products': products,
        'notes': notes,
      }),
    );
    
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get store inventory for a specific business
  Future<List<Map<String, dynamic>>> getStoreInventory(int storeId, int businessId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/store-inventory/$storeId/inventory/$businessId'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
                        // Handle both old format (direct array) and new format (object with inventory property)
      if (data is List) {
                return List<Map<String, dynamic>>.from(data);
      } else if (data is Map && data.containsKey('inventory')) {
                final inventory = data['inventory'] ?? [];
                if (inventory.isNotEmpty) {
                            }
        return List<Map<String, dynamic>>.from(inventory);
      } else {
                return [];
      }
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get inventory movement history
  Future<List<Map<String, dynamic>>> getStoreInventoryMovements(int storeId, int businessId, {
    int limit = 50,
    int offset = 0,
    String movementType = '',
    String productId = '',
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    
    if (movementType.isNotEmpty) queryParams['movement_type'] = movementType;
    if (productId.isNotEmpty) queryParams['product_id'] = productId;
    
    final uri = Uri.parse('$baseUrl/api/store-inventory/$storeId/movements/$businessId').replace(queryParameters: queryParams);
    
            final response = await http.get(uri, headers: _headers);
    
        if (response.statusCode == 200) {
      final data = json.decode(response.body);
                  if (data.isNotEmpty) {
                      }
      return List<Map<String, dynamic>>.from(data);
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get store inventory reports
  Future<Map<String, dynamic>> getStoreInventoryReports(int storeId, int businessId, {
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{
      'report_type': 'comprehensive',
    };
    
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    
    final uri = Uri.parse('$baseUrl/api/store-inventory/$storeId/reports/$businessId').replace(queryParameters: queryParams);
    
        final response = await http.get(uri, headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
            return data;
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // =====================================================
  // STORE WAREHOUSE MANAGEMENT (Two-Tier System)
  // =====================================================

  // Add single product to store inventory (simplified approach)
  Future<Map<String, dynamic>> addProductToStoreInventory(int storeId, int productId, int quantity, double unitCost, {String? notes}) async {
                        final requestBody = {
      'product_id': productId,
      'quantity': quantity,
      'unit_cost': unitCost,
      if (notes != null) 'notes': notes,
    };
        final response = await http.post(
      Uri.parse('$baseUrl/api/store-warehouse/$storeId/add-product'),
      headers: _headers,
      body: json.encode(requestBody),
    );
    
            if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final result = json.decode(response.body);
                return result;
      } catch (e) {
                        throw Exception('Failed to parse response: $e');
      }
    } else {
                  throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Add products to store warehouse (first tier - bulk storage)
  Future<Map<String, dynamic>> addProductsToStoreWarehouse(int storeId, List<Map<String, dynamic>> products) async {
                final requestBody = {
      'products': products,
    };
        final response = await http.post(
      Uri.parse('$baseUrl/api/store-warehouse/$storeId/add-products'),
      headers: _headers,
      body: json.encode(requestBody),
    );
    
            if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final result = json.decode(response.body);
                return result;
      } catch (e) {
                        throw Exception('Failed to parse response: $e');
      }
    } else {
                  throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Get store warehouse inventory (all products in store, not assigned to specific business)
  Future<Map<String, dynamic>> getStoreWarehouseInventory(int storeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/store-warehouse/$storeId/inventory'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Transfer products from store warehouse to business (second tier)
  Future<Map<String, dynamic>> transferFromWarehouseToBusiness(int storeId, int businessId, List<Map<String, dynamic>> products) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/store-warehouse/$storeId/transfer-to-business'),
      headers: _headers,
      body: json.encode({
        'business_id': businessId,
        'products': products,
      }),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get business inventory (products assigned to specific business from this store)
  Future<Map<String, dynamic>> getBusinessInventoryFromStore(int storeId, int businessId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/store-warehouse/$storeId/business-inventory/$businessId'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Increment existing product quantity in store inventory
  Future<Map<String, dynamic>> incrementProductQuantity(int storeId, int productId, int quantity, {double? costPrice, String? notes}) async {
                    final requestBody = {
      'product_id': productId,
      'quantity': quantity,
      if (costPrice != null) 'cost_price': costPrice,
      if (notes != null) 'notes': notes,
    };
        final response = await http.post(
      Uri.parse('$baseUrl/api/store-warehouse/$storeId/add-product'),
      headers: _headers,
      body: json.encode(requestBody),
    );
    
            if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final result = json.decode(response.body);
                return result;
      } catch (e) {
                        throw Exception('Failed to parse response: $e');
      }
    } else {
                  throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Update product cost price
  Future<Map<String, dynamic>> updateProductCostPrice(int productId, double costPrice) async {
                final requestBody = {
      'cost_price': costPrice,
    };
        final response = await http.put(
      Uri.parse('$baseUrl/api/products/$productId'),
      headers: _headers,
      body: json.encode(requestBody),
    );
    
            if (response.statusCode == 200) {
      try {
        final result = json.decode(response.body);
                return result;
      } catch (e) {
                        throw Exception('Failed to parse response: $e');
      }
    } else {
                  throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Get store inventory report
  Future<Map<String, dynamic>> getStoreInventoryReport(int storeId, int businessId, DateTime startDate, DateTime endDate) async {
                        final startDateStr = startDate.toIso8601String().split('T')[0];
    final endDateStr = endDate.toIso8601String().split('T')[0];
    
    final response = await http.get(
      Uri.parse('$baseUrl/api/store-inventory/$storeId/reports/$businessId?start_date=$startDateStr&end_date=$endDateStr'),
      headers: _headers,
    );
    
            if (response.statusCode == 200) {
      try {
        final result = json.decode(response.body);
                return result;
      } catch (e) {
                        throw Exception('Failed to parse response: $e');
      }
    } else {
                  throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // =====================================================
  // DETAILED REPORTS API METHODS
  // =====================================================

  // Get detailed movements report
  Future<Map<String, dynamic>> getDetailedMovementsReport(int storeId, int businessId, {
    String? startDate,
    String? endDate,
    int? productId,
    int? categoryId,
    String? movementType,
    String? referenceType,
    int? targetBusinessId,
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (productId != null) queryParams['product_id'] = productId.toString();
    if (categoryId != null) queryParams['category_id'] = categoryId.toString();
    if (movementType != null) queryParams['movement_type'] = movementType;
    if (referenceType != null) queryParams['reference_type'] = referenceType;
    if (targetBusinessId != null) queryParams['target_business_id'] = targetBusinessId.toString();
    
    final uri = Uri.parse('$baseUrl/api/store-inventory/$storeId/detailed-movements/$businessId').replace(queryParameters: queryParams);
    
        final response = await http.get(uri, headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
            return data;
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get purchases report
  Future<Map<String, dynamic>> getPurchasesReport(int storeId, int businessId, {
    String? startDate,
    String? endDate,
    int? productId,
    int? categoryId,
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (productId != null) queryParams['product_id'] = productId.toString();
    if (categoryId != null) queryParams['category_id'] = categoryId.toString();
    
    final uri = Uri.parse('$baseUrl/api/store-inventory/$storeId/purchases/$businessId').replace(queryParameters: queryParams);
    
        final response = await http.get(uri, headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
            return data;
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get increments report
  Future<Map<String, dynamic>> getIncrementsReport(int storeId, int businessId, {
    String? startDate,
    String? endDate,
    int? productId,
    int? categoryId,
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (productId != null) queryParams['product_id'] = productId.toString();
    if (categoryId != null) queryParams['category_id'] = categoryId.toString();
    
    final uri = Uri.parse('$baseUrl/api/store-inventory/$storeId/increments/$businessId').replace(queryParameters: queryParams);
    
        final response = await http.get(uri, headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
            return data;
    } else {
            throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get transfer reports - NEW IMPLEMENTATION
  Future<Map<String, dynamic>> getTransferReports(int storeId, int businessId, {
    String timePeriod = 'all',
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 50,
  }) async {
    // Validate parameters
    if (storeId <= 0) {
      throw ArgumentError('Store ID must be a positive integer');
    }
    if (businessId <= 0) {
      throw ArgumentError('Business ID must be a positive integer');
    }
    
    const validTimePeriods = ['all', 'today', 'week', 'month', 'custom'];
    if (!validTimePeriods.contains(timePeriod)) {
      throw ArgumentError('Invalid time period. Must be one of: all, today, week, month, custom');
    }
    
    if (page < 1) {
      throw ArgumentError('Page must be a positive integer');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError('Limit must be between 1 and 100');
    }
    
    // Validate custom date range
    if (timePeriod == 'custom') {
      if (startDate == null || endDate == null) {
        throw ArgumentError('Start date and end date are required for custom time period');
      }
      
      // Validate date format (YYYY-MM-DD)
      final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (!dateRegex.hasMatch(startDate) || !dateRegex.hasMatch(endDate)) {
        throw ArgumentError('Invalid date format. Use YYYY-MM-DD');
      }
      
      // Validate date range
      final start = DateTime.tryParse(startDate);
      final end = DateTime.tryParse(endDate);
      if (start == null || end == null) {
        throw ArgumentError('Invalid date values');
      }
      if (start.isAfter(end)) {
        throw ArgumentError('Start date cannot be after end date');
      }
    }
    
    final queryParams = <String, String>{
      'time_period': timePeriod,
      'page': page.toString(),
      'limit': limit.toString(),
    };
    
    if (timePeriod == 'custom') {
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
    }
    
    final uri = Uri.parse('$baseUrl/api/store-inventory/$storeId/transfer-reports/$businessId').replace(queryParameters: queryParams);
    
                try {
      final response = await http.get(uri, headers: _headers);
      
                  if (response.statusCode == 200) {
        final data = json.decode(response.body);
                return data;
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        throw Exception('Validation Error: ${errorData['message'] ?? 'Invalid request parameters'}');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied: You do not have permission to view this data');
      } else if (response.statusCode == 404) {
        throw Exception('Store or business not found');
      } else {
                throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Invalid response format from server');
      } else if (e is ArgumentError) {
        rethrow; // Re-throw validation errors
      } else {
        throw Exception('Network error: ${e.toString()}');
      }
    }
  }

  Future<void> exportProductsToExcel({BuildContext? context}) async {
    final uri = Uri.parse('$baseUrl/api/products/bulk-export').replace(queryParameters: {
      'token': _token ?? '',
    });
    
    if (kIsWeb) {
      // On web, we can use url_launcher to just open the link which triggers the download
      // since we now support token in query params.
      try {
        final url = uri.toString();
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch $url');
        }
      } catch (e) {
                rethrow;
      }
    } else {
      // On mobile/desktop, download the bytes and save/share
      try {
        final response = await _executeRequest(
          () => http.get(uri, headers: _headers),
          context: context,
        );

        if (response.statusCode == 200) {
          // We'll use the platform-specific save logic
          // For now, let's just use a helper if we have one or implement it here
          // I'll create a generic helper for this
          await _saveAndShareExcel(response.bodyBytes, 'products_export');
        } else {
          throw Exception('Failed to export products: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
                rethrow;
      }
    }
  }

  // Internal helper for mobile/desktop Excel saving
  Future<void> _saveAndShareExcel(Uint8List bytes, String fileName) async {
    if (kIsWeb) return; // Should not be called on web
    
    try {
      final Directory output = await getApplicationDocumentsDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String cleanFileName = '${fileName}_$timestamp'.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final File file = File('${output.path}/$cleanFileName.xlsx');
      
      await file.writeAsBytes(bytes);
      
      if (Platform.isAndroid || Platform.isIOS) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: '$cleanFileName.xlsx')],
          text: 'Exported Products Inventory',
        );
        
        // Show notification if possible
        try {
          await NotificationService.showPdfDownloadNotification(
            fileName: '$cleanFileName.xlsx',
            filePath: file.path,
            location: 'App Documents',
          );
        } catch (e) {
                  }
      }
      
      Toast.show(
        'Excel Exported! 📄',
        duration: Toast.lengthLong,
        gravity: Toast.bottom,
      );
    } catch (e) {
            rethrow;
    }
  }
}

 