import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/models/sale.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/widgets/branded_header.dart';

class SalesManagementScreen extends StatefulWidget {
  const SalesManagementScreen({super.key});

  @override
  State<SalesManagementScreen> createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> {
  final ApiService _apiService = ApiService();
  
  List<Sale> _sales = [];
  Map<int, List<Map<String, dynamic>>> _saleItems = {}; // Store sale items for each sale
  bool _isLoading = true;
  String? _error;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _selectedStatus = 'all';
  String? _selectedPaymentMethod = 'all';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sales = await _apiService.getSales();
      // Sort sales by most recent first
      sales.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1900);
        final bDate = b.createdAt ?? DateTime(1900);
        return bDate.compareTo(aDate); // Most recent first
      });
      
      // Load sale items for each sale
      final saleItemsMap = <int, List<Map<String, dynamic>>>{};
      for (final sale in sales) {
        if (sale.id != null) {
          try {
            final items = await _apiService.getSaleItems(sale.id!);
            saleItemsMap[sale.id!] = items;
          } catch (e) {
            print('Error loading items for sale ${sale.id}: $e');
            saleItemsMap[sale.id!] = [];
          }
        }
      }
      
      setState(() {
        _sales = sales;
        _saleItems = saleItemsMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelSale(Sale sale) async {
    final reason = await _showCancellationDialog(sale);
    if (reason == null) return;

    // Check if sale ID exists
    if (sale.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Sale ID is missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _apiService.cancelSale(sale.id!, reason);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'Sale cancelled successfully')),
          backgroundColor: Colors.green,
        ),
      );
      _loadSales(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling sale: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showCancellationDialog(Sale sale) async {
    final reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('Cancel Sale #${sale.id ?? 'Unknown'}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sale details being cancelled
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sale Details:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Amount: \$${(sale.totalAmount ?? 0.0).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[600],
                    ),
                  ),
                  Text(
                    'Payment: ${_formatPaymentMethod(sale.paymentMethod)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[600],
                    ),
                  ),
                  Text(
                    'Date: ${_formatDate(sale.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Info about what will happen
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action will restore product stock and process refunds if applicable.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please provide a reason for cancelling this sale:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Cancellation Reason',
                hintText: 'e.g., Customer request, Wrong item, etc.',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit, color: Colors.grey[600]),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: Text(t(context, 'Confirm Cancellation')),
          ),
        ],
      ),
    );
  }

  List<Sale> get _filteredSales {
    return _sales.where((sale) {
      // Status filter
      if (_selectedStatus != null && _selectedStatus != 'all') {
        if (sale.status != _selectedStatus) return false;
      }
      
      // Payment method filter
      if (_selectedPaymentMethod != null && _selectedPaymentMethod != 'all') {
        if (sale.paymentMethod != _selectedPaymentMethod) return false;
      }
      
      // Date filter
      if (_filterStartDate != null || _filterEndDate != null) {
        final saleDate = sale.createdAt;
        if (saleDate == null) return false;
        
        if (_filterStartDate != null && saleDate.isBefore(_filterStartDate!)) {
          return false;
        }
        if (_filterEndDate != null && saleDate.isAfter(_filterEndDate!)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallMobile = size.width <= 360;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    final isDesktop = size.width > 1024;
    final isLargeDesktop = size.width > 1440;
    final user = context.read<AuthProvider>().user;
    
    // Check if user can access sales management
    if (user == null || (user.role != 'admin' && user.role != 'manager' && user.role != 'cashier')) {
      return Scaffold(
        appBar: AppBar(title: Text(t(context, 'Access Denied'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                t(context, 'You do not have permission to access Sales Management'),
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.receipt, size: isSmallMobile ? 20 : (isMobile ? 24 : 28)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t(context, 'Sales Management'),
                style: TextStyle(
                  fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (!isSmallMobile) ...[
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showAdvancedFilters(),
              tooltip: t(context, 'Advanced Filters'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
            tooltip: t(context, 'Refresh'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          left: isSmallMobile ? 8 : (isMobile ? 12 : 16),
          right: isSmallMobile ? 8 : (isMobile ? 12 : 16),
          bottom: isSmallMobile ? 8 : (isMobile ? 12 : 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards - Scrollable within main scroll
            _buildSummaryCards(isSmallMobile, isMobile, isTablet, isDesktop, isLargeDesktop),
            
            SizedBox(height: isSmallMobile ? 12 : (isMobile ? 16 : 24)),
            
            // Filters - Scrollable within main scroll
            _buildFilters(isSmallMobile, isMobile, isTablet, isDesktop),
            
            SizedBox(height: isSmallMobile ? 12 : (isMobile ? 16 : 24)),
            
            // Sales List - Scrollable within main scroll
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _filteredSales.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(t(context, 'No sales found')),
                              ],
                            ),
                          )
                        : _buildSalesList(isSmallMobile, isMobile, isTablet, isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isSmallMobile, bool isMobile, bool isTablet, bool isDesktop, bool isLargeDesktop) {
    final totalSales = _sales.length;
    final completedSales = _sales.where((s) => s.status == 'completed').length;
    final cancelledSales = _sales.where((s) => s.status == 'cancelled').length;
    final creditSales = _sales.where((s) => s.status == 'unpaid').length;
    
    // Truly responsive grid layout
    int crossAxisCount;
    
    if (isSmallMobile) {
      crossAxisCount = 2; // 2 columns on very small screens
    } else if (isMobile) {
      crossAxisCount = 2; // 2 columns on mobile
    } else if (isTablet) {
      crossAxisCount = 3; // 3 columns on tablet for better balance
    } else if (isDesktop) {
      crossAxisCount = 4; // 4 columns on desktop
    } else {
      crossAxisCount = 4; // 4 columns on large desktop
    }
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 14 : 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Overview',
              style: TextStyle(
                fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallMobile ? 12 : 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isSmallMobile ? 2 : (isMobile ? 4 : 8),
              mainAxisSpacing: isSmallMobile ? 2 : (isMobile ? 4 : 8),
              children: [
                _buildSummaryCard('Total', totalSales.toString(), Icons.receipt, Colors.blue, isSmallMobile, isMobile),
                _buildSummaryCard('Completed', completedSales.toString(), Icons.check_circle, Colors.green, isSmallMobile, isMobile),
                _buildSummaryCard('Credit', creditSales.toString(), Icons.credit_card, Colors.orange, isSmallMobile, isMobile),
                _buildSummaryCard('Cancelled', cancelledSales.toString(), Icons.cancel, Colors.red, isSmallMobile, isMobile),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isSmallMobile, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes based on available space
        final cardWidth = constraints.maxWidth;
        final cardHeight = constraints.maxHeight;
        
        // Responsive padding based on card size
        final padding = cardWidth < 100 ? 4.0 : (cardWidth < 150 ? 6.0 : 8.0);
        
        // Responsive icon size based on card size
        final iconSize = cardWidth < 100 ? 16.0 : (cardWidth < 150 ? 20.0 : 24.0);
        
        // Responsive font sizes based on card size
        final valueFontSize = cardWidth < 100 ? 12.0 : (cardWidth < 150 ? 14.0 : 16.0);
        final titleFontSize = cardWidth < 100 ? 8.0 : (cardWidth < 150 ? 10.0 : 12.0);
        
        // Responsive spacing based on card size
        final spacing = cardHeight < 80 ? 2.0 : (cardHeight < 120 ? 4.0 : 6.0);
        
        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(padding),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: iconSize),
              SizedBox(height: spacing),
              Text(
                value,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing / 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters(bool isSmallMobile, bool isMobile, bool isTablet, bool isDesktop) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 14 : 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'Filters'),
              style: TextStyle(
                fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallMobile ? 12 : 16),
            
            // Responsive filter layout
            if (isSmallMobile) ...[
              // Stack vertically on very small screens
              Column(
                children: [
                  _buildFilterDropdown(
                    'Status',
                    _selectedStatus ?? 'all',
                    [
                      DropdownMenuItem(value: 'all', child: Text(t(context, 'All Statuses'))),
                      DropdownMenuItem(value: 'completed', child: Text(t(context, 'Completed'))),
                      DropdownMenuItem(value: 'unpaid', child: Text(t(context, 'Unpaid (Credit)'))),
                      DropdownMenuItem(value: 'cancelled', child: Text(t(context, 'Cancelled'))),
                    ],
                    (value) => setState(() => _selectedStatus = value),
                    isSmallMobile,
                    isMobile,
                  ),
                  SizedBox(height: 8),
                  _buildFilterDropdown(
                    'Payment Method',
                    _selectedPaymentMethod ?? 'all',
                    [
                      DropdownMenuItem(value: 'all', child: Text(t(context, 'All Methods'))),
                      DropdownMenuItem(value: 'evc', child: Text(t(context, 'EVC'))),
                      DropdownMenuItem(value: 'edahab', child: Text(t(context, 'Edahab'))),
                      DropdownMenuItem(value: 'merchant', child: Text(t(context, 'Merchant'))),
                      DropdownMenuItem(value: 'credit', child: Text(t(context, 'Credit'))),
                    ],
                    (value) => setState(() => _selectedPaymentMethod = value),
                    isSmallMobile,
                    isMobile,
                  ),
                ],
              ),
            ] else if (isMobile) ...[
              // 2 columns on mobile
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdown(
                      'Status',
                      _selectedStatus ?? 'all',
                      [
                        DropdownMenuItem(value: 'all', child: Text(t(context, 'All Statuses'))),
                        DropdownMenuItem(value: 'completed', child: Text(t(context, 'Completed'))),
                        DropdownMenuItem(value: 'unpaid', child: Text(t(context, 'Unpaid (Credit)'))),
                        DropdownMenuItem(value: 'cancelled', child: Text(t(context, 'Cancelled'))),
                      ],
                      (value) => setState(() => _selectedStatus = value),
                      isSmallMobile,
                      isMobile,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterDropdown(
                      'Payment Method',
                      _selectedPaymentMethod ?? 'all',
                      [
                        DropdownMenuItem(value: 'all', child: Text(t(context, 'All Methods'))),
                        DropdownMenuItem(value: 'evc', child: Text(t(context, 'EVC'))),
                        DropdownMenuItem(value: 'edahab', child: Text(t(context, 'Edahab'))),
                        DropdownMenuItem(value: 'merchant', child: Text(t(context, 'Merchant'))),
                        DropdownMenuItem(value: 'credit', child: Text(t(context, 'Credit'))),
                      ],
                      (value) => setState(() => _selectedPaymentMethod = value),
                      isSmallMobile,
                      isMobile,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // 3+ columns on larger screens
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdown(
                      'Status',
                      _selectedStatus ?? 'all',
                      [
                        DropdownMenuItem(value: 'all', child: Text(t(context, 'All Statuses'))),
                        DropdownMenuItem(value: 'completed', child: Text(t(context, 'Completed'))),
                        DropdownMenuItem(value: 'unpaid', child: Text(t(context, 'Unpaid (Credit)'))),
                        DropdownMenuItem(value: 'cancelled', child: Text(t(context, 'Cancelled'))),
                      ],
                      (value) => setState(() => _selectedStatus = value),
                      isSmallMobile,
                      isMobile,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildFilterDropdown(
                      'Payment Method',
                      _selectedPaymentMethod ?? 'all',
                      [
                        DropdownMenuItem(value: 'all', child: Text(t(context, 'All Methods'))),
                        DropdownMenuItem(value: 'evc', child: Text(t(context, 'EVC'))),
                        DropdownMenuItem(value: 'edahab', child: Text(t(context, 'Edahab'))),
                        DropdownMenuItem(value: 'merchant', child: Text(t(context, 'Merchant'))),
                        DropdownMenuItem(value: 'credit', child: Text(t(context, 'Credit'))),
                      ],
                      (value) => setState(() => _selectedPaymentMethod = value),
                      isSmallMobile,
                      isMobile,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: isSmallMobile ? 4 : (isMobile ? 6 : 8)),
            // Show/Hide Cancelled Sales Toggle
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final fontSize = availableWidth < 200 ? 10.0 : (availableWidth < 300 ? 11.0 : 12.0);
                final padding = availableWidth < 200 ? 4.0 : (availableWidth < 300 ? 6.0 : 8.0);
                
                return Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: Text(
                          t(context, 'Show Cancelled Sales'),
                          style: TextStyle(fontSize: fontSize),
                        ),
                        value: _selectedStatus != 'cancelled' || _selectedStatus == 'all',
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedStatus = 'all';
                            } else {
                              _selectedStatus = 'completed';
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.all(padding),
                        dense: availableWidth < 200,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<DropdownMenuItem<String>> items,
    Function(String?) onChanged,
    bool isSmallMobile,
    bool isMobile,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes based on available space
        final availableWidth = constraints.maxWidth;
        
        // Responsive padding based on available width
        final horizontalPadding = availableWidth < 120 ? 8.0 : (availableWidth < 180 ? 10.0 : 12.0);
        final verticalPadding = availableWidth < 120 ? 8.0 : (availableWidth < 180 ? 10.0 : 12.0);
        
        // Responsive font sizes based on available width
        final labelFontSize = availableWidth < 120 ? 12.0 : (availableWidth < 180 ? 13.0 : 14.0);
        final itemFontSize = availableWidth < 120 ? 11.0 : (availableWidth < 180 ? 12.0 : 13.0);
        
        return DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            labelText: t(context, label),
            border: const OutlineInputBorder(),
            isDense: availableWidth < 120, // Make it dense on small screens
            contentPadding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            labelStyle: TextStyle(fontSize: labelFontSize),
          ),
          items: items.map((item) => DropdownMenuItem<String>(
            value: item.value,
            child: Text(
              item.child.toString().replaceAll('Text("', '').replaceAll('")', ''),
              style: TextStyle(fontSize: itemFontSize),
            ),
          )).toList(),
          onChanged: onChanged,
          style: TextStyle(fontSize: itemFontSize),
          icon: Icon(
            Icons.arrow_drop_down,
            size: availableWidth < 120 ? 16.0 : 20.0,
          ),
        );
      },
    );
  }

  Widget _buildSalesList(bool isSmallMobile, bool isMobile, bool isTablet, bool isDesktop) {
    // Responsive layout based on screen size
    if (isSmallMobile) {
      return _buildSalesCards(isSmallMobile, isMobile); // Always cards on very small screens
    } else if (isMobile) {
      return _buildSalesCards(isSmallMobile, isMobile); // Cards on mobile
    } else if (isTablet) {
      // On tablet, show table but make it more mobile-friendly
      return _buildSalesTable(isSmallMobile, isMobile, isTablet, isDesktop);
    } else {
      // Desktop gets the full table experience
      return _buildSalesTable(isSmallMobile, isMobile, isTablet, isDesktop);
    }
  }

  Widget _buildSalesCards(bool isSmallMobile, bool isMobile) {
    return Column(
      children: List.generate(_filteredSales.length, (index) {
        final sale = _filteredSales[index];
        final canCancel = sale.status == 'completed' || sale.status == 'unpaid';
        
        return Card(
          margin: EdgeInsets.only(bottom: isSmallMobile ? 4 : (isMobile ? 6 : 16)),
          child: ListTile(
            dense: isSmallMobile || isMobile, // Make it dense on mobile
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 8 : (isMobile ? 12 : 16),
              vertical: isSmallMobile ? 4 : (isMobile ? 6 : 8),
            ),
            title: Text(
              'Sale #${sale.id ?? 'Unknown'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 18),
              ),
            ),
             subtitle: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // Sale Amount - Make it prominent but compact
                 Container(
                   padding: EdgeInsets.symmetric(
                     horizontal: isSmallMobile ? 6 : (isMobile ? 8 : 8),
                     vertical: isSmallMobile ? 2 : (isMobile ? 4 : 4),
                   ),
                   decoration: BoxDecoration(
                     color: Colors.blue[50],
                     borderRadius: BorderRadius.circular(4),
                     border: Border.all(color: Colors.blue[200]!),
                   ),
                   child: Text(
                     'Total Amount: \$${(sale.totalAmount ?? 0.0).toStringAsFixed(2)}',
                     style: TextStyle(
                       fontSize: isSmallMobile ? 11 : (isMobile ? 13 : 15),
                       fontWeight: FontWeight.bold,
                       color: Colors.blue[700],
                     ),
                   ),
                 ),
                 SizedBox(height: isSmallMobile ? 3 : (isMobile ? 4 : 6)),
                 // Status with color coding
                 Row(
                   children: [
                     Container(
                       width: isSmallMobile ? 6 : 8,
                       height: isSmallMobile ? 6 : 8,
                       decoration: BoxDecoration(
                         color: _getStatusColor(sale.status),
                         shape: BoxShape.circle,
                       ),
                     ),
                     SizedBox(width: isSmallMobile ? 4 : 6),
                     Text(
                       'Status: ${sale.status?.toString().toUpperCase() ?? 'UNKNOWN'}',
                       style: TextStyle(
                         fontSize: isSmallMobile ? 9 : (isMobile ? 10 : 12),
                         color: _getStatusColor(sale.status),
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ],
                 ),
                 SizedBox(height: isSmallMobile ? 1 : 2),
                 // Payment method
                 Text(
                   'Payment: ${_formatPaymentMethod(sale.paymentMethod)}',
                   style: TextStyle(
                     fontSize: isSmallMobile ? 9 : (isMobile ? 10 : 12),
                     color: Colors.grey[600],
                   ),
                 ),
                 SizedBox(height: isSmallMobile ? 1 : 2),
                 // Date and time
                 Text(
                   'Date: ${_formatDate(sale.createdAt)}',
                   style: TextStyle(
                     fontSize: isSmallMobile ? 9 : (isMobile ? 10 : 12),
                     color: Colors.grey[600],
                   ),
                 ),
                 SizedBox(height: isSmallMobile ? 2 : 4),
                 // Product details
                 if (_saleItems[sale.id] != null && _saleItems[sale.id]!.isNotEmpty) ...[
                   SizedBox(height: isSmallMobile ? 2 : 4),
                   Container(
                     padding: EdgeInsets.symmetric(
                       horizontal: isSmallMobile ? 6 : (isMobile ? 8 : 8),
                       vertical: isSmallMobile ? 4 : (isMobile ? 6 : 6),
                     ),
                     decoration: BoxDecoration(
                       color: Colors.green[50],
                       borderRadius: BorderRadius.circular(4),
                       border: Border.all(color: Colors.green[200]!),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           'Products Sold:',
                           style: TextStyle(
                             fontSize: isSmallMobile ? 8 : (isMobile ? 9 : 10),
                             fontWeight: FontWeight.bold,
                             color: Colors.green[700],
                           ),
                         ),
                         SizedBox(height: isSmallMobile ? 2 : 4),
                                                   ...(_saleItems[sale.id]!.take(3).map((item) => Text(
                            '• ${item['product_name'] ?? 'Unknown Product'} x${_safeInt(item['quantity'])} @\$${_safeDouble(item['unit_price']).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 7 : (isMobile ? 8 : 9),
                              color: Colors.green[600],
                            ),
                          ))),
                         if (_saleItems[sale.id]!.length > 3) ...[
                           Text(
                             '... and ${_saleItems[sale.id]!.length - 3} more items',
                             style: TextStyle(
                               fontSize: isSmallMobile ? 6 : (isMobile ? 7 : 8),
                               color: Colors.green[500],
                               fontStyle: FontStyle.italic,
                             ),
                           ),
                         ],
                       ],
                     ),
                   ),
                 ],
                                  // Show cancellation details if sale was cancelled
                 if (sale.status == 'cancelled') ...[
                  SizedBox(height: isSmallMobile ? 2 : 4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallMobile ? 6 : (isMobile ? 8 : 8),
                      vertical: isSmallMobile ? 2 : (isMobile ? 2 : 2),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                     child: Text(
                       'Cancelled by: ${sale.cancelledByName ?? 'Unknown'}',
                       style: TextStyle(
                         fontSize: isSmallMobile ? 8 : (isMobile ? 9 : 10),
                         color: Colors.red[700],
                         fontWeight: FontWeight.w500,
                       ),
                     ),
                   ),
                   if (sale.cancellationReason != null) ...[
                     SizedBox(height: isSmallMobile ? 1 : 2),
                     Text(
                       'Reason: ${sale.cancellationReason}',
                       style: TextStyle(
                         fontSize: isSmallMobile ? 8 : (isMobile ? 9 : 10),
                         color: Colors.red[600],
                         fontStyle: FontStyle.italic,
                       ),
                     ),
                   ],
                   if (sale.cancelledAt != null) ...[
                     SizedBox(height: isSmallMobile ? 1 : 2),
                     Text(
                       'Cancelled: ${_formatDate(sale.cancelledAt)}',
                       style: TextStyle(
                         fontSize: isSmallMobile ? 8 : (isMobile ? 9 : 10),
                         color: Colors.red[600],
                       ),
                     ),
                   ],
                ],
               ],
             ),
             trailing: canCancel
                 ? IconButton(
                     icon: const Icon(Icons.cancel, color: Colors.red),
                     onPressed: () => _cancelSale(sale),
                     tooltip: t(context, 'Cancel Sale'),
                   )
                 : sale.status == 'cancelled'
                     ? const Icon(Icons.cancel, color: Colors.grey)
                     : null,
           ),
         );
       }),
     );
   }

  Widget _buildSalesTable(bool isSmallMobile, bool isMobile, bool isTablet, bool isDesktop) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: isTablet ? 12 : (isDesktop ? 20 : 24),
        dataRowHeight: isTablet ? 56 : (isDesktop ? 68 : 72),
        headingRowHeight: isTablet ? 48 : (isDesktop ? 60 : 64),
        columns: [
          DataColumn(
            label: Text(
              'Sale ID',
              style: TextStyle(
                fontSize: isTablet ? 12 : (isDesktop ? 14 : 16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Amount',
              style: TextStyle(
                fontSize: isTablet ? 12 : (isDesktop ? 14 : 16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Status',
              style: TextStyle(
                fontSize: isTablet ? 12 : (isDesktop ? 14 : 16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Payment',
              style: TextStyle(
                fontSize: isTablet ? 12 : (isDesktop ? 14 : 16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Date',
              style: TextStyle(
                fontSize: isTablet ? 12 : (isDesktop ? 14 : 16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Actions',
              style: TextStyle(
                fontSize: isTablet ? 12 : (isDesktop ? 14 : 16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        rows: _filteredSales.map((sale) {
          final canCancel = sale.status == 'completed' || sale.status == 'unpaid';
          
          return DataRow(
            cells: [
              DataCell(
                Text(
                  '#${sale.id ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: isTablet ? 13 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    '\$${(sale.totalAmount ?? 0.0).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isTablet ? 13 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(sale.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sale.status?.toString().toUpperCase() ?? 'UNKNOWN',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 14,
                        color: _getStatusColor(sale.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Text(
                  _formatPaymentMethod(sale.paymentMethod),
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              DataCell(
                Text(
                  _formatDate(sale.createdAt),
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              DataCell(
                canCancel
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _cancelSale(sale),
                        tooltip: t(context, 'Cancel Sale'),
                      )
                    : sale.status == 'cancelled'
                        ? const Icon(Icons.cancel, color: Colors.grey)
                        : const SizedBox.shrink(),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'unpaid':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatPaymentMethod(String? method) {
    if (method == null) return 'UNKNOWN';
    switch (method.toLowerCase()) {
      case 'evc':
        return 'EVC (Electronic Voucher)';
      case 'edahab':
        return 'Edahab (Mobile Money)';
      case 'merchant':
        return 'Merchant Services';
      case 'credit':
        return 'Credit (Unpaid)';
      default:
        return method.toUpperCase();
    }
  }

  // Safe type conversion helpers
  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _showAdvancedFilters() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'Advanced Filters')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Date range picker
            ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(t(context, 'Date Range')),
              subtitle: Text(
                _filterStartDate != null && _filterEndDate != null
                    ? '${_formatDate(_filterStartDate)} - ${_formatDate(_filterEndDate)}'
                    : 'No date filter',
              ),
              onTap: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _filterStartDate != null && _filterEndDate != null
                      ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
                      : null,
                );
                if (picked != null) {
                  setState(() {
                    _filterStartDate = picked.start;
                    _filterEndDate = picked.end;
                  });
                }
              },
            ),
            // Clear filters button
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: Text(t(context, 'Clear All Filters')),
              onTap: () {
                setState(() {
                  _filterStartDate = null;
                  _filterEndDate = null;
                  _selectedStatus = 'all';
                  _selectedPaymentMethod = 'all';
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t(context, 'Close')),
          ),
        ],
      ),
    );
  }
}
