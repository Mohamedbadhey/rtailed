import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/success_utils.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';

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
                    t(context,'Available'),
                    item['available_quantity'] ?? 0,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildQuantityInfo(
                    t(context,'Reserved'),
                    item['reserved_quantity'] ?? 0,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildQuantityInfo(
                    t(context,'Total'),
                    item['quantity'] ?? 0,
                    Colors.green,
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
                  '${t(context,'Cost')}: ₦${(item['cost_price'] ?? 0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.sell, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Price')}: ₦${(item['price'] ?? 0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
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

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }

  void _showAddProductsDialog() {
    // TODO: Implement add products dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context,'Add products dialog coming soon'))),
    );
  }

  void _showTransferDialog() {
    // TODO: Implement transfer dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context,'Transfer dialog coming soon'))),
    );
  }
}
