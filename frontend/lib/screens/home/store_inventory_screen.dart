import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/success_utils.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:retail_management/models/product.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:retail_management/utils/api.dart';

class StoreInventoryScreen extends StatefulWidget {
  final int storeId;
  final String storeName;
  
  const StoreInventoryScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StoreInventoryScreen> createState() => _StoreInventoryScreenState();
}

class _StoreInventoryScreenState extends State<StoreInventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  // Data variables
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _movements = [];
  Map<String, dynamic> _reports = {};
  bool _loading = false;
  String? _error;
  
  // Filter variables
  String _searchQuery = '';
  String _selectedMovementType = '';
  String _selectedProductId = '';
  
  // Stock Summary Report fields (matching inventory_screen.dart)
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
  // Add separate state for stock summary date filters
  DateTime? _stockSummaryStartDate;
  DateTime? _stockSummaryEndDate;
  // Add state for stock summary filter type
  String _stockSummaryFilterType = 'Today';
  final List<String> _stockSummaryFilterOptions = ['Today', 'This Week', 'This Month', 'Custom'];
  // Pagination state variables
  static const int _itemsPerPage = 10;
  int _stockSummaryCurrentPage = 0;
  
  // Business selection for superadmin
  List<Map<String, dynamic>> _businesses = [];
  int? _selectedBusinessId;
  
  // Detailed Reports state variables
  Map<String, dynamic> _detailedMovementsData = {};
  Map<String, dynamic> _purchasesData = {};
  Map<String, dynamic> _incrementsData = {};
  Map<String, dynamic> _businessTransfersData = {};
  bool _detailedMovementsLoading = false;
  bool _purchasesLoading = false;
  bool _incrementsLoading = false;
  bool _businessTransfersLoading = false;
  
  // Business Transfers filter state
  String _businessTransfersTimePeriod = 'all'; // 'all', 'today', 'week', 'month', 'custom'
  DateTime? _businessTransfersStartDate;
  DateTime? _businessTransfersEndDate;
  int? _selectedProductForTransfers;
  int? _selectedBusinessForTransfers;
  String? _selectedTransferStatus;
  
  // Detailed Reports filter variables
  DateTime? _detailedMovementsStartDate;
  DateTime? _detailedMovementsEndDate;
  String? _selectedDetailedMovementType;
  String? _selectedReferenceType;
  int? _selectedProductForDetailed;
  int _detailedMovementsPage = 1;
  
  static const int _detailedReportsPageSize = 50;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _initializeDateFilters();
    // Load data after the widget is built to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeDateFilters() {
    _stockSummaryFilterType = 'Today';
    _applyStockSummaryPreset('Today');
  }
  
  Future<void> _initializeData() async {
    final user = context.read<AuthProvider>().user;
    
    // Load businesses for all users (needed for transfer dialog)
    await _loadBusinesses();
    
    // If superadmin, wait for business selection
    if (user?.role == 'superadmin') {
      // Don't load data yet, wait for business selection
    } else {
      _loadData();
    }
  }
  
  Future<void> _loadBusinesses() async {
    try {
      // Get businesses assigned to this store
      final businesses = await _apiService.getBusinessesAssignedToStore(widget.storeId);
      setState(() {
        _businesses = businesses;
      });
    } catch (e) {
      print('Error loading businesses for store: $e');
      setState(() {
        _error = 'Failed to load businesses for this store: $e';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          setState(() {
            _error = 'Please select a business to view inventory.';
            _loading = false;
          });
          return;
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }
      
      // Load inventory
      final inventory = await _apiService.getStoreInventory(widget.storeId, businessId);
      setState(() {
        _inventory = inventory;
      });
      
      // Load movements
      final movements = await _apiService.getStoreInventoryMovements(
        widget.storeId, 
        businessId,
        movementType: _selectedMovementType,
        productId: _selectedProductId,
      );
      setState(() {
        _movements = movements;
      });
      
      // Load reports
      print('🔍 Loading reports for storeId: ${widget.storeId}, businessId: $businessId');
      final reports = await _apiService.getStoreInventoryReports(widget.storeId, businessId);
      print('📊 Reports loaded: ${reports.keys}');
      print('📊 Current stock data: ${reports['current_stock']}');
      print('📊 Current stock summary: ${reports['current_stock']?['summary']}');
      print('📊 Current stock products: ${reports['current_stock']?['products']?.length ?? 0} products');
      setState(() {
        _reports = reports;
      });
      
    } catch (e) {
      print('Store Inventory Error: $e');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load store inventory', e.toString());
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Load detailed movements data
  Future<void> _loadDetailedMovements() async {
    if (_detailedMovementsLoading) return;
    
    setState(() {
      _detailedMovementsLoading = true;
    });

    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          throw Exception('Please select a business to view detailed movements.');
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }

      final data = await _apiService.getDetailedMovementsReport(
        widget.storeId,
        businessId,
        startDate: _detailedMovementsStartDate?.toIso8601String().split('T')[0],
        endDate: _detailedMovementsEndDate?.toIso8601String().split('T')[0],
        productId: _selectedProductForDetailed,
        movementType: _selectedDetailedMovementType,
        referenceType: _selectedReferenceType,
        page: _detailedMovementsPage,
        limit: _detailedReportsPageSize,
      );

      setState(() {
        _detailedMovementsData = data;
      });
      
    } catch (e) {
      print('Detailed Movements Error: $e');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load detailed movements', e.toString());
      }
    } finally {
      setState(() {
        _detailedMovementsLoading = false;
      });
    }
  }

  // Load purchases data
  Future<void> _loadPurchases() async {
    if (_purchasesLoading) return;
    
    setState(() {
      _purchasesLoading = true;
    });

    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          throw Exception('Please select a business to view purchases.');
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }

      final data = await _apiService.getPurchasesReport(
        widget.storeId,
        businessId,
        startDate: _detailedMovementsStartDate?.toIso8601String().split('T')[0],
        endDate: _detailedMovementsEndDate?.toIso8601String().split('T')[0],
        productId: _selectedProductForDetailed,
        page: 1,
        limit: _detailedReportsPageSize,
      );

      setState(() {
        _purchasesData = data;
      });
      
    } catch (e) {
      print('Purchases Error: $e');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load purchases', e.toString());
      }
    } finally {
      setState(() {
        _purchasesLoading = false;
      });
    }
  }

  // Load increments data
  Future<void> _loadIncrements() async {
    if (_incrementsLoading) return;
    
    setState(() {
      _incrementsLoading = true;
    });

    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          throw Exception('Please select a business to view increments.');
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }

      final data = await _apiService.getIncrementsReport(
        widget.storeId,
        businessId,
        startDate: _detailedMovementsStartDate?.toIso8601String().split('T')[0],
        endDate: _detailedMovementsEndDate?.toIso8601String().split('T')[0],
        productId: _selectedProductForDetailed,
        page: 1,
        limit: _detailedReportsPageSize,
      );

      setState(() {
        _incrementsData = data;
      });
      
    } catch (e) {
      print('Increments Error: $e');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load increments', e.toString());
      }
    } finally {
      setState(() {
        _incrementsLoading = false;
      });
    }
  }

  // Load business transfers data
  Future<void> _loadBusinessTransfers() async {
    if (_businessTransfersLoading) return;
    
    print('🔍 FRONTEND: Starting to load business transfers...');
    print('🔍 FRONTEND: Store ID: ${widget.storeId}');
    print('🔍 FRONTEND: Time Period: $_businessTransfersTimePeriod');
    print('🔍 FRONTEND: Start Date: $_businessTransfersStartDate');
    print('🔍 FRONTEND: End Date: $_businessTransfersEndDate');
    print('🔍 FRONTEND: Product ID: $_selectedProductForTransfers');
    print('🔍 FRONTEND: Target Business ID: $_selectedBusinessForTransfers');
    print('🔍 FRONTEND: Status: $_selectedTransferStatus');
    
    setState(() {
      _businessTransfersLoading = true;
    });

    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          throw Exception('Please select a business to view transfers.');
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }
      
      print('🔍 FRONTEND: Business ID determined: $businessId');
      print('🔍 FRONTEND: User role: ${user?.role}');

        print('🔍 FRONTEND: Calling API service...');
        final data = await _apiService.getBusinessTransfersReport(
          widget.storeId,
          businessId,
          timePeriod: _businessTransfersTimePeriod,
          startDate: _businessTransfersStartDate?.toIso8601String().split('T')[0],
          endDate: _businessTransfersEndDate?.toIso8601String().split('T')[0],
          productId: _selectedProductForTransfers,
          targetBusinessId: _selectedBusinessForTransfers,
          status: _selectedTransferStatus,
          page: 1,
          limit: _detailedReportsPageSize,
        );
        
        print('🔍 FRONTEND: API call completed successfully');

      setState(() {
        _businessTransfersData = data;
      });
      
      print('✅ Business Transfers Data Loaded:');
      print('  - Transfers count: ${(data['transfers'] as List?)?.length ?? 0}');
      print('  - Summary: ${data['summary']}');
      print('  - Pagination: ${data['pagination']}');
      
    } catch (e) {
      print('❌ FRONTEND: Business Transfers Error: $e');
      print('❌ FRONTEND: Error type: ${e.runtimeType}');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load business transfers', e.toString());
      }
    } finally {
      setState(() {
        _businessTransfersLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final isSuperAdmin = user?.role == 'superadmin';
    
    return Scaffold(
      appBar: BrandedAppBar(
        title: '${t(context,'Store Inventory')} - ${widget.storeName}',
        actions: [
          // Business selection for superadmin
          if (isSuperAdmin && _businesses.isNotEmpty)
            Container(
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonFormField<int>(
                value: _selectedBusinessId,
                decoration: InputDecoration(
                  labelText: t(context, 'Select Business'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _businesses.map((business) {
                  return DropdownMenuItem<int>(
                    value: business['id'],
                    child: Text(
                      business['name'] ?? 'Business ${business['id']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBusinessId = value;
                  });
                  _loadData();
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddProductsDialog,
            tooltip: t(context,'Add Products'),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _showTransferDialog,
            tooltip: t(context,'Transfer to Business'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: t(context,'Refresh'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Theme.of(context).primaryColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: t(context,'Inventory')),
                Tab(text: t(context,'Movements')),
                Tab(text: t(context,'Reports')),
                Tab(text: t(context,'Detailed Movements')),
                Tab(text: t(context,'Purchases')),
                Tab(text: t(context,'Increments')),
                Tab(text: 'Business Transfers'),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInventoryTab(),
                _buildMovementsTab(),
                _buildReportsTab(),
                _buildDetailedMovementsTab(),
                _buildPurchasesTab(),
                _buildIncrementsTab(),
                _buildBusinessTransfersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              t(context,'Error loading inventory'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: Text(t(context,'Retry')),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: t(context,'Search products...'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        // Inventory List
        Expanded(
          child: _buildInventoryList(),
        ),
      ],
    );
  }

  Widget _buildInventoryList() {
    final filteredInventory = _inventory.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item['product_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item['sku'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      return matchesSearch;
    }).toList();

    if (filteredInventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              t(context,'No inventory found'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              t(context,'Add products to this store to get started'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredInventory.length,
      itemBuilder: (context, index) {
        final item = filteredInventory[index];
        return _buildInventoryCard(item);
      },
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final stockStatus = item['stock_status'] as String?;
    Color statusColor;
    IconData statusIcon;
    
    switch (stockStatus) {
      case 'LOW_STOCK':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case 'OUT_OF_STOCK':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (item['image_url'] != null && item['image_url'].toString().isNotEmpty) ...[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        'https://rtailed-production.up.railway.app${item['image_url']}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.image, color: Colors.grey[400]),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['product_name'] ?? '',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item['description'],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${item['sku'] ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _getStockStatusLabel(stockStatus),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuantityInfo(
                    t(context,'Store Quantity'),
                    item['store_quantity'] ?? item['quantity'] ?? 0,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildQuantityInfo(
                    t(context,'Min Level'),
                    item['min_stock_level'] ?? 0,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildQuantityInfo(
                    t(context,'Inventory ID'),
                    item['inventory_id'] ?? 0,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Store Quantity')}: ${item['store_quantity'] ?? item['quantity'] ?? 0}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.warning, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Min Level')}: ${item['min_stock_level'] ?? 0}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Cost Price')}: ₦${(double.tryParse(item['cost_price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.sell, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Selling Price')}: ₦${(double.tryParse(item['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.update, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Last Updated')}: ${_formatDate(item['last_updated'])}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Updated By')}: ${item['updated_by'] ?? 'N/A'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showIncrementDialog(item),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(t(context,'Add Stock'), style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditCostPriceDialog(item),
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(t(context,'Edit Cost'), style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showTransferDialog(),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: Text(t(context,'Transfer'), style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityInfo(String label, int quantity, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            quantity.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  String _getStockStatusLabel(String? status) {
    switch (status) {
      case 'LOW_STOCK':
        return t(context,'Low Stock');
      case 'OUT_OF_STOCK':
        return t(context,'Out of Stock');
      case 'IN_STOCK':
        return t(context,'In Stock');
      default:
        return t(context,'Unknown');
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildMovementsTab() {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMovementType.isEmpty ? null : _selectedMovementType,
                  decoration: InputDecoration(
                    labelText: t(context,'Movement Type'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: '', child: Text(t(context,'All Types'))),
                    DropdownMenuItem(value: 'in', child: Text(t(context,'In'))),
                    DropdownMenuItem(value: 'out', child: Text(t(context,'Out'))),
                    DropdownMenuItem(value: 'transfer_out', child: Text(t(context,'Transfer Out'))),
                    DropdownMenuItem(value: 'adjustment', child: Text(t(context,'Adjustment'))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMovementType = value ?? '';
                    });
                    _loadData();
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Movements List
        Expanded(
          child: _buildMovementsList(),
        ),
      ],
    );
  }

  Widget _buildMovementsList() {
    if (_movements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              t(context,'No movements found'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _movements.length,
      itemBuilder: (context, index) {
        final movement = _movements[index];
        return _buildMovementCard(movement);
      },
    );
  }

  Widget _buildMovementCard(Map<String, dynamic> movement) {
    final movementType = movement['movement_type'] as String?;
    final quantityChange = movement['quantity_change'] as int? ?? 0;
    
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    
    switch (movementType) {
      case 'in':
        typeColor = Colors.green;
        typeIcon = Icons.arrow_downward;
        typeLabel = t(context,'In');
        break;
      case 'out':
        typeColor = Colors.red;
        typeIcon = Icons.arrow_upward;
        typeLabel = t(context,'Out');
        break;
      case 'transfer_out':
        typeColor = Colors.blue;
        typeIcon = Icons.send;
        typeLabel = t(context,'Transfer Out');
        break;
      case 'adjustment':
        typeColor = Colors.orange;
        typeIcon = Icons.edit;
        typeLabel = t(context,'Adjustment');
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help;
        typeLabel = t(context,'Unknown');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(movement['product_name'] ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${movement['sku'] ?? ''}'),
            Text('${t(context,'By')}: ${movement['created_by_username'] ?? ''}'),
            Text('${t(context,'Date')}: ${_formatDate(movement['created_at'])}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              typeLabel,
              style: TextStyle(
                color: typeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              '${quantityChange > 0 ? '+' : ''}$quantityChange',
              style: TextStyle(
                color: typeColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    print('🔍 Building reports tab - _reports: ${_reports.keys}');
    print('🔍 _reports isEmpty: ${_reports.isEmpty}');
    print('🔍 _reports current_stock: ${_reports['current_stock']}');
    
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: Text(t(context, 'Retry')),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(context, 'Store Inventory Reports'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.storeName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_reports.isNotEmpty && _reports['report_metadata'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDate(DateTime.parse(_reports['report_metadata']['generated_at'])),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Current Stock Summary
          _buildCurrentStockSummary(),
          
          const SizedBox(height: 16),
          
          // Financial Summary
          _buildFinancialSummary(),
          
          const SizedBox(height: 16),
          
          // Movement Summary
          _buildMovementSummary(),
          
          const SizedBox(height: 16),
          
          // Low Stock Alerts
          _buildLowStockAlerts(),
          
          const SizedBox(height: 16),
          
          // Top Products
          _buildTopProducts(),
        ],
      ),
    );
  }

  // =====================================================
  // NEW DETAILED REPORT TABS
  // =====================================================

  Widget _buildDetailedMovementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with filters
          Row(
            children: [
              Expanded(
                child: Text(
                  'Detailed Movements Report',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadDetailedMovements,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filters Row
          _buildDetailedMovementsFilters(),
          const SizedBox(height: 16),
          
          // Data Display
          _detailedMovementsLoading
              ? const Center(child: CircularProgressIndicator())
              : _detailedMovementsData.isEmpty
                  ? _buildEmptyDetailedMovements()
                  : _buildDetailedMovementsTable(),
        ],
      ),
    );
  }

  Widget _buildPurchasesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with filters
          Row(
            children: [
              Expanded(
                child: Text(
                  'Purchases Report',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadPurchases,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filters Row
          _buildPurchasesFilters(),
          const SizedBox(height: 16),
          
          // Data Display
          _purchasesLoading
              ? const Center(child: CircularProgressIndicator())
              : _purchasesData.isEmpty
                  ? _buildEmptyPurchases()
                  : _buildPurchasesTable(),
        ],
      ),
    );
  }

  Widget _buildIncrementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with filters
          Row(
            children: [
              Expanded(
                child: Text(
                  'Increments Report',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadIncrements,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filters Row
          _buildIncrementsFilters(),
          const SizedBox(height: 16),
          
          // Data Display
          _incrementsLoading
              ? const Center(child: CircularProgressIndicator())
              : _incrementsData.isEmpty
                  ? _buildEmptyIncrements()
                  : _buildIncrementsTable(),
        ],
      ),
    );
  }

  Widget _buildBusinessTransfersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with filters
          Row(
            children: [
              Expanded(
                child: Text(
                  'Business Transfers Report',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadBusinessTransfers,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filters Row
          _buildBusinessTransfersFilters(),
          const SizedBox(height: 16),
          
          // Data Display
          _businessTransfersLoading
              ? const Center(child: CircularProgressIndicator())
              : (_businessTransfersData['transfers'] as List?)?.isEmpty ?? true
                  ? _buildEmptyBusinessTransfers()
                  : _buildBusinessTransfersTable(),
        ],
      ),
    );
  }

  // =====================================================
  // DETAILED MOVEMENTS HELPER METHODS
  // =====================================================

  Widget _buildDetailedMovementsFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            isSmallScreen ? _buildMobileFilters() : _buildDesktopFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFilters() {
    return Column(
      children: [
        // Date Range
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showDetailedMovementsStartDatePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _detailedMovementsStartDate != null
                            ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                            : 'Start Date',
                        style: TextStyle(
                          color: _detailedMovementsStartDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('to'),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _showDetailedMovementsEndDatePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _detailedMovementsEndDate != null
                            ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                            : 'End Date',
                        style: TextStyle(
                          color: _detailedMovementsEndDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Movement Type Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Movement Type:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDetailedMovementType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Types')),
                const DropdownMenuItem(value: 'in', child: Text('Stock In')),
                const DropdownMenuItem(value: 'transfer_out', child: Text('Transfer Out')),
                const DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDetailedMovementType = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Apply Filters Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _detailedMovementsPage = 1;
              _loadDetailedMovements();
            },
            child: const Text('Apply Filters'),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    return Row(
      children: [
        // Date Range
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailedMovementsStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _detailedMovementsStartDate != null
                              ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _detailedMovementsStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailedMovementsEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _detailedMovementsEndDate != null
                              ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _detailedMovementsEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Movement Type Filter
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Movement Type:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedDetailedMovementType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Types')),
                  const DropdownMenuItem(value: 'in', child: Text('Stock In')),
                  const DropdownMenuItem(value: 'transfer_out', child: Text('Transfer Out')),
                  const DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDetailedMovementType = value;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Apply Filters Button
        ElevatedButton(
          onPressed: () {
            _detailedMovementsPage = 1;
            _loadDetailedMovements();
          },
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }

  Widget _buildEmptyDetailedMovements() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No detailed movements found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or add some inventory movements',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDetailedMovements,
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMovementsTable() {
    final movements = _detailedMovementsData['movements'] as List<dynamic>? ?? [];
    final summary = _detailedMovementsData['summary'] as Map<String, dynamic>? ?? {};
    final pagination = _detailedMovementsData['report_metadata']?['pagination'] as Map<String, dynamic>? ?? {};
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;

    return Column(
      children: [
        // Summary Cards
        if (summary.isNotEmpty) _buildDetailedMovementsSummary(summary),
        const SizedBox(height: 16),
        
        // Data Table
        Card(
          child: isSmallScreen 
              ? _buildMobileMovementsList(movements)
              : _buildDesktopMovementsTable(movements),
        ),
      ],
    );
  }

  Widget _buildDesktopMovementsTable(List<dynamic> movements) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('User', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        // Table Body
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: movements.length,
          itemBuilder: (context, index) {
            final movement = movements[index] as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movement['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'SKU: ${movement['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getMovementTypeColor(movement['movement_type']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getMovementTypeLabel(movement['movement_type']),
                        style: TextStyle(
                          color: _getMovementTypeColor(movement['movement_type']),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${movement['quantity'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(movement['created_at']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      movement['created_by_name'] ?? 'Unknown',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileMovementsList(List<dynamic> movements) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: movements.length,
      itemBuilder: (context, index) {
        final movement = movements[index] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movement['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          'SKU: ${movement['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getMovementTypeColor(movement['movement_type']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getMovementTypeLabel(movement['movement_type']),
                      style: TextStyle(
                        color: _getMovementTypeColor(movement['movement_type']),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Details Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quantity', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${movement['quantity'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          _formatDate(movement['created_at']),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // User Info
              Text('User', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                movement['created_by_name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailedMovementsSummary(Map<String, dynamic> summary) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.blue[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_movements'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Transfers', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.category, color: Colors.green[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['unique_products'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Products', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.arrow_downward, color: Colors.orange[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_stock_in'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Stock In', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.arrow_upward, color: Colors.red[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_transferred_out'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Transferred Out', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inventory, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_movements'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Transfers'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.category, color: Colors.green[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['unique_products'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Products'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.arrow_downward, color: Colors.orange[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_stock_in'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Stock In'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.arrow_upward, color: Colors.red[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_transferred_out'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Transferred Out'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getMovementTypeColor(String? type) {
    switch (type) {
      case 'in':
        return Colors.green;
      case 'transfer_out':
        return Colors.orange;
      case 'adjustment':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getMovementTypeLabel(String? type) {
    switch (type) {
      case 'in':
        return 'Stock In';
      case 'transfer_out':
        return 'Transfer Out';
      case 'adjustment':
        return 'Adjustment';
      default:
        return 'Unknown';
    }
  }

  Future<void> _showDetailedMovementsStartDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _detailedMovementsStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _detailedMovementsStartDate = date;
      });
    }
  }

  Future<void> _showDetailedMovementsEndDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _detailedMovementsEndDate ?? DateTime.now(),
      firstDate: _detailedMovementsStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _detailedMovementsEndDate = date;
      });
    }
  }

  // =====================================================
  // PURCHASES REPORT HELPER METHODS
  // =====================================================

  Widget _buildPurchasesFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            isSmallScreen ? _buildMobilePurchasesFilters() : _buildDesktopPurchasesFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePurchasesFilters() {
    return Column(
      children: [
        // Date Range
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showDetailedMovementsStartDatePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _detailedMovementsStartDate != null
                            ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                            : 'Start Date',
                        style: TextStyle(
                          color: _detailedMovementsStartDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('to'),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _showDetailedMovementsEndDatePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _detailedMovementsEndDate != null
                            ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                            : 'End Date',
                        style: TextStyle(
                          color: _detailedMovementsEndDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Apply Filters Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loadPurchases,
            child: const Text('Apply Filters'),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopPurchasesFilters() {
    return Row(
      children: [
        // Date Range
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailedMovementsStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _detailedMovementsStartDate != null
                              ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _detailedMovementsStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailedMovementsEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _detailedMovementsEndDate != null
                              ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _detailedMovementsEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Apply Filters Button
        ElevatedButton(
          onPressed: _loadPurchases,
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }

  Widget _buildEmptyPurchases() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No purchases found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or add some inventory purchases',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPurchases,
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasesTable() {
    final purchases = _purchasesData['purchases'] as List<dynamic>? ?? [];
    final summary = _purchasesData['summary'] as Map<String, dynamic>? ?? {};
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;

    return Column(
      children: [
        // Summary Cards
        if (summary.isNotEmpty) _buildPurchasesSummary(summary),
        const SizedBox(height: 16),
        
        // Data Table
        Card(
          child: isSmallScreen 
              ? _buildMobilePurchasesList(purchases)
              : _buildDesktopPurchasesTable(purchases),
        ),
      ],
    );
  }

  Widget _buildDesktopPurchasesTable(List<dynamic> purchases) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Units', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Cost Price', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Total Cost', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        // Table Body
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: purchases.length,
          itemBuilder: (context, index) {
            final purchase = purchases[index] as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'SKU: ${purchase['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${purchase['units_purchased'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '\$${_formatNumber(purchase['cost_price'] ?? 0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '\$${_formatNumber(purchase['total_cost'] ?? 0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(purchase['purchase_date']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobilePurchasesList(List<dynamic> purchases) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final purchase = purchases[index] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          'SKU: ${purchase['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '\$${_formatNumber(purchase['total_cost'] ?? 0)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Details Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Units', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${purchase['units_purchased'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cost/Unit', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '\$${_formatNumber(purchase['cost_price'] ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Date Info
              Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                _formatDate(purchase['purchase_date']),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPurchasesSummary(Map<String, dynamic> summary) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart, color: Colors.green[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_purchases'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Purchases', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.blue[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_units_purchased'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Units Purchased', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.attach_money, color: Colors.orange[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_formatNumber(summary['total_purchase_cost'] ?? 0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Cost', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, color: Colors.purple[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_formatNumber(summary['total_purchase_value'] ?? 0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Value', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.green[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_purchases'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Purchases'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inventory, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_units_purchased'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Units Purchased'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.attach_money, color: Colors.orange[600]),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_formatNumber(summary['total_purchase_cost'] ?? 0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Cost'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.trending_up, color: Colors.purple[600]),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_formatNumber(summary['total_purchase_value'] ?? 0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Value'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // INCREMENTS REPORT HELPER METHODS
  // =====================================================

  Widget _buildIncrementsFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            isSmallScreen ? _buildMobileIncrementsFilters() : _buildDesktopIncrementsFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileIncrementsFilters() {
    return Column(
      children: [
        // Date Range
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showDetailedMovementsStartDatePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _detailedMovementsStartDate != null
                            ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                            : 'Start Date',
                        style: TextStyle(
                          color: _detailedMovementsStartDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('to'),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _showDetailedMovementsEndDatePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _detailedMovementsEndDate != null
                            ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                            : 'End Date',
                        style: TextStyle(
                          color: _detailedMovementsEndDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Apply Filters Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loadIncrements,
            child: const Text('Apply Filters'),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopIncrementsFilters() {
    return Row(
      children: [
        // Date Range
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailedMovementsStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _detailedMovementsStartDate != null
                              ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _detailedMovementsStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailedMovementsEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _detailedMovementsEndDate != null
                              ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _detailedMovementsEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Apply Filters Button
        ElevatedButton(
          onPressed: _loadIncrements,
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }

  Widget _buildEmptyIncrements() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No increments found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or add some inventory increments',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadIncrements,
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildIncrementsTable() {
    final increments = _incrementsData['increments'] as List<dynamic>? ?? [];
    final summary = _incrementsData['summary'] as Map<String, dynamic>? ?? {};
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;

    return Column(
      children: [
        // Summary Cards
        if (summary.isNotEmpty) _buildIncrementsSummary(summary),
        const SizedBox(height: 16),
        
        // Data Table
        Card(
          child: isSmallScreen 
              ? _buildMobileIncrementsList(increments)
              : _buildDesktopIncrementsTable(increments),
        ),
      ],
    );
  }

  Widget _buildDesktopIncrementsTable(List<dynamic> increments) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Units Added', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Stock Before', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Stock After', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        // Table Body
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: increments.length,
          itemBuilder: (context, index) {
            final increment = increments[index] as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          increment['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'SKU: ${increment['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+${increment['units_added'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${increment['stock_before'] ?? 0}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${increment['stock_after'] ?? 0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(increment['increment_date']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileIncrementsList(List<dynamic> increments) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: increments.length,
      itemBuilder: (context, index) {
        final increment = increments[index] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          increment['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          'SKU: ${increment['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+${increment['units_added'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Details Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock Before', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${increment['stock_before'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock After', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${increment['stock_after'] ?? 0}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Date Info
              Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                _formatDate(increment['increment_date']),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIncrementsSummary(Map<String, dynamic> summary) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, color: Colors.blue[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_increments'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Increments', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.green[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_units_added'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Units Added', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.attach_money, color: Colors.orange[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_formatNumber(summary['total_cost_added'] ?? 0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Cost Added', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, color: Colors.purple[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_formatNumber(summary['total_value_added'] ?? 0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Value Added', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.trending_up, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_increments'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Increments'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inventory, color: Colors.green[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_units_added'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Units Added'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.attach_money, color: Colors.orange[600]),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_formatNumber(summary['total_cost_added'] ?? 0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Cost Added'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.trending_up, color: Colors.purple[600]),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_formatNumber(summary['total_value_added'] ?? 0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Value Added'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // BUSINESS TRANSFERS REPORT HELPER METHODS
  // =====================================================

  Widget _buildBusinessTransfersFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            isSmallScreen ? _buildMobileBusinessTransfersFilters() : _buildDesktopBusinessTransfersFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBusinessTransfersFilters() {
    return Column(
      children: [
        // Time Period
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _businessTransfersTimePeriod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Time')),
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: 'week', child: Text('This Week')),
                DropdownMenuItem(value: 'month', child: Text('This Month')),
                DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
              ],
              onChanged: (value) {
                setState(() {
                  _businessTransfersTimePeriod = value ?? 'all';
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Custom Date Range (only show if custom is selected)
        if (_businessTransfersTimePeriod == 'custom') ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Custom Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showBusinessTransfersStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _businessTransfersStartDate != null
                              ? 'From: ${_businessTransfersStartDate!.day}/${_businessTransfersStartDate!.month}/${_businessTransfersStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _businessTransfersStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showBusinessTransfersEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _businessTransfersEndDate != null
                              ? 'To: ${_businessTransfersEndDate!.day}/${_businessTransfersEndDate!.month}/${_businessTransfersEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _businessTransfersEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 16),
        // Product Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedProductForTransfers,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: 'All Products',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Products')),
                ..._inventory.map((item) => DropdownMenuItem(
                  value: item['product_id'],
                  child: Text('${item['product_name']} (${item['sku']})'),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedProductForTransfers = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Business Filter (for superadmin)
        if (context.read<AuthProvider>().user?.role == 'superadmin')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Target Business:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedBusinessForTransfers,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'All Businesses',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Businesses')),
                  ..._businesses.map((business) => DropdownMenuItem(
                    value: business['id'],
                    child: Text(business['name']),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBusinessForTransfers = value;
                  });
                },
              ),
            ],
          ),
        const SizedBox(height: 16),
        // Apply Filters Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loadBusinessTransfers,
            child: const Text('Apply Filters'),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopBusinessTransfersFilters() {
    return Row(
      children: [
        // Time Period
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _businessTransfersTimePeriod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: 'week', child: Text('This Week')),
                  DropdownMenuItem(value: 'month', child: Text('This Month')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                ],
                onChanged: (value) {
                  setState(() {
                    _businessTransfersTimePeriod = value ?? 'all';
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Custom Date Range (only show if custom is selected)
        if (_businessTransfersTimePeriod == 'custom')
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Custom Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showBusinessTransfersStartDatePicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _businessTransfersStartDate != null
                                ? 'From: ${_businessTransfersStartDate!.day}/${_businessTransfersStartDate!.month}/${_businessTransfersStartDate!.year}'
                                : 'Start Date',
                            style: TextStyle(
                              color: _businessTransfersStartDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('to'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _showBusinessTransfersEndDatePicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _businessTransfersEndDate != null
                                ? 'To: ${_businessTransfersEndDate!.day}/${_businessTransfersEndDate!.month}/${_businessTransfersEndDate!.year}'
                                : 'End Date',
                            style: TextStyle(
                              color: _businessTransfersEndDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (_businessTransfersTimePeriod == 'custom') const SizedBox(width: 16),
        // Product Filter
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Product:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                value: _selectedProductForTransfers,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'All Products',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Products')),
                  ..._inventory.map((item) => DropdownMenuItem(
                    value: item['product_id'],
                    child: Text('${item['product_name']} (${item['sku']})'),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProductForTransfers = value;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Business Filter (for superadmin)
        if (context.read<AuthProvider>().user?.role == 'superadmin')
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Target Business:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  value: _selectedBusinessForTransfers,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: 'All Businesses',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Businesses')),
                    ..._businesses.map((business) => DropdownMenuItem(
                      value: business['id'],
                      child: Text(business['name']),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBusinessForTransfers = value;
                    });
                  },
                ),
              ],
            ),
          ),
        const SizedBox(width: 16),
        // Apply Filters Button
        ElevatedButton(
          onPressed: _loadBusinessTransfers,
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }

  Widget _buildEmptyBusinessTransfers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_center_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No business transfers found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or check if there are any transfers to businesses',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBusinessTransfers,
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessTransfersTable() {
    final transfers = _businessTransfersData['transfers'] as List<dynamic>? ?? [];
    final summary = _businessTransfersData['summary'] as Map<String, dynamic>? ?? {};
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;

    return Column(
      children: [
        // Summary Cards
        if (summary.isNotEmpty) _buildBusinessTransfersSummary(summary),
        const SizedBox(height: 16),
        
        // Data Table
        Card(
          child: isSmallScreen 
              ? _buildMobileBusinessTransfersList(transfers)
              : _buildDesktopBusinessTransfersTable(transfers),
        ),
      ],
    );
  }

  Widget _buildDesktopBusinessTransfersTable(List<dynamic> transfers) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('To Business', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        // Table Body
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transfers.length,
          itemBuilder: (context, index) {
            final transfer = transfers[index] as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'SKU: ${transfer['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${transfer['quantity'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      transfer['target_business_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(transfer['transfer_date']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTransferStatusColor(transfer['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTransferStatusLabel(transfer['status']),
                        style: TextStyle(
                          color: _getTransferStatusColor(transfer['status']),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileBusinessTransfersList(List<dynamic> transfers) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          'SKU: ${transfer['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${transfer['quantity'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Details Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('To Business', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          transfer['target_business_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTransferStatusColor(transfer['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getTransferStatusLabel(transfer['status']),
                            style: TextStyle(
                              color: _getTransferStatusColor(transfer['status']),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Date Info
              Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                _formatDate(transfer['transfer_date']),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBusinessTransfersSummary(Map<String, dynamic> summary) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.business_center, color: Colors.blue[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_transfers'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Transfers', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.green[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_quantity_transferred'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Units Transferred', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.business, color: Colors.orange[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['unique_businesses'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Businesses Served', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.category, color: Colors.purple[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['unique_products'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Products Transferred', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.business_center, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_transfers'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Transfers'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inventory, color: Colors.green[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_quantity_transferred'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Units Transferred'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.business, color: Colors.orange[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['unique_businesses'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Businesses Served'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.category, color: Colors.purple[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['unique_products'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Products Transferred'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getTransferStatusColor(String? status) {
    switch (status) {
      case 'transfer':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTransferStatusLabel(String? status) {
    switch (status) {
      case 'transfer':
        return 'Transfer';
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  void _showBusinessTransfersStartDatePicker(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: _businessTransfersStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((date) {
      if (date != null) {
        setState(() {
          _businessTransfersStartDate = date;
        });
      }
    });
  }

  void _showBusinessTransfersEndDatePicker(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: _businessTransfersEndDate ?? DateTime.now(),
      firstDate: _businessTransfersStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    ).then((date) {
      if (date != null) {
        setState(() {
          _businessTransfersEndDate = date;
        });
      }
    });
  }

  Widget _buildTopProductCard(Map<String, dynamic> product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(product['product_name'] ?? ''),
        subtitle: Text('SKU: ${product['sku'] ?? ''}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${product['movement_count'] ?? 0} ${t(context,'movements')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${product['total_in'] ?? 0} in, ${product['total_transferred'] ?? 0} out',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }



  void _showAddProductsDialog() {
    // Use the exact same add product dialog from inventory screen
    _showAddProductDialog();
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => _ProductDialog(
        apiService: _apiService,
                  onSave: (productData, imageFile, {webImageBytes, webImageName}) async {
                    try {
                      // Add storeId to productData so it gets added to store inventory immediately
                      productData['storeId'] = widget.storeId;
                      
                      // Create the product (it will automatically be added to store inventory)
                      final product = await _apiService.createProduct(productData, imageFile: imageFile, webImageBytes: webImageBytes, webImageName: webImageName);
                      
                      _loadData();
                      if (mounted) {
                        Navigator.of(context).pop();
                        SuccessUtils.showProductSuccess(context, 'added to ${widget.storeName} warehouse');
                      }
                    } catch (e, stack) {
                      print('Error adding product to store: $e');
                      print('Stack trace: $stack');
                      if (mounted) {
                        SuccessUtils.showOperationError(context, 'add product to store', e.toString());
                      }
                    }
                  },
      ),
    );
  }

  void _showTransferDialog() {
    showDialog(
      context: context,
      builder: (context) => _TransferDialog(
        storeId: widget.storeId,
        storeName: widget.storeName,
        inventory: _inventory,
        businesses: _businesses,
        apiService: _apiService,
        onTransfer: () {
          _loadData(); // Refresh inventory after transfer
        },
      ),
    );
  }

  void _showIncrementDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _IncrementDialog(
        item: item,
        onIncrement: (quantity, costPrice, notes) async {
          try {
            await _apiService.incrementProductQuantity(
              widget.storeId,
              item['product_id'],
              quantity,
              costPrice: costPrice,
              notes: notes,
            );
            
            _loadData();
            if (mounted) {
              Navigator.of(context).pop();
              SuccessUtils.showProductSuccess(context, 'stock incremented');
            }
          } catch (e) {
            print('Error incrementing product: $e');
            if (mounted) {
              SuccessUtils.showOperationError(context, 'increment stock', e.toString());
            }
          }
        },
      ),
    );
  }

  void _showEditCostPriceDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _EditCostPriceDialog(
        item: item,
        onUpdate: (newCostPrice) async {
          try {
            await _apiService.updateProductCostPrice(
              item['product_id'],
              newCostPrice,
            );
            
            _loadData();
            if (mounted) {
              Navigator.of(context).pop();
              SuccessUtils.showProductSuccess(context, 'cost price updated');
            }
          } catch (e) {
            print('Error updating cost price: $e');
            if (mounted) {
              SuccessUtils.showOperationError(context, 'update cost price', e.toString());
            }
          }
        },
      ),
    );
  }


  // Stock Summary methods (copied from inventory_screen.dart)
  Widget _buildStoreReportFilters() {
    return Row(
      children: [
        // Category Filter
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReportCategory,
                isExpanded: true,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('All Categories'),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                  size: 18,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('All Categories'),
                    ),
                  ),
                  ...['Electronics', 'Clothing', 'Food', 'Books'].map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(category),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedReportCategory = value;
                    _stockSummaryCurrentPage = 0;
                  });
                  _fetchInventoryValueReport();
                },
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Product Filter
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReportProduct,
                isExpanded: true,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('All Products'),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                  size: 18,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('All Products'),
                    ),
                  ),
                  ..._inventory.map((item) {
                    return DropdownMenuItem(
                      value: item['product_name']?.toString(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(item['product_name']?.toString() ?? ''),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedReportProduct = value;
                    _stockSummaryCurrentPage = 0;
                  });
                  _fetchInventoryValueReport();
                },
              ),
            ),
          ),
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
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _stockSummaryFilterType,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                    items: _stockSummaryFilterOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _stockSummaryFilterType = value!;
                      });
                      if (value != 'Custom') {
                        _applyStockSummaryPreset(value!);
                      } else {
                        // For custom, just refresh with current dates
                        _fetchInventoryValueReport();
                      }
                    },
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Custom Date Range (only show when Custom is selected)
            if (_stockSummaryFilterType == 'Custom') ...[
              Expanded(
                flex: 1,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showStockSummaryStartDatePicker(context),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _stockSummaryStartDate != null 
                                ? '${_stockSummaryStartDate!.day}/${_stockSummaryStartDate!.month}/${_stockSummaryStartDate!.year}'
                                : 'Start',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                flex: 1,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showStockSummaryEndDatePicker(context),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _stockSummaryEndDate != null 
                                ? '${_stockSummaryEndDate!.day}/${_stockSummaryEndDate!.month}/${_stockSummaryEndDate!.year}'
                                : 'End',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
            ],
            
            // Refresh Button
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _fetchInventoryValueReport,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh,
                          color: Theme.of(context).primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Refresh',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
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
      ],
    );
  }

  // Custom date picker methods for stock summary
  Future<void> _showStockSummaryStartDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _stockSummaryStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _stockSummaryStartDate) {
      setState(() {
        _stockSummaryStartDate = picked;
      });
      _fetchInventoryValueReport();
    }
  }

  Future<void> _showStockSummaryEndDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _stockSummaryEndDate ?? DateTime.now(),
      firstDate: _stockSummaryStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _stockSummaryEndDate) {
      setState(() {
        _stockSummaryEndDate = picked;
      });
      _fetchInventoryValueReport();
    }
  }

  void _applyStockSummaryPreset(String filterType) {
    final now = DateTime.now();
    
    switch (filterType) {
      case 'Today':
        _stockSummaryStartDate = DateTime(now.year, now.month, now.day);
        _stockSummaryEndDate = _stockSummaryStartDate!.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        break;
      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        _stockSummaryStartDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        _stockSummaryEndDate = _stockSummaryStartDate!.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
        break;
      case 'This Month':
        _stockSummaryStartDate = DateTime(now.year, now.month, 1);
        _stockSummaryEndDate = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
        break;
      case 'Custom':
        // Keep existing dates
        break;
    }
    
    _fetchInventoryValueReport();
  }

  Future<void> _fetchInventoryValueReport() async {
    setState(() {
      _valueReportLoading = true;
      _valueReportError = null;
    });
    try {
      // Apply filter logic based on selected filter type
      DateTime? startDate;
      DateTime? endDate;

      final now = DateTime.now();
      
      switch (_stockSummaryFilterType) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          endDate = startDate.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
          break;
        case 'This Week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          endDate = startDate.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
          break;
        case 'Custom':
          // Use existing custom date range
          startDate = _stockSummaryStartDate;
          endDate = _stockSummaryEndDate;
          break;
        default:
          // Default to Today if no filter selected
          startDate = DateTime(now.year, now.month, now.day);
          endDate = startDate.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
      }
      
      print('🔍 Stock Summary Filter: $_stockSummaryFilterType');
      print('🔍 Start Date: $startDate');
      print('🔍 End Date: $endDate');
      print('🔍 Store ID: ${widget.storeId}');
      print('🔍 Selected Business ID: $_selectedBusinessId');
      
      // Prepare filter parameters
      final Map<String, dynamic> filterParams = {};
      if (startDate != null) filterParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) filterParams['end_date'] = endDate.toIso8601String();
      
      // Add category filter
      if (_selectedReportCategory != null && _selectedReportCategory != 'All') {
        filterParams['category'] = _selectedReportCategory;
      }
      
      // Add product filter
      if (_selectedReportProduct != null && _selectedReportProduct != 'All') {
        filterParams['product_name'] = _selectedReportProduct;
      }
      
      print('🔍 Stock Summary Filters: $filterParams');
      
      // Get store inventory report data
      final businessId = _selectedBusinessId ?? context.read<AuthProvider>().user?.businessId;
      if (businessId == null) {
        throw Exception('Business ID not found');
      }

      final data = await _apiService.getStoreInventoryReport(
        widget.storeId,
        businessId,
        startDate ?? DateTime.now().subtract(const Duration(days: 1)),
        endDate ?? DateTime.now(),
      );
      
      print('🔍 API Response Data: $data');
      print('🔍 Top Products: ${data['top_products']}');
      print('🔍 Summary: ${data['summary']}');
      
      // Convert the report data to match the expected format
      final List<Map<String, dynamic>> reportRows = [];
      
      // Add top products data (products with movements)
      if (data['top_products'] != null && data['top_products'].isNotEmpty) {
        for (var product in data['top_products']) {
          reportRows.add({
            'product_id': product['product_id'],
            'product_name': product['product_name'],
            'sku': product['sku'],
            'category_name': 'Store Product',
            'quantity_sold': product['total_out'] ?? 0,
            'quantity_remaining': product['current_stock'] ?? 0,
            'revenue': (product['total_out'] ?? 0) * (double.tryParse(product['price']?.toString() ?? '0') ?? 0.0),
            'profit': ((product['total_out'] ?? 0) * (double.tryParse(product['price']?.toString() ?? '0') ?? 0.0)) - 
                     ((product['total_out'] ?? 0) * (double.tryParse(product['cost_price']?.toString() ?? '0') ?? 0.0)),
            'sale_mode': 'retail',
          });
        }
      } else {
        // If no movements, show current inventory data
        print('🔍 No top products found, showing current inventory data');
        
        // Get current inventory data from the main inventory
        try {
          final businessId = _selectedBusinessId ?? context.read<AuthProvider>().user?.businessId;
          if (businessId != null) {
            final inventoryData = await _apiService.getStoreInventory(widget.storeId, businessId);
            print('🔍 Current inventory data: $inventoryData');
            
            // getStoreInventory returns List<Map<String, dynamic>> directly
            if (inventoryData is List) {
              // Direct list of inventory items
              for (var item in inventoryData) {
                if (item is Map<String, dynamic>) {
                  reportRows.add({
                    'product_id': item['product_id'],
                    'product_name': item['product_name'],
                    'sku': item['sku'] ?? '',
                    'category_name': item['category_name'] ?? 'Store Product',
                    'quantity_sold': 0, // No movements in this period
                    'quantity_remaining': item['store_quantity'] ?? 0,
                    'revenue': 0.0, // No sales in this period
                    'profit': 0.0, // No profit in this period
                    'sale_mode': 'retail',
                  });
                }
              }
            }
          }
        } catch (e) {
          print('🔍 Error getting current inventory: $e');
        }
      }
      
      print('🔍 Final Report Rows: ${reportRows.length} items');
      print('🔍 Report Rows Data: $reportRows');
      
      setState(() {
        _valueReportRows = reportRows;
        _resetStockSummaryPagination();
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

  void _resetStockSummaryPagination() {
    _stockSummaryCurrentPage = 0;
  }

  String _buildFilterStatusText() {
    List<String> filters = [];
    if (_selectedReportCategory != null && _selectedReportCategory != 'All') {
      filters.add('Category: $_selectedReportCategory');
    }
    if (_selectedReportProduct != null && _selectedReportProduct != 'All') {
      filters.add('Product: $_selectedReportProduct');
    }
    return filters.isNotEmpty ? 'Filters: ${filters.join(', ')}' : 'No filters applied';
  }

  List<Map<String, dynamic>> get _filteredStockSummaryData {
    return _valueReportRows;
  }

  List<Map<String, dynamic>> _getPaginatedData(List<Map<String, dynamic>> data, int page) {
    final startIndex = page * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, data.length);
    return data.sublist(startIndex, endIndex);
  }

  int _getTotalPages(int totalItems) {
    return (totalItems / _itemsPerPage).ceil();
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _exportStockSummaryToPdf() {
    // TODO: Implement PDF export
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'PDF export functionality coming soon'))),
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

    // Check if filtered data is empty
    if (_filteredStockSummaryData.isEmpty) {
      return Column(
        children: [
          Icon(
            Icons.filter_list,
            size: isSmallMobile ? 32 : 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No data matches the selected filters',
            style: TextStyle(
              fontSize: isSmallMobile ? 12 : 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your category or product filters',
            style: TextStyle(
              fontSize: isSmallMobile ? 10 : 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      );
    }

    if (isSmallMobile) {
      // Mobile layout - cards with pagination
      final paginatedData = _getPaginatedData(_filteredStockSummaryData, _stockSummaryCurrentPage);
      final totalPages = _getTotalPages(_filteredStockSummaryData.length);
      
      return Column(
        children: [
          ...paginatedData.map((row) => Card(
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
                            Text('Sold: ${_filteredStockSummaryData.fold<double>(0, (sum, r) => sum + _safeToDouble(r['quantity_sold'])).toInt()}', 
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
                        child: Text('Revenue: ₦${_safeToDouble(row['revenue']).toStringAsFixed(2)}'),
                      ),
                      Expanded(
                        child: Text('Profit: ₦${_safeToDouble(row['profit']).toStringAsFixed(2)}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )).toList(),
          
          // Mobile Pagination Controls
          if (totalPages > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Page ${_stockSummaryCurrentPage + 1} of $totalPages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: _stockSummaryCurrentPage > 0
                          ? () => setState(() => _stockSummaryCurrentPage--)
                          : null,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      Text(
                        '${(_stockSummaryCurrentPage * _itemsPerPage) + 1}-${(_stockSummaryCurrentPage + 1) * _itemsPerPage} of ${_filteredStockSummaryData.length}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _stockSummaryCurrentPage < totalPages - 1
                          ? () => setState(() => _stockSummaryCurrentPage++)
                          : null,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // Desktop layout - table with pagination
    final paginatedData = _getPaginatedData(_filteredStockSummaryData, _stockSummaryCurrentPage);
    final totalPages = _getTotalPages(_filteredStockSummaryData.length);
    
    return Column(
      children: [
        // Table
        SingleChildScrollView(
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
              ...paginatedData.map((row) => DataRow(
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
                  DataCell(Text('₦${_safeToDouble(row['revenue']).toStringAsFixed(2)}')),
                  DataCell(Text('₦${_safeToDouble(row['profit']).toStringAsFixed(2)}')),
                  DataCell(Text((row['sale_mode'] ?? '').toString().isNotEmpty ? (row['sale_mode'] == 'wholesale' ? 'Wholesale' : 'Retail') : '')),
                ],
              )),
              // Totals row
              DataRow(
                color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                  return Colors.grey[200];
                }),
                cells: [
                  DataCell(Text(t(context, 'TOTAL'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  DataCell(Text(_filteredStockSummaryData.fold<double>(0, (sum, r) => sum + _safeToDouble(r['quantity_sold'])).toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  DataCell(Text('₦${_filteredStockSummaryData.fold<double>(0, (sum, r) => sum + _safeToDouble(r['revenue'])).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text('₦${_filteredStockSummaryData.fold<double>(0, (sum, r) => sum + _safeToDouble(r['profit'])).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                ],
              ),
            ],
          ),
        ),
        
        // Desktop Pagination Controls
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${(_stockSummaryCurrentPage * _itemsPerPage) + 1} to ${(_stockSummaryCurrentPage + 1) * _itemsPerPage} of ${_filteredStockSummaryData.length} entries',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: _stockSummaryCurrentPage > 0
                        ? () => setState(() => _stockSummaryCurrentPage--)
                        : null,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Page ${_stockSummaryCurrentPage + 1} of $totalPages',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: _stockSummaryCurrentPage < totalPages - 1
                        ? () => setState(() => _stockSummaryCurrentPage++)
                        : null,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showProductTransactionsDialog(int productId, String productName) {
    // TODO: Implement product transactions dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Product transactions for $productName (ID: $productId)')),
    );
  }

  // =====================================================
  // COMPREHENSIVE REPORTS - NEW METHODS
  // =====================================================

  Widget _buildCurrentStockSummary() {
    if (_reports.isEmpty || _reports['current_stock'] == null) {
      return _buildEmptyCard('Current Stock Summary', Icons.inventory_2);
    }

    final currentStock = _reports['current_stock'];
    final summary = currentStock['summary'] ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Current Stock Summary'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Products',
                    '${summary['total_products'] ?? 0}',
                    Icons.category,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Units',
                    '${summary['total_units'] ?? 0}',
                    Icons.inventory,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'In Stock',
                    '${summary['in_stock'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Low Stock',
                    '${summary['low_stock'] ?? 0}',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Out of Stock',
                    '${summary['out_of_stock'] ?? 0}',
                    Icons.error,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String title, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'No data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary() {
    if (_reports.isEmpty || _reports['financial_summary'] == null) {
      return _buildEmptyCard('Financial Summary', Icons.attach_money);
    }

    final financial = _reports['financial_summary'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Financial Summary'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Cost Value',
                    '\$${_formatNumber(financial['total_cost_value'] ?? 0)}',
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Selling Value',
                    '\$${_formatNumber(financial['total_selling_value'] ?? 0)}',
                    Icons.sell,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Profit Potential',
                    '\$${_formatNumber(financial['total_profit_potential'] ?? 0)}',
                    Icons.trending_up,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Avg Cost Price',
                    '\$${_formatNumber(financial['average_cost_price'] ?? 0)}',
                    Icons.price_check,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num = double.tryParse(value.toString()) ?? 0;
    return num.toStringAsFixed(2);
  }

  Widget _buildMovementSummary() {
    if (_reports.isEmpty || _reports['movement_summary'] == null) {
      return _buildEmptyCard('Movement Summary', Icons.trending_up);
    }

    final movement = _reports['movement_summary'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Movement Summary'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Stock In',
                    '${movement['total_stock_in'] ?? 0}',
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Transferred Out',
                    '${movement['total_transferred_out'] ?? 0}',
                    Icons.arrow_upward,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlerts() {
    if (_reports.isEmpty || _reports['low_stock_alerts'] == null) {
      return _buildEmptyCard('Low Stock Alerts', Icons.warning);
    }

    final alerts = _reports['low_stock_alerts'] as List;
    if (alerts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.check_circle, size: 48, color: Colors.green[400]),
              const SizedBox(height: 8),
              Text(
                'Low Stock Alerts',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'All products are well stocked!',
                style: TextStyle(color: Colors.green[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Low Stock Alerts'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...alerts.take(3).map((alert) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: alert['alert_level']?.contains('CRITICAL') == true 
                    ? Colors.red[50] 
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: alert['alert_level']?.contains('CRITICAL') == true 
                      ? Colors.red[200]! 
                      : Colors.orange[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    alert['alert_level']?.contains('CRITICAL') == true 
                        ? Icons.error 
                        : Icons.warning,
                    color: alert['alert_level']?.contains('CRITICAL') == true 
                        ? Colors.red[600] 
                        : Colors.orange[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['product_name'] ?? 'Unknown Product',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Stock: ${alert['current_quantity'] ?? 0} / Min: ${alert['min_stock_level'] ?? 0}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts() {
    if (_reports.isEmpty || _reports['top_products'] == null) {
      return _buildEmptyCard('Top Products', Icons.star);
    }

    final topProducts = _reports['top_products'] as List;
    if (topProducts.isEmpty) {
      return _buildEmptyCard('Top Products', Icons.star);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber[600]),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Top Products'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Top ${topProducts.length}',
                    style: TextStyle(
                      color: Colors.amber[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...topProducts.take(3).map((product) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory,
                      color: Colors.amber[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['product_name'] ?? 'Unknown Product',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'SKU: ${product['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${product['current_stock'] ?? 0}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Stock',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
}


class _ProductDialog extends StatefulWidget {
  final ApiService apiService;
  final Product? product;
  final Function(Map<String, dynamic>, File?, {Uint8List? webImageBytes, String? webImageName}) onSave;

  const _ProductDialog({
    required this.apiService,
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
                          labelText: t(context, 'Category'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.category),
                          filled: true,
                          fillColor: Colors.purple[50],
                          helperText: t(context, 'Select a category for this product (optional)'),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: isMobile ? 16 : 20,
              color: Colors.blue[600],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.add,
              size: isMobile ? 12 : 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.photo_library,
              size: isMobile ? 16 : 20,
              color: Colors.green[600],
            ),
          ],
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
        const SizedBox(height: 4),
        Text(
          t(context, 'Camera or Gallery'),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: isMobile ? 8 : 10,
          ),
        ),
      ],
    );
  }
}

class _IncrementDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(int quantity, double costPrice, String? notes) onIncrement;

  const _IncrementDialog({
    required this.item,
    required this.onIncrement,
  });

  @override
  State<_IncrementDialog> createState() => _IncrementDialogState();
}

class _IncrementDialogState extends State<_IncrementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current cost price if available
    final currentCostPrice = widget.item['cost_price'];
    if (currentCostPrice != null) {
      _costPriceController.text = currentCostPrice.toString();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final quantity = int.parse(_quantityController.text.trim());
      final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
      
      await widget.onIncrement(quantity, costPrice, notes);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SuccessUtils.showOperationError(context, 'increment stock', e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t(context, 'Add Stock'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item['product_name'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU: ${widget.item['sku'] ?? ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Stock: ${widget.item['store_quantity'] ?? widget.item['quantity'] ?? 0}',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Quantity input
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: t(context, 'Quantity to Add'),
                hintText: t(context, 'Enter quantity'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.inventory),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t(context, 'Please enter quantity');
                }
                final quantity = int.tryParse(value.trim());
                if (quantity == null || quantity <= 0) {
                  return t(context, 'Please enter a valid quantity');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Cost price input
            TextFormField(
              controller: _costPriceController,
              decoration: InputDecoration(
                labelText: t(context, 'Cost Price'),
                hintText: t(context, 'Enter cost price per unit'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                prefixText: '₦ ',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t(context, 'Please enter cost price');
                }
                final costPrice = double.tryParse(value.trim());
                if (costPrice == null || costPrice < 0) {
                  return t(context, 'Please enter a valid cost price');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Notes input
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: t(context, 'Notes (Optional)'),
                hintText: t(context, 'e.g., New purchase, Restock'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(t(context, 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(t(context, 'Add Stock')),
        ),
      ],
    );
  }
}

class _EditCostPriceDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(double costPrice) onUpdate;

  const _EditCostPriceDialog({
    required this.item,
    required this.onUpdate,
  });

  @override
  State<_EditCostPriceDialog> createState() => _EditCostPriceDialogState();
}

class _EditCostPriceDialogState extends State<_EditCostPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _costPriceController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current cost price
    final currentCostPrice = widget.item['cost_price'];
    if (currentCostPrice != null) {
      _costPriceController.text = currentCostPrice.toString();
    }
  }

  @override
  void dispose() {
    _costPriceController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final costPrice = double.parse(_costPriceController.text.trim());
      await widget.onUpdate(costPrice);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SuccessUtils.showOperationError(context, 'update cost price', e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t(context, 'Edit Cost Price'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item['product_name'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU: ${widget.item['sku'] ?? ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Cost: ₦${(double.tryParse(widget.item['cost_price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Cost price input
            TextFormField(
              controller: _costPriceController,
              decoration: InputDecoration(
                labelText: t(context, 'New Cost Price'),
                hintText: t(context, 'Enter new cost price per unit'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                prefixText: '₦ ',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t(context, 'Please enter cost price');
                }
                final costPrice = double.tryParse(value.trim());
                if (costPrice == null || costPrice < 0) {
                  return t(context, 'Please enter a valid cost price');
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(t(context, 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(t(context, 'Update Cost Price')),
        ),
      ],
    );
  }
}

class _TransferDialog extends StatefulWidget {
  final int storeId;
  final String storeName;
  final List<Map<String, dynamic>> inventory;
  final List<Map<String, dynamic>> businesses;
  final ApiService apiService;
  final VoidCallback onTransfer;

  const _TransferDialog({
    required this.storeId,
    required this.storeName,
    required this.inventory,
    required this.businesses,
    required this.apiService,
    required this.onTransfer,
  });

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  int? _selectedBusinessId;
  final Map<int, int> _selectedQuantities = {};
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize quantities to 0 for all products
    for (var item in widget.inventory) {
      _selectedQuantities[item['product_id']] = 0;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Dialog(
      child: Container(
        width: isSmallScreen ? screenSize.width * 0.95 : screenSize.width * 0.8,
        height: isSmallScreen ? screenSize.height * 0.9 : screenSize.height * 0.8,
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.send,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Transfer Products to Business',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'From: ${widget.storeName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Business Selection
            Text(
              'Select Business:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedBusinessId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: widget.businesses.map((business) {
                return DropdownMenuItem<int>(
                  value: business['id'],
                  child: Text(business['name'] ?? 'Business ${business['id']}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBusinessId = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Products Selection
            Text(
              'Select Products and Quantities:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Products List
            Expanded(
              child: widget.inventory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products available for transfer',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.inventory.length,
                      itemBuilder: (context, index) {
                        final item = widget.inventory[index];
                        final productId = item['product_id'];
                        final currentQuantity = _selectedQuantities[productId] ?? 0;
                        final availableQuantity = item['store_quantity'] ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: isSmallScreen
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Mobile layout
                                      Row(
                                        children: [
                                          // Product Image
                                          _buildProductImage(item, isSmallScreen),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['product_name'] ?? 'Unknown Product',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'SKU: ${item['sku'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  'Available: $availableQuantity',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Quantity Input (full width on mobile)
                                      TextFormField(
                                        initialValue: currentQuantity.toString(),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Quantity to Transfer',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          suffixText: 'Max: $availableQuantity',
                                        ),
                                        onChanged: (value) {
                                          final quantity = int.tryParse(value) ?? 0;
                                          if (quantity <= availableQuantity) {
                                            setState(() {
                                              _selectedQuantities[productId] = quantity;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      // Desktop layout
                                      _buildProductImage(item, isSmallScreen),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['product_name'] ?? 'Unknown Product',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'SKU: ${item['sku'] ?? 'N/A'}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              'Available: $availableQuantity',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Quantity Input
                                      SizedBox(
                                        width: 120,
                                        child: TextFormField(
                                          initialValue: currentQuantity.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Qty',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            suffixText: 'Max: $availableQuantity',
                                          ),
                                          onChanged: (value) {
                                            final quantity = int.tryParse(value) ?? 0;
                                            if (quantity <= availableQuantity) {
                                              setState(() {
                                                _selectedQuantities[productId] = quantity;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(t(context, 'Cancel')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading || _selectedBusinessId == null || _getTotalSelectedQuantity() == 0
                      ? null
                      : _performTransfer,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(t(context, 'Transfer')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _getTotalSelectedQuantity() {
    return _selectedQuantities.values.fold(0, (sum, quantity) => sum + quantity);
  }

  Widget _buildProductImage(Map<String, dynamic> item, bool isSmallScreen) {
    final imageSize = isSmallScreen ? 60.0 : 50.0;
    
    if (item['image_url'] != null && item['image_url'].toString().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          'https://rtailed-production.up.railway.app${item['image_url']}',
          width: imageSize,
          height: imageSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, color: Colors.grey),
            );
          },
        ),
      );
    } else {
      return Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }
  }

  Future<void> _performTransfer() async {
    if (_selectedBusinessId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare products for transfer
      final products = <Map<String, dynamic>>[];
      for (var entry in _selectedQuantities.entries) {
        if (entry.value > 0) {
          products.add({
            'product_id': entry.key,
            'quantity': entry.value,
          });
        }
      }

      if (products.isEmpty) {
        throw Exception('No products selected for transfer');
      }

      // Perform the transfer
      await widget.apiService.transferStoreToBusiness(
        widget.storeId,
        _selectedBusinessId!,
        products,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        SuccessUtils.showBusinessSuccess(context, 'Products transferred successfully');
        widget.onTransfer();
      }
    } catch (e) {
      if (mounted) {
        SuccessUtils.showOperationError(context, 'transfer products', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 
