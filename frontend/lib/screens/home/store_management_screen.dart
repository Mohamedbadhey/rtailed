import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/success_utils.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:retail_management/screens/home/store_inventory_screen.dart';
import 'package:retail_management/screens/home/enhanced_assignment_dialogs.dart';
import 'package:retail_management/screens/home/store_business_dialog.dart';
import 'package:retail_management/widgets/custom_text_field.dart';
import 'package:retail_management/models/product.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:retail_management/utils/api.dart';
import 'package:retail_management/utils/responsive_utils.dart';

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
      appBar: AppBar(
        title: Text(t(context, 'Store Management')),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
              isScrollable: ResponsiveUtils.isMobile(context),
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 11, tablet: 13, desktop: 15),
                fontWeight: FontWeight.w400,
              ),
              tabs: [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.isMobile(context) ? 8 : 16,
                      vertical: ResponsiveUtils.isMobile(context) ? 4 : 8,
                    ),
                    child: Text(t(context, 'Stores')),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.isMobile(context) ? 8 : 16,
                      vertical: ResponsiveUtils.isMobile(context) ? 4 : 8,
                    ),
                    child: Text(t(context, 'Transfers')),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.isMobile(context) ? 8 : 16,
                      vertical: ResponsiveUtils.isMobile(context) ? 4 : 8,
                    ),
                    child: Text(t(context, 'Inventory')),
                  ),
                ),
                if (isSuperAdmin) Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.isMobile(context) ? 8 : 16,
                      vertical: ResponsiveUtils.isMobile(context) ? 4 : 8,
                    ),
                    child: Text(t(context, 'Assignments')),
                  ),
                ),
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
        return _buildStoreCardForStoresTab(store);
      },
    );
  }

  Widget _buildStoreCardForStoresTab(Map<String, dynamic> store) {
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

  String _formatTimestamp(String timestamp) {
    try {
      if (timestamp.isEmpty) return '';
      
      // Parse the timestamp and convert to local time
      final dateTime = DateTime.parse(timestamp);
      final localDateTime = dateTime.toLocal();
      
      // Format: "2025-08-27 19:15:33" (same as inventory screen)
      return '${localDateTime.year}-${localDateTime.month.toString().padLeft(2, '0')}-${localDateTime.day.toString().padLeft(2, '0')} ${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}:${localDateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      // Fallback to original timestamp if parsing fails
      return timestamp;
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
              t(context, 'Error loading inventory'),
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
        // Header
        Container(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: ResponsiveUtils.isMobile(context) 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'Store Inventory Management'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 18, tablet: 20, desktop: 22),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showCategoryManagementDialog,
                          icon: const Icon(Icons.category, size: 18),
                          label: Text(
                            t(context, 'Manage Categories'),
                            style: TextStyle(fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showAddProductsDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            t(context, 'Add Products'),
                            style: TextStyle(fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16)),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      t(context, 'Store Inventory Management'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 18, tablet: 20, desktop: 22),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showCategoryManagementDialog,
                        icon: const Icon(Icons.category),
                        label: Text(t(context, 'Manage Categories')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _showAddProductsDialog,
                        icon: const Icon(Icons.add),
                        label: Text(t(context, 'Add Products')),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
    if (_stores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              t(context, 'No stores found'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              t(context, 'Create stores first to manage inventory'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveUtils.getResponsivePadding(context),
      itemCount: _stores.length,
      itemBuilder: (context, index) {
        final store = _stores[index];
        return _buildStoreInventoryCard(store);
      },
    );
  }

  Widget _buildStoreInventoryCard(Map<String, dynamic> store) {
    return Card(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
        left: ResponsiveUtils.isMobile(context) ? 0 : 4,
        right: ResponsiveUtils.isMobile(context) ? 0 : 4,
      ),
      child: ListTile(
        contentPadding: ResponsiveUtils.getResponsivePadding(context).copyWith(
          left: ResponsiveUtils.getResponsivePadding(context).left,
          right: ResponsiveUtils.getResponsivePadding(context).right,
        ),
        leading: CircleAvatar(
          radius: ResponsiveUtils.isMobile(context) ? 20 : 24,
          backgroundColor: Theme.of(context).primaryColor,
          child: Icon(
            Icons.store,
            color: Colors.white,
            size: ResponsiveUtils.isMobile(context) ? 20 : 24,
          ),
        ),
        title: Text(
          store['name'] ?? '',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 18),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t(context, 'Store Code')}: ${store['store_code'] ?? ''}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
              ),
            ),
            Text(
              '${t(context, 'Type')}: ${store['store_type'] ?? ''}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
              ),
            ),
            Text(
              '${t(context, 'Status')}: ${store['is_active'] == 1 ? t(context, 'Active') : t(context, 'Inactive')}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
              ),
            ),
          ],
        ),
        trailing: ResponsiveUtils.isMobile(context)
          ? IconButton(
              onPressed: () => _navigateToStoreInventory(store),
              icon: Icon(
                Icons.arrow_forward_ios,
                size: 16,
              ),
            )
          : ElevatedButton(
              onPressed: () => _navigateToStoreInventory(store),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.3,
                ),
              ),
              child: Text(
                t(context, 'Manage'),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
                ),
              ),
            ),
        onTap: () => _navigateToStoreInventory(store),
      ),
    );
  }

  void _navigateToStoreInventory(Map<String, dynamic> store) {
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

  void _showAddProductsDialog() {
    // For now, show a simple dialog to select a store
    if (_stores.isEmpty) {
      SuccessUtils.showOperationError(context, 'add products', 'No stores available');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.store,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t(context, 'Select Store'),
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
                const SizedBox(height: 24),

                // Store List
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _stores.length,
                    itemBuilder: (context, index) {
                      final store = _stores[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.store,
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(store['name'] ?? 'Store ${store['id']}'),
                          subtitle: Text(store['address'] ?? 'No address'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.of(context).pop(); // Close dialog
                            // Call the exact same add product dialog from inventory screen
                            _showAddProductDialog();
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Cancel Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t(context, 'Cancel')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCategoryManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => _CategoryManagementDialog(
        apiService: _apiService,
        onCategoryChanged: () {
          // Refresh data if needed
          _loadData();
        },
      ),
    );
  }

  void _showAddProductDialog() {
    // First show store selection dialog
    if (_stores.isEmpty) {
      SuccessUtils.showOperationError(context, 'add products', 'No stores available');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.store,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t(context, 'Select Store for Product'),
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
                const SizedBox(height: 24),

                // Store List
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _stores.length,
                    itemBuilder: (context, index) {
                      final store = _stores[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.store,
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(store['name'] ?? 'Store ${store['id']}'),
                          subtitle: Text(store['address'] ?? 'No address'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.of(context).pop(); // Close store selection
                            _showProductDialogForStore(store['id'], store['name']);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Cancel Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t(context, 'Cancel')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProductDialogForStore(int storeId, String storeName) {
    showDialog(
      context: context,
      builder: (context) => _ProductDialog(
        apiService: _apiService,
                  onSave: (productData, imageFile, {webImageBytes, webImageName}) async {
                    try {
                      // Add storeId to productData so it gets added to store inventory immediately
                      productData['storeId'] = storeId;
                      
                      // Create the product (it will automatically be added to store inventory)
                      final product = await _apiService.createProduct(productData, imageFile: imageFile, webImageBytes: webImageBytes, webImageName: webImageName);
                      
                      _loadData();
                      if (mounted) {
                        Navigator.of(context).pop();
                        SuccessUtils.showProductSuccess(context, 'added to $storeName warehouse');
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
        // Simple Header
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
                onPressed: _showAssignmentHistoryDialog,
                icon: const Icon(Icons.history),
                label: Text(t(context, 'History')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
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
    if (_stores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              t(context, 'No stores found'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              t(context, 'Create stores first to manage assignments'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stores.length,
      itemBuilder: (context, index) {
        final store = _stores[index];
        return _buildStoreCard(store);
      },
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    // Count assigned businesses for this store
    final storeId = store['id'];
    final storeIdType = storeId.runtimeType;
    
    print('=== DEBUGGING STORE ASSIGNMENTS ===');
    print('Store: ${store['name']} (ID: $storeId, type: $storeIdType)');
    print('Total assignments loaded: ${_assignments.length}');
    
    // Check each assignment for this store
    for (var assignment in _assignments) {
      final assignmentStoreId = assignment['store_id'];
      final assignmentStoreIdType = assignmentStoreId.runtimeType;
      final isActive = assignment['is_active'];
      
      print('Assignment: store_id=$assignmentStoreId (type: $assignmentStoreIdType), is_active=$isActive');
      
      if (assignmentStoreId == storeId) {
        print('  -> MATCH FOUND for store ${store['name']}!');
      }
    }
    
    final assignedBusinessCount = _assignments.where((assignment) => 
      assignment['store_id'] == store['id'] && 
      (assignment['is_active'] == true || assignment['is_active'] == 1 || assignment['is_active'] == '1')
    ).length;
    
    print('Final count for ${store['name']}: $assignedBusinessCount');
    print('=====================================');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.store, color: Colors.white),
        ),
        title: Text(
          store['name'] ?? '',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t(context, 'Code')}: ${store['store_code'] ?? ''}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.business, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '$assignedBusinessCount ${t(context, 'businesses assigned')}',
                  style: TextStyle(
                    color: assignedBusinessCount > 0 ? Colors.green : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assignedBusinessCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$assignedBusinessCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
        onTap: () => _showStoreBusinessDialog(store),
      ),
    );
  }

  Future<void> _loadAssignments() async {
    try {
      print('=== LOADING ASSIGNMENTS ===');
      print('Stores loaded: ${_stores.length}');
      if (_stores.isNotEmpty) {
        print('Sample store: ${_stores[0]}');
      }
      
      // Use the dedicated assignments endpoint that returns complete assignment data
      final allAssignments = await _apiService.getAllStoreBusinessAssignments();
      
      setState(() {
        _assignments = allAssignments;
      });
      
      print('Loaded ${allAssignments.length} assignments from backend');
      if (allAssignments.isNotEmpty) {
        print('Sample assignment: ${allAssignments[0]}');
        print('Assignment keys: ${allAssignments[0].keys.toList()}');
        
        // Check each assignment in detail
        for (int i = 0; i < allAssignments.length; i++) {
          final assignment = allAssignments[i];
          print('Assignment $i: store_id=${assignment['store_id']} (${assignment['store_id'].runtimeType}), business_id=${assignment['business_id']} (${assignment['business_id'].runtimeType}), is_active=${assignment['is_active']} (${assignment['is_active'].runtimeType})');
        }
      } else {
        print('NO ASSIGNMENTS FOUND! This is the problem.');
      }
      print('===========================');
    } catch (e) {
      print('Error loading assignments: $e');
      print('Error type: ${e.runtimeType}');
      // Don't set error state for assignments, just log it
    }
  }

  bool _isStoreAssignedToBusiness(int storeId, int businessId) {
    // Check if this store-business combination exists in the assignments
    return _assignments.any((assignment) => 
      assignment['store_id'] == storeId && 
      assignment['business_id'] == businessId &&
      (assignment['is_active'] == true || assignment['is_active'] == 1 || assignment['is_active'] == '1')
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

  // =====================================================
  // ENHANCED SUPERADMIN ASSIGNMENT METHODS
  // =====================================================

  void _showBulkAssignmentDialog() {
    showDialog(
      context: context,
      builder: (context) => BulkAssignmentDialog(
        stores: _stores,
        businesses: _businesses,
        onAssignmentsCreated: () async {
          await _loadAssignments();
          setState(() {});
        },
      ),
    );
  }

  void _showResetStoreDialog() {
    showDialog(
      context: context,
      builder: (context) => ResetStoreDialog(
        stores: _stores,
        onStoreReset: () async {
          await _loadAssignments();
          setState(() {});
        },
      ),
    );
  }

  void _showAssignmentHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AssignmentHistoryDialog(),
    );
  }

  void _showAssignmentDetailsDialog(Map<String, dynamic> store, Map<String, dynamic> business) {
    showDialog(
      context: context,
      builder: (context) => AssignmentDetailsDialog(
        store: store,
        business: business,
        onAssignmentUpdated: () async {
          await _loadAssignments();
          setState(() {});
        },
      ),
    );
  }

  void _showQuickAssignDialog(Map<String, dynamic> store, Map<String, dynamic> business) {
    showDialog(
      context: context,
      builder: (context) => QuickAssignDialog(
        store: store,
        business: business,
        onAssignmentCreated: () async {
          await _loadAssignments();
          setState(() {});
        },
      ),
    );
  }

  void _showStoreBusinessDialog(Map<String, dynamic> store) {
    showDialog(
      context: context,
      builder: (context) => StoreBusinessDialog(
        store: store,
        businesses: _businesses,
        assignments: _assignments,
        onAssignmentChanged: () async {
          await _loadAssignments();
          setState(() {});
        },
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
  
  // Product name validation
  bool _isCheckingName = false;
  bool _isNameAvailable = true;
  bool _isNameTaken = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.product != null) {
      // Initialize name validation state for editing
      _isNameAvailable = true;
      _isNameTaken = false;
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

  Future<void> _checkProductName(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _isCheckingName = false;
        _isNameAvailable = true;
        _isNameTaken = false;
      });
      return;
    }

    setState(() {
      _isCheckingName = true;
    });

    try {
      final response = await ApiService.postStatic('/api/products/check-name', {
        'name': value.trim(),
        'exclude_id': widget.product?.id
      });

      if (mounted) {
        setState(() {
          _isCheckingName = false;
          _isNameAvailable = response['available'];
          _isNameTaken = !response['available'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingName = false;
          _isNameAvailable = true;
          _isNameTaken = false;
        });
      }
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

    // Check if name is taken
    if (_isNameTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'Product name already exists')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
                          suffixIcon: _isCheckingName
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                                  ),
                                )
                              : _isNameTaken
                                  ? Icon(
                                      Icons.error,
                                      color: Colors.red,
                                      size: 20,
                                    )
                                  : _isNameAvailable && _nameController.text.isNotEmpty
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 20,
                                        )
                                      : null,
                        ),
                        onChanged: (value) {
                          // Debounce the API call
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (_nameController.text == value) {
                              _checkProductName(value);
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t(context, 'Product name is required');
                          }
                          if (_isNameTaken) {
                            return t(context, 'Product name already exists');
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
                        onChanged: (value) {
                          // Trigger validation of cost field when price changes
                          if (_costController.text.isNotEmpty) {
                            _formKey.currentState?.validate();
                          }
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t(context, 'Price is required');
                          }
                          if (double.tryParse(value) == null) {
                            return t(context, 'Please enter a valid number');
                          }
                          // Check if price is less than cost
                          final price = double.tryParse(value);
                          final cost = double.tryParse(_costController.text);
                          if (price != null && cost != null && price < cost) {
                            return t(context, 'Price cannot be less than cost');
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
                        onChanged: (value) {
                          // Trigger validation of price field when cost changes
                          if (_priceController.text.isNotEmpty) {
                            _formKey.currentState?.validate();
                          }
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t(context, 'Cost is required');
                          }
                          if (double.tryParse(value) == null) {
                            return t(context, 'Please enter a valid number');
                          }
                          // Check if cost is greater than price
                          final cost = double.tryParse(value);
                          final price = double.tryParse(_priceController.text);
                          if (cost != null && price != null && cost > price) {
                            return t(context, 'Cost cannot be greater than price');
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
                                suffixIcon: _isCheckingName
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                                        ),
                                      )
                                    : _isNameTaken
                                        ? Icon(
                                            Icons.error,
                                            color: Colors.red,
                                            size: 20,
                                          )
                                        : _isNameAvailable && _nameController.text.isNotEmpty
                                            ? Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 20,
                                              )
                                            : null,
                              ),
                              onChanged: (value) {
                                // Debounce the API call
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  if (_nameController.text == value) {
                                    _checkProductName(value);
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return t(context, 'Product name is required');
                                }
                                if (_isNameTaken) {
                                  return t(context, 'Product name already exists');
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
                              onChanged: (value) {
                                // Trigger validation of cost field when price changes
                                if (_costController.text.isNotEmpty) {
                                  _formKey.currentState?.validate();
                                }
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return t(context, 'Price is required');
                                }
                                if (double.tryParse(value) == null) {
                                  return t(context, 'Please enter a valid number');
                                }
                                // Check if price is less than cost
                                final price = double.tryParse(value);
                                final cost = double.tryParse(_costController.text);
                                if (price != null && cost != null && price < cost) {
                                  return t(context, 'Price cannot be less than cost');
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
                              onChanged: (value) {
                                // Trigger validation of price field when cost changes
                                if (_priceController.text.isNotEmpty) {
                                  _formKey.currentState?.validate();
                                }
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return t(context, 'Cost is required');
                                }
                                if (double.tryParse(value) == null) {
                                  return t(context, 'Please enter a valid number');
                                }
                                // Check if cost is greater than price
                                final cost = double.tryParse(value);
                                final price = double.tryParse(_priceController.text);
                                if (cost != null && price != null && cost > price) {
                                  return t(context, 'Cost cannot be greater than price');
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

class _CategoryManagementDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onCategoryChanged;

  const _CategoryManagementDialog({
    required this.apiService,
    required this.onCategoryChanged,
  });

  @override
  State<_CategoryManagementDialog> createState() => _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends State<_CategoryManagementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _editingCategory;
  bool _isAddingNew = true;
  bool _isCheckingName = false;
  bool _isNameAvailable = true;
  bool _isNameTaken = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    // Initialize validation state for editing
    if (_editingCategory != null) {
      _isNameAvailable = true;
      _isNameTaken = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.apiService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load categories', e.toString());
      }
    }
  }

  Future<void> _checkCategoryName(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _isCheckingName = false;
        _isNameAvailable = true;
        _isNameTaken = false;
      });
      return;
    }

    setState(() {
      _isCheckingName = true;
    });

    try {
      final response = await ApiService.postStatic('/api/categories/check-name', {
        'name': value.trim(),
        'exclude_id': _editingCategory?['id']
      });

      if (mounted) {
        setState(() {
          _isCheckingName = false;
          _isNameAvailable = response['available'];
          _isNameTaken = !response['available'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingName = false;
          _isNameAvailable = true;
          _isNameTaken = false;
        });
      }
    }
  }

  void _showAddForm() {
    setState(() {
      _isAddingNew = true;
      _editingCategory = null;
      _nameController.clear();
      _descriptionController.clear();
    });
  }

  void _showEditForm(Map<String, dynamic> category) {
    setState(() {
      _isAddingNew = false;
      _editingCategory = category;
      _nameController.text = category['name'] ?? '';
      _descriptionController.text = category['description'] ?? '';
      _isNameAvailable = true;
      _isNameTaken = false;
    });
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if name is taken
    if (_isNameTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'Category name already exists')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isAddingNew) {
        await widget.apiService.createCategory({
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
        });
        if (mounted) {
          SuccessUtils.showSuccessTick(context, 'Category created successfully!');
        }
      } else {
        await widget.apiService.updateCategory(
          _editingCategory!['id'],
          {
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
          },
        );
        if (mounted) {
          SuccessUtils.showSuccessTick(context, 'Category updated successfully!');
        }
      }

      await _loadCategories();
      widget.onCategoryChanged();
      _showAddForm(); // Reset form
    } catch (e) {
      if (mounted) {
        SuccessUtils.showOperationError(context, 'save category', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCategory(int categoryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'Delete Category')),
        content: Text(t(context, 'Are you sure you want to delete this category? This action cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t(context, 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await widget.apiService.deleteCategory(categoryId);
        if (mounted) {
          SuccessUtils.showSuccessTick(context, 'Category deleted successfully!');
        }
        await _loadCategories();
        widget.onCategoryChanged();
      } catch (e) {
        if (mounted) {
          SuccessUtils.showOperationError(context, 'delete category', e.toString());
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

  Widget _buildCategoriesList() {
    return _categories.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  t(context, 'No categories found'),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'Add your first category'),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          )
        : ListView.builder(
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return ListTile(
                title: Text(
                  category['name'] ?? '',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 18),
                  ),
                ),
                subtitle: Text(
                  category['description'] ?? '',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditForm(category);
                    } else if (value == 'delete') {
                      _deleteCategory(category['id']);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        t(context, 'Edit'),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        t(context, 'Delete'),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () => _showEditForm(category),
              );
            },
          );
  }

  Widget _buildCategoryForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isAddingNew ? t(context, 'Add New Category') : t(context, 'Edit Category'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16, tablet: 18, desktop: 20),
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
          
          // Name Field
          CustomTextField(
            controller: _nameController,
            labelText: t(context, 'Category Name'),
            onChanged: (value) {
              // Debounce the API call
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_nameController.text == value) {
                  _checkCategoryName(value);
                }
              });
            },
            suffixIcon: _isCheckingName
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                    ),
                  )
                : _isNameTaken
                    ? Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 20,
                      )
                    : _isNameAvailable && _nameController.text.isNotEmpty
                        ? Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          )
                        : null,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return t(context, 'Please enter a category name');
              }
              if (_isNameTaken) {
                return t(context, 'Category name already exists');
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
          
          // Description Field
          CustomTextField(
            controller: _descriptionController,
            labelText: t(context, 'Description'),
            maxLines: 3,
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.4,
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _isAddingNew ? t(context, 'Add Category') : t(context, 'Update Category'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    
    return Dialog(
      child: Container(
        width: isMobile 
          ? MediaQuery.of(context).size.width * 0.95
          : MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: isMobile ? 400 : (isTablet ? 700 : 800),
          maxHeight: isMobile ? 600 : 700,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: ResponsiveUtils.getResponsivePadding(context),
              decoration: BoxDecoration(
                color: Colors.purple[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.category, 
                    color: Colors.white,
                    size: isMobile ? 20 : 24,
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Text(
                      t(context, 'Manage Categories'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close, 
                      color: Colors.white,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: isMobile 
                ? Column(
                    children: [
                      // Add Category Button
                      Container(
                        width: double.infinity,
                        padding: ResponsiveUtils.getResponsivePadding(context),
                        child: ElevatedButton.icon(
                          onPressed: _showAddForm,
                          icon: Icon(Icons.add, size: isMobile ? 18 : 20),
                          label: Text(
                            t(context, 'Add Category'),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.4,
                            ),
                          ),
                        ),
                      ),
                      // Categories List
                      Expanded(
                        child: _buildCategoriesList(),
                      ),
                      // Form
                      if (_isAddingNew || _editingCategory != null)
                        Container(
                          height: MediaQuery.of(context).size.height * 0.4,
                          padding: ResponsiveUtils.getResponsivePadding(context),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: _buildCategoryForm(),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      // Categories List
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Add Category Button
                              Container(
                                width: double.infinity,
                                padding: ResponsiveUtils.getResponsivePadding(context),
                                child: ElevatedButton.icon(
                                  onPressed: _showAddForm,
                                  icon: const Icon(Icons.add),
                                  label: Text(t(context, 'Add Category')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple[700],
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.4,
                                    ),
                                  ),
                                ),
                              ),
                          
                              // Categories List
                              Expanded(
                                child: _buildCategoriesList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Form
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: ResponsiveUtils.getResponsivePadding(context),
                          child: _buildCategoryForm(),
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }
} 