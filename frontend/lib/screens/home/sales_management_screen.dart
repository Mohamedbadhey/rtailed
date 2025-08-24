import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/widgets/branded_header.dart';

class SalesManagementScreen extends StatefulWidget {
  const SalesManagementScreen({super.key});

  @override
  State<SalesManagementScreen> createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> {
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _sales = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _selectedStatus;
  String? _selectedPaymentMethod;

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
      setState(() {
        _sales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelSale(Map<String, dynamic> sale) async {
    final reason = await _showCancellationDialog();
    if (reason == null) return;

    try {
      await _apiService.cancelSale(sale['id'], reason);
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

  Future<String?> _showCancellationDialog() async {
    final reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'Cancel Sale')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t(context, 'Please provide a reason for cancelling this sale:')),
            const SizedBox(height: 8),
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
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: t(context, 'Reason'),
                hintText: t(context, 'e.g., Customer request, Wrong item, etc.'),
                border: const OutlineInputBorder(),
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

  List<Map<String, dynamic>> get _filteredSales {
    return _sales.where((sale) {
      // Status filter
      if (_selectedStatus != null && _selectedStatus != 'all') {
        if (sale['status'] != _selectedStatus) return false;
      }
      
      // Payment method filter
      if (_selectedPaymentMethod != null && _selectedPaymentMethod != 'all') {
        if (sale['payment_method'] != _selectedPaymentMethod) return false;
      }
      
      // Date filter
      if (_filterStartDate != null || _filterEndDate != null) {
        final saleDate = DateTime.tryParse(sale['created_at'] ?? '');
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
    final completedSales = _sales.where((s) => s['status'] == 'completed').length;
    final cancelledSales = _sales.where((s) => s['status'] == 'cancelled').length;
    final creditSales = _sales.where((s) => s['status'] == 'unpaid').length;
    
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
                      DropdownMenuItem(value: 'cash', child: Text(t(context, 'Cash'))),
                      DropdownMenuItem(value: 'card', child: Text(t(context, 'Card'))),
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
        final canCancel = sale['status'] == 'completed' || sale['status'] == 'unpaid';
        
        return Card(
          margin: EdgeInsets.only(bottom: isSmallMobile ? 8 : 12),
          child: ListTile(
            title: Text(
              'Sale #${sale['id']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallMobile ? 14 : 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount: \$${double.tryParse(sale['total_amount'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Status: ${sale['status']?.toString().toUpperCase() ?? 'UNKNOWN'}',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 11 : 12,
                    color: _getStatusColor(sale['status']),
                  ),
                ),
                Text(
                  'Payment: ${sale['payment_method']?.toString().toUpperCase() ?? 'UNKNOWN'}',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Date: ${_formatDate(DateTime.tryParse(sale['created_at'] ?? ''))}',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
                // Show cancellation details if sale was cancelled
                if (sale['status'] == 'cancelled') ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      'Cancelled by: ${sale['cancelled_by_name'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (sale['cancellation_reason'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Reason: ${sale['cancellation_reason']}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (sale['cancelled_at'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cancelled: ${_formatDate(DateTime.tryParse(sale['cancelled_at'] ?? ''))}',
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
                : sale['status'] == 'cancelled'
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
}
