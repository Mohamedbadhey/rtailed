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
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'filter_by_date_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t(context, 'all_time')),
              trailing: selectedQuick == 'All Time' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                setState(() => _quickRangeLabel = 'All Time');
                Navigator.pop(context);
                _setQuickRange('All Time');
                _loadAllReports();
              },
            ),
            ListTile(
              title: Text(t(context, 'today')),
              trailing: selectedQuick == 'Today' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                setState(() => _quickRangeLabel = 'Today');
                Navigator.pop(context);
                _setQuickRange('Today');
                _loadAllReports();
              },
            ),
            ListTile(
              title: Text(t(context, 'this_week')),
              trailing: selectedQuick == 'This Week' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                setState(() => _quickRangeLabel = 'This Week');
                Navigator.pop(context);
                _setQuickRange('This Week');
                _loadAllReports();
              },
            ),
            ListTile(
              title: Text(t(context, 'last_7_days')),
              trailing: selectedQuick == 'Last 7 Days' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                setState(() => _quickRangeLabel = 'Last 7 Days');
                Navigator.pop(context);
                _setQuickRange('Last 7 Days');
                _loadAllReports();
              },
            ),
            ListTile(
              title: Text(t(context, 'custom_range')),
              trailing: selectedQuick == 'Custom' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () async {
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
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'cancel')),
          ),
        ],
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
      final user = context.read<AuthProvider>().user;
      Map<String, dynamic> salesReport;
      if (user != null && user.role == 'admin' && _selectedCashierId != null && _selectedCashierId != 'all') {
        print('Sending userId: \'$_selectedCashierId\' to getSalesReport');
        salesReport = await _apiService.getSalesReport(
          startDate: startDateParam,
          endDate: endDateParam,
          userId: _selectedCashierId,
        );
      } else {
        print('No cashier filter, loading all or self');
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
        final day = DateFormat('yyyy-MM-dd').format(_filterStartDate!);
        params['start_date'] = '$day 00:00:00';
        params['end_date'] = '$day 23:59:59';
      } else {
        if (_filterStartDate != null) params['start_date'] = DateFormat('yyyy-MM-dd').format(_filterStartDate!);
        if (_filterEndDate != null) params['end_date'] = DateFormat('yyyy-MM-dd').format(_filterEndDate!);
      }
      final user = context.read<AuthProvider>().user;
      if (user != null && user.role == 'admin' && _selectedCashierId != null && _selectedCashierId != 'all') {
        print('Sending user_id: \'$_selectedCashierId\' to getInventoryTransactions');
        params['user_id'] = _selectedCashierId;
      } else {
        print('No cashier filter for inventory transactions');
      }
      final data = await _apiService.getInventoryTransactions(params);
      setState(() => _productTransactions = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      setState(() => _productTxError = e.toString());
    } finally {
      setState(() => _isProductTxLoading = false);
    }
  }

  Future<void> _loadDamagedProductsReport() async {
    setState(() => _isDamagedProductsLoading = true);
    try {
      final report = await _apiService.getDamagedProductsReport(
        startDate: _filterStartDate?.toIso8601String().split('T')[0],
        endDate: _filterEndDate?.toIso8601String().split('T')[0],
      );
      setState(() => _damagedProductsReport = report);
    } catch (e) {
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

  Widget _metricCard(String label, dynamic value, {Color? color, IconData? icon}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: color ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.blueAccent, size: 28),
              const SizedBox(width: 12),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(_formatMetricValue(value), style: const TextStyle(fontSize: 22, color: Colors.black87)),
              ],
            ),
          ],
        ),
      ),
    );
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

    return Scaffold(
      appBar: BrandedAppBar(
        title: t(context, 'business_report_title'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            tooltip: t(context, 'filter_by_date_tooltip'),
            onPressed: _showDateFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Text(t(context, 'Filter by Cashier: '), style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _selectedCashierId ?? 'all',
                            items: [
                              DropdownMenuItem(value: 'all', child: Text(t(context, 'All Cashiers'))),
                              ..._cashiers.map((c) => DropdownMenuItem(
                                value: c['id'].toString(),
                                child: Text(c['username'] ?? ''),
                              )),
                            ],
                            onChanged: (val) {
                              setState(() { _selectedCashierId = val; });
                              _loadAllReports();
                            },
                          ),
                        ],
                      ),
                    ),
                  if (isCashier)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'This report shows only your own sales and performance.',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Chip(
                        label: Text(_quickRangeLabel ?? t(context, 'custom_range_label')),
                        avatar: const Icon(Icons.calendar_today, size: 18),
                        backgroundColor: Colors.blue[50],
                      ),
                      const SizedBox(width: 8),
                      if (_quickRangeLabel == 'All Time')
                        Text(t(context, 'all_history'), style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (_quickRangeLabel != 'All Time' && _filterStartDate != null && _filterEndDate != null)
                        Text(
                          '${DateFormat('yyyy-MM-dd').format(_filterStartDate!)} - ${DateFormat('yyyy-MM-dd').format(_filterEndDate!)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Summary Metrics
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _metricCard(t(context, 'Total Sales'), totalSales, color: Colors.lightBlue[50], icon: Icons.attach_money),
                      _metricCard(t(context, 'Total Credits'), totalCredits, color: Colors.orange[50], icon: Icons.credit_card),
                      _metricCard(t(context, 'Cash in Hand'), cashInHand, color: Colors.green[50], icon: Icons.account_balance_wallet),
                      _metricCard(t(context, 'Total Orders'), totalOrders, color: Colors.purple[50], icon: Icons.shopping_cart),
                      _metricCard(t(context, 'Profit'), profit, color: Colors.teal[50], icon: Icons.trending_up),
                      _metricCard(t(context, 'Products Sold'), totalProductsSold, color: Colors.cyan[50], icon: Icons.inventory),
                      _metricCard(t(context, 'Unique Customers'), uniqueCustomers, color: Colors.amber[50], icon: Icons.people),
                      _metricCard(t(context, 'Cash (Balance Sheet)'), cashFromBalanceSheet, color: Colors.red[50], icon: Icons.account_balance),
                      if (_damagedProductsReport != null) ...[
                        _metricCard(
                          'Damaged Items', 
                          int.tryParse(_damagedProductsReport!['summary']['total_quantity_damaged']?.toString() ?? '0') ?? 0, 
                          color: Colors.orange[50], 
                          icon: Icons.warning
                        ),
                        _metricCard(
                          'Damage Loss', 
                          double.tryParse((_damagedProductsReport!['summary']['total_estimated_loss'] ?? 0).toString()) ?? 0.0, 
                          color: Colors.red[50], 
                          icon: Icons.money_off
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Payment Methods
                  Text(t(context, 'payment_methods'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  paymentMethods.isEmpty
                      ? Text(t(context, 'no_payment_method_data'))
                      : Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  const SizedBox(height: 32),
                  // Product Transactions
                  Text(t(context, 'product_transactions'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const SizedBox(height: 16),
                  _isProductTxLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _productTxError != null
                          ? Text('${t(context, 'error')}: $_productTxError')
                          : _productTransactions.isEmpty
                              ? Text(t(context, 'no_transactions_found_for_product'))
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
                                          DataCell(Text(tx['created_at'] ?? '')),
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