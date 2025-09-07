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
  
  // Business selection for superadmin
  List<Map<String, dynamic>> _businesses = [];
  int? _selectedBusinessId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load data after the widget is built to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }
  
  Future<void> _initializeData() async {
    final user = context.read<AuthProvider>().user;
    
    // If superadmin, load businesses first
    if (user?.role == 'superadmin') {
      await _loadBusinesses();
    } else {
      _loadData();
    }
  }
  
  Future<void> _loadBusinesses() async {
    try {
      final businesses = await _apiService.getBusinesses();
      setState(() {
        _businesses = businesses;
      });
    } catch (e) {
      print('Error loading businesses: $e');
      setState(() {
        _error = 'Failed to load businesses: $e';
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
      final reports = await _apiService.getStoreInventoryReports(widget.storeId, businessId);
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
    if (_reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = _reports['summary'] as Map<String, dynamic>? ?? {};
    final topProducts = _reports['top_products'] as List<dynamic>? ?? [];
    final dailyTrends = _reports['daily_trends'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  t(context,'Total Products'),
                  summary['total_products']?.toString() ?? '0',
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  t(context,'Total In'),
                  summary['total_in']?.toString() ?? '0',
                  Icons.arrow_downward,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  t(context,'Total Transferred'),
                  summary['total_transferred']?.toString() ?? '0',
                  Icons.send,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  t(context,'Total Movements'),
                  (summary['in_movements'] ?? 0 + summary['transfer_movements'] ?? 0).toString(),
                  Icons.history,
                  Colors.purple,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Top Products
          Text(
            t(context,'Top Products by Movement'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...topProducts.map((product) => _buildTopProductCard(product)).toList(),
        ],
      ),
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
    // TODO: Implement transfer dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context,'Transfer dialog coming soon'))),
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
