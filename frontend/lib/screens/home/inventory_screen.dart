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
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _apiService.getProducts();
      print('🖼️ Inventory: Loaded ${products.length} products');
      
      // Debug: Print image URLs for products with images
      for (final product in products) {
        if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
          final fullUrl = Api.getFullImageUrl(product.imageUrl);
          print('🖼️ Inventory: Product "${product.name}" - Image URL: $fullUrl');
        }
      }
      
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'error_loading_products')}: $e')),
        );
      }
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
    final isTablet = screenWidth > 768;
    final isMobile = screenWidth <= 600; // Increased mobile breakpoint for better coverage
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
                  return BrandedHeader(
                    subtitle: t(context, 'Manage your product inventory efficiently'),
                    logoSize: isMobile ? 50 : 60,
                    actions: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _loadProducts,
                          tooltip: t(context, 'Refresh Data'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showAddProductDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          isMobile ? t(context, 'Add') : t(context, 'Add Product'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Filters Section
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(context, 'Filters'),
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isMobile) ...[
                      CustomTextField(
                        controller: _searchController,
                        labelText: t(context, 'Search Products'),
                        prefixIcon: const Icon(Icons.search),
                        onChanged: (value) {
                          _applyFilters();
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _categories.contains(_selectedCategory) ? _selectedCategory : (_categories.isNotEmpty ? _categories.first : null),
                                underline: const SizedBox(),
                                isExpanded: true,
                                items: _categories.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(
                                      category,
                                      overflow: TextOverflow.ellipsis,
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
                          const SizedBox(width: 12),
                          FilterChip(
                            label: const Text('Low Stock'),
                            selected: _showLowStock,
                            selectedColor: Colors.red[100],
                            checkmarkColor: Colors.red,
                            onSelected: (value) {
                              setState(() {
                                _showLowStock = value;
                              });
                              _applyFilters();
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _searchController,
                              labelText: t(context, 'Search Products'),
                              prefixIcon: const Icon(Icons.search),
                              onChanged: (value) {
                                _applyFilters();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: _categories.contains(_selectedCategory) ? _selectedCategory : (_categories.isNotEmpty ? _categories.first : null),
                              underline: const SizedBox(),
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(
                                    category,
                                    overflow: TextOverflow.ellipsis,
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
                          const SizedBox(width: 16),
                          FilterChip(
                            label: const Text('Low Stock'),
                            selected: _showLowStock,
                            selectedColor: Colors.red[100],
                            checkmarkColor: Colors.red,
                            onSelected: (value) {
                              setState(() {
                                _showLowStock = value;
                              });
                              _applyFilters();
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Inventory Report Section
              ExpansionPanelList(
                expansionCallback: (int index, bool isExpanded) {
                  setState(() { _showInventoryReport = !_showInventoryReport; });
                },
                children: [
                  ExpansionPanel(
                    isExpanded: _showInventoryReport,
                    headerBuilder: (context, isExpanded) {
                      return ListTile(
                        leading: Icon(Icons.bar_chart, color: Theme.of(context).primaryColor),
                        title: Text(t(context, 'Inventory Report'), style: TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                    body: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
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
                                  icon: Icon(Icons.date_range),
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
                                  icon: Icon(Icons.date_range),
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
                                  icon: Icon(Icons.search),
                                  label: Text(t(context, 'Filter')),
                                  onPressed: _fetchInventoryReport,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(t(context, 'Stock Summary'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Row(
                              children: [
                                DropdownButton<String>(
                                  value: _stockSummaryFilterType,
                                  items: _stockSummaryFilterOptions.map((option) => DropdownMenuItem(
                                    value: option,
                                    child: Text(option),
                                  )).toList(),
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setState(() { _stockSummaryFilterType = val; });
                                    if (val != 'Custom') {
                                      _applyStockSummaryPreset(val);
                                    }
                                  },
                                ),
                                if (_stockSummaryFilterType == 'Custom') ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    icon: Icon(Icons.date_range),
                                    label: Text(_stockSummaryStartDate == null ? t(context, 'Start Date') : _stockSummaryStartDate!.toLocal().toString().split(' ')[0]),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _stockSummaryStartDate ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) setState(() { _stockSummaryStartDate = picked; });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    icon: Icon(Icons.date_range),
                                    label: Text(_stockSummaryEndDate == null ? t(context, 'End Date') : _stockSummaryEndDate!.toLocal().toString().split(' ')[0]),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _stockSummaryEndDate ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) setState(() { _stockSummaryEndDate = picked; });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.search),
                                    label: Text(t(context, 'Filter')),
                                    onPressed: _fetchInventoryValueReport,
                                  ),
                                ],
                              ],
                            ),
                            _valueReportLoading
                                ? Center(child: CircularProgressIndicator())
                                : _valueReportError != null
                                    ? Text(_valueReportError!, style: TextStyle(color: Colors.red))
                                    : _valueReportRows.isEmpty
                                        ? Text(t(context, 'No stock summary data'))
                                        : SingleChildScrollView(
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
                                                    DataCell(Text(_valueReportRows.fold<double>(0, (sum, r) => sum + _safeToDouble(r['quantity_sold'])).toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                                    const DataCell(Text('')),
                                                    DataCell(Text(_valueReportRows.fold<double>(0, (sum, r) => sum + _safeToDouble(r['revenue'])).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                                                    DataCell(Text(_valueReportRows.fold<double>(0, (sum, r) => sum + _safeToDouble(r['profit'])).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                                                    const DataCell(Text('')),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                            const SizedBox(height: 16),
                            _reportLoading
                                ? Center(child: CircularProgressIndicator())
                                : _reportTransactions.isEmpty
                                    ? Text(t(context, 'No report data, adjust filters and try again'))
                                    : SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          columns: [
                                            DataColumn(label: Text(t(context, 'Date'))),
                                            DataColumn(label: Text(t(context, 'Product'))),
                                            DataColumn(label: Text(t(context, 'SKU'))),
                                            DataColumn(label: Text(t(context, 'Category'))),
                                            DataColumn(label: Text(t(context, 'Type'))),
                                            DataColumn(label: Text(t(context, 'Quantity'))),
                                            DataColumn(label: Text(t(context, 'Notes'))),
                                            DataColumn(label: Text(t(context, 'Mode'))),
                                          ],
                                          rows: _reportTransactions.map((tx) => DataRow(cells: [
                                            DataCell(Text(tx['created_at']?.toString()?.split('T')?.first ?? '')),
                                            DataCell(Text(tx['product_name'] ?? '')),
                                            DataCell(Text(tx['sku'] ?? '')),
                                            DataCell(Text(tx['category_name'] ?? '')),
                                            DataCell(Text(tx['transaction_type'] ?? '')),
                                            DataCell(Text(tx['quantity']?.toString() ?? '')),
                                            DataCell(Text(tx['notes'] ?? '')),
                                            DataCell(Text((tx['sale_mode'] ?? '').toString().isNotEmpty ? (tx['sale_mode'] == 'wholesale' ? 'Wholesale' : 'Retail') : '')),
                                          ])).toList(),
                                        ),
                                      ),
                            const SizedBox(height: 24),
                            Text(t(context, 'Recent Transactions'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            _recentLoading
                                ? Center(child: CircularProgressIndicator())
                                : _recentError != null
                                    ? Text(_recentError!, style: TextStyle(color: Colors.red))
                                    : _recentTransactions.isEmpty
                                        ? Text(t(context, 'No recent transactions'))
                                        : SingleChildScrollView(
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
                                              rows: _recentTransactions.map((tx) => DataRow(cells: [
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
                                          ),
                            const SizedBox(height: 24),
                            Text('Todays Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            _todayLoading
                                ? Center(child: CircularProgressIndicator())
                                : _todayError != null
                                    ? Text(_todayError!, style: TextStyle(color: Colors.red))
                                    : _todayTransactions.isEmpty
                                        ? Text(t(context, 'No transactions today'))
                                        : SingleChildScrollView(
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
                                              rows: _todayTransactions.map((tx) => DataRow(cells: [
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
                                          ),
                            const SizedBox(height: 24),
                            Text('This Weeks Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            _weekLoading
                                ? Center(child: CircularProgressIndicator())
                                : _weekError != null
                                    ? Text(_weekError!, style: TextStyle(color: Colors.red))
                                    : _weekTransactions.isEmpty
                                        ? Text(t(context, 'No transactions this week'))
                                        : SingleChildScrollView(
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
                                              rows: _weekTransactions.map((tx) => DataRow(cells: [
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
                                          ),
                            const SizedBox(height: 24),
                            Text('Filter Transactions by Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: Icon(Icons.date_range),
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
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: Icon(Icons.date_range),
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
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.search),
                                  label: Text(t(context, 'Filter')),
                                  onPressed: () => _fetchFilteredTransactions(_reportStartDate, _reportEndDate),
                                ),
                              ],
                            ),
                            _filteredLoading
                                ? Center(child: CircularProgressIndicator())
                                : _filteredError != null
                                    ? Text(_filteredError!, style: TextStyle(color: Colors.red))
                                    : _filteredTransactions.isEmpty
                                        ? Text(t(context, 'No transactions for selected dates'))
                                        : SingleChildScrollView(
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
                                              rows: _filteredTransactions.map((tx) => DataRow(cells: [
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
                                          ),
                          ],
                        ),
                      ),
                    ),
                    canTapOnHeader: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Products Table Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(t(context, 'Loading products...')),
                          ],
                        ),
                      )
                    : _filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  t(context, 'No products found'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : isMobile
                            ? _buildMobileProductList()
                            : SingleChildScrollView(
                                child: DataTable(
                                  columns: _buildDataTableColumns(isTablet),
                                  rows: _buildProductRows(isTablet),
                                ),
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

  Widget _buildMobileProductList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final isLowStock = product.stockQuantity <= product.lowStockThreshold;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Header
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
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
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.image,
                                color: Colors.blue,
                                size: 24,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SKU: ${product.sku}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Product Details
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(product.categoryName ?? 'Uncategorized').withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getCategoryColor(product.categoryName ?? 'Uncategorized').withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.category,
                                  size: 14,
                                  color: _getCategoryColor(product.categoryName ?? 'Uncategorized'),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    product.categoryName ?? 'Uncategorized',
                                    style: TextStyle(
                                      color: _getCategoryColor(product.categoryName ?? 'Uncategorized'),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text(
                              '\$${product.costPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLowStock ? Colors.red[50] : Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isLowStock ? Colors.red[200]! : Colors.blue[200]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stock: ${product.stockQuantity}',
                                  style: TextStyle(
                                    color: isLowStock ? Colors.red : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (product.damagedQuantity > 0)
                                  Text(
                                    'Damaged: ${product.damagedQuantity}',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
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
                                  isLowStock ? t(context, 'Low Stock') : t(context, 'In Stock'),
                                  style: TextStyle(
                                    color: isLowStock ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                        onPressed: () {
                          _showEditProductDialog(product);
                        },
                        tooltip: t(context, 'Edit Product'),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () {
                          _showDeleteProductDialog(product);
                        },
                        tooltip: t(context, 'Delete Product'),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                style: const TextStyle(
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

  Future<void> _fetchFilteredTransactions(DateTime? start, DateTime? end) async {
    setState(() { _filteredLoading = true; _filteredError = null; });
    try {
      final params = <String, dynamic>{};
      if (start != null) params['start_date'] = start.toIso8601String();
      if (end != null) params['end_date'] = end.toIso8601String();
      final data = await _apiService.getInventoryTransactions(params);
      setState(() { _filteredTransactions = List<Map<String, dynamic>>.from(data); });
    } catch (e) {
      setState(() { _filteredError = 'Failed to load filtered transactions: $e'; });
    } finally {
      setState(() { _filteredLoading = false; });
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
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickImageWeb() async {
    try {
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
          
          return Container(
            width: MediaQuery.of(context).size.width * (isMobile ? 0.95 : 0.9),
            constraints: BoxConstraints(
              maxWidth: isMobile ? 400 : 600,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isMobile ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.product == null ? Icons.add_box : Icons.edit,
                              color: Colors.white,
                              size: isMobile ? 20 : 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.product == null ? t(context, 'Add New Product') : t(context, 'Edit Product'),
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.product == null 
                                      ? t(context, 'Create a new product in your inventory')
                                      : t(context, 'Update product information'),
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                            padding: EdgeInsets.all(isMobile ? 4 : 8),
                            constraints: BoxConstraints(
                              minWidth: isMobile ? 32 : 40,
                              minHeight: isMobile ? 32 : 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
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
                          width: isMobile ? 100 : 120,
                          height: isMobile ? 100 : 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: kIsWeb
                              ? (_webImageDataUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(
                                        _webImageDataUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            _buildImagePlaceholder(isMobile),
                                      ),
                                    )
                                  : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.network(
                                            Api.getFullImageUrl(_imageUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildImagePlaceholder(isMobile),
                                          ),
                                        )
                                      : _buildImagePlaceholder(isMobile))
                              : _imageFile != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.network(
                                            Api.getFullImageUrl(_imageUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildImagePlaceholder(isMobile),
                                          ),
                                        )
                                      : _buildImagePlaceholder(isMobile),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form Fields
                    if (isMobile) ...[
                      // Mobile layout - stacked vertically
                      TextFormField(
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
                      const SizedBox(height: 16),
                      TextFormField(
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
                      TextFormField(
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
                      const SizedBox(height: 16),
                      TextFormField(
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
                            return t(context, 'Cost is required');
                          }
                          if (double.tryParse(value) == null) {
                            return t(context, 'Please enter a valid number');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _categories.any((cat) => cat['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
                        decoration: InputDecoration(
                          labelText: t(context, 'Category *'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.category),
                          filled: true,
                          fillColor: Colors.purple[50],
                          helperText: t(context, 'Select a category for this product'),
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
                        validator: (value) {
                          if (value == null) {
                            return t(context, 'Please select a category');
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      // Desktop/Tablet layout - horizontal rows
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
                                  return t(context, 'Cost is required');
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
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              t(context, 'Cancel'),
                              style: TextStyle(fontSize: isMobile ? 14 : 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: isMobile ? 16 : 20,
                                    width: isMobile ? 16 : 20,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    widget.product == null ? 'Add Product' : 'Update Product',
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 16,
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

  Widget _buildImagePlaceholder(bool isMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo,
          size: isMobile ? 24 : 32,
          color: Colors.grey[600],
        ),
        const SizedBox(height: 8),
        Text(
          t(context, 'Add Image'),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: isMobile ? 10 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
} 