import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:retail_management/models/product.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/widgets/custom_text_field.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/widgets/branded_header.dart';
import 'package:retail_management/utils/theme.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:retail_management/utils/api.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:intl/intl.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  List<Map<String, dynamic>> _categoryList = [];
  bool _showLowStock = false;
  bool _isLoading = true;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String? _webImageName;
  // Inventory Report fields
  bool _showInventoryReport = false;
  String? _selectedReportCategory;
  String? _selectedReportProduct;
  String? _reportSku;
  DateTime? _reportStartDate;
  DateTime? _reportEndDate;
  List<Map<String, dynamic>> _reportTransactions = [];
  bool _reportLoading = false;
  // Inventory Value Report fields
  List<Map<String, dynamic>> _valueReportRows = [];
  bool _valueReportLoading = false;
  String? _valueReportError;
  // Drill-down dialog state
  bool _drilldownLoading = false;
  List<Map<String, dynamic>> _drilldownTransactions = [];
  String? _drilldownError;
  String? _drilldownProductName;
  // Add state for recent, today, week, and filtered transactions
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _todayTransactions = [];
  List<Map<String, dynamic>> _weekTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _recentLoading = false;
  bool _todayLoading = false;
  bool _weekLoading = false;
  bool _filteredLoading = false;
  String? _recentError;
  String? _todayError;
  String? _weekError;
  String? _filteredError;
  // Add separate state for stock summary date filters
  DateTime? _stockSummaryStartDate;
  DateTime? _stockSummaryEndDate;
  // Add state for stock summary filter type
  String _stockSummaryFilterType = 'Today';
  final List<String> _stockSummaryFilterOptions = ['Today', 'This Week', 'This Month', 'Custom'];
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _loadData();
    _stockSummaryFilterType = 'Today';
    _applyStockSummaryPreset('Today');
    _fetchRecentTransactions();
    _fetchTodayTransactions();
    _fetchWeekTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('=== FRONTEND LOAD DATA DEBUG ===');
      print('Loading products and categories...');
      
      // Load products and categories in parallel
      final results = await Future.wait([
        _apiService.getProducts(),
        _apiService.getCategories(),
      ]);

      final products = results[0] as List<Product>;
      print('Loaded ${products.length} products from API');
      
      // Debug: Print each product's details
      for (var product in products) {
        print('Product ${product.id}: ${product.name} - Cost: ${product.costPrice}, Stock: ${product.stockQuantity}');
      }
      final categories = results[1] as List<Map<String, dynamic>>;

      setState(() {
        _products = products;
        _filteredProducts = products;
        _categoryList = categories;
        _categories = ['All', ...categories.map((c) => c['name'] as String).toList()];
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'Error loading data: ')}$e')),
        );
      }
    }
  }

  Future<void> _loadProducts() async {
    print('📦 ===== INVENTORY LOAD PRODUCTS START =====');
    setState(() {
      _isLoading = true;
    });

    try {
      print('📦 Calling API service to get products...');
      final products = await _apiService.getProducts();
      print('📦 ✅ API call successful, loaded ${products.length} products');
      
      // Debug: Print image URLs for products with images
      print('📦 Analyzing product images...');
      int productsWithImages = 0;
      int productsWithoutImages = 0;
      
      for (final product in products) {
        print('📦 Product: ${product.name} (ID: ${product.id})');
        print('📦   - Image URL from API: ${product.imageUrl ?? 'NULL'}');
        
        if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
          productsWithImages++;
          final fullUrl = Api.getFullImageUrl(product.imageUrl);
          print('📦   - Full image URL: $fullUrl');
        } else {
          productsWithoutImages++;
          print('📦   - No image URL');
        }
      }
      
      print('📦 Summary: $productsWithImages products with images, $productsWithoutImages without images');
      
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
      });
      print('📦 ✅ State updated, applying filters...');
      _applyFilters();
      print('📦 ===== INVENTORY LOAD PRODUCTS END (SUCCESS) =====');
    } catch (e) {
      print('📦 ❌ Error loading products: $e');
      print('📦 Error stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'error_loading_products')}: $e')),
        );
      }
      print('📦 ===== INVENTORY LOAD PRODUCTS END (ERROR) =====');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _products.where((product) {
        // Search filter
        final searchMatch = _searchController.text.isEmpty ||
            product.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            (product.sku?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false);

        // Category filter
        final categoryMatch = _selectedCategory == 'All' ||
            (product.categoryName ?? 'Uncategorized') == _selectedCategory;

        // Low stock filter
        final stockMatch = !_showLowStock ||
            product.stockQuantity <= product.lowStockThreshold;

        return searchMatch && categoryMatch && stockMatch;
      }).toList();
    });
  }

  Future<void> _fetchInventoryReport() async {
    setState(() { _reportLoading = true; });
    try {
      final params = <String, dynamic>{};
      if (_selectedReportCategory != null && _selectedReportCategory != 'All') {
        final cat = _categoryList.firstWhere(
          (c) => c['name'] == _selectedReportCategory,
          orElse: () => <String, dynamic>{},
        );
        if (cat.isNotEmpty) params['category_id'] = cat['id'];
      }
      if (_selectedReportProduct != null && _selectedReportProduct != 'All') {
        final prod = _products.firstWhere(
          (p) => p.name == _selectedReportProduct,
          orElse: () => Product(
            id: -1,
            name: '',
            sku: '',
            price: 0,
            costPrice: 0,
            stockQuantity: 0,
            damagedQuantity: 0,
            lowStockThreshold: 0,
          ),
        );
        if (prod.id != -1) params['product_id'] = prod.id;
      }
      if (_reportSku != null && _reportSku!.isNotEmpty) params['sku'] = _reportSku;
      if (_reportStartDate != null) params['start_date'] = _reportStartDate!.toIso8601String();
      if (_reportEndDate != null) params['end_date'] = _reportEndDate!.toIso8601String();
      final data = await _apiService.getInventoryTransactions(params);
      setState(() { _reportTransactions = List<Map<String, dynamic>>.from(data); });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'Error loading inventory report: ')}$e')),
        );
      }
    } finally {
      setState(() { _reportLoading = false; });
    }
  }

  Future<void> _fetchInventoryValueReport() async {
    setState(() {
      _valueReportLoading = true;
      _valueReportError = null;
    });
    try {
      final data = await _apiService.getInventoryReport(
        startDate: _stockSummaryStartDate?.toIso8601String(),
        endDate: _stockSummaryEndDate?.toIso8601String(),
      );
      setState(() {
        _valueReportRows = List<Map<String, dynamic>>.from(data['products'] ?? []);
      });
    } catch (e) {
      setState(() {
        _valueReportError = 'Failed to load value report: $e';
      });
    } finally {
      setState(() {
        _valueReportLoading = false;
      });
    }
  }

  Future<void> _showProductTransactionsDialog(int productId, String productName) async {
    setState(() {
      _drilldownLoading = true;
      _drilldownTransactions = [];
      _drilldownError = null;
      _drilldownProductName = productName;
    });
    try {
      final txs = await _apiService.getInventoryTransactions({'product_id': productId});
      setState(() {
        _drilldownTransactions = List<Map<String, dynamic>>.from(txs);
      });
    } catch (e) {
      setState(() {
        _drilldownError = 'Failed to load transactions: $e';
      });
    } finally {
      setState(() {
        _drilldownLoading = false;
      });
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${t(context, 'Transactions for ')}$_drilldownProductName'),
          content: SizedBox(
            width: 500,
            child: _drilldownLoading
                ? Center(child: CircularProgressIndicator())
                : _drilldownError != null
                    ? Text(_drilldownError!)
                    : _drilldownTransactions.isEmpty
                        ? Text(t(context, 'No transactions found.'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                        DataColumn(label: Text(t(context, 'Date'))),
        DataColumn(label: Text(t(context, 'Type'))),
        DataColumn(label: Text(t(context, 'Qty'))),
        DataColumn(label: Text(t(context, 'Sale Amount'))),
        DataColumn(label: Text(t(context, 'Profit'))),
        DataColumn(label: Text(t(context, 'Notes'))),
        DataColumn(label: Text(t(context, 'Mode'))),
        DataColumn(label: Text(t(context, 'Cashier'))),
                              ],
                              rows: _drilldownTransactions.map((tx) {
                                // Check if this is a damaged product transaction
                                final isDamaged = tx['transaction_type'] == 'adjustment' && 
                                                 tx['notes'] != null && 
                                                 tx['notes'].toString().toLowerCase().contains('damaged');
                                final isNegativeQuantity = tx['quantity'] != null && tx['quantity'] < 0;
                                
                                return DataRow(cells: [
                                  DataCell(Text(tx['created_at']?.toString()?.split('T')?.first ?? '')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDamaged ? Colors.orange[100] : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isDamaged ? 'DAMAGED' : (tx['transaction_type'] ?? '').toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isDamaged ? Colors.orange[800] : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      tx['quantity']?.toString() ?? '',
                                      style: isNegativeQuantity ? TextStyle(
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                      ) : null,
                                    ),
                                  ),
                                  DataCell(Text(_safeToDouble(tx['sale_total_price']).toStringAsFixed(2))),
                                  DataCell(Text(_safeToDouble(tx['profit']).toStringAsFixed(2))),
                                  DataCell(
                                    Tooltip(
                                      message: tx['notes'] ?? '',
                                      child: Text(
                                        tx['notes'] ?? '',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDamaged ? Colors.orange[700] : Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text((tx['sale_mode'] ?? '').toString().isNotEmpty ? (tx['sale_mode'] == 'wholesale' ? 'Wholesale' : 'Retail') : '')),
                                  DataCell(
                                    Text(
                                      tx['cashier_name'] ?? '',
                                      style: isDamaged ? TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                      ) : null,
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t(context, 'Close')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final isMobile = screenWidth <= 768;
    final isSmallMobile = screenWidth <= 480;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Branded Header Section
              Consumer<BrandingProvider>(
                builder: (context, brandingProvider, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.8),
                          Theme.of(context).primaryColor.withOpacity(0.6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 12 : 20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Logo and Title
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.inventory_2,
                                          color: Colors.white,
                                          size: isSmallMobile ? 14 : (isMobile ? 18 : 24),
                                        ),
                                      ),
                                      SizedBox(width: isSmallMobile ? 6 : 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isSmallMobile ? 'Inventory' : 'Inventory Management',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: isSmallMobile ? 12 : (isMobile ? 16 : 20),
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            if (!isSmallMobile) ...[
                                              SizedBox(height: isSmallMobile ? 2 : 4),
                                              Text(
                                                t(context, 'Manage your product inventory efficiently'),
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontSize: isSmallMobile ? 10 : (isMobile ? 12 : 14),
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Action Buttons
                                Row(
                                  children: [
                                    // Refresh Button
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.refresh, color: Colors.white),
                                        onPressed: _loadProducts,
                                        tooltip: t(context, 'Refresh Data'),
                                        padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                                        constraints: BoxConstraints(
                                          minWidth: isSmallMobile ? 28 : 36,
                                          minHeight: isSmallMobile ? 28 : 36,
                                        ),
                                      ),
                                    ),
                                    
                                    SizedBox(width: isSmallMobile ? 4 : 6),
                                    
                                    // Add Product Button
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: isSmallMobile 
                                        ? IconButton(
                                            onPressed: () {
                                              _showAddProductDialog();
                                            },
                                            icon: Icon(
                                              Icons.add_circle_outline,
                                              color: Theme.of(context).primaryColor,
                                              size: 16,
                                            ),
                                            padding: EdgeInsets.all(6),
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            onPressed: () {
                                              _showAddProductDialog();
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              foregroundColor: Theme.of(context).primaryColor,
                                              elevation: 0,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: Icon(
                                              Icons.add_circle_outline,
                                              size: 14,
                                            ),
                                            label: Text(
                                              isMobile ? t(context, 'Add') : t(context, 'Add Product'),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Compact Mobile Stats
                            if (isMobile) ...[
                              SizedBox(height: isSmallMobile ? 8 : 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${_products.length}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: isSmallMobile ? 14 : 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Total',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: isSmallMobile ? 8 : 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isSmallMobile ? 4 : 6),
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${_filteredProducts.length}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: isSmallMobile ? 14 : 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Found',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: isSmallMobile ? 8 : 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isSmallMobile ? 4 : 6),
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${_products.where((p) => p.stockQuantity <= p.lowStockThreshold).length}',
                                            style: TextStyle(
                                              color: Colors.orange[300],
                                              fontSize: isSmallMobile ? 14 : 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Low',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: isSmallMobile ? 8 : 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: isSmallMobile ? 6 : 8),
              // Filters Section
              Container(
                margin: EdgeInsets.symmetric(horizontal: isSmallMobile ? 4 : 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Icon
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                            ),
                            child: Icon(
                              Icons.filter_list,
                              color: Theme.of(context).primaryColor,
                              size: isSmallMobile ? 12 : 14,
                            ),
                          ),
                          SizedBox(width: isSmallMobile ? 6 : 8),
                          Text(
                            isSmallMobile ? 'Filters' : t(context, 'Search & Filters'),
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallMobile ? 8 : 12),
                      
                      if (isMobile) ...[
                        // Mobile Layout - Stacked
                        _buildMobileFilters(isSmallMobile),
                      ] else ...[
                        // Desktop Layout - Horizontal
                        _buildDesktopFilters(),
                      ],
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: isSmallMobile ? 4 : 6),
              
              // Inventory Report Section
              Container(
                margin: EdgeInsets.symmetric(horizontal: isSmallMobile ? 4 : 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ExpansionPanelList(
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() { _showInventoryReport = !_showInventoryReport; });
                  },
                  children: [
                    ExpansionPanel(
                      isExpanded: _showInventoryReport,
                      headerBuilder: (context, isExpanded) {
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallMobile ? 8 : 12,
                            vertical: isSmallMobile ? 4 : 8,
                          ),
                          leading: Container(
                            padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                            ),
                            child: Icon(
                              Icons.bar_chart, 
                              color: Theme.of(context).primaryColor,
                              size: isSmallMobile ? 12 : 14,
                            ),
                          ),
                          title: Text(
                            isSmallMobile ? 'Reports' : t(context, 'Inventory Report'), 
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallMobile ? 11 : 13,
                            ),
                          ),
                          trailing: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey[600],
                            size: isSmallMobile ? 16 : 18,
                          ),
                        );
                      },
                      body: Padding(
                        padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isMobile) ...[
                                // Mobile layout - stacked vertically
                                _buildMobileReportFilters(),
                              ] else ...[
                                // Desktop layout - horizontal
                                _buildDesktopReportFilters(),
                              ],
                              SizedBox(height: isSmallMobile ? 6 : 8),
                              Text(
                                isSmallMobile ? 'Stock Summary' : t(context, 'Stock Summary'), 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: isSmallMobile ? 11 : 13,
                                ),
                              ),
                              SizedBox(height: isSmallMobile ? 4 : 6),
                              _buildStockSummaryFilters(isSmallMobile),
                              SizedBox(height: isSmallMobile ? 6 : 8),
                              _buildValueReportTable(isSmallMobile),
                              SizedBox(height: isSmallMobile ? 8 : 12),
                              Text(
                                isSmallMobile ? 'Recent Transactions' : t(context, 'Recent Transactions'), 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: isSmallMobile ? 11 : 13,
                                ),
                              ),
                              SizedBox(height: isSmallMobile ? 4 : 6),
                              _buildTransactionsTable(_recentTransactions, _recentLoading, _recentError, 'No recent transactions', isSmallMobile),
                              SizedBox(height: isSmallMobile ? 8 : 12),
                              Text(
                                'Todays Transactions', 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: isSmallMobile ? 11 : 13,
                                ),
                              ),
                              SizedBox(height: isSmallMobile ? 4 : 6),
                              _buildTransactionsTable(_todayTransactions, _todayLoading, _todayError, 'No transactions today', isSmallMobile),
                              SizedBox(height: isSmallMobile ? 8 : 12),
                              Text(
                                'This Weeks Transactions', 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: isSmallMobile ? 11 : 13,
                                ),
                              ),
                              SizedBox(height: isSmallMobile ? 4 : 6),
                              _buildTransactionsTable(_weekTransactions, _weekLoading, _weekError, 'No transactions this week', isSmallMobile),
                              SizedBox(height: isSmallMobile ? 8 : 12),
                              Text(
                                'Filter Transactions by Date', 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: isSmallMobile ? 11 : 13,
                                ),
                              ),
                              SizedBox(height: isSmallMobile ? 4 : 6),
                              _buildDateFilterControls(isSmallMobile),
                              SizedBox(height: isSmallMobile ? 6 : 8),
                              _buildTransactionsTable(_filteredTransactions, _filteredLoading, _filteredError, 'No transactions for selected dates', isSmallMobile),
                            ],
                          ),
                        ),
                      ),
                      canTapOnHeader: true,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isSmallMobile ? 8 : 12),
              
              // Products Table Section
              Container(
                margin: EdgeInsets.symmetric(horizontal: isSmallMobile ? 4 : 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isSmallMobile ? 8 : 12),
                          topRight: Radius.circular(isSmallMobile ? 8 : 12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                            ),
                            child: Icon(
                              Icons.inventory_2,
                              color: Theme.of(context).primaryColor,
                              size: isSmallMobile ? 12 : 14,
                            ),
                          ),
                          SizedBox(width: isSmallMobile ? 6 : 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSmallMobile ? 'Products' : 'Products Inventory',
                                  style: TextStyle(
                                    fontSize: isSmallMobile ? 12 : 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: isSmallMobile ? 1 : 2),
                                Text(
                                  '${_filteredProducts.length} products found',
                                  style: TextStyle(
                                    fontSize: isSmallMobile ? 9 : 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isMobile) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallMobile ? 6 : 8,
                                vertical: isSmallMobile ? 4 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '${_products.length} Total',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: isSmallMobile ? 9 : 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Table Content
                    _isLoading
                        ? Container(
                            padding: EdgeInsets.all(isSmallMobile ? 20 : 30),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                                SizedBox(height: isSmallMobile ? 8 : 12),
                                Text(
                                  t(context, 'Loading products...'),
                                  style: TextStyle(
                                    fontSize: isSmallMobile ? 10 : 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredProducts.isEmpty
                            ? Container(
                                padding: EdgeInsets.all(isSmallMobile ? 20 : 30),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_outlined,
                                        size: isSmallMobile ? 24 : 32,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    SizedBox(height: isSmallMobile ? 8 : 12),
                                    Text(
                                      t(context, 'No products found'),
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 12 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: isSmallMobile ? 4 : 6),
                                    Text(
                                      'Try adjusting your search or filters',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 9 : 10,
                                        color: Colors.grey[500],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : isMobile
                                ? _buildMobileProductList(isSmallMobile)
                                : Container(
                                    padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        columns: _buildDataTableColumns(isTablet),
                                        rows: _buildProductRows(isTablet),
                                        headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                                          (Set<MaterialState> states) => Colors.grey[50],
                                        ),
                                        dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                                          (Set<MaterialState> states) => Colors.white,
                                        ),
                                        border: TableBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          horizontalInside: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildDataTableColumns(bool isTablet) {
    return [
      DataColumn(label: Text(t(context, 'Product'))),
      DataColumn(label: Text(t(context, 'Category'))),
      DataColumn(label: Text(t(context, 'Cost Price'))),
      DataColumn(label: Text(t(context, 'Stock'))),
      DataColumn(label: Text(t(context, 'Status'))),
      DataColumn(label: Text(t(context, 'Actions'))),
    ];
  }

  Widget _buildMobileProductList(bool isSmallMobile) {
    return GridView.builder(
      padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSmallMobile ? 1 : 2,
        childAspectRatio: isSmallMobile ? 2.8 : 2.5,
        crossAxisSpacing: isSmallMobile ? 0 : 8,
        mainAxisSpacing: isSmallMobile ? 6 : 8,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final isLowStock = product.stockQuantity <= product.lowStockThreshold;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Compact Header Row
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    // Product Image
                    Container(
                      width: isSmallMobile ? 40 : 50,
                      height: isSmallMobile ? 40 : 50,
                      margin: EdgeInsets.all(isSmallMobile ? 4 : 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                        child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                            ? Image.network(
                                Api.getFullImageUrl(product.imageUrl),
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
                                      strokeWidth: 1.5,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                                    ),
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.blue[600],
                                      size: isSmallMobile ? 16 : 18,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                                ),
                                child: Icon(
                                  Icons.image,
                                  color: Colors.blue[600],
                                  size: isSmallMobile ? 16 : 18,
                                ),
                              ),
                      ),
                    ),
                    
                    // Product Info
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: isSmallMobile ? 4 : 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Product Name
                            Text(
                              product.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallMobile ? 10 : 12,
                                color: Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            SizedBox(height: isSmallMobile ? 1 : 2),
                            
                            // SKU
                            Text(
                              'SKU: ${product.sku}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isSmallMobile ? 7 : 8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            
                            SizedBox(height: isSmallMobile ? 2 : 3),
                            
                            // Category Badge
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallMobile ? 4 : 6,
                                vertical: isSmallMobile ? 1 : 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(product.categoryName ?? 'Uncategorized').withOpacity(0.1),
                                borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                                border: Border.all(
                                  color: _getCategoryColor(product.categoryName ?? 'Uncategorized').withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                product.categoryName ?? 'Uncategorized',
                                style: TextStyle(
                                  color: _getCategoryColor(product.categoryName ?? 'Uncategorized'),
                                  fontWeight: FontWeight.w600,
                                  fontSize: isSmallMobile ? 6 : 7,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Compact Stats Row
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallMobile ? 6 : 8,
                    vertical: isSmallMobile ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(isSmallMobile ? 8 : 10),
                      bottomRight: Radius.circular(isSmallMobile ? 8 : 10),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Cost
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Cost',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isSmallMobile ? 6 : 7,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '\$${product.costPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallMobile ? 8 : 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Stock
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Stock',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isSmallMobile ? 6 : 7,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${product.stockQuantity}',
                              style: TextStyle(
                                color: isLowStock ? Colors.red[700] : Colors.blue[700],
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallMobile ? 8 : 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Price
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Price',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isSmallMobile ? 6 : 7,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.purple[700],
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallMobile ? 8 : 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Status Indicator
                      Container(
                        padding: EdgeInsets.all(isSmallMobile ? 3 : 4),
                        decoration: BoxDecoration(
                          color: isLowStock ? Colors.red[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                          border: Border.all(
                            color: isLowStock ? Colors.red[200]! : Colors.green[200]!,
                          ),
                        ),
                        child: Icon(
                          isLowStock ? Icons.warning : Icons.check_circle,
                          size: isSmallMobile ? 10 : 12,
                          color: isLowStock ? Colors.red[600] : Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Action Buttons Row
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallMobile ? 6 : 8,
                    vertical: isSmallMobile ? 2 : 4,
                  ),
                  child: Row(
                    children: [
                      // Edit Button
                      Expanded(
                        child: Container(
                          height: isSmallMobile ? 24 : 28,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                              onTap: () {
                                _showEditProductDialog(product);
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: Colors.blue[600],
                                    size: isSmallMobile ? 10 : 12,
                                  ),
                                  SizedBox(width: isSmallMobile ? 2 : 3),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: isSmallMobile ? 7 : 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(width: isSmallMobile ? 4 : 6),
                      
                      // Delete Button
                      Expanded(
                        child: Container(
                          height: isSmallMobile ? 24 : 28,
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                              onTap: () {
                                _showDeleteProductDialog(product);
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red[600],
                                    size: isSmallMobile ? 10 : 12,
                                  ),
                                  SizedBox(width: isSmallMobile ? 2 : 3),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: isSmallMobile ? 7 : 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<DataRow> _buildProductRows(bool isTablet) {
    return _filteredProducts.map((product) {
      final isLowStock = product.stockQuantity <= product.lowStockThreshold;
      
      return DataRow(
        cells: [
          DataCell(
            Container(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              Api.getFullImageUrl(product.imageUrl),
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  print('🖼️ Inventory: Image loaded successfully for product ${product.name}');
                                  return child;
                                }
                                print('🖼️ Inventory: Loading image for product ${product.name}: ${loadingProgress.expectedTotalBytes != null ? (loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).toStringAsFixed(1) : 'Unknown'}%');
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('🖼️ Inventory: Image error for product ${product.name}: $error');
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                );
                              },
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.image,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'SKU: ${product.sku}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getCategoryColor(product.categoryName ?? 'Uncategorized').withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getCategoryColor(product.categoryName ?? 'Uncategorized').withOpacity(0.3),
                ),
              ),
              child: Text(
                product.categoryName ?? 'Uncategorized',
                style: TextStyle(
                  color: _getCategoryColor(product.categoryName ?? 'Uncategorized'),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Text(
                '\$${product.costPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLowStock ? Colors.red[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isLowStock ? Colors.red[200]! : Colors.blue[200]!,
                ),
              ),
              child: Text(
                '${product.stockQuantity}',
                style: TextStyle(
                  color: isLowStock ? Colors.red : Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLowStock
                    ? Colors.red[100]
                    : Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLowStock ? Icons.warning : Icons.check_circle,
                    size: 14,
                    color: isLowStock ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isLowStock ? t(context, 'Low') : t(context, 'In Stock'),
                    style: TextStyle(
                      color: isLowStock ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                    onPressed: () {
                      _showEditProductDialog(product);
                    },
                    tooltip: t(context, 'Edit Product'),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    onPressed: () {
                      _showDeleteProductDialog(product);
                    },
                    tooltip: t(context, 'Delete Product'),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();
  }

  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'electronics':
        return Colors.blue;
      case 'clothing':
        return Colors.purple;
      case 'food':
        return Colors.orange;
      case 'sports':
        return Colors.green;
      case 'accessories':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => _ProductDialog(
        onSave: (productData, imageFile, {webImageBytes, webImageName}) async {
          try {
            await _apiService.createProduct(productData, imageFile: imageFile, webImageBytes: webImageBytes, webImageName: webImageName);
            _loadProducts();
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(t(context, 'Product added successfully')),
                    ],
                  ),
                  backgroundColor: Colors.green[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          } catch (e, stack) {
            print('Error adding product: $e');
            print('Stack trace: $stack');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t(context, 'Failed to add product. Please try again.')),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => _ProductDialog(
        product: product,
        onSave: (productData, imageFile, {webImageBytes, webImageName}) async {
          try {
            print('=== FRONTEND PRODUCT UPDATE DEBUG ===');
            print('Product ID to update: ${product.id}');
            print('Product data to send: $productData');
            
            await _apiService.updateProduct(product.id!, productData, imageFile: imageFile, webImageBytes: webImageBytes, webImageName: webImageName);
            
            print('Product updated successfully, now reloading products...');
            await _loadProducts();
            
            print('Products reloaded. Current products count: ${_products.length}');
            print('Updated product should be in list. Checking...');
            
            final updatedProduct = _products.firstWhere(
              (p) => p.id == product.id,
              orElse: () => Product(id: -1, name: '', sku: '', price: 0, costPrice: 0, stockQuantity: 0, damagedQuantity: 0, lowStockThreshold: 0),
            );
            
            if (updatedProduct.id != -1) {
              print('Found updated product in list:');
              print('  - Name: ${updatedProduct.name}');
              print('  - Cost Price: ${updatedProduct.costPrice}');
              print('  - Stock Quantity: ${updatedProduct.stockQuantity}');
            } else {
              print('ERROR: Updated product not found in list!');
            }
            
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(t(context, 'Product updated successfully')),
                    ],
                  ),
                  backgroundColor: Colors.green[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          } catch (e, stack) {
            print('Error updating product: $e');
            print('Stack trace: $stack');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t(context, 'Failed to update product. Please try again.')),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showDeleteProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth <= 480;
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_forever,
                    color: Colors.red,
                    size: isMobile ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete Product',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'Are you sure you want to delete this product?'),
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t(context, 'SKU')}: ${product.sku}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t(context, 'Stock')}: ${product.stockQuantity}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t(context, 'This action cannot be undone'),
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  t(context, 'Cancel'),
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteProduct(product.id!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  t(context, 'Delete'),
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ],
            actionsPadding: EdgeInsets.all(isMobile ? 16 : 24),
          );
        },
      ),
    );
  }

  Future<void> _deleteProduct(int productId) async {
    try {
      await _apiService.deleteProduct(productId);
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'Product deleted successfully')),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t(context, 'Error deleting product: ')}$e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _fetchRecentTransactions() async {
    setState(() { _recentLoading = true; _recentError = null; });
    try {
      final data = await _apiService.getInventoryTransactions({'limit': 10});
      setState(() { _recentTransactions = List<Map<String, dynamic>>.from(data); });
    } catch (e) {
      setState(() { _recentError = 'Failed to load recent transactions: $e'; });
    } finally {
      setState(() { _recentLoading = false; });
    }
  }

  Future<void> _fetchTodayTransactions() async {
    setState(() { _todayLoading = true; _todayError = null; });
    try {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      final end = start.add(Duration(days: 1)).subtract(Duration(milliseconds: 1));
      final data = await _apiService.getInventoryTransactions({
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
      });
      setState(() { _todayTransactions = List<Map<String, dynamic>>.from(data); });
    } catch (e) {
      setState(() { _todayError = 'Failed to load today\'s transactions: $e'; });
    } finally {
      setState(() { _todayLoading = false; });
    }
  }

  Future<void> _fetchWeekTransactions() async {
    setState(() { _weekLoading = true; _weekError = null; });
    try {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: now.weekday - 1));
      final end = start.add(Duration(days: 7)).subtract(Duration(milliseconds: 1));
      final data = await _apiService.getInventoryTransactions({
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
      });
      setState(() { _weekTransactions = List<Map<String, dynamic>>.from(data); });
    } catch (e) {
      setState(() { _weekError = 'Failed to load this week\'s transactions: $e'; });
    } finally {
      setState(() { _weekLoading = false; });
    }
  }

  void _loadFilteredTransactions() {
    if (_filterStartDate != null && _filterEndDate != null) {
      setState(() {
        _filteredLoading = true;
        _filteredError = null;
      });
      
      final params = <String, dynamic>{
        'start_date': _filterStartDate!.toIso8601String(),
        'end_date': _filterEndDate!.toIso8601String(),
      };
      
      _apiService.getInventoryTransactions(params).then((transactions) {
        setState(() {
          _filteredTransactions = transactions;
          _filteredLoading = false;
        });
      }).catchError((error) {
        setState(() {
          _filteredError = error.toString();
          _filteredLoading = false;
        });
      });
    }
  }

  void _applyStockSummaryPreset(String type) {
    final now = DateTime.now();
    if (type == 'Today') {
      _stockSummaryStartDate = DateTime(now.year, now.month, now.day);
      _stockSummaryEndDate = _stockSummaryStartDate!.add(Duration(days: 1)).subtract(Duration(milliseconds: 1));
    } else if (type == 'This Week') {
      _stockSummaryStartDate = now.subtract(Duration(days: now.weekday - 1));
      _stockSummaryEndDate = _stockSummaryStartDate!.add(Duration(days: 7)).subtract(Duration(milliseconds: 1));
    } else if (type == 'This Month') {
      _stockSummaryStartDate = DateTime(now.year, now.month, 1);
      _stockSummaryEndDate = DateTime(now.year, now.month + 1, 1).subtract(Duration(milliseconds: 1));
    }
    setState(() {});
    _fetchInventoryValueReport();
  }

  Widget _buildMobileReportFilters() {
    return Column(
      children: [
        // Horizontal Date Range Row
        Row(
          children: [
            // Start Date
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _startDate = date;
                      });
                      _loadFilteredTransactions();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _startDate != null
                                ? DateFormat('MMM dd').format(_startDate!)
                                : 'Start',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 6),
            
            // End Date
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _endDate = date;
                      });
                      _loadFilteredTransactions();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _endDate != null
                                ? DateFormat('MMM dd').format(_endDate!)
                                : 'End',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 6),
        
        // Horizontal Quick Date Buttons
        Row(
          children: [
            Expanded(
              child: _buildQuickDateButton('Today', () {
                setState(() {
                  _startDate = DateTime.now();
                  _endDate = DateTime.now();
                });
                _loadFilteredTransactions();
              }, isActive: _startDate?.day == DateTime.now().day && _endDate?.day == DateTime.now().day),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildQuickDateButton('Week', () {
                setState(() {
                  _startDate = DateTime.now().subtract(const Duration(days: 7));
                  _endDate = DateTime.now();
                });
                _loadFilteredTransactions();
              }, isActive: _startDate?.difference(DateTime.now()).inDays.abs() == 7),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildQuickDateButton('Month', () {
                setState(() {
                  _startDate = DateTime.now().subtract(const Duration(days: 30));
                  _endDate = DateTime.now();
                });
                _loadFilteredTransactions();
              }, isActive: _startDate?.difference(DateTime.now()).inDays.abs() == 30),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickDateButton(String text, VoidCallback onTap, {required bool isActive}) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).primaryColor : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive ? Theme.of(context).primaryColor : Colors.grey[300]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopReportFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        DropdownButton<String>(
          value: _selectedReportCategory ?? 'All',
          items: ['All', ..._categories.where((c) => c != 'All')]
              .map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  ))
              .toList(),
          onChanged: (val) {
            setState(() { _selectedReportCategory = val; });
          },
          hint: Text(t(context, 'Category')),
        ),
        DropdownButton<String>(
          value: _selectedReportProduct ?? 'All',
          items: ['All', ..._products.map((p) => p.name)]
              .map((prod) => DropdownMenuItem(
                    value: prod,
                    child: Text(prod),
                  ))
              .toList(),
          onChanged: (val) {
            setState(() { _selectedReportProduct = val; });
          },
          hint: Text(t(context, 'Product')),
        ),
        SizedBox(
          width: 120,
          child: CustomTextField(
            labelText: t(context, 'SKU'),
            onChanged: (val) { setState(() { _reportSku = val; }); },
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(_reportStartDate == null ? t(context, 'Start Date') : _reportStartDate!.toLocal().toString().split(' ')[0]),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() { _reportStartDate = picked; });
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(_reportEndDate == null ? t(context, 'End Date') : _reportEndDate!.toLocal().toString().split(' ')[0]),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() { _reportEndDate = picked; });
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: Text(t(context, 'Filter')),
          onPressed: _fetchInventoryReport,
        ),
      ],
    );
  }

  Widget _buildStockSummaryFilters(bool isSmallMobile) {
    return Column(
      children: [
        // Horizontal Filter Row
        Row(
          children: [
            // Filter Type Dropdown
            Expanded(
              flex: 2,
              child: Container(
                height: isSmallMobile ? 28 : 32,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _stockSummaryFilterType,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                      size: isSmallMobile ? 12 : 14,
                    ),
                    items: _stockSummaryFilterOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 6 : 8),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: isSmallMobile ? 9 : 10,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _stockSummaryFilterType = value!;
                      });
                      _fetchInventoryReport();
                    },
                  ),
                ),
              ),
            ),
            
            SizedBox(width: isSmallMobile ? 4 : 6),
            
            // Refresh Button
            Container(
              height: isSmallMobile ? 28 : 32,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                  onTap: _fetchInventoryReport,
                  child: Center(
                    child: Icon(
                      Icons.refresh,
                      color: Theme.of(context).primaryColor,
                      size: isSmallMobile ? 12 : 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValueReportTable(bool isSmallMobile) {
    if (_valueReportLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_valueReportError != null) {
      return Text(
        _valueReportError!,
        style: TextStyle(color: Colors.red, fontSize: isSmallMobile ? 12 : 14),
      );
    }
    
    if (_valueReportRows.isEmpty) {
      return Text(
        t(context, 'No stock summary data'),
        style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
      );
    }

    if (isSmallMobile) {
      // Mobile layout - cards
      return Column(
        children: _valueReportRows.map((row) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['product_name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SKU: ${row['sku'] ?? ''}', style: const TextStyle(fontSize: 12)),
                          Text('Category: ${row['category_name'] ?? ''}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Sold: ${_valueReportRows.fold<double>(0, (sum, r) => sum + _safeToDouble(r['quantity_sold'])).toInt()}', 
                               style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Remaining: ${row['quantity_remaining']?.toString() ?? ''}'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('Revenue: \$${_safeToDouble(row['revenue']).toStringAsFixed(2)}'),
                    ),
                    Expanded(
                      child: Text('Profit: \$${_safeToDouble(row['profit']).toStringAsFixed(2)}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )).toList(),
      );
    }

    // Desktop layout - table
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(t(context, 'Product'))),
          DataColumn(label: Text(t(context, 'SKU'))),
          DataColumn(label: Text(t(context, 'Category'))),
          DataColumn(label: Text(t(context, 'Sold Qty'))),
          DataColumn(label: Text(t(context, 'Qty Remaining'))),
          DataColumn(label: Text(t(context, 'Revenue'))),
          DataColumn(label: Text(t(context, 'Profit'))),
          DataColumn(label: Text(t(context, 'Mode'))),
        ],
        rows: [
          ..._valueReportRows.map((row) => DataRow(
            cells: [
              DataCell(
                InkWell(
                  child: Text(row['product_name'] ?? '', style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline)),
                  onTap: () => _showProductTransactionsDialog(row['product_id'], row['product_name'] ?? ''),
                ),
              ),
              DataCell(Text(row['sku'] ?? '')),
              DataCell(Text(row['category_name'] ?? '')),
              DataCell(Text(_valueReportRows.fold<double>(0, (sum, r) => sum + _safeToDouble(r['quantity_sold'])).toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(row['quantity_remaining']?.toString() ?? '')),
              DataCell(Text(_safeToDouble(row['revenue']).toStringAsFixed(2))),
              DataCell(Text(_safeToDouble(row['profit']).toStringAsFixed(2))),
              DataCell(Text((row['sale_mode'] ?? '').toString().isNotEmpty ? (row['sale_mode'] == 'wholesale' ? 'Wholesale' : 'Retail') : '')),
            ],
          )),
          // Totals row
          DataRow(
            color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
              return Colors.grey[200];
            }),
            cells: [
              DataCell(Text(t(context, 'TOTAL'), style: TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(_valueReportRows.fold<double>(0, (sum, r) => sum + _safeToDouble(r['quantity_sold'])).toInt().toString(), style: TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('')),
              DataCell(Text(_valueReportRows.fold<double>(0, (sum, r) => sum + _safeToDouble(r['revenue'])).toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_valueReportRows.fold<double>(0, (sum, r) => sum + _safeToDouble(r['profit'])).toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTable(List<Map<String, dynamic>> transactions, bool isLoading, String? error, String emptyMessage, bool isSmallMobile) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (error != null) {
      return Text(
        error,
        style: TextStyle(color: Colors.red, fontSize: isSmallMobile ? 12 : 14),
      );
    }
    
    if (transactions.isEmpty) {
      return Text(
        emptyMessage,
        style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
      );
    }

    if (isSmallMobile) {
      // Mobile layout - cards
      return Column(
        children: transactions.map((tx) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx['product_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tx['transaction_type'] ?? '',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Date: ${tx['created_at']?.toString()?.split('T')?.first ?? ''}', style: const TextStyle(fontSize: 12)),
                Text('Qty: ${tx['quantity']?.toString() ?? ''}', style: const TextStyle(fontSize: 12)),
                Text('Amount: \$${_safeToDouble(tx['sale_total_price']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                if (tx['notes'] != null && tx['notes'].toString().isNotEmpty)
                  Text('Notes: ${tx['notes']}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        )).toList(),
      );
    }

    // Desktop layout - table
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Sale Amount')),
          DataColumn(label: Text('Profit')),
          DataColumn(label: Text('Notes')),
          DataColumn(label: Text('Mode')),
        ],
        rows: transactions.map((tx) => DataRow(cells: [
          DataCell(Text(tx['created_at']?.toString()?.split('T')?.first ?? '')),
          DataCell(Text(tx['product_name'] ?? '')),
          DataCell(Text(tx['transaction_type'] ?? '')),
          DataCell(Text(tx['quantity']?.toString() ?? '')),
          DataCell(Text(_safeToDouble(tx['sale_total_price']).toStringAsFixed(2))),
          DataCell(Text(_safeToDouble(tx['profit']).toStringAsFixed(2))),
          DataCell(Text(tx['notes'] ?? '')),
          DataCell(Text((tx['sale_mode'] ?? '').toString().isNotEmpty ? (tx['sale_mode'] == 'wholesale' ? 'Wholesale' : 'Retail') : '')),
        ])).toList(),
      ),
    );
  }

  Widget _buildDateFilterControls(bool isSmallMobile) {
    return Column(
      children: [
        // Horizontal Date Range Row
        Row(
          children: [
            // Start Date
            Expanded(
              child: Container(
                height: isSmallMobile ? 28 : 32,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _filterStartDate ?? DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _filterStartDate = date;
                      });
                      _loadFilteredTransactions();
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 6 : 8, vertical: isSmallMobile ? 4 : 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: isSmallMobile ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: isSmallMobile ? 3 : 4),
                        Expanded(
                          child: Text(
                            _filterStartDate != null
                                ? DateFormat('MMM dd').format(_filterStartDate!)
                                : 'Start',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 9 : 10,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(width: isSmallMobile ? 4 : 6),
            
            // End Date
            Expanded(
              child: Container(
                height: isSmallMobile ? 28 : 32,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _filterEndDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _filterEndDate = date;
                      });
                      _loadFilteredTransactions();
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 6 : 8, vertical: isSmallMobile ? 4 : 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: isSmallMobile ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: isSmallMobile ? 3 : 4),
                        Expanded(
                          child: Text(
                            _filterEndDate != null
                                ? DateFormat('MMM dd').format(_filterEndDate!)
                                : 'End',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 9 : 10,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: isSmallMobile ? 4 : 6),
        
        // Horizontal Quick Date Buttons
        Row(
          children: [
            Expanded(
              child: _buildQuickFilterButton('Today', () {
                setState(() {
                  _filterStartDate = DateTime.now();
                  _filterEndDate = DateTime.now();
                });
                _loadFilteredTransactions();
              }, isActive: _filterStartDate?.day == DateTime.now().day && _filterEndDate?.day == DateTime.now().day),
            ),
            SizedBox(width: isSmallMobile ? 3 : 4),
            Expanded(
              child: _buildQuickFilterButton('Week', () {
                setState(() {
                  _filterStartDate = DateTime.now().subtract(const Duration(days: 7));
                  _filterEndDate = DateTime.now();
                });
                _loadFilteredTransactions();
              }, isActive: _filterStartDate?.difference(DateTime.now()).inDays.abs() == 7),
            ),
            SizedBox(width: isSmallMobile ? 3 : 4),
            Expanded(
              child: _buildQuickFilterButton('Month', () {
                setState(() {
                  _filterStartDate = DateTime.now().subtract(const Duration(days: 30));
                  _filterEndDate = DateTime.now();
                });
                _loadFilteredTransactions();
              }, isActive: _filterStartDate?.difference(DateTime.now()).inDays.abs() == 30),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickFilterButton(String text, VoidCallback onTap, {required bool isActive}) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).primaryColor : Colors.grey[100],
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isActive ? Theme.of(context).primaryColor : Colors.grey[300]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(3),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(bool isSmallMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: isSmallMobile ? 14 : 16,
              color: Colors.blue[600],
            ),
            SizedBox(width: isSmallMobile ? 3 : 4),
            Icon(
              Icons.add,
              size: isSmallMobile ? 10 : 12,
              color: Colors.grey[600],
            ),
            SizedBox(width: isSmallMobile ? 3 : 4),
            Icon(
              Icons.photo_library,
              size: isSmallMobile ? 14 : 16,
              color: Colors.green[600],
            ),
          ],
        ),
        SizedBox(height: isSmallMobile ? 6 : 8),
        Text(
          t(context, 'Add Image'),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: isSmallMobile ? 9 : 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isSmallMobile ? 2 : 4),
        Text(
          t(context, 'Camera or Gallery'),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: isSmallMobile ? 7 : 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFilters(bool isSmallMobile) {
    return Column(
      children: [
        // Horizontal Search and Category Row
        Row(
          children: [
            // Search Field - Compact
            Expanded(
              flex: 2,
              child: Container(
                height: isSmallMobile ? 32 : 36,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isSmallMobile ? 'Search...' : 'Search...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[600],
                      size: isSmallMobile ? 14 : 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallMobile ? 8 : 10,
                      vertical: isSmallMobile ? 6 : 8,
                    ),
                  ),
                  onChanged: (value) {
                    _applyFilters();
                  },
                ),
              ),
            ),
            
            SizedBox(width: isSmallMobile ? 6 : 8),
            
            // Category Dropdown - Compact
            Expanded(
              flex: 1,
              child: Container(
                height: isSmallMobile ? 32 : 36,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _categories.contains(_selectedCategory) ? _selectedCategory : (_categories.isNotEmpty ? _categories.first : null),
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                      size: isSmallMobile ? 14 : 16,
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 6 : 8),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                      _applyFilters();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: isSmallMobile ? 6 : 8),
        
        // Horizontal Low Stock Toggle
        Container(
          height: isSmallMobile ? 32 : 36,
          decoration: BoxDecoration(
            color: _showLowStock ? Colors.red[50] : Colors.grey[50],
            borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
            border: Border.all(
              color: _showLowStock ? Colors.red[200]! : Colors.grey[200]!,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                margin: EdgeInsets.only(left: isSmallMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: _showLowStock ? Colors.red[100] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                ),
                child: Icon(
                  _showLowStock ? Icons.warning : Icons.inventory,
                  color: _showLowStock ? Colors.red[600] : Colors.grey[600],
                  size: isSmallMobile ? 14 : 16,
                ),
              ),
              SizedBox(width: isSmallMobile ? 6 : 8),
              Expanded(
                child: Text(
                  'Low Stock Only',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: _showLowStock ? Colors.red[800] : Colors.grey[800],
                  ),
                ),
              ),
              Switch(
                value: _showLowStock,
                onChanged: (value) {
                  setState(() {
                    _showLowStock = value;
                  });
                  _applyFilters();
                },
                activeColor: Colors.red[600],
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              SizedBox(width: isSmallMobile ? 8 : 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    return Row(
      children: [
        // Search Field
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: t(context, 'Search products by name or SKU...'),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              onChanged: (value) {
                _applyFilters();
              },
            ),
          ),
        ),
        const SizedBox(width: 20),
        
        // Category Dropdown
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _categories.contains(_selectedCategory) ? _selectedCategory : (_categories.isNotEmpty ? _categories.first : null),
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                  size: 24,
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                  _applyFilters();
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        
        // Low Stock Toggle
        Container(
          decoration: BoxDecoration(
            color: _showLowStock ? Colors.red[50] : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _showLowStock ? Colors.red[200]! : Colors.grey[200]!,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showLowStock ? Icons.warning : Icons.inventory,
                  color: _showLowStock ? Colors.red[600] : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Low Stock',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _showLowStock ? Colors.red[800] : Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _showLowStock,
                  onChanged: (value) {
                    setState(() {
                      _showLowStock = value;
                    });
                    _applyFilters();
                  },
                  activeColor: Colors.red[600],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductDialog extends StatefulWidget {
  final Product? product;
  final Function(Map<String, dynamic>, File?, {Uint8List? webImageBytes, String? webImageName}) onSave;

  const _ProductDialog({
    this.product,
    required this.onSave,
  });

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _skuController = TextEditingController();
  
  File? _imageFile;
  String? _imageUrl;
  String? _webImageDataUrl;
  String? _webImageName;
  bool _isLoading = false;
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description ?? '';
      _priceController.text = widget.product!.price.toString();
      _costController.text = widget.product!.costPrice.toString();
      _stockController.text = widget.product!.stockQuantity.toString();
      _skuController.text = widget.product!.sku ?? '';
      _imageUrl = widget.product!.imageUrl;
      _selectedCategoryId = widget.product!.categoryId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ApiService().getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show dialog to choose between camera and gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.add_a_photo, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(t(context, 'Select Image Source')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.blue),
                        ),
                        title: Text(
                          t(context, 'Camera'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(t(context, 'Take a new photo')),
                        onTap: () => Navigator.of(context).pop(ImageSource.camera),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                      Divider(height: 1, color: Colors.grey[300]),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.photo_library, color: Colors.green),
                        ),
                        title: Text(
                          t(context, 'Gallery'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(t(context, 'Choose from gallery')),
                        onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t(context, 'Cancel')),
              ),
            ],
          );
        },
      );

      if (source != null) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        
        if (image != null) {
          setState(() {
            _imageFile = File(image.path);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickImageWeb() async {
    try {
      // Show dialog to choose between camera and file picker
      final bool? useCamera = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.add_a_photo, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(t(context, 'Select Image Source')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.blue),
                        ),
                        title: Text(
                          t(context, 'Camera'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(t(context, 'Take a new photo')),
                        onTap: () => Navigator.of(context).pop(true),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                      Divider(height: 1, color: Colors.grey[300]),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.photo_library, color: Colors.green),
                        ),
                        title: Text(
                          t(context, 'File Picker'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(t(context, 'Choose from files')),
                        onTap: () => Navigator.of(context).pop(false),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t(context, 'Cancel')),
              ),
            ],
          );
        },
      );

      if (useCamera == null) return;

      if (useCamera) {
        // Use camera for web
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        
        if (image != null) {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          final mimeType = 'image/jpeg'; // Camera typically returns JPEG
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          
          setState(() {
            _webImageDataUrl = 'data:$mimeType;base64,$base64String';
            _webImageName = 'camera_$timestamp.jpg';
          });
        }
      } else {
        // Use file picker
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg'],
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          if (file.bytes != null) {
            // Determine MIME type and force lowercase extension
            String? ext = file.extension?.toLowerCase();
            String mimeType =
                ext == 'png' ? 'image/png' :
                (ext == 'jpg' || ext == 'jpeg') ? 'image/jpeg' : 'image/jpeg';
            String forcedExt = (ext == 'png' || ext == 'jpg' || ext == 'jpeg') ? ext! : 'jpg';
            String baseName = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
            setState(() {
              _webImageDataUrl = 'data:$mimeType;base64,${base64Encode(file.bytes!)}';
              _webImageName = baseName + '.' + forcedExt;
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'cost_price': double.parse(_costController.text),
        'stock_quantity': int.parse(_stockController.text),
        'category_id': _selectedCategoryId,
        'sku': _skuController.text.trim(),
        'low_stock_threshold': 10, // Default value
      };

      widget.onSave(productData, _imageFile, webImageBytes: kIsWeb && _webImageDataUrl != null ? base64Decode(_webImageDataUrl!.split(',').last) : null, webImageName: kIsWeb ? _webImageName : null);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'Error: ')}$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth <= 480;
          final isSmallMobile = constraints.maxWidth <= 360;
          
          return Container(
            width: MediaQuery.of(context).size.width * (isSmallMobile ? 0.98 : (isMobile ? 0.95 : 0.9)),
            constraints: BoxConstraints(
              maxWidth: isSmallMobile ? 350 : (isMobile ? 400 : 600),
              maxHeight: MediaQuery.of(context).size.height * (isSmallMobile ? 0.95 : 0.9),
            ),
            padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 16 : 24)),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 12 : 16)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(isSmallMobile ? 12 : 16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isSmallMobile ? 4 : (isMobile ? 6 : 8)),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                            ),
                            child: Icon(
                              widget.product == null ? Icons.add_box : Icons.edit,
                              color: Colors.white,
                              size: isSmallMobile ? 18 : (isMobile ? 20 : 24),
                            ),
                          ),
                          SizedBox(width: isSmallMobile ? 8 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.product == null ? t(context, 'Add New Product') : t(context, 'Edit Product'),
                                  style: TextStyle(
                                    fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 20),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: isSmallMobile ? 1 : 2),
                                Text(
                                  widget.product == null 
                                      ? t(context, 'Create a new product in your inventory')
                                      : t(context, 'Update product information'),
                                  style: TextStyle(
                                    fontSize: isSmallMobile ? 9 : (isMobile ? 11 : 14),
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                            padding: EdgeInsets.all(isSmallMobile ? 2 : (isMobile ? 4 : 8)),
                            constraints: BoxConstraints(
                              minWidth: isSmallMobile ? 28 : (isMobile ? 32 : 40),
                              minHeight: isSmallMobile ? 28 : (isMobile ? 32 : 40),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallMobile ? 16 : 24),
                    
                    // Image Section
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          if (kIsWeb) {
                            _pickImageWeb();
                          } else {
                            _pickImage();
                          }
                        },
                        child: Container(
                          width: isSmallMobile ? 80 : (isMobile ? 100 : 120),
                          height: isSmallMobile ? 80 : (isMobile ? 100 : 120),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(isSmallMobile ? 12 : 16),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: kIsWeb
                              ? (_webImageDataUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(isSmallMobile ? 10 : 14),
                                      child: Image.network(
                                        _webImageDataUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            _buildImagePlaceholder(isSmallMobile),
                                      ),
                                    )
                                  : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(isSmallMobile ? 10 : 14),
                                          child: Image.network(
                                            Api.getFullImageUrl(_imageUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildImagePlaceholder(isSmallMobile),
                                          ),
                                        )
                                      : _buildImagePlaceholder(isSmallMobile))
                              : _imageFile != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(isSmallMobile ? 10 : 14),
                                      child: Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(isSmallMobile ? 10 : 14),
                                          child: Image.network(
                                            Api.getFullImageUrl(_imageUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildImagePlaceholder(isSmallMobile),
                                          ),
                                        )
                                      : _buildImagePlaceholder(isSmallMobile),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallMobile ? 16 : 24),

                    // Form Fields
                    if (isMobile) ...[
                      // Mobile layout - stacked vertically
                      _buildMobileFormFields(isSmallMobile),
                    ] else ...[
                      // Desktop/Tablet layout - horizontal rows
                      _buildDesktopFormFields(),
                    ],
                    SizedBox(height: isSmallMobile ? 16 : 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isSmallMobile ? 10 : (isMobile ? 12 : 16)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                              ),
                            ),
                            child: Text(
                              t(context, 'Cancel'),
                              style: TextStyle(fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16)),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallMobile ? 12 : 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isSmallMobile ? 10 : (isMobile ? 12 : 16)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: isSmallMobile ? 14 : (isMobile ? 16 : 20),
                                    width: isSmallMobile ? 14 : (isMobile ? 16 : 20),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    widget.product == null ? 'Add Product' : 'Update Product',
                                    style: TextStyle(
                                      fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileFormFields(bool isSmallMobile) {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: t(context, 'Product Name *'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
            ),
            prefixIcon: Icon(Icons.inventory_2, size: isSmallMobile ? 18 : 20),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 12 : 16,
              vertical: isSmallMobile ? 10 : 14,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return t(context, 'Product name is required');
            }
            return null;
          },
        ),
        SizedBox(height: isSmallMobile ? 12 : 16),
        TextFormField(
          controller: _skuController,
          decoration: InputDecoration(
            labelText: t(context, 'SKU *'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
            ),
            prefixIcon: Icon(Icons.qr_code, size: isSmallMobile ? 18 : 20),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 12 : 16,
              vertical: isSmallMobile ? 10 : 14,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return t(context, 'SKU is required');
            }
            return null;
          },
        ),
        SizedBox(height: isSmallMobile ? 12 : 16),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: t(context, 'Description'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
            ),
            prefixIcon: Icon(Icons.description, size: isSmallMobile ? 18 : 20),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 12 : 16,
              vertical: isSmallMobile ? 10 : 14,
            ),
          ),
          maxLines: 3,
        ),
        SizedBox(height: isSmallMobile ? 12 : 16),
        TextFormField(
          controller: _priceController,
          decoration: InputDecoration(
            labelText: t(context, 'Price *'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
            ),
            prefixIcon: Icon(Icons.attach_money, size: isSmallMobile ? 18 : 20),
            filled: true,
            fillColor: Colors.green[50],
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 12 : 16,
              vertical: isSmallMobile ? 10 : 14,
            ),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return t(context, 'Price is required');
            }
            if (double.tryParse(value) == null) {
              return t(context, 'Please enter a valid number');
            }
            return null;
          },
        ),
        SizedBox(height: isSmallMobile ? 12 : 16),
        TextFormField(
          controller: _costController,
          decoration: InputDecoration(
            labelText: t(context, 'Cost *'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
            ),
            prefixIcon: Icon(Icons.account_balance_wallet, size: isSmallMobile ? 18 : 20),
            filled: true,
            fillColor: Colors.orange[50],
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 12 : 16,
              vertical: isSmallMobile ? 10 : 14,
            ),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return t(context, 'Cost is required');
            }
            if (double.tryParse(value) == null) {
              return t(context, 'Please enter a valid number');
            }
            return null;
          },
        ),
        SizedBox(height: isSmallMobile ? 12 : 16),
        TextFormField(
          controller: _stockController,
          decoration: InputDecoration(
            labelText: t(context, 'Stock Quantity'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
            ),
            prefixIcon: Icon(Icons.inventory, size: isSmallMobile ? 18 : 20),
            filled: true,
            fillColor: Colors.blue[50],
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 12 : 16,
              vertical: isSmallMobile ? 10 : 14,
            ),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return t(context, 'Stock quantity is required');
            }
            if (int.tryParse(value) == null) {
              return t(context, 'Please enter a valid number');
            }
            return null;
          },
        ),
        SizedBox(height: isSmallMobile ? 12 : 16),
        DropdownButtonFormField<int>(
          value: _categories.any((cat) => cat['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
          decoration: InputDecoration(
            labelText: t(context, 'Category'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
            ),
            prefixIcon: Icon(Icons.category, size: isSmallMobile ? 18 : 20),
            filled: true,
            fillColor: Colors.purple[50],
            helperText: t(context, 'Select a category for this product (optional)'),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 12 : 16,
              vertical: isSmallMobile ? 10 : 14,
            ),
          ),
          items: [
            DropdownMenuItem<int>(
              value: null,
              child: Text(t(context, 'Select Category')),
            ),
            ..._categories.map((category) {
              return DropdownMenuItem<int>(
                value: category['id'] as int,
                child: Text(category['name'] as String),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDesktopFormFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: t(context, 'Product Name *'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.inventory_2),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return t(context, 'Product name is required');
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _skuController,
                decoration: InputDecoration(
                  labelText: t(context, 'SKU *'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.qr_code),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return t(context, 'SKU is required');
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: t(context, 'Description'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.description),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: t(context, 'Price *'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
                  filled: true,
                  fillColor: Colors.green[50],
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return t(context, 'Price is required');
                  }
                  if (double.tryParse(value) == null) {
                    return t(context, 'Please enter a valid number');
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _costController,
                decoration: InputDecoration(
                  labelText: t(context, 'Cost *'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.account_balance_wallet),
                  filled: true,
                  fillColor: Colors.orange[50],
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return t(context, 'Price is required');
                  }
                  if (double.tryParse(value) == null) {
                    return t(context, 'Please enter a valid number');
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: t(context, 'Stock Quantity'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.inventory),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return t(context, 'Stock quantity is required');
                  }
                  if (int.tryParse(value) == null) {
                    return t(context, 'Please enter a valid number');
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _categories.any((cat) => cat['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
                decoration: InputDecoration(
                  labelText: t(context, 'Category'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                  filled: true,
                  fillColor: Colors.purple[50],
                ),
                items: [
                  DropdownMenuItem<int>(
                    value: null,
                    child: Text(t(context, 'Select Category')),
                  ),
                  ..._categories.map((category) {
                    return DropdownMenuItem<int>(
                      value: category['id'] as int,
                      child: Text(category['name'] as String),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder(bool isSmallMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: isSmallMobile ? 14 : 16,
              color: Colors.blue[600],
            ),
            SizedBox(width: isSmallMobile ? 3 : 4),
            Icon(
              Icons.add,
              size: isSmallMobile ? 10 : 12,
              color: Colors.grey[600],
            ),
            SizedBox(width: isSmallMobile ? 3 : 4),
            Icon(
              Icons.photo_library,
              size: isSmallMobile ? 14 : 16,
              color: Colors.green[600],
            ),
          ],
        ),
        SizedBox(height: isSmallMobile ? 6 : 8),
        Text(
          t(context, 'Add Image'),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: isSmallMobile ? 9 : 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isSmallMobile ? 2 : 4),
        Text(
          t(context, 'Camera or Gallery'),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: isSmallMobile ? 7 : 8,
          ),
        ),
      ],
    );
  }
} 