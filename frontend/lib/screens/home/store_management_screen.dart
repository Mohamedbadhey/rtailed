import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/success_utils.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:retail_management/screens/home/store_inventory_screen.dart';
import 'package:retail_management/widgets/custom_text_field.dart';

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
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = false;
  String? _error;
  
  // Filter variables
  String _searchQuery = '';
  String _selectedStoreType = '';
  String _selectedTransferStatus = '';
  String _selectedTransferType = '';
  String _selectedStatus = '';

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final isSuperAdmin = user != null && user.role == 'superadmin';
    
    // Number of tabs based on user role
    final tabCount = isSuperAdmin ? 4 : 3; // Superadmin gets Store Assignment tab
    print('Store Management - Tab count: $tabCount (isSuperAdmin: $isSuperAdmin)');
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
        
        // Load assignments for superadmin
        await _loadAssignments();
      }
      
    } catch (e) {
      print('Store Management Error: $e');
      print('Store Management Error Type: ${e.runtimeType}');
      print('Store Management Error Details: ${e.toString()}');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load store data', e.toString());
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
    
    print('Store Management - User role: ${user?.role}');
    print('Store Management - Is superadmin: $isSuperAdmin');
    print('Store Management - Loading: $_loading');
    print('Store Management - Error: $_error');
    print('Store Management - Stores count: ${_stores.length}');
    print('Store Management - Businesses count: ${_businesses.length}');
    
    print('Store Management Screen - Building UI');
    
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
              children: isSuperAdmin ? [
                _buildStoresTab(),
                _buildTransfersTab(),
                _buildInventoryTab(),
                _buildAssignmentsTab(),
              ] : [
                _buildStoresTab(),
                _buildTransfersTab(),
                _buildInventoryTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _getCurrentTabIndex() == 1 
          ? FloatingActionButton(
              onPressed: _showCreateTransferDialog,
              tooltip: t(context, 'Create Transfer'),
              child: const Icon(Icons.swap_horiz),
            )
          : FloatingActionButton(
              onPressed: _showCreateStoreDialog,
              tooltip: t(context, 'Create Store'),
              child: const Icon(Icons.add),
            ),
    );
  }

  int _getCurrentTabIndex() {
    return _tabController.index;
  }

  void _showCreateTransferDialog() {
    // TODO: Implement create transfer dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'Create transfer dialog coming soon'))),
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
              t(context, 'Error loading transfers'),
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
                    hintText: t(context, 'Search transfers...'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButtonFormField<String>(
                value: _selectedTransferStatus,
                decoration: InputDecoration(
                  labelText: t(context, 'Status'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text(t(context, 'All Status'))),
                  DropdownMenuItem(value: 'pending', child: Text(t(context, 'Pending'))),
                  DropdownMenuItem(value: 'approved', child: Text(t(context, 'Approved'))),
                  DropdownMenuItem(value: 'in_transit', child: Text(t(context, 'In Transit'))),
                  DropdownMenuItem(value: 'delivered', child: Text(t(context, 'Delivered'))),
                  DropdownMenuItem(value: 'cancelled', child: Text(t(context, 'Cancelled'))),
                  DropdownMenuItem(value: 'rejected', child: Text(t(context, 'Rejected'))),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTransferStatus = value ?? '';
                  });
                  _loadData();
                },
              ),
              const SizedBox(width: 16),
              DropdownButtonFormField<String>(
                value: _selectedTransferType,
                decoration: InputDecoration(
                  labelText: t(context, 'Type'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text(t(context, 'All Types'))),
                  DropdownMenuItem(value: 'store_to_store', child: Text(t(context, 'Store to Store'))),
                  DropdownMenuItem(value: 'business_to_business', child: Text(t(context, 'Business to Business'))),
                  DropdownMenuItem(value: 'store_to_business', child: Text(t(context, 'Store to Business'))),
                  DropdownMenuItem(value: 'business_to_store', child: Text(t(context, 'Business to Store'))),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTransferType = value ?? '';
                  });
                  _loadData();
                },
              ),
            ],
          ),
        ),
        
        // Transfers List
        Expanded(
          child: _buildTransfersList(),
        ),
      ],
    );
  }

  Widget _buildTransfersList() {
    if (_transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              t(context, 'No transfers found'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              t(context, 'Create your first transfer request'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transfers.length,
      itemBuilder: (context, index) {
        final transfer = _transfers[index];
        return _buildTransferCard(transfer);
      },
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> transfer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer['transfer_code'] ?? 'N/A',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getTransferTypeText(transfer['transfer_type']),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(transfer['status']),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Transfer Details
            Row(
              children: [
                Expanded(
                  child: _buildTransferDetail(
                    Icons.store,
                    t(context, 'From'),
                    _getTransferFromText(transfer),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTransferDetail(
                    Icons.store,
                    t(context, 'To'),
                    _getTransferToText(transfer),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Request Info
            Row(
              children: [
                Expanded(
                  child: _buildTransferDetail(
                    Icons.person,
                    t(context, 'Requested by'),
                    transfer['requested_by_username'] ?? 'N/A',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTransferDetail(
                    Icons.calendar_today,
                    t(context, 'Requested'),
                    _formatDate(transfer['requested_at']),
                  ),
                ),
              ],
            ),
            
            if (transfer['expected_delivery_date'] != null) ...[
              const SizedBox(height: 12),
              _buildTransferDetail(
                Icons.schedule,
                t(context, 'Expected Delivery'),
                _formatDate(transfer['expected_delivery_date']),
              ),
            ],
            
            if (transfer['notes'] != null && transfer['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTransferDetail(
                Icons.note,
                t(context, 'Notes'),
                transfer['notes'],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showTransferDetails(transfer),
                  child: Text(t(context, 'View Details')),
                ),
                const SizedBox(width: 8),
                if (_canApproveTransfer(transfer))
                  ElevatedButton(
                    onPressed: () => _approveTransfer(transfer['id']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: Text(t(context, 'Approve')),
                  ),
                if (_canRejectTransfer(transfer)) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _rejectTransfer(transfer['id']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text(t(context, 'Reject')),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'approved':
        color = Colors.blue;
        break;
      case 'in_transit':
        color = Colors.purple;
        break;
      case 'delivered':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.grey;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getTransferTypeText(String? type) {
    switch (type) {
      case 'store_to_store':
        return t(context, 'Store to Store');
      case 'business_to_business':
        return t(context, 'Business to Business');
      case 'store_to_business':
        return t(context, 'Store to Business');
      case 'business_to_store':
        return t(context, 'Business to Store');
      default:
        return t(context, 'Unknown Type');
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return t(context, 'Pending');
      case 'approved':
        return t(context, 'Approved');
      case 'in_transit':
        return t(context, 'In Transit');
      case 'delivered':
        return t(context, 'Delivered');
      case 'cancelled':
        return t(context, 'Cancelled');
      case 'rejected':
        return t(context, 'Rejected');
      default:
        return t(context, 'Unknown');
    }
  }

  String _getTransferFromText(Map<String, dynamic> transfer) {
    if (transfer['from_store_name'] != null) {
      return transfer['from_store_name'];
    } else if (transfer['from_business_name'] != null) {
      return transfer['from_business_name'];
    }
    return t(context, 'Unknown');
  }

  String _getTransferToText(Map<String, dynamic> transfer) {
    if (transfer['to_store_name'] != null) {
      return transfer['to_store_name'];
    } else if (transfer['to_business_name'] != null) {
      return transfer['to_business_name'];
    }
    return t(context, 'Unknown');
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  bool _canApproveTransfer(Map<String, dynamic> transfer) {
    final user = context.read<AuthProvider>().user;
    return user?.role == 'superadmin' && transfer['status'] == 'pending';
  }

  bool _canRejectTransfer(Map<String, dynamic> transfer) {
    final user = context.read<AuthProvider>().user;
    return user?.role == 'superadmin' && transfer['status'] == 'pending';
  }

  void _showTransferDetails(Map<String, dynamic> transfer) {
    // TODO: Implement transfer details dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'Transfer details coming soon'))),
    );
  }

  void _approveTransfer(int transferId) async {
    // For now, approve with default quantities (approve all requested quantities)
    // In a full implementation, you'd show a dialog to let user specify approved quantities
    try {
      // Get transfer details first to get the items
      final transferDetails = await _apiService.getTransferDetails(transferId);
      final items = transferDetails['items'] as List<dynamic>? ?? [];
      
      // Create approved quantities list (approve all requested quantities for now)
      final approvedQuantities = items.map((item) => {
        'product_id': item['product_id'],
        'approved_quantity': item['requested_quantity'],
      }).toList();
      
      await _apiService.approveTransfer(transferId, approvedQuantities);
      SuccessUtils.showBusinessSuccess(context, 'Transfer approved successfully');
      _loadData(); // Refresh the list
    } catch (e) {
      SuccessUtils.showOperationError(context, 'approve transfer', e.toString());
    }
  }

  void _rejectTransfer(int transferId) async {
    // Show dialog to get rejection reason
    final TextEditingController reasonController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t(context, 'Reject Transfer')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t(context, 'Please provide a reason for rejecting this transfer:')),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: t(context, 'Rejection Reason'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t(context, 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(reasonController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(t(context, 'Reject')),
            ),
          ],
        );
      },
    );
    
    if (result != null) {
      try {
        await _apiService.rejectTransfer(transferId, result);
        SuccessUtils.showBusinessSuccess(context, 'Transfer rejected successfully');
        _loadData(); // Refresh the list
      } catch (e) {
        SuccessUtils.showOperationError(context, 'reject transfer', e.toString());
      }
    }
  }

  Widget _buildInventoryTab() {
    return const Center(
      child: Text('Inventory Tab - Coming Soon'),
    );
  }

  Widget _buildAssignmentsTab() {
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
              t(context, 'Error loading assignments'),
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
        // Header with Add Assignment button
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t(context, 'Store-Business Assignments'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateAssignmentDialog,
                icon: const Icon(Icons.add),
                label: Text(t(context, 'Assign Store')),
              ),
            ],
          ),
        ),
        
        // Assignments List
        Expanded(
          child: _buildAssignmentsList(),
        ),
      ],
    );
  }

  Widget _buildAssignmentsList() {
    // Create a list of all possible store-business combinations
    List<Map<String, dynamic>> allAssignments = [];
    
    for (var store in _stores) {
      for (var business in _businesses) {
        allAssignments.add({
          'store': store,
          'business': business,
          'is_assigned': _isStoreAssignedToBusiness(store['id'], business['id']),
        });
      }
    }

    if (allAssignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              t(context, 'No assignments found'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              t(context, 'Create stores and businesses first'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allAssignments.length,
      itemBuilder: (context, index) {
        final assignment = allAssignments[index];
        return _buildAssignmentCard(assignment);
      },
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final store = assignment['store'];
    final business = assignment['business'];
    final isAssigned = assignment['is_assigned'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
                    '${t(context, 'Store Code')}: ${store['store_code'] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    business['name'] ?? '',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${t(context, 'Business Code')}: ${business['business_code'] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAssigned ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAssigned ? t(context, 'Assigned') : t(context, 'Not Assigned'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (isAssigned)
                  ElevatedButton(
                    onPressed: () => _removeAssignment(store['id'], business['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t(context, 'Remove')),
                  )
                else
                  ElevatedButton(
                    onPressed: () => _assignStoreToBusiness(store['id'], business['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t(context, 'Assign')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAssignments() async {
    try {
      // Load assignments for all stores
      List<Map<String, dynamic>> allAssignments = [];
      
      for (var store in _stores) {
        final storeAssignments = await _apiService.getStoreBusinesses(store['id']);
        for (var assignment in storeAssignments) {
          allAssignments.add({
            'store_id': store['id'],
            'business_id': assignment['business_id'],
            'assignment_id': assignment['id'],
            'assigned_at': assignment['assigned_at'],
            'is_active': assignment['is_active'],
          });
        }
      }
      
      setState(() {
        _assignments = allAssignments;
      });
    } catch (e) {
      print('Error loading assignments: $e');
      // Don't set error state for assignments, just log it
    }
  }

  bool _isStoreAssignedToBusiness(int storeId, int businessId) {
    // Check if this store-business combination exists in the assignments
    return _assignments.any((assignment) => 
      assignment['store_id'] == storeId && 
      assignment['business_id'] == businessId &&
      assignment['is_active'] == true
    );
  }

  void _showCreateAssignmentDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateAssignmentDialog(
        stores: _stores,
        businesses: _businesses,
        onAssignmentCreated: () async {
          await _loadAssignments(); // Refresh assignments
          setState(() {}); // Refresh UI
        },
      ),
    );
  }

  void _assignStoreToBusiness(int storeId, int businessId) async {
    try {
      await _apiService.assignBusinessToStore(storeId, businessId);
      SuccessUtils.showBusinessSuccess(context, 'Store assigned to business successfully');
      await _loadAssignments(); // Refresh assignments
      setState(() {}); // Refresh UI
    } catch (e) {
      SuccessUtils.showOperationError(context, 'assign store to business', e.toString());
    }
  }

  void _removeAssignment(int storeId, int businessId) async {
    try {
      // Find the assignment ID
      final assignment = _assignments.firstWhere(
        (assignment) => assignment['store_id'] == storeId && assignment['business_id'] == businessId,
      );
      
      await _apiService.removeBusinessFromStore(storeId, businessId);
      SuccessUtils.showBusinessSuccess(context, 'Assignment removed successfully');
      await _loadAssignments(); // Refresh assignments
      setState(() {}); // Refresh UI
    } catch (e) {
      SuccessUtils.showOperationError(context, 'remove assignment', e.toString());
    }
  }

  void _showCreateStoreDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreateStoreDialog(
          onStoreCreated: (store) {
            if (mounted) {
              setState(() {
                _stores.add(store);
              });
              // Use a post-frame callback to ensure the widget is still mounted
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  SuccessUtils.showBusinessSuccess(context, 'Store "${store['name']}" created successfully');
                }
              });
            }
          },
        );
      },
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

// Create Store Dialog Widget
class CreateStoreDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onStoreCreated;

  const CreateStoreDialog({
    super.key,
    required this.onStoreCreated,
  });

  @override
  State<CreateStoreDialog> createState() => _CreateStoreDialogState();
}

class _CreateStoreDialogState extends State<CreateStoreDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _storeCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  final _managerEmailController = TextEditingController();
  final _capacityController = TextEditingController();

  String _selectedStoreType = 'warehouse';
  bool _isActive = true;
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _nameController.dispose();
    _storeCodeController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _managerEmailController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.add_business, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t(context, 'Create New Store'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Section
                      _buildSectionHeader(t(context, 'Basic Information')),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: CustomTextField(
                              controller: _nameController,
                              labelText: t(context, 'Store Name'),
                              hintText: t(context, 'Enter store name'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return t(context, 'Store name is required');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _storeCodeController,
                              labelText: t(context, 'Store Code'),
                              hintText: t(context, 'e.g., MWL001'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return t(context, 'Store code is required');
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      CustomTextField(
                        controller: _descriptionController,
                        labelText: t(context, 'Description'),
                        hintText: t(context, 'Enter store description'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      
                      // Store Type and Status
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(context, 'Store Type'),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedStoreType,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  items: [
                                    DropdownMenuItem(value: 'warehouse', child: Text(t(context, 'Warehouse'))),
                                    DropdownMenuItem(value: 'retail', child: Text(t(context, 'Retail Store'))),
                                    DropdownMenuItem(value: 'distribution_center', child: Text(t(context, 'Distribution Center'))),
                                    DropdownMenuItem(value: 'showroom', child: Text(t(context, 'Showroom'))),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStoreType = value!;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(context, 'Capacity'),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CustomTextField(
                                  controller: _capacityController,
                                  hintText: t(context, 'Optional'),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Location Information Section
                      _buildSectionHeader(t(context, 'Location Information')),
                      const SizedBox(height: 12),
                      
                      CustomTextField(
                        controller: _addressController,
                        labelText: t(context, 'Address'),
                        hintText: t(context, 'Enter full address'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t(context, 'Address is required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _cityController,
                              labelText: t(context, 'City'),
                              hintText: t(context, 'Enter city'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _stateController,
                              labelText: t(context, 'State'),
                              hintText: t(context, 'Enter state'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Contact Information Section
                      _buildSectionHeader(t(context, 'Contact Information')),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _phoneController,
                              labelText: t(context, 'Phone'),
                              hintText: t(context, 'Enter phone number'),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _emailController,
                              labelText: t(context, 'Email'),
                              hintText: t(context, 'Enter email address'),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Manager Information Section
                      _buildSectionHeader(t(context, 'Manager Information')),
                      const SizedBox(height: 12),
                      
                      CustomTextField(
                        controller: _managerNameController,
                        labelText: t(context, 'Manager Name'),
                        hintText: t(context, 'Enter manager name'),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _managerPhoneController,
                              labelText: t(context, 'Manager Phone'),
                              hintText: t(context, 'Enter manager phone'),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _managerEmailController,
                              labelText: t(context, 'Manager Email'),
                              hintText: t(context, 'Enter manager email'),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Status Section
                      _buildSectionHeader(t(context, 'Status')),
                      const SizedBox(height: 12),
                      
                      SwitchListTile(
                        title: Text(t(context, 'Active Store')),
                        subtitle: Text(t(context, 'Store is currently operational')),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Action Buttons
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(t(context, 'Cancel')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createStore,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t(context, 'Create Store')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Future<void> _createStore() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final storeData = {
        'name': _nameController.text.trim(),
        'store_code': _storeCodeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country': 'Nigeria',
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'manager_name': _managerNameController.text.trim(),
        'manager_phone': _managerPhoneController.text.trim(),
        'manager_email': _managerEmailController.text.trim(),
        'store_type': _selectedStoreType,
        'capacity': _capacityController.text.trim().isEmpty ? 0 : int.tryParse(_capacityController.text.trim()) ?? 0,
        'is_active': _isActive,
      };

      final createdStore = await _apiService.createStore(storeData);
      
      if (mounted) {
        Navigator.of(context).pop();
        // Use a post-frame callback to ensure the widget is still mounted
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onStoreCreated(createdStore);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SuccessUtils.showOperationError(context, 'create store', e.toString());
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

// Create Assignment Dialog Widget
class CreateAssignmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> businesses;
  final VoidCallback onAssignmentCreated;

  const CreateAssignmentDialog({
    super.key,
    required this.stores,
    required this.businesses,
    required this.onAssignmentCreated,
  });

  @override
  State<CreateAssignmentDialog> createState() => _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends State<CreateAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _selectedStore;
  Map<String, dynamic>? _selectedBusiness;
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.assignment, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t(context, 'Assign Store to Business'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Store Selection
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedStore,
                    decoration: InputDecoration(
                      labelText: t(context, 'Select Store'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: widget.stores.map((store) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: store,
                        child: Text('${store['name']} (${store['store_code']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStore = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return t(context, 'Please select a store');
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Business Selection
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedBusiness,
                    decoration: InputDecoration(
                      labelText: t(context, 'Select Business'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: widget.businesses.map((business) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: business,
                        child: Text('${business['name']} (${business['business_code']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBusiness = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return t(context, 'Please select a business');
                      }
                      return null;
                    },
                  ),
                ],
              ),
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
                  onPressed: _isLoading ? null : _createAssignment,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t(context, 'Assign')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAssignment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.assignBusinessToStore(
        _selectedStore!['id'],
        _selectedBusiness!['id'],
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        SuccessUtils.showBusinessSuccess(
          context,
          'Store "${_selectedStore!['name']}" assigned to business "${_selectedBusiness!['name']}" successfully',
        );
        widget.onAssignmentCreated();
      }
    } catch (e) {
      if (mounted) {
        SuccessUtils.showOperationError(context, 'create assignment', e.toString());
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
