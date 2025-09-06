import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:retail_management/screens/home/store_inventory_screen.dart';

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  // Data variables
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _transfers = [];
  List<Map<String, dynamic>> _businesses = [];
  bool _loading = false;
  String? _error;
  
  // Filter variables
  String _searchQuery = '';
  String _selectedStoreType = '';
  String _selectedStatus = '';

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final isSuperAdmin = user != null && user.role == 'superadmin';
    
    // Number of tabs based on user role
    final tabCount = isSuperAdmin ? 4 : 3; // Superadmin gets Store Assignment tab
    _tabController = TabController(length: tabCount, vsync: this);
    
    _loadData();
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
      final isSuperAdmin = user?.role == 'superadmin';
      
      // Load stores
      final stores = await _apiService.getStores();
      setState(() {
        _stores = stores;
      });
      
      // Load transfers
      final transfers = await _apiService.getStoreTransfers();
      setState(() {
        _transfers = transfers;
      });
      
      // Load businesses (only for superadmin)
      if (isSuperAdmin) {
        final businesses = await _apiService.getBusinesses();
        setState(() {
          _businesses = businesses;
        });
      }
      
    } catch (e) {
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
        title: t(context, 'Store Management'),
        actions: [
          if (isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateStoreDialog,
              tooltip: t(context, 'Add Store'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: t(context, 'Refresh'),
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
              isScrollable: true,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: t(context, 'Stores')),
                Tab(text: t(context, 'Transfers')),
                Tab(text: t(context, 'Inventory')),
                if (isSuperAdmin) Tab(text: t(context, 'Assignments')),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStoresTab(),
                _buildTransfersTab(),
                _buildInventoryTab(),
                if (isSuperAdmin) _buildAssignmentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoresTab() {
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
              t(context, 'Error loading stores'),
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
              child: Text(t(context, 'Retry')),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: t(context,'Search stores...'),
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
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedStoreType.isEmpty ? null : _selectedStoreType,
                hint: Text(t(context,'Type')),
                items: [
                  DropdownMenuItem(value: '', child: Text(t(context,'All Types'))),
                  DropdownMenuItem(value: 'warehouse', child: Text(t(context,'Warehouse'))),
                  DropdownMenuItem(value: 'retail', child: Text(t(context,'Retail'))),
                  DropdownMenuItem(value: 'distribution_center', child: Text(t(context,'Distribution Center'))),
                  DropdownMenuItem(value: 'showroom', child: Text(t(context,'Showroom'))),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStoreType = value ?? '';
                  });
                },
              ),
            ],
          ),
        ),
        
        // Stores List
        Expanded(
          child: _buildStoresList(),
        ),
      ],
    );
  }

  Widget _buildStoresList() {
    final filteredStores = _stores.where((store) {
      final matchesSearch = _searchQuery.isEmpty ||
          store['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          store['store_code'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          store['address'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesType = _selectedStoreType.isEmpty ||
          store['store_type'] == _selectedStoreType;
      
      return matchesSearch && matchesType;
    }).toList();

    if (filteredStores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              t(context,'No stores found'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              t(context,'Try adjusting your search criteria'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredStores.length,
      itemBuilder: (context, index) {
        final store = filteredStores[index];
        return _buildStoreCard(store);
      },
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showStoreDetails(store),
        borderRadius: BorderRadius.circular(8),
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
                          store['name'] ?? '',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          store['store_code'] ?? '',
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
                      color: _getStoreTypeColor(store['store_type']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStoreTypeLabel(store['store_type']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      store['address'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${store['assigned_businesses_count'] ?? 0} ${t(context,'businesses')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${store['total_products'] ?? 0} ${t(context,'products')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStoreTypeColor(String? type) {
    switch (type) {
      case 'warehouse':
        return Colors.blue;
      case 'retail':
        return Colors.green;
      case 'distribution_center':
        return Colors.orange;
      case 'showroom':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStoreTypeLabel(String? type) {
    switch (type) {
      case 'warehouse':
        return t(context,'Warehouse');
      case 'retail':
        return t(context,'Retail');
      case 'distribution_center':
        return t(context,'Distribution Center');
      case 'showroom':
        return t(context,'Showroom');
      default:
        return t(context,'Unknown');
    }
  }

  Widget _buildTransfersTab() {
    return const Center(
      child: Text('Transfers Tab - Coming Soon'),
    );
  }

  Widget _buildInventoryTab() {
    return const Center(
      child: Text('Inventory Tab - Coming Soon'),
    );
  }

  Widget _buildAssignmentsTab() {
    return const Center(
      child: Text('Assignments Tab - Coming Soon'),
    );
  }

  void _showCreateStoreDialog() {
    // TODO: Implement create store dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context,'Create store dialog coming soon'))),
    );
  }

  void _showStoreDetails(Map<String, dynamic> store) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoreInventoryScreen(
          storeId: store['id'],
          storeName: store['name'],
        ),
      ),
    );
  }
}
