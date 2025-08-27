import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/models/product.dart';
import 'package:retail_management/models/sale.dart';
import 'package:retail_management/models/customer.dart';
import 'package:retail_management/utils/type_converter.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/widgets/branded_header.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'dart:ui';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  List<Map<String, dynamic>> _productTransactions = [];
  bool _isProductTxLoading = false;
  String? _productTxError;
  Map<String, dynamic> _reportData = {};
  Map<String, dynamic> _balanceSheet = {};
  Map<String, dynamic>? _damagedProductsReport;
  bool _isLoading = true;
  bool _isBalanceSheetLoading = false;
  bool _isDamagedProductsLoading = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _quickRangeLabel;
  List<Map<String, dynamic>> _cashiers = [];
  String? _selectedCashierId;

  @override
  void initState() {
    super.initState();
    _setQuickRange('Today');
    _loadProducts();
    _loadCashiers();
    _loadAllReports();
  }

  void _setQuickRange(String label) {
    final now = DateTime.now();
    DateTime start, end;
    if (label == 'All Time') {
      setState(() {
        _filterStartDate = null;
        _filterEndDate = null;
        _quickRangeLabel = 'All Time';
      });
      return;
    }
    if (label == 'Today') {
      start = DateTime(now.year, now.month, now.day);
      end = start;
    } else if (label == 'This Week') {
      final weekday = now.weekday;
      start = now.subtract(Duration(days: weekday - 1));
      end = now;
    } else if (label == 'Last 7 Days') {
      start = now.subtract(const Duration(days: 6));
      end = now;
    } else {
      start = _filterStartDate ?? now;
      end = _filterEndDate ?? now;
    }
    setState(() {
      _filterStartDate = start;
      _filterEndDate = end;
      _quickRangeLabel = label;
    });
  }

  Future<void> _showDateFilterDialog() async {
    final now = DateTime.now();
    DateTime? customStart = _filterStartDate;
    DateTime? customEnd = _filterEndDate;
    String? selectedQuick = _quickRangeLabel;
    
    // Responsive breakpoints for dialog
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.filter_alt,
              color: Theme.of(context).primaryColor,
              size: isSmallMobile ? 18 : 24,
            ),
            SizedBox(width: isSmallMobile ? 6 : 8),
            Text(
              isSmallMobile ? 'Date Filter' : t(context, 'filter_by_date_title'),
              style: TextStyle(
                fontSize: isSmallMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          width: isSmallMobile ? double.maxFinite : (isMobile ? 300 : 400),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              _buildQuickFilterOption('All Time', selectedQuick == 'All Time', () {
                setState(() => _quickRangeLabel = 'All Time');
                Navigator.pop(context);
                _setQuickRange('All Time');
                _loadAllReports();
              }, isSmallMobile),
              _buildQuickFilterOption('Today', selectedQuick == 'Today', () {
                setState(() => _quickRangeLabel = 'Today');
                Navigator.pop(context);
                _setQuickRange('Today');
                _loadAllReports();
              }, isSmallMobile),
              _buildQuickFilterOption('This Week', selectedQuick == 'This Week', () {
                setState(() => _quickRangeLabel = 'This Week');
                Navigator.pop(context);
                _setQuickRange('This Week');
                _loadAllReports();
              }, isSmallMobile),
              _buildQuickFilterOption('Last 7 Days', selectedQuick == 'Last 7 Days', () {
                setState(() => _quickRangeLabel = 'Last 7 Days');
                Navigator.pop(context);
                _setQuickRange('Last 7 Days');
                _loadAllReports();
              }, isSmallMobile),
              _buildQuickFilterOption('Custom Range', selectedQuick == 'Custom', () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: now,
                  initialDateRange: customStart != null && customEnd != null
                      ? DateTimeRange(start: customStart, end: customEnd)
                      : null,
                );
                if (picked != null) {
                  setState(() {
                    _filterStartDate = picked.start;
                    _filterEndDate = picked.end;
                    _quickRangeLabel = 'Custom';
                  });
                  Navigator.pop(context);
                  _loadAllReports();
                }
              }, isSmallMobile),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              t(context, 'cancel'),
              style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterOption(String title, bool isSelected, VoidCallback onTap, bool isSmallMobile) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
        border: Border.all(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallMobile ? 12 : 16,
          vertical: isSmallMobile ? 4 : 8,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: isSmallMobile ? 12 : 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[800],
          ),
        ),
        trailing: isSelected ? Icon(
          Icons.check,
          color: Theme.of(context).primaryColor,
          size: isSmallMobile ? 16 : 20,
        ) : null,
        onTap: onTap,
      ),
    );
  }

  Future<void> _loadCashiers() async {
    final user = context.read<AuthProvider>().user;
    if (user != null && user.role == 'admin') {
      try {
        final response = await _apiService.getUsers();
        setState(() {
          _cashiers = List<Map<String, dynamic>>.from(response.where((u) => u['role'] == 'cashier'));
        });
      } catch (e) {
        setState(() { _cashiers = []; });
      }
    }
  }

  Future<void> _loadAllReports() async {
    await Future.wait([
      _loadReportData(),
      _loadBalanceSheet(),
      _loadProductTransactions(),
      _loadDamagedProductsReport(),
    ]);
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _apiService.getProducts();
      setState(() => _products = products);
    } catch (e) {
      setState(() => _products = []);
    }
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      String? startDateParam;
      String? endDateParam;
      if (_filterStartDate != null && _filterEndDate != null &&
          DateFormat('yyyy-MM-dd').format(_filterStartDate!) == DateFormat('yyyy-MM-dd').format(_filterEndDate!)) {
        final day = DateFormat('yyyy-MM-dd').format(_filterStartDate!);
        startDateParam = '$day 00:00:00';
        endDateParam = '$day 23:59:59';
      } else {
        if (_filterStartDate != null) {
          startDateParam = DateFormat('yyyy-MM-dd').format(_filterStartDate!);
        }
        if (_filterEndDate != null) {
          endDateParam = DateFormat('yyyy-MM-dd').format(_filterEndDate!);
        }
      }
      print('REPORTS: Date parameters - startDateParam: $startDateParam, endDateParam: $endDateParam');
      print('REPORTS: Current date filter - start: $_filterStartDate, end: $_filterEndDate, quickRange: $_quickRangeLabel');
      final user = context.read<AuthProvider>().user;
      Map<String, dynamic> salesReport;
      if (user != null && user.role == 'admin' && _selectedCashierId != null && _selectedCashierId != 'all') {
        print('Sending userId: \'$_selectedCashierId\' to getSalesReport with dates: $startDateParam to $endDateParam');
        salesReport = await _apiService.getSalesReport(
          startDate: startDateParam,
          endDate: endDateParam,
          userId: _selectedCashierId,
        );
      } else {
        print('No cashier filter, loading all or self with dates: $startDateParam to $endDateParam');
        salesReport = await _apiService.getSalesReport(
          startDate: startDateParam,
          endDate: endDateParam,
        );
      }
      setState(() => _reportData = salesReport);
    } catch (e) {
      setState(() => _reportData = {});
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBalanceSheet() async {
    setState(() => _isBalanceSheetLoading = true);
    try {
      final data = await ApiService().getBalanceSheet();
      setState(() => _balanceSheet = data);
    } catch (e) {
      setState(() => _balanceSheet = {});
    } finally {
      setState(() => _isBalanceSheetLoading = false);
    }
  }

  Future<void> _loadProductTransactions() async {
    setState(() {
      _isProductTxLoading = true;
      _productTxError = null;
    });
    try {
      final params = <String, dynamic>{};
      if (_filterStartDate != null && _filterEndDate != null &&
          DateFormat('yyyy-MM-dd').format(_filterStartDate!) == DateFormat('yyyy-MM-dd').format(_filterEndDate!)) {
        // Same day - use full day range
        final day = DateFormat('yyyy-MM-dd').format(_filterStartDate!);
        params['start_date'] = '$day 00:00:00';
        params['end_date'] = '$day 23:59:59';
      } else {
        // Different days or single day - ensure proper time boundaries
        if (_filterStartDate != null) {
          final startDay = DateFormat('yyyy-MM-dd').format(_filterStartDate!);
          params['start_date'] = '$startDay 00:00:00';
        }
        if (_filterEndDate != null) {
          final endDay = DateFormat('yyyy-MM-dd').format(_filterEndDate!);
          params['end_date'] = '$endDay 23:59:59';
        }
      }
      
      print('🔍 REPORTS: Product Transactions Date Filters:');
      print('  - Filter Start Date: $_filterStartDate');
      print('  - Filter End Date: $_filterEndDate');
      print('  - Params being sent: $params');
      
      final user = context.read<AuthProvider>().user;
      if (user != null && user.role == 'admin' && _selectedCashierId != null && _selectedCashierId != 'all') {
        print('🔍 REPORTS: Sending user_id: \'$_selectedCashierId\' to getInventoryTransactions');
        params['user_id'] = _selectedCashierId;
      } else {
        print('🔍 REPORTS: No cashier filter for inventory transactions');
      }
      
      print('🔍 REPORTS: Final params for getInventoryTransactions: $params');
      
      final data = await _apiService.getInventoryTransactions(params);
      print('🔍 REPORTS: Received ${data.length} product transactions');
      setState(() => _productTransactions = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('🔍 REPORTS: Error loading product transactions: $e');
      setState(() => _productTxError = e.toString());
    } finally {
      setState(() => _isProductTxLoading = false);
    }
  }

  Future<void> _loadDamagedProductsReport() async {
    setState(() => _isDamagedProductsLoading = true);
    try {
      final user = context.read<AuthProvider>().user;
      String? cashierId;
      if (user != null && user.role == 'admin' && _selectedCashierId != null && _selectedCashierId != 'all') {
        cashierId = _selectedCashierId;
      }
      
      // Use the same date formatting logic as other reports
      String? startDateParam;
      String? endDateParam;
      if (_filterStartDate != null && _filterEndDate != null &&
          DateFormat('yyyy-MM-dd').format(_filterStartDate!) == DateFormat('yyyy-MM-dd').format(_filterEndDate!)) {
        // Same day - use full day range
        final day = DateFormat('yyyy-MM-dd').format(_filterStartDate!);
        startDateParam = '$day 00:00:00';
        endDateParam = '$day 23:59:59';
      } else {
        // Different days or single day - ensure proper time boundaries
        if (_filterStartDate != null) {
          final startDay = DateFormat('yyyy-MM-dd').format(_filterStartDate!);
          startDateParam = '$startDay 00:00:00';
        }
        if (_filterEndDate != null) {
          final endDay = DateFormat('yyyy-MM-dd').format(_filterEndDate!);
          endDateParam = '$endDay 23:59:59';
        }
      }
      
      print('🔍 REPORTS: Damaged Products Date Filters:');
      print('  - Filter Start Date: $_filterStartDate');
      print('  - Filter End Date: $_filterEndDate');
      print('  - Start Date Param: $startDateParam');
      print('  - End Date Param: $endDateParam');
      print('  - Cashier ID: $cashierId');
      
      final report = await _apiService.getDamagedProductsReport(
        startDate: startDateParam,
        endDate: endDateParam,
        cashierId: cashierId,
      );
      setState(() => _damagedProductsReport = report);
    } catch (e) {
      print('🔍 REPORTS: Error loading damaged products report: $e');
      setState(() => _damagedProductsReport = null);
    } finally {
      setState(() => _isDamagedProductsLoading = false);
    }
  }

  double parseNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _formatMetricValue(dynamic value) {
    if (value == null) return '0';
    if (value is num) {
      return value is double ? value.toStringAsFixed(2) : value.toString();
    }
    if (value is String) {
      // Try to parse as number first
      final numValue = double.tryParse(value);
      if (numValue != null) {
        return numValue.toStringAsFixed(2);
      }
      return value;
    }
    return value.toString();
  }

  Widget _metricCard(String label, dynamic value, {Color? color, IconData? icon, bool isSmallMobile = false, bool isMobile = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: color ?? Colors.white,
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 6 : (isMobile ? 8 : 12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon, 
                color: Colors.blueAccent, 
                size: isSmallMobile ? 16 : (isMobile ? 20 : 24),
              ),
              SizedBox(height: isSmallMobile ? 3 : (isMobile ? 4 : 6)),
            ],
            Text(
              _formatMetricValue(value), 
              style: TextStyle(
                fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18), 
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallMobile ? 2 : (isMobile ? 3 : 4)),
            Text(
              label, 
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                fontSize: isSmallMobile ? 8 : (isMobile ? 9 : 10),
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileProductTransactionsCards(List<Map<String, dynamic>> transactions, bool isSmallMobile) {
    if (transactions.isEmpty) {
      return Text(t(context, 'no_transactions_found_for_product'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        // Check if this is a damaged product transaction
        final isDamaged = tx['transaction_type'] == 'adjustment' && 
                         tx['notes'] != null && 
                         tx['notes'].toString().toLowerCase().contains('damaged');
        final isNegativeQuantity = tx['quantity'] != null && tx['quantity'] < 0;
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.only(bottom: isSmallMobile ? 8 : 12),
          child: Padding(
            padding: EdgeInsets.all(isSmallMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name + Type Badge
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            tx['product_name'] ?? '',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: isDamaged ? Colors.orange[700] : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Type:',
                          style: TextStyle(
                            fontSize: isSmallMobile ? 10 : 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDamaged ? Colors.orange[100] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isDamaged ? 'DAMAGED' : (tx['transaction_type'] ?? '').toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDamaged ? Colors.orange[800] : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 8 : 12),
                
                // Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Text(
                      'Date:',
                      style: TextStyle(
                        fontSize: isSmallMobile ? 10 : 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatTimestamp(tx['created_at'] ?? ''),
                      style: TextStyle(
                        fontSize: isSmallMobile ? 11 : 13,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 8 : 12),
                
                // Quantity + Notes
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantity:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${tx['quantity']}',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: isNegativeQuantity ? Colors.red[700] : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Tooltip(
                            message: tx['notes'] ?? '',
                            child: Text(
                              tx['notes'] ?? '',
                              style: TextStyle(
                                fontSize: isSmallMobile ? 11 : 13,
                                color: isDamaged ? Colors.orange[700] : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 8 : 12),
                
                // Unit Price + Total Price
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit Price:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            tx['sale_unit_price'] != null ? '\$${tx['sale_unit_price']}' : '-',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Price:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            tx['sale_total_price'] != null ? '\$${tx['sale_total_price']}' : '-',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 8 : 12),
                
                // Profit + Customer
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profit:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            tx['profit'] != null ? '\$${tx['profit']}' : '-',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            tx['customer_name'] ?? '-',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 8 : 12),
                
                // Payment Method + Sale ID
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            tx['payment_method'] ?? '-',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sale ID:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            tx['sale_id']?.toString() ?? '-',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 8 : 12),
                
                // Status + Mode
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            tx['status'] ?? '-',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode:',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            (tx['sale_mode'] ?? '').toString().isNotEmpty 
                                ? (tx['sale_mode'] == 'wholesale' ? t(context, 'wholesale') : t(context, 'retail'))
                                : '-',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 8 : 12),
                
                // Cashier
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cashier:',
                      style: TextStyle(
                        fontSize: isSmallMobile ? 10 : 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      tx['cashier_name'] ?? '-',
                      style: TextStyle(
                        fontSize: isSmallMobile ? 12 : 14,
                        fontWeight: FontWeight.bold,
                        color: isDamaged ? Colors.orange[700] : Colors.grey[800],
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

  String _formatTimestamp(String timestamp) {
    try {
      if (timestamp.isEmpty) return '';
      
      // Parse the timestamp and convert to local time
      final dateTime = DateTime.parse(timestamp);
      final localDateTime = dateTime.toLocal();
      
      // Format: "2025-08-27 19:15:33"
      return '${localDateTime.year}-${localDateTime.month.toString().padLeft(2, '0')}-${localDateTime.day.toString().padLeft(2, '0')} ${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}:${localDateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      // Fallback to original timestamp if parsing fails
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesReport = _reportData.isNotEmpty ? _reportData : null;
    final paymentMethods = (salesReport?['paymentMethodBreakdown'] as List? ?? [])
        .map((item) => TypeConverter.safeToMap(item)).toList();
    final totalSales = parseNum(salesReport?['totalSales']);
    double totalCredits = 0.0;
    if (salesReport?['outstandingCredits'] != null) {
      totalCredits = parseNum(salesReport?['outstandingCredits']);
    } else if (salesReport?['creditSummary'] != null && salesReport?['creditSummary']['total_credit_amount'] != null) {
      totalCredits = parseNum(salesReport?['creditSummary']['total_credit_amount']);
    }
    final cashInHand = parseNum(salesReport?['cashInHand']);
    final totalOrders = parseNum(salesReport?['totalOrders']);
    final profit = parseNum(salesReport?['totalProfit']);
    final totalProductsSold = parseNum(salesReport?['totalProductsSold']);
    final uniqueCustomers = parseNum(salesReport?['customerInsights']?['unique_customers']);
    final cashFromBalanceSheet = parseNum(_balanceSheet['cash']);

    final user = context.read<AuthProvider>().user;
    final isCashier = user != null && user.role == 'cashier';
    final isAdmin = user != null && user.role == 'admin';

    // Responsive breakpoints
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    final isTablet = MediaQuery.of(context).size.width > 768 && MediaQuery.of(context).size.width <= 1200;
    final isLargeScreen = MediaQuery.of(context).size.width > 1200;

    return Scaffold(
      appBar: BrandedAppBar(
        title: isSmallMobile ? 'Reports' : t(context, 'business_report_title'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            tooltip: t(context, 'filter_by_date_tooltip'),
            onPressed: _showDateFilterDialog,
            padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
            constraints: BoxConstraints(
              minWidth: isSmallMobile ? 32 : 48,
              minHeight: isSmallMobile ? 32 : 48,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 16 : 20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAdmin)
                    Container(
                      margin: EdgeInsets.only(bottom: isSmallMobile ? 8 : 12),
                      padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.blue[600],
                            size: isSmallMobile ? 16 : 20,
                          ),
                          SizedBox(width: isSmallMobile ? 6 : 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(context, 'Filter by Cashier:'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallMobile ? 12 : 14,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                SizedBox(height: isSmallMobile ? 4 : 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                                    border: Border.all(color: Colors.blue[300]!),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                            value: _selectedCashierId ?? 'all',
                                      isExpanded: true,
                            items: [
                              DropdownMenuItem(value: 'all', child: Text(t(context, 'All Cashiers'))),
                              ..._cashiers.map((c) => DropdownMenuItem(
                                value: c['id'].toString(),
                                          child: Text(
                                            c['username'] ?? '',
                                            style: TextStyle(fontSize: isSmallMobile ? 11 : 13),
                                          ),
                              )),
                            ],
                            onChanged: (val) {
                              setState(() { _selectedCashierId = val; });
                              // If selecting a specific cashier (not "all"), reset to today's date
                              if (val != null && val != 'all') {
                                _setQuickRange('Today');
                              }
                              _loadAllReports();
                            },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isCashier)
                    Container(
                      margin: EdgeInsets.only(bottom: isSmallMobile ? 8 : 12),
                      padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.blue[600],
                            size: isSmallMobile ? 16 : 20,
                          ),
                          SizedBox(width: isSmallMobile ? 6 : 8),
                          Expanded(
                      child: Text(
                        'This report shows only your own sales and performance.',
                        style: TextStyle(
                                color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                                fontSize: isSmallMobile ? 11 : 13,
                        ),
                      ),
                    ),
                        ],
                      ),
                    ),
                  // Show info when specific cashier is selected
                  if (_selectedCashierId != null && _selectedCashierId != 'all')
                    Container(
                      margin: EdgeInsets.only(bottom: isSmallMobile ? 8 : 12),
                      padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.green[600],
                            size: isSmallMobile ? 16 : 20,
                          ),
                          SizedBox(width: isSmallMobile ? 6 : 8),
                          Expanded(
                            child: Text(
                              'Showing today\'s data for selected cashier. Change date range if needed.',
                              style: TextStyle(
                                color: Colors.green[800],
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallMobile ? 11 : 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Date Filter Section
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Colors.blue[600],
                          size: isSmallMobile ? 14 : 18,
                        ),
                      ),
                      SizedBox(width: isSmallMobile ? 8 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _quickRangeLabel ?? t(context, 'custom_range_label'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallMobile ? 12 : 14,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: isSmallMobile ? 2 : 4),
                      if (_quickRangeLabel == 'All Time')
                              Text(
                                t(context, 'all_history'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: isSmallMobile ? 10 : 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                      if (_quickRangeLabel != 'All Time' && _filterStartDate != null && _filterEndDate != null)
                        Text(
                          '${DateFormat('yyyy-MM-dd').format(_filterStartDate!)} - ${DateFormat('yyyy-MM-dd').format(_filterEndDate!)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: isSmallMobile ? 10 : 12,
                                  color: Colors.grey[600],
                                ),
                        ),
                    ],
                  ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                        ),
                        child: IconButton(
                          onPressed: _showDateFilterDialog,
                          icon: Icon(
                            Icons.edit,
                            color: Colors.blue[600],
                            size: isSmallMobile ? 14 : 18,
                          ),
                          padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                          constraints: BoxConstraints(
                            minWidth: isSmallMobile ? 28 : 36,
                            minHeight: isSmallMobile ? 28 : 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallMobile ? 8 : 16),
                  // Summary Metrics
                  GridView.count(
                    crossAxisCount: isSmallMobile ? 2 : (isMobile ? 2 : (isTablet ? 3 : 4)),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isSmallMobile ? 1.8 : (isMobile ? 2.0 : (isTablet ? 2.5 : 3.0)),
                    mainAxisSpacing: isSmallMobile ? 4 : (isMobile ? 6 : 8),
                    crossAxisSpacing: isSmallMobile ? 4 : (isMobile ? 6 : 8),
                    children: [
                      _metricCard(t(context, 'Total Sales'), totalSales, color: Colors.lightBlue[50], icon: Icons.attach_money, isSmallMobile: isSmallMobile, isMobile: isMobile),
                      _metricCard(t(context, 'Total Credits'), totalCredits, color: Colors.orange[50], icon: Icons.credit_card, isSmallMobile: isSmallMobile, isMobile: isMobile),
                      _metricCard(t(context, 'Cash in Hand'), cashInHand, color: Colors.green[50], icon: Icons.account_balance_wallet, isSmallMobile: isSmallMobile, isMobile: isMobile),
                      _metricCard(t(context, 'Total Orders'), totalOrders, color: Colors.purple[50], icon: Icons.shopping_cart, isSmallMobile: isSmallMobile, isMobile: isMobile),
                      _metricCard(t(context, 'Profit'), profit, color: Colors.teal[50], icon: Icons.trending_up, isSmallMobile: isSmallMobile, isMobile: isMobile),
                      _metricCard(t(context, 'Products Sold'), totalProductsSold, color: Colors.cyan[50], icon: Icons.inventory, isSmallMobile: isSmallMobile, isMobile: isMobile),
                      _metricCard(t(context, 'Unique Customers'), uniqueCustomers, color: Colors.amber[50], icon: Icons.people, isSmallMobile: isSmallMobile, isMobile: isMobile),
                      _metricCard(t(context, 'Cash (Balance Sheet)'), cashFromBalanceSheet, color: Colors.red[50], icon: Icons.account_balance, isSmallMobile: isSmallMobile, isMobile: isMobile),
                      if (_damagedProductsReport != null) ...[
                        _metricCard(
                          'Damaged Items', 
                          int.tryParse(_damagedProductsReport!['summary']['total_quantity_damaged']?.toString() ?? '0') ?? 0, 
                          color: Colors.orange[50], 
                          icon: Icons.warning,
                          isSmallMobile: isSmallMobile,
                          isMobile: isMobile,
                        ),
                        _metricCard(
                          'Damage Loss', 
                          double.tryParse((_damagedProductsReport!['summary']['total_estimated_loss'] ?? 0).toString()) ?? 0.0, 
                          color: Colors.red[50], 
                          icon: Icons.money_off,
                          isSmallMobile: isSmallMobile,
                          isMobile: isMobile,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: isSmallMobile ? 16 : 32),
                  // Payment Methods
                  Text(
                    t(context, 'payment_methods'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallMobile ? 14 : 16,
                    ),
                  ),
                  SizedBox(height: isSmallMobile ? 6 : 10),
                  paymentMethods.isEmpty
                      ? Text(t(context, 'no_payment_method_data'))
                      : Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              DataColumn(label: Text(t(context, 'method'))),
                              DataColumn(label: Text(t(context, 'percentage'))),
                              DataColumn(label: Text(t(context, 'total_amount'))),
                            ],
                            rows: paymentMethods.map((pm) {
                              final total = paymentMethods.fold<double>(0, (sum, m) => sum + (m['total_amount'] is num ? m['total_amount'] : double.tryParse(m['total_amount'].toString()) ?? 0.0));
                              final amount = pm['total_amount'] is num ? pm['total_amount'] : double.tryParse(pm['total_amount'].toString()) ?? 0.0;
                              final percent = total > 0 ? (amount / total * 100) : 0.0;
                              return DataRow(cells: [
                                DataCell(Text(pm['payment_method'] ?? '')),
                                DataCell(Text('${percent.toStringAsFixed(1)}%')),
                                DataCell(Text(amount.toString())),
                              ]);
                            }).toList(),
                          ),
                        ),
                        ),
                  SizedBox(height: isSmallMobile ? 16 : 32),
                  // Product Transactions
                  Text(
                    t(context, 'product_transactions'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallMobile ? 14 : 16,
                    ),
                  ),
                  SizedBox(height: isSmallMobile ? 8 : 12),
                  SizedBox(height: isSmallMobile ? 8 : 16),
                  _isProductTxLoading
                      ? Center(child: CircularProgressIndicator())
                      : _productTxError != null
                          ? Text('${t(context, 'error')}: $_productTxError')
                          : _productTransactions.isEmpty
                              ? Text(t(context, 'no_transactions_found_for_product'))
                              : isMobile
                                  ? _buildMobileProductTransactionsCards(_productTransactions, isSmallMobile)
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: [
                                      DataColumn(label: Text(t(context, 'Product'))),
                                      DataColumn(label: Text(t(context, 'Date'))),
                                      DataColumn(label: Text(t(context, 'Type'))),
                                      DataColumn(label: Text(t(context, 'Quantity'))),
                                      DataColumn(label: Text(t(context, 'Notes'))),
                                      DataColumn(label: Text(t(context, 'Unit Price'))),
                                      DataColumn(label: Text(t(context, 'Total Price'))),
                                      DataColumn(label: Text(t(context, 'Profit'))),
                                      DataColumn(label: Text(t(context, 'Customer'))),
                                      DataColumn(label: Text(t(context, 'Payment Method'))),
                                      DataColumn(label: Text(t(context, 'Sale ID'))),
                                      DataColumn(label: Text(t(context, 'Status'))),
                                      DataColumn(label: Text(t(context, 'Mode'))),
                                      DataColumn(label: Text(t(context, 'Cashier'))),
                                    ],
                                    rows: _productTransactions.map((tx) {
                                      // Check if this is a damaged product transaction
                                      final isDamaged = tx['transaction_type'] == 'adjustment' && 
                                                       tx['notes'] != null && 
                                                       tx['notes'].toString().toLowerCase().contains('damaged');
                                      final isNegativeQuantity = tx['quantity'] != null && tx['quantity'] < 0;
                                      
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              tx['product_name'] ?? '',
                                              style: isDamaged ? TextStyle(
                                                color: Colors.orange[700],
                                                fontWeight: FontWeight.bold,
                                              ) : null,
                                            ),
                                          ),
                                          DataCell(Text(_formatTimestamp(tx['created_at'] ?? ''))),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isDamaged ? Colors.orange[100] : Colors.grey[100],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                isDamaged ? 'DAMAGED' : (tx['transaction_type'] ?? '').toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDamaged ? Colors.orange[800] : Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${tx['quantity']}',
                                              style: isNegativeQuantity ? TextStyle(
                                                color: Colors.red[700],
                                                fontWeight: FontWeight.bold,
                                              ) : null,
                                            ),
                                          ),
                                          DataCell(
                                            Tooltip(
                                              message: tx['notes'] ?? '',
                                              child: Text(
                                                tx['notes'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDamaged ? Colors.orange[700] : Colors.grey[600],
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(tx['sale_unit_price'] != null ? tx['sale_unit_price'].toString() : '')),
                                          DataCell(Text(tx['sale_total_price'] != null ? tx['sale_total_price'].toString() : '')),
                                          DataCell(Text(tx['profit'] != null ? tx['profit'].toString() : '')),
                                          DataCell(Text(tx['customer_name'] ?? '')),
                                          DataCell(Text(tx['payment_method'] ?? '')),
                                          DataCell(Text(tx['sale_id']?.toString() ?? '')),
                                          DataCell(Text(tx['status'] ?? '')),
                                          DataCell(Text((tx['sale_mode'] ?? '').toString().isNotEmpty ? (tx['sale_mode'] == 'wholesale' ? t(context, 'wholesale') : t(context, 'retail')) : '')),
                                          DataCell(
                                            Text(
                                              tx['cashier_name'] ?? '',
                                              style: isDamaged ? TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[700],
                                              ) : null,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                ],
              ),
            ),
    );
  }
} 