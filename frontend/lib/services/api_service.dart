import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:retail_management/models/user.dart';
import 'package:retail_management/models/product.dart';
import 'package:retail_management/models/customer.dart';
import 'package:retail_management/models/sale.dart';
import 'package:retail_management/models/inventory_transaction.dart';
import 'package:retail_management/utils/type_converter.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb

class ApiService {
  static const String baseUrl = 'https://rtailed-production.up.railway.app';
  String? _token;
  
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
    print('Token set: $_token'); // Debug log
  }

  void clearToken() {
    _token = null;
    print('Token cleared'); // Debug log
  }

  String? get token => _token;

  // Health check
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Connection check failed: $e');
      return false;
    }
  }

  // Authentication
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers,
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      print('Login Response Status: ${response.statusCode}');
      print('Login Response Body: ${response.body}');

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
      print('Login Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loginWithUsername(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers,
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      print('Login with Username Response Status: ${response.statusCode}');
      print('Login with Username Response Body: ${response.body}');

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
      print('Login with Username Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loginWithIdentifier(String identifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers,
        body: json.encode({
          'identifier': identifier,
          'password': password,
        }),
      );

      print('Login with Identifier Response Status: ${response.statusCode}');
      print('Login with Identifier Response Body: ${response.body}');

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
      print('Login with Identifier Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
    String role,
    {String? adminCode, String? businessId}
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

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: _headers,
        body: json.encode(body),
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
      print('Register Error: $e');
      rethrow;
    }
  }

  Future<User> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get profile: ${response.body}');
      }
    } catch (e) {
      print('Get Profile Error: $e');
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
      print('Update Profile Error: $e');
      rethrow;
    }
  }

  // Products
  Future<List<Product>> getProducts() async {
    try {
      print('🛍️ ===== API GET PRODUCTS START =====');
      final response = await http.get(
        Uri.parse('$baseUrl/api/products'),
        headers: _headers,
      );

      print('🛍️ Response status: ${response.statusCode}');
      print('🛍️ Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('🛍️ Raw JSON response length: ${data.length}');
        
        // Debug: Print first product's raw JSON
        if (data.isNotEmpty) {
          print('🛍️ First product raw JSON: ${data.first}');
          print('🛍️ First product image_url field: ${data.first['image_url']}');
        }
        
        final products = data.map((json) => Product.fromJson(json)).toList();
        print('🛍️ Parsed products length: ${products.length}');
        
        // Debug: Print first product's parsed data
        if (products.isNotEmpty) {
          final firstProduct = products.first;
          print('🛍️ First product parsed:');
          print('  - ID: ${firstProduct.id}');
          print('  - Name: ${firstProduct.name}');
          print('  - Image URL: ${firstProduct.imageUrl}');
        }
        
        print('🛍️ ===== API GET PRODUCTS END (SUCCESS) =====');
        return products;
      } else {
        print('🛍️ ❌ Error response: ${response.body}');
        print('🛍️ ===== API GET PRODUCTS END (ERROR) =====');
        throw Exception('Failed to get products: ${response.body}');
      }
    } catch (e) {
      print('🛍️ ❌ Exception: $e');
      print('🛍️ ===== API GET PRODUCTS END (EXCEPTION) =====');
      rethrow;
    }
  }

  // Get all products including deleted ones (for inventory management)
  Future<List<Product>> getAllProducts() async {
    try {
      print('🛍️ ===== API GET ALL PRODUCTS START =====');
      final response = await http.get(
        Uri.parse('$baseUrl/api/products/all'),
        headers: _headers,
      );

      print('🛍️ Response status: ${response.statusCode}');
      print('🛍️ Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('🛍️ Raw JSON response length: ${data.length}');
        
        // Debug: Print first product's raw JSON
        if (data.isNotEmpty) {
          print('🛍️ First product raw JSON: ${data.first}');
          print('🛍️ First product is_deleted field: ${data.first['is_deleted']}');
          print('🛍️ First product is_deleted type: ${data.first['is_deleted'].runtimeType}');
        }
        
        final products = data.map((json) => Product.fromJson(json)).toList();
        print('🛍️ Parsed products length: ${products.length}');
        
        // Debug: Print first product's parsed data
        if (products.isNotEmpty) {
          final firstProduct = products.first;
          print('🛍️ First product parsed:');
          print('  - ID: ${firstProduct.id}');
          print('  - Name: ${firstProduct.name}');
          print('  - Is Deleted: ${firstProduct.isDeleted}');
          print('  - Is Deleted Type: ${firstProduct.isDeleted.runtimeType}');
        }
        
        print('🛍️ ===== API GET ALL PRODUCTS END (SUCCESS) =====');
        return products;
      } else {
        print('🛍️ ❌ Error response: ${response.body}');
        print('🛍️ ===== API GET ALL PRODUCTS END (ERROR) =====');
        throw Exception('Failed to get all products: ${response.body}');
      }
    } catch (e) {
      print('🛍️ ❌ Exception: $e');
      print('🛍️ ===== API GET ALL PRODUCTS END (EXCEPTION) =====');
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
      print('Get Product Error: $e');
      rethrow;
    }
  }

  Future<Product> createProduct(Map<String, dynamic> productData, {File? imageFile, Uint8List? webImageBytes, String? webImageName}) async {
    print('ApiService.createProduct called');
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
        print('ApiService.createProduct response: ${response.statusCode} ${response.body}');
        if (response.statusCode == 201) {
          final data = json.decode(response.body);
          return await getProduct(data['productId']);
        } else {
          print('ApiService.createProduct error: ${response.body}');
          throw Exception('Failed to create product: ${response.body}');
        }
      } else {
        // Regular JSON request without image
        final response = await http.post(
          Uri.parse('$baseUrl/api/products'),
          headers: _headers,
          body: json.encode(productData),
        );
        print('ApiService.createProduct response: ${response.statusCode} ${response.body}');
        if (response.statusCode == 201) {
          final data = json.decode(response.body);
          return await getProduct(data['productId']);
        } else {
          print('ApiService.createProduct error: ${response.body}');
          throw Exception('Failed to create product: ${response.body}');
        }
      }
    } catch (e, stack) {
      print('Create Product Error (ApiService): $e');
      print('Stack trace: $stack');
      rethrow;
    }
  }

  Future<void> updateProduct(int id, Map<String, dynamic> productData, {File? imageFile, Uint8List? webImageBytes, String? webImageName}) async {
    print('ApiService.updateProduct called');
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
        print('ApiService.updateProduct response: ${response.statusCode} ${response.body}');
        if (response.statusCode != 200) {
          print('ApiService.updateProduct error: ${response.body}');
          throw Exception('Failed to update product: ${response.body}');
        }
      } else {
        final response = await http.put(
          Uri.parse('$baseUrl/api/products/$id'),
          headers: _headers,
          body: json.encode(productData),
        );
        print('ApiService.updateProduct response: ${response.statusCode} ${response.body}');
        if (response.statusCode != 200) {
          print('ApiService.updateProduct error: ${response.body}');
          throw Exception('Failed to update product: ${response.body}');
        }
      }
    } catch (e, stack) {
      print('Update Product Error (ApiService): $e');
      print('Stack trace: $stack');
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
      print('Delete Product Error: $e');
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
      print('Restore Product Error: $e');
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
      print('Get Customers Error: $e');
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
      print('Create Customer Error: $e');
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
      print('Get Sales Error: $e');
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
      print('Create Sale Error: $e');
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
      print('Get Sale Error: $e');
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
      print('getInventoryTransactionsForPdf queryParams: ' + queryParams.toString());
      final uri = Uri.parse('$baseUrl/api/inventory/transactions/pdf').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return TypeConverter.safeToList(data);
      } else {
        throw Exception('Failed to get enhanced inventory transactions: ${response.body}');
      }
    } catch (e) {
      print('Get Enhanced Inventory Transactions Error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getInventoryTransactions([Map<String, dynamic>? filters]) async {
    try {
      final queryParams = <String, String>{};
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            queryParams[key] = value.toString();
          }
        });
      }
      print('getInventoryTransactions queryParams: ' + queryParams.toString());
      final uri = Uri.parse('$baseUrl/api/inventory/transactions').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return TypeConverter.safeToList(data);
      } else {
        throw Exception('Failed to get inventory transactions: ${response.body}');
      }
    } catch (e) {
      print('Get Inventory Transactions Error: $e');
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
      print('Create Inventory Transaction Error: $e');
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
      print('getSalesReport queryParams: ' + queryParams.toString());
      final uri = Uri.parse('$baseUrl/api/sales/report').replace(queryParameters: queryParams);
      
      print('Sales Report Request:');
      print('  URL: $uri');
      print('  Start Date: $startDate');
      print('  End Date: $endDate');
      print('  Group By: $groupBy');
      
      final response = await http.get(uri, headers: _headers);

      print('Sales Report Response Status: ${response.statusCode}');
      print('Sales Report Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return TypeConverter.safeToMap(json.decode(response.body));
      } else {
        throw Exception('Failed to get sales report: ${response.body}');
      }
    } catch (e) {
      print('Error fetching sales report: $e');
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
      print('Error fetching inventory report: $e');
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
      print('Get Business Details Error: $e');
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
        print('GET BUSINESSES ERROR: ${response.statusCode} ${response.body}');
        throw Exception('Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Get Businesses Error: $e');
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
      print('Get Categories Error: $e');
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
      print('Create Category Error: $e');
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
      print('Update Category Error: $e');
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
      print('Delete Category Error: $e');
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
      print('Get Top Products Error: $e');
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
      print('Error fetching credit report: $e');
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
      print('Error fetching credit customers: $e');
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
      print('Error fetching customer credit transactions: $e');
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
      print('Get Sale Items Error: $e');
      rethrow;
    }
  }

  // --- ACCOUNTING: EXPENSES ---
  Future<List<Map<String, dynamic>>> getExpenses() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/accounting/expenses'), headers: _headers);
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
      print('PATCH ERROR: ${response.statusCode} ${response.body}');
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
    
    print('GET STORES REQUEST: $uri');
    print('GET STORES HEADERS: $_headers');
    
    final response = await http.get(uri, headers: _headers);
    
    print('GET STORES RESPONSE STATUS: ${response.statusCode}');
    print('GET STORES RESPONSE BODY: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('GET STORES PARSED DATA: $data');
      return List<Map<String, dynamic>>.from(data['stores'] ?? []);
    } else {
      print('GET STORES ERROR: ${response.statusCode} ${response.body}');
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
      print('GET STORE DETAILS ERROR: ${response.statusCode} ${response.body}');
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
      print('CREATE STORE ERROR: ${response.statusCode} ${response.body}');
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
      print('UPDATE STORE ERROR: ${response.statusCode} ${response.body}');
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
      print('ASSIGN BUSINESS ERROR: ${response.statusCode} ${response.body}');
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
      print('REMOVE BUSINESS ERROR: ${response.statusCode} ${response.body}');
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
      print('GET STORE BUSINESSES ERROR: ${response.statusCode} ${response.body}');
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
    
    print('GET STORE TRANSFERS REQUEST: $uri');
    print('GET STORE TRANSFERS HEADERS: $_headers');
    
    final response = await http.get(uri, headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['transfers'] ?? []);
    } else {
      print('GET TRANSFERS ERROR: ${response.statusCode} ${response.body}');
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
      print('GET TRANSFER DETAILS ERROR: ${response.statusCode} ${response.body}');
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
      print('CREATE TRANSFER ERROR: ${response.statusCode} ${response.body}');
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
      print('APPROVE TRANSFER ERROR: ${response.statusCode} ${response.body}');
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
      print('REJECT TRANSFER ERROR: ${response.statusCode} ${response.body}');
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
      print('ADD PRODUCTS TO STORE ERROR: ${response.statusCode} ${response.body}');
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
      print('TRANSFER STORE TO BUSINESS ERROR: ${response.statusCode} ${response.body}');
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
        return List<Map<String, dynamic>>.from(data['inventory'] ?? []);
      } else {
        return [];
      }
    } else {
      print('GET STORE INVENTORY ERROR: ${response.statusCode} ${response.body}');
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
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      print('GET STORE INVENTORY MOVEMENTS ERROR: ${response.statusCode} ${response.body}');
      throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // Get store inventory reports
  Future<Map<String, dynamic>> getStoreInventoryReports(int storeId, int businessId, {
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{};
    
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    
    final uri = Uri.parse('$baseUrl/api/store-inventory/$storeId/reports/$businessId').replace(queryParameters: queryParams);
    
    final response = await http.get(uri, headers: _headers);
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('GET STORE INVENTORY REPORTS ERROR: ${response.statusCode} ${response.body}');
      throw Exception('Error: ${response.statusCode} ${response.body}');
    }
  }

  // =====================================================
  // STORE WAREHOUSE MANAGEMENT (Two-Tier System)
  // =====================================================

  // Add single product to store inventory (simplified approach)
  Future<Map<String, dynamic>> addProductToStoreInventory(int storeId, int productId, int quantity, double unitCost, {String? notes}) async {
    print('=== API SERVICE: ADD PRODUCT TO STORE INVENTORY ===');
    print('Store ID: $storeId');
    print('Product ID: $productId');
    print('Quantity: $quantity');
    print('Unit Cost: $unitCost');
    
    final requestBody = {
      'product_id': productId,
      'quantity': quantity,
      'unit_cost': unitCost,
      if (notes != null) 'notes': notes,
    };
    print('Request body: ${json.encode(requestBody)}');
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/store-warehouse/$storeId/add-product'),
      headers: _headers,
      body: json.encode(requestBody),
    );
    
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final result = json.decode(response.body);
        print('Successfully decoded response: $result');
        return result;
      } catch (e) {
        print('JSON decode error: $e');
        print('Response body that failed to decode: ${response.body}');
        throw Exception('Failed to parse response: $e');
      }
    } else {
      print('API call failed with status: ${response.statusCode}');
      print('Error response body: ${response.body}');
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Add products to store warehouse (first tier - bulk storage)
  Future<Map<String, dynamic>> addProductsToStoreWarehouse(int storeId, List<Map<String, dynamic>> products) async {
    print('=== API SERVICE: ADD TO STORE WAREHOUSE ===');
    print('Store ID: $storeId');
    print('Products: $products');
    
    final requestBody = {
      'products': products,
    };
    print('Request body: ${json.encode(requestBody)}');
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/store-warehouse/$storeId/add-products'),
      headers: _headers,
      body: json.encode(requestBody),
    );
    
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final result = json.decode(response.body);
        print('Successfully decoded response: $result');
        return result;
      } catch (e) {
        print('JSON decode error: $e');
        print('Response body that failed to decode: ${response.body}');
        throw Exception('Failed to parse response: $e');
      }
    } else {
      print('API call failed with status: ${response.statusCode}');
      print('Error response body: ${response.body}');
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
  Future<Map<String, dynamic>> incrementProductQuantity(int storeId, int productId, int quantity, {String? notes}) async {
    print('=== API SERVICE: INCREMENT PRODUCT QUANTITY ===');
    print('Store ID: $storeId');
    print('Product ID: $productId');
    print('Quantity to add: $quantity');
    
    final requestBody = {
      'product_id': productId,
      'quantity': quantity,
      if (notes != null) 'notes': notes,
    };
    print('Request body: ${json.encode(requestBody)}');
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/store-warehouse/$storeId/add-product'),
      headers: _headers,
      body: json.encode(requestBody),
    );
    
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final result = json.decode(response.body);
        print('Successfully incremented product: $result');
        return result;
      } catch (e) {
        print('JSON decode error: $e');
        print('Response body that failed to decode: ${response.body}');
        throw Exception('Failed to parse response: $e');
      }
    } else {
      print('API call failed with status: ${response.statusCode}');
      print('Error response body: ${response.body}');
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }
} 