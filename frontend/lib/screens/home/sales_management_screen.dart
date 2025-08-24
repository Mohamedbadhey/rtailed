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
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
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
        title: Text(t(context, 'Sales Management')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
            tooltip: t(context, 'Refresh'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          _buildSummaryCards(isSmallMobile, isMobile),
          
          // Filters
          _buildFilters(isSmallMobile, isMobile),
          
          // Sales List
          Expanded(
            child: _isLoading
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
                        : _buildSalesList(isSmallMobile, isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isSmallMobile, bool isMobile) {
    final totalSales = _sales.length;
    final completedSales = _sales.where((s) => s.status == 'completed').length;
    final cancelledSales = _sales.where((s) => s.status == 'cancelled').length;
    final creditSales = _sales.where((s) => s.status == 'unpaid').length;
    
    return Card(
      margin: EdgeInsets.all(isSmallMobile ? 8 : 16),
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'Sales Overview'),
              style: TextStyle(
                fontSize: isSmallMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total',
                    totalSales.toString(),
                    Icons.receipt,
                    Colors.blue,
                    isSmallMobile,
                  ),
                ),
                SizedBox(width: isSmallMobile ? 8 : 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Completed',
                    completedSales.toString(),
                    Icons.check_circle,
                    Colors.green,
                    isSmallMobile,
                  ),
                ),
                SizedBox(width: isSmallMobile ? 8 : 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Credit',
                    creditSales.toString(),
                    Icons.credit_card,
                    Colors.orange,
                    isSmallMobile,
                  ),
                ),
                SizedBox(width: isSmallMobile ? 8 : 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Cancelled',
                    cancelledSales.toString(),
                    Icons.cancel,
                    Colors.red,
                    isSmallMobile,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isSmallMobile) {
    return Container(
      padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isSmallMobile ? 16 : 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallMobile ? 14 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallMobile ? 10 : 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isSmallMobile, bool isMobile) {
    return Card(
      margin: EdgeInsets.all(isSmallMobile ? 8 : 16),
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'Filters'),
              style: TextStyle(
                fontSize: isSmallMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus ?? 'all',
                    decoration: InputDecoration(
                      labelText: t(context, 'Status'),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallMobile ? 8 : 12,
                        vertical: isSmallMobile ? 8 : 12,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text(t(context, 'All Statuses'))),
                      DropdownMenuItem(value: 'completed', child: Text(t(context, 'Completed'))),
                      DropdownMenuItem(value: 'unpaid', child: Text(t(context, 'Unpaid (Credit)'))),
                      DropdownMenuItem(value: 'cancelled', child: Text(t(context, 'Cancelled'))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),
                ),
                SizedBox(width: isSmallMobile ? 8 : 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod ?? 'all',
                    decoration: InputDecoration(
                      labelText: t(context, 'Payment Method'),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallMobile ? 8 : 12,
                        vertical: isSmallMobile ? 8 : 12,
                      ),
                    ),
                                         items: [
                       DropdownMenuItem(value: 'all', child: Text(t(context, 'All Methods'))),
                       DropdownMenuItem(value: 'evc', child: Text(t(context, 'EVC'))),
                       DropdownMenuItem(value: 'edahab', child: Text(t(context, 'Edahab'))),
                       DropdownMenuItem(value: 'merchant', child: Text(t(context, 'Merchant'))),
                       DropdownMenuItem(value: 'credit', child: Text(t(context, 'Credit'))),
                     ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Show/Hide Cancelled Sales Toggle
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      t(context, 'Show Cancelled Sales'),
                      style: TextStyle(
                        fontSize: isSmallMobile ? 12 : 14,
                      ),
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
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList(bool isSmallMobile, bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.all(isSmallMobile ? 8 : 16),
      itemCount: _filteredSales.length,
             itemBuilder: (context, index) {
         final sale = _filteredSales[index];
         final canCancel = sale.status == 'completed' || sale.status == 'unpaid';
        
        return Card(
          margin: EdgeInsets.only(bottom: isSmallMobile ? 8 : 12),
          child: ListTile(
                         title: Text(
               'Sale #${sale.id ?? 'Unknown'}',
               style: TextStyle(
                 fontWeight: FontWeight.bold,
                 fontSize: isSmallMobile ? 14 : 16,
               ),
             ),
             subtitle: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // Sale Amount - Make it prominent
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: Colors.blue[50],
                     borderRadius: BorderRadius.circular(4),
                     border: Border.all(color: Colors.blue[200]!),
                   ),
                   child: Text(
                     'Total Amount: \$${(sale.totalAmount ?? 0.0).toStringAsFixed(2)}',
                     style: TextStyle(
                       fontSize: isSmallMobile ? 13 : 15,
                       fontWeight: FontWeight.bold,
                       color: Colors.blue[700],
                     ),
                   ),
                 ),
                 const SizedBox(height: 6),
                 // Status with color coding
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
                     const SizedBox(width: 6),
                     Text(
                       'Status: ${sale.status?.toString().toUpperCase() ?? 'UNKNOWN'}',
                       style: TextStyle(
                         fontSize: isSmallMobile ? 11 : 12,
                         color: _getStatusColor(sale.status),
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 2),
                 // Payment method
                 Text(
                   'Payment: ${_formatPaymentMethod(sale.paymentMethod)}',
                   style: TextStyle(
                     fontSize: isSmallMobile ? 11 : 12,
                     color: Colors.grey[600],
                   ),
                 ),
                 const SizedBox(height: 2),
                 // Date and time
                 Text(
                   'Date: ${_formatDate(sale.createdAt)}',
                   style: TextStyle(
                     fontSize: isSmallMobile ? 11 : 12,
                     color: Colors.grey[600],
                   ),
                 ),
                 const SizedBox(height: 4),
                 // Product details
                 if (_saleItems[sale.id] != null && _saleItems[sale.id]!.isNotEmpty) ...[
                   const SizedBox(height: 4),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                             fontSize: 10,
                             fontWeight: FontWeight.bold,
                             color: Colors.green[700],
                           ),
                         ),
                         const SizedBox(height: 4),
                                                   ...(_saleItems[sale.id]!.take(3).map((item) => Text(
                            '• ${item['product_name'] ?? 'Unknown Product'} x${_safeInt(item['quantity'])} @\$${_safeDouble(item['unit_price']).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.green[600],
                            ),
                          ))),
                         if (_saleItems[sale.id]!.length > 3) ...[
                           Text(
                             '... and ${_saleItems[sale.id]!.length - 3} more items',
                             style: TextStyle(
                               fontSize: 8,
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
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                                         child: Text(
                       'Cancelled by: ${sale.cancelledByName ?? 'Unknown'}',
                       style: TextStyle(
                         fontSize: 10,
                         color: Colors.red[700],
                         fontWeight: FontWeight.w500,
                       ),
                     ),
                   ),
                   if (sale.cancellationReason != null) ...[
                     const SizedBox(height: 2),
                     Text(
                       'Reason: ${sale.cancellationReason}',
                       style: TextStyle(
                         fontSize: 10,
                         color: Colors.red[600],
                         fontStyle: FontStyle.italic,
                       ),
                     ),
                   ],
                   if (sale.cancelledAt != null) ...[
                     const SizedBox(height: 2),
                     Text(
                       'Cancelled: ${_formatDate(sale.cancelledAt)}',
                       style: TextStyle(
                         fontSize: 10,
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
      },
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
}
