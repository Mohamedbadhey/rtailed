import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/models/product.dart';
import 'package:retail_management/models/customer.dart';
import 'package:retail_management/models/sale.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/providers/auth_provider.dart'; // Added import for AuthProvider
import 'package:provider/provider.dart'; // Added import for Provider
import 'package:retail_management/widgets/branded_header.dart';
import 'manage_cashiers_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  List<Sale> _recentSales = [];
  List<Product> _lowStockProducts = [];
  Map<String, dynamic> _salesReport = {};
  bool _showCreditSection = false;
  List<Map<String, dynamic>> _creditCustomers = [];
  List<Map<String, dynamic>> _selectedCustomerTransactions = [];
  bool _creditLoading = false;
  String? _creditError;
  String? _selectedCustomerName;
  List<Map<String, dynamic>> _paidCustomerTransactions = [];

  double safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all data in parallel, each with its own error handling
      final futures = await Future.wait([
        _loadSummaryData().catchError((e) { print('Error in _loadSummaryData: $e'); return <String, dynamic>{}; }) as Future<Map<String, dynamic>>,
        _loadRecentSales().catchError((e) { print('Error in _loadRecentSales: $e'); return <Sale>[]; }) as Future<List<Sale>>,
        _loadLowStockProducts().catchError((e) { print('Error in _loadLowStockProducts: $e'); return <Product>[]; }) as Future<List<Product>>,
        ApiService().getCreditReport().catchError((e) { print('Error in getCreditReport: $e'); return <String, dynamic>{}; }) as Future<Map<String, dynamic>>,
        ApiService().getSalesReport().catchError((e) { print('Error in getSalesReport: $e'); return <String, dynamic>{}; }) as Future<Map<String, dynamic>>,
      ]);

      final salesReport = await futures[4] as Map<String, dynamic>? ?? {};
      Map<String, dynamic> creditReport = await futures[3] as Map<String, dynamic>? ?? {};
      double totalCreditAmount = 0.0;
      if (salesReport['outstandingCredits'] != null) {
        totalCreditAmount = double.tryParse(salesReport['outstandingCredits'].toString()) ?? 0.0;
      } else if (creditReport.isNotEmpty && creditReport['summary'] != null && creditReport['summary']['total_credit_amount'] != null) {
        totalCreditAmount = double.tryParse(creditReport['summary']['total_credit_amount'].toString()) ?? 0.0;
      } else if (salesReport['creditSummary'] != null && salesReport['creditSummary']['total_credit_amount'] != null) {
        totalCreditAmount = double.tryParse(salesReport['creditSummary']['total_credit_amount'].toString()) ?? 0.0;
      }

      setState(() {
        _dashboardData = futures[0] as Map<String, dynamic>;
        // Use new backend fields for dashboard
        _dashboardData['totalSales'] = salesReport['totalSales'] ?? 0.0;
        _dashboardData['cashOnHand'] = salesReport['cashInHand'] ?? 0.0;
        _dashboardData['totalCreditAmount'] = totalCreditAmount;
        _dashboardData['paymentMethodBreakdown'] = salesReport['paymentMethodBreakdown'] ?? [];
        _dashboardData['totalProfit'] = salesReport['totalProfit'] ?? 0.0;
        _recentSales = futures[1] as List<Sale>;
        _lowStockProducts = futures[2] as List<Product>;
        _salesReport = salesReport;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Dashboard: Error loading dashboard: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _loadSummaryData() async {
    try {
      print('Dashboard: Loading sales report...');
      final salesReport = await _apiService.getSalesReport();
      print('Dashboard: Sales report loaded: $salesReport');
      final summary = salesReport['summary'] ?? {};
      final totalSales = double.tryParse(summary['total_revenue']?.toString() ?? '') ?? 0.0;
      final totalOrders = summary['total_orders'] ?? 0;
      final averageOrderValue = double.tryParse(summary['average_order_value']?.toString() ?? '') ?? 0.0;
      // For customers and products, still fetch from API
      print('Dashboard: Loading products...');
      final products = await _apiService.getProducts();
      print('Dashboard: Products loaded: ${products.length}');
      print('Dashboard: Loading customers...');
      final customers = await _apiService.getCustomers();
      print('Dashboard: Customers loaded: ${customers.length}');
      final lowStockCount = products.where((p) => p.stockQuantity <= p.lowStockThreshold).length;

      // Calculate total cost of goods sold (COGS) from sales report's productBreakdown
      double totalCost = 0.0;
      if (salesReport['productBreakdown'] != null) {
        for (final product in salesReport['productBreakdown']) {
          final productId = product['id'];
          final quantitySold = double.tryParse(product['quantity_sold']?.toString() ?? '') ?? 0.0;
          final productObj = products.firstWhere(
            (p) => p.id == productId,
            orElse: () => Product(
              id: productId,
              name: product['name'] ?? '',
              description: '',
              sku: '',
              barcode: '',
              categoryId: 0,
              price: 0.0,
              costPrice: 0.0,
              stockQuantity: 0,
              damagedQuantity: 0,
              lowStockThreshold: 0,
              imageUrl: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          totalCost += (productObj.costPrice * quantitySold);
        }
      }
      final profit = totalSales - totalCost;
      print('Dashboard: Calculated totalCost: $totalCost, profit: $profit');

      final summaryData = {
        'totalSales': totalSales,
        'totalOrders': totalOrders,
        'totalCustomers': customers.length,
        'totalProducts': products.length,
        'totalProfit': profit,
        'averageOrderValue': averageOrderValue,
        'lowStockCount': lowStockCount,
      };
      print('Dashboard: Summary data calculated: $summaryData');
      return summaryData;
    } catch (e) {
      print('Dashboard: Error loading summary data: $e');
      return {
        'totalSales': 0.0,
        'totalOrders': 0,
        'totalCustomers': 0,
        'totalProducts': 0,
        'totalProfit': 0.0,
        'averageOrderValue': 0.0,
        'lowStockCount': 0,
      };
    }
  }

  Future<List<Sale>> _loadRecentSales() async {
    try {
      print('Dashboard: Loading recent sales...');
      final sales = await _apiService.getSales();
      print('Dashboard: Recent sales loaded: ${sales.length}');
      for (final sale in sales) {
        print('Sale: id=${sale.id}, totalAmount=${sale.totalAmount}, customerName=${sale.customerName}');
      }
      // Sort by date and take the most recent 5
      sales.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      final recentSales = sales.take(5).toList();
      print('Dashboard: Recent sales (top 5): ${recentSales.length}');
      return recentSales;
    } catch (e) {
      print('Dashboard: Error loading recent sales: $e');
      return [];
    }
  }

  Future<List<Product>> _loadLowStockProducts() async {
    try {
      print('Dashboard: Loading low stock products...');
      final products = await _apiService.getProducts();
      print('Dashboard: Low stock products loaded: ${products.length}');
      final lowStockProducts = products.where((p) => p.stockQuantity <= p.lowStockThreshold).toList();
      print('Dashboard: Low stock products count: ${lowStockProducts.length}');
      return lowStockProducts;
    } catch (e) {
      print('Dashboard: Error loading low stock products: $e');
      return [];
    }
  }

  Future<void> _loadCreditCustomers() async {
    setState(() {
      _creditLoading = true;
      _creditError = null;
    });

    try {
      final customers = await ApiService().getCreditCustomers();
      print('Credit customers data: $customers'); // Debug log
      setState(() {
        _creditCustomers = customers;
        _creditLoading = false;
      });
    } catch (e) {
      print('Error loading credit customers: $e'); // Debug log
      setState(() {
        _creditError = 'Error: $e';
        _creditLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final isCashier = user != null && user.role == 'cashier';
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    print('Dashboard: _dashboardData in build = $_dashboardData');
    // Use new backend fields for dashboard
    final double totalSales = safeToDouble(_dashboardData['totalSales']);
    final int totalOrders = (_dashboardData['totalOrders'] is int) ? _dashboardData['totalOrders'] as int : int.tryParse(_dashboardData['totalOrders']?.toString() ?? '') ?? 0;
    final int totalCustomers = (_dashboardData['totalCustomers'] is int) ? _dashboardData['totalCustomers'] as int : int.tryParse(_dashboardData['totalCustomers']?.toString() ?? '') ?? 0;
    final int totalProducts = (_dashboardData['totalProducts'] is int) ? _dashboardData['totalProducts'] as int : int.tryParse(_dashboardData['totalProducts']?.toString() ?? '') ?? 0;
    final double totalProfit = safeToDouble(_dashboardData['totalProfit']);
    final double averageOrderValue = safeToDouble(_dashboardData['averageOrderValue']);
    final int lowStockCount = (_dashboardData['lowStockCount'] is int) ? _dashboardData['lowStockCount'] as int : int.tryParse(_dashboardData['lowStockCount']?.toString() ?? '') ?? 0;
    final double totalCreditAmount = safeToDouble(_dashboardData['totalCreditAmount']);
    final double cashOnHand = safeToDouble(_dashboardData['cashOnHand']);
    final double receivables = totalCreditAmount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 768;
        final isSmallMobile = constraints.maxWidth <= 480;
        final isTablet = constraints.maxWidth > 768 && constraints.maxWidth <= 1024;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 12 : 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Branded Header
              BrandedHeader(
                subtitle: t(context, 'Monitor your business performance'),
                actions: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadDashboardData,
                        tooltip: t(context, 'Refresh Data'),
                        padding: EdgeInsets.all(isMobile ? 8 : 12),
                        constraints: BoxConstraints(
                          minWidth: isMobile ? 40 : 48,
                          minHeight: isMobile ? 40 : 48,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.credit_card, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showCreditSection = !_showCreditSection;
                          });
                          if (_showCreditSection) {
                            _loadCreditCustomers();
                          }
                        },
                        tooltip: t(context, 'Credit Section'),
                        padding: EdgeInsets.all(isMobile ? 8 : 12),
                        constraints: BoxConstraints(
                          minWidth: isMobile ? 40 : 48,
                          minHeight: isMobile ? 40 : 48,
                        ),
                      ),
                    ),
                  ],
              ),
              SizedBox(height: isSmallMobile ? 12 : (isMobile ? 16 : 24)),
              _buildAccountingSummaryCardsWithValues(isSmallMobile, isMobile, isTablet, totalSales, totalProfit, totalCreditAmount, receivables, cashOnHand),
              SizedBox(height: isSmallMobile ? 12 : (isMobile ? 16 : 24)),
              _buildSummaryCardsWithValues(isSmallMobile, isMobile, isTablet, totalSales, totalOrders, totalCustomers, totalProducts, averageOrderValue, lowStockCount),
              SizedBox(height: isSmallMobile ? 12 : (isMobile ? 16 : 24)),
              _buildCharts(isSmallMobile, isMobile, isTablet),
              SizedBox(height: isSmallMobile ? 12 : (isMobile ? 16 : 24)),
              _buildRecentActivity(isSmallMobile, isMobile),
              SizedBox(height: isSmallMobile ? 12 : (isMobile ? 16 : 24)),
              _buildLowStockAlert(isSmallMobile, isMobile),
              if (_showCreditSection) ...[
                const SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(isSmallMobile ? 10 : (isMobile ? 12 : 16)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: isSmallMobile ? 6 : 10,
                        offset: Offset(0, isSmallMobile ? 1 : 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.credit_card, color: Colors.orange, size: isSmallMobile ? 20 : 24),
                          SizedBox(width: isSmallMobile ? 6 : 8),
                          Text(
                            t(context, 'Credit Customers'),
                            style: TextStyle(
                              fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallMobile ? 12 : 16),
                      _creditLoading
                          ? Center(child: CircularProgressIndicator())
                          : _creditError != null
                              ? Text(_creditError!, style: TextStyle(color: Colors.red))
                              : _creditCustomers.isEmpty
                                  ? Text(t(context, 'No credit customers found.'))
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        columnSpacing: isSmallMobile ? 8 : 16,
                                        columns: [
                                          DataColumn(
                                            label: Text(
                                              'Customer',
                                              style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Phone',
                                              style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Credit Sales',
                                              style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Outstanding',
                                              style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Email',
                                              style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Actions',
                                              style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                            ),
                                          ),
                                        ],
                                        rows: _creditCustomers.map((customer) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(
                                                customer['name'] ?? '',
                                                style: TextStyle(fontSize: isSmallMobile ? 9 : 11),
                                              )),
                                              DataCell(Text(
                                                customer['phone'] ?? '',
                                                style: TextStyle(fontSize: isSmallMobile ? 9 : 11),
                                              )),
                                              DataCell(Text(
                                                '${customer['credit_sales_count'] ?? 0}',
                                                style: TextStyle(fontSize: isSmallMobile ? 9 : 11),
                                              )),
                                              DataCell(Text(
                                                '\$${(double.tryParse((customer['outstanding_amount'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: isSmallMobile ? 9 : 11),
                                              )),
                                              DataCell(Text(
                                                customer['email'] ?? '',
                                                style: TextStyle(fontSize: isSmallMobile ? 9 : 11),
                                              )),
                                              DataCell(
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.visibility,
                                                    size: isSmallMobile ? 18 : 20,
                                                  ),
                                                  onPressed: () => _showCustomerTransactions(customer),
                                                  padding: EdgeInsets.all(isSmallMobile ? 4 : 8),
                                                  constraints: BoxConstraints(
                                                    minWidth: isSmallMobile ? 32 : 40,
                                                    minHeight: isSmallMobile ? 32 : 40,
                                                  ),
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
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountingSummaryCardsWithValues(bool isSmallMobile, bool isMobile, bool isTablet, double totalSales, double totalProfit, double totalCreditAmount, double receivables, double cashOnHand) {
    if (isSmallMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.8,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        children: [
          _buildSummaryCard(t(context, 'Total Sales'), '\$${totalSales.toStringAsFixed(2)}', Icons.attach_money, Colors.green, '', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Outstanding Credits'), '\$${receivables.toStringAsFixed(2)}', Icons.credit_card, Colors.orange, t(context, 'Receivables'), isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Cash on Hand'), '\$${cashOnHand.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.teal, t(context, 'Available'), isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Profit'), '\$${totalProfit.toStringAsFixed(2)}', Icons.trending_up, Colors.deepPurple, t(context, 'Gross profit'), isSmallMobile, isMobile),
        ],
      );
    } else if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          _buildSummaryCard(t(context, 'Total Sales'), '\$${totalSales.toStringAsFixed(2)}', Icons.attach_money, Colors.green, '', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Outstanding Credits'), '\$${receivables.toStringAsFixed(2)}', Icons.credit_card, Colors.orange, t(context, 'Receivables'), isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Cash on Hand'), '\$${cashOnHand.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.teal, t(context, 'Available'), isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Profit'), '\$${totalProfit.toStringAsFixed(2)}', Icons.trending_up, Colors.deepPurple, t(context, 'Gross profit'), isSmallMobile, isMobile),
        ],
      );
    } else if (isTablet) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildSummaryCard(t(context, 'Total Sales'), '\$${totalSales.toStringAsFixed(2)}', Icons.attach_money, Colors.green, '', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Outstanding Credits'), '\$${receivables.toStringAsFixed(2)}', Icons.credit_card, Colors.orange, t(context, 'Receivables'), isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Cash on Hand'), '\$${cashOnHand.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.teal, t(context, 'Available'), isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Profit'), '\$${totalProfit.toStringAsFixed(2)}', Icons.trending_up, Colors.deepPurple, t(context, 'Gross profit'), isSmallMobile, isMobile),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: _buildSummaryCard(t(context, 'Total Sales'), '\$${totalSales.toStringAsFixed(2)}', Icons.attach_money, Colors.green, '', isSmallMobile, isMobile)),
          const SizedBox(width: 16),
          Expanded(child: _buildSummaryCard(t(context, 'Outstanding Credits'), '\$${receivables.toStringAsFixed(2)}', Icons.credit_card, Colors.orange, t(context, 'Receivables'), isSmallMobile, isMobile)),
          const SizedBox(width: 16),
          Expanded(child: _buildSummaryCard(t(context, 'Cash on Hand'), '\$${cashOnHand.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.teal, t(context, 'Available'), isSmallMobile, isMobile)),
          const SizedBox(width: 16),
          Expanded(child: _buildSummaryCard(t(context, 'Profit'), '\$${totalProfit.toStringAsFixed(2)}', Icons.trending_up, Colors.deepPurple, t(context, 'Gross profit'), isSmallMobile, isMobile)),
        ],
      );
    }
  }

  Widget _buildSummaryCardsWithValues(bool isSmallMobile, bool isMobile, bool isTablet, double totalSales, int totalOrders, int totalCustomers, int totalProducts, double averageOrderValue, int lowStockCount) {
    if (isSmallMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.8,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        children: [
          _buildSummaryCard(t(context, 'Total Sales'), '\$${totalSales.toStringAsFixed(2)}', Icons.attach_money, Colors.green, '$totalOrders orders', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Total Orders'), '$totalOrders', Icons.shopping_cart, Colors.blue, '${averageOrderValue.toStringAsFixed(2)} avg', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Total Customers'), '$totalCustomers', Icons.people, Colors.orange, '$totalCustomers active', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Total Products'), '$totalProducts', Icons.inventory, Colors.purple, '$lowStockCount low stock', isSmallMobile, isMobile),
        ],
      );
    } else if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          _buildSummaryCard(t(context, 'Total Sales'), '\$${totalSales.toStringAsFixed(2)}', Icons.attach_money, Colors.green, '$totalOrders orders', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Total Orders'), '$totalOrders', Icons.shopping_cart, Colors.blue, '${averageOrderValue.toStringAsFixed(2)} avg', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Total Customers'), '$totalCustomers', Icons.people, Colors.orange, '$totalCustomers active', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Total Products'), '$totalProducts', Icons.inventory, Colors.purple, '$lowStockCount low stock', isSmallMobile, isMobile),
        ],
      );
    } else if (isTablet) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildSummaryCard(t(context, 'Total Sales'), '\$${totalSales.toStringAsFixed(2)}', Icons.attach_money, Colors.green, '$totalOrders orders', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Total Orders'), '$totalOrders', Icons.shopping_cart, Colors.blue, '${averageOrderValue.toStringAsFixed(2)} avg', isSmallMobile, isMobile),
          _buildSummaryCard(t(context, 'Total Products'), '$totalProducts', Icons.inventory, Colors.purple, '$lowStockCount low stock', isSmallMobile, isMobile),
        ],
      );
          } else {
        return Row(
          children: [
            Expanded(child: _buildSummaryCard(t(context, 'Total Sales'), '\$${totalSales.toStringAsFixed(2)}', Icons.attach_money, Colors.green, '$totalOrders orders', isSmallMobile, isMobile)),
            const SizedBox(width: 16),
            Expanded(child: _buildSummaryCard(t(context, 'Total Orders'), '$totalOrders', Icons.shopping_cart, Colors.blue, '${averageOrderValue.toStringAsFixed(2)} avg', isSmallMobile, isMobile)),
            const SizedBox(width: 16),
            Expanded(child: _buildSummaryCard(t(context, 'Total Customers'), '$totalCustomers', Icons.people, Colors.orange, '$totalCustomers active', isSmallMobile, isMobile)),
            const SizedBox(width: 16),
            Expanded(child: _buildSummaryCard(t(context, 'Total Products'), '$totalProducts', Icons.inventory, Colors.purple, '$lowStockCount low stock', isSmallMobile, isMobile)),
          ],
        );
    }
  }

  Widget _buildCharts(bool isSmallMobile, bool isMobile, bool isTablet) {
    final List<dynamic> salesByPeriod = _salesReport['salesByPeriod'] ?? [];
    final List<dynamic> paymentMethods = _dashboardData['paymentMethodBreakdown'] ?? _salesReport['paymentMethods'] ?? [];

    double totalRevenue = 0.0;
    for (final period in salesByPeriod) {
      final y = safeToDouble(period['total_revenue']);
      totalRevenue += y;
    }

    double totalPaymentAmount = 0.0;
    for (final method in paymentMethods) {
      totalPaymentAmount += safeToDouble(method['total_amount']);
    }

      return Column(
        children: [
        if (salesByPeriod.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(isSmallMobile ? 10 : (isMobile ? 12 : 16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: isSmallMobile ? 6 : 10,
                  offset: Offset(0, isSmallMobile ? 1 : 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart, color: Colors.blue, size: isSmallMobile ? 20 : 24),
                    SizedBox(width: isSmallMobile ? 6 : 8),
                    Text(
                      t(context, 'Sales Overview'),
                      style: TextStyle(
                        fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 12 : 16),
                SizedBox(
                  height: isSmallMobile ? 120 : (isMobile ? 160 : 300),
                    child: LineChart(
                      LineChartData(
                      gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text('\$${value.toInt()}');
                            },
                          ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                              if (value.toInt() < salesByPeriod.length) {
                                final period = salesByPeriod[value.toInt()];
                                final date = period['period'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    date.toString().split('-').last,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const Text('');
                              },
                            ),
                          ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                      borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                          spots: salesByPeriod.asMap().entries.map((entry) {
                            final index = entry.key;
                            final period = entry.value;
                            final y = safeToDouble(period['total_revenue']);
                            return FlSpot(index.toDouble(), y);
                          }).toList(),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                          dotData: FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (paymentMethods.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(isSmallMobile ? 10 : (isMobile ? 12 : 16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: isSmallMobile ? 6 : 10,
                  offset: Offset(0, isSmallMobile ? 1 : 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart, color: Colors.green, size: isSmallMobile ? 20 : 24),
                    SizedBox(width: isSmallMobile ? 6 : 8),
                    Text(
                      t(context, 'Revenue Distribution'),
                      style: TextStyle(
                        fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 12 : 16),
                                    SizedBox(
                      height: isSmallMobile ? 120 : (isMobile ? 160 : 300),
                      child: PieChart(
                    PieChartData(
                      sections: paymentMethods.map((method) {
                        final value = safeToDouble(method['total_amount']);
                        final percentage = totalPaymentAmount > 0 ? (value / totalPaymentAmount) * 100 : 0;
                        return PieChartSectionData(
                          value: value,
                          title: '${percentage.toStringAsFixed(1)}%',
                          color: _getPaymentMethodColor(method['payment_method']),
                          radius: isSmallMobile ? 40 : (isMobile ? 50 : 80),
                          titleStyle: TextStyle(
                            fontSize: isSmallMobile ? 9 : 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      centerSpaceRadius: isSmallMobile ? 20 : (isMobile ? 25 : 40),
                              ),
                            ),
                          ),
                SizedBox(height: isSmallMobile ? 12 : 16),
                Wrap(
                  spacing: isSmallMobile ? 12 : 16,
                  runSpacing: isSmallMobile ? 6 : 8,
                  children: paymentMethods.map((method) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isSmallMobile ? 10 : 12,
                          height: isSmallMobile ? 10 : 12,
                          decoration: BoxDecoration(
                            color: _getPaymentMethodColor(method['payment_method']),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: isSmallMobile ? 3 : 4),
                        Text(
                          '${method['payment_method']}: \$${safeToDouble(method['total_amount']).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
                      ),
                    ),
                  ],
        ],
      );
  }

  Widget _buildRecentActivity(bool isSmallMobile, bool isMobile) {
    print('Dashboard: recentSales=${_recentSales.length}');
    return Container(
      padding: EdgeInsets.all(isSmallMobile ? 10 : (isMobile ? 12 : 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isSmallMobile ? 6 : 10,
            offset: Offset(0, isSmallMobile ? 1 : 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: Colors.orange, size: isSmallMobile ? 20 : 24),
              SizedBox(width: isSmallMobile ? 6 : 8),
              Text(
                t(context, 'Recent Sales'),
                style: TextStyle(
                  fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallMobile ? 12 : 16),
            if (_recentSales.isEmpty)
              Center(
                child: Column(
                  children: [
                  Icon(Icons.receipt, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                    Text(
                      t(context, 'No recent sales'),
                    style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentSales.length,
                itemBuilder: (context, index) {
                  final sale = _recentSales[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.shopping_cart, color: Colors.white),
                    ),
                    title: Text('Sale #${sale.id}'),
                    subtitle: Text('${sale.customerName} • ${_formatDate(sale.createdAt)}'),
                    trailing: Text(
                      '\$${sale.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      ),
                    ),
                  );
                },
              ),
          ],
      ),
    );
  }

  Widget _buildLowStockAlert(bool isSmallMobile, bool isMobile) {
    if (_lowStockProducts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(isSmallMobile ? 10 : (isMobile ? 12 : 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isSmallMobile ? 6 : 10,
            offset: Offset(0, isSmallMobile ? 1 : 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: isSmallMobile ? 20 : 24),
              const SizedBox(width: 8),
                Text(
                  t(context, 'Low Stock Alert'),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lowStockProducts.length,
              itemBuilder: (context, index) {
                final product = _lowStockProducts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.inventory, color: Colors.white),
                  ),
                  title: Text(product.name),
                  subtitle: Text('Stock: ${product.stockQuantity} (Threshold: ${product.lowStockThreshold})'),
                  trailing: Text(
                    'Low Stock',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, String subtitle, bool isSmallMobile, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isSmallMobile ? 6 : (isMobile ? 8 : 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isSmallMobile ? 4 : 10,
            offset: Offset(0, isSmallMobile ? 1 : 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                ),
                child: Icon(icon, color: color, size: isSmallMobile ? 16 : 18),
              ),
              SizedBox(width: isSmallMobile ? 6 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallMobile ? 10 : (isMobile ? 11 : 14),
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: isSmallMobile ? 2 : 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isSmallMobile ? 13 : (isMobile ? 15 : 18),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: isSmallMobile ? 4 : 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: isSmallMobile ? 8 : (isMobile ? 9 : 12),
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getPaymentMethodColor(String? method) {
    switch (method?.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'evc':
        return Colors.purple;
      case 'credit':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return t(context, 'Unknown');
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return t(context, 'Today');
    } else if (difference.inDays == 1) {
      return t(context, 'Yesterday');
    } else {
      return '${difference.inDays} ${t(context, 'days ago')}';
    }
  }

  void _showCustomerTransactions(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CustomerCreditTransactionsDialog(
          customer: customer,
          apiService: _apiService,
        );
      },
    ).then((_) {
      // Reload credit customers when dialog is closed
      if (_showCreditSection) {
        _loadCreditCustomers();
      }
    });
  }
} 

class CustomerCreditTransactionsDialog extends StatefulWidget {
  final Map<String, dynamic> customer;
  final ApiService apiService;

  const CustomerCreditTransactionsDialog({
    super.key,
    required this.customer,
    required this.apiService,
  });

  @override
  State<CustomerCreditTransactionsDialog> createState() => _CustomerCreditTransactionsDialogState();
}

class _CustomerCreditTransactionsDialogState extends State<CustomerCreditTransactionsDialog> {
  bool _isLoading = true;
  Map<String, dynamic> _transactionsData = {};
  String? _error;
  final TextEditingController _paymentAmountController = TextEditingController();
  int? _selectedSaleId;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _paymentAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final customerId = widget.customer['id'];
      final data = await widget.apiService.getCustomerCreditTransactions(customerId);
      setState(() {
        _transactionsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading transactions: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _makePayment(int saleId, double originalAmount, double outstandingAmount, String paymentMethod) async {
    final amount = double.tryParse(_paymentAmountController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount')),
      );
      return;
    }

    if (amount > outstandingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment amount cannot exceed outstanding amount (\$${outstandingAmount.toStringAsFixed(2)})')),
      );
      return;
    }

    try {
      await widget.apiService.payCreditSale(saleId, amount, paymentMethod: paymentMethod);
      
      // Clear form
      _paymentAmountController.clear();
      _selectedSaleId = null;
      
      // Reload transactions
      await _loadTransactions();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording payment: $e')),
      );
    }
  }

  void _showPaymentDialog(int saleId, double originalAmount, double outstandingAmount) {
    _selectedSaleId = saleId;
    _paymentAmountController.text = outstandingAmount.toString();
    
    // Use the same payment methods as POS, excluding credit
    final List<String> _paymentMethods = [
      'evc',
      'edahab', 
      'merchant',
    ];
    String _selectedPaymentMethod = 'evc';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Record Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Original Credit: \$${originalAmount.toStringAsFixed(2)}'),
                  Text('Outstanding: \$${outstandingAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _paymentAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Payment Amount',
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedPaymentMethod,
                      underline: const SizedBox(),
                      isExpanded: true,
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem<String>(
                          value: method,
                          child: Text(
                            method[0].toUpperCase() + method.substring(1),
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _makePayment(saleId, originalAmount, outstandingAmount, _selectedPaymentMethod);
                  },
                  child: const Text('Record Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return Dialog(
      child: Container(
        width: isMobile ? double.infinity : 800,
        height: isMobile ? double.infinity : 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Credit Transactions - ${widget.customer['name']}',
                    style: const TextStyle(
                      fontSize: 18,
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
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadTransactions,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards
                      _buildSummaryCards(),
                      const SizedBox(height: 16),
                      
                      // All Transactions (Credit Sales + Payments in chronological order)
                      _buildAllTransactionsSection(),
                      const SizedBox(height: 16),
                      
                      // Credit Sales
                      _buildCreditSalesSection(),
                      const SizedBox(height: 16),
                      
                      // Payment History
                      _buildPaymentHistorySection(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _transactionsData['summary'] ?? {};
    final totalCredit = summary['total_credit_amount'] ?? 0.0;
    final totalPaid = summary['total_paid_amount'] ?? 0.0;
    final totalOutstanding = summary['total_outstanding'] ?? 0.0;
    final fullyPaidCredits = summary['fully_paid_credits'] ?? 0;
    final partiallyPaidCredits = summary['partially_paid_credits'] ?? 0;
    final unpaidCredits = summary['unpaid_credits'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Credit',
                '\$${totalCredit.toStringAsFixed(2)}',
                Icons.credit_card,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Total Paid',
                '\$${totalPaid.toStringAsFixed(2)}',
                Icons.payment,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Outstanding',
                '\$${totalOutstanding.toStringAsFixed(2)}',
                Icons.warning,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Fully Paid Credits',
                '$fullyPaidCredits',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Partially Paid',
                '$partiallyPaidCredits',
                Icons.pending,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Unpaid Credits',
                '$unpaidCredits',
                Icons.error,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTransactionsSection() {
    final allTransactions = _transactionsData['all_transactions'] ?? [];
    
    // Sort transactions by priority: unpaid first, then partially paid, then fully paid, then by date
    allTransactions.sort((a, b) {
      final aIsCreditSale = a['transaction_type'] == 'credit_sale';
      final bIsCreditSale = b['transaction_type'] == 'credit_sale';
      
      if (aIsCreditSale && bIsCreditSale) {
        // Both are credit sales - sort by payment status priority
        final aOutstanding = double.tryParse(a['outstanding_amount']?.toString() ?? '0') ?? 0;
        final bOutstanding = double.tryParse(b['outstanding_amount']?.toString() ?? '0') ?? 0;
        
        if (aOutstanding > 0 && bOutstanding > 0) {
          // Both have outstanding amounts - sort by amount (highest first)
          return bOutstanding.compareTo(aOutstanding);
        } else if (aOutstanding > 0) {
          return -1; // A has outstanding, B doesn't - A comes first
        } else if (bOutstanding > 0) {
          return 1; // B has outstanding, A doesn't - B comes first
        } else {
          // Both fully paid - sort by date (newest first)
          final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
          return dateB.compareTo(dateA);
        }
      } else if (aIsCreditSale) {
        return -1; // Credit sales come before payments
      } else if (bIsCreditSale) {
        return 1; // Credit sales come before payments
      } else {
        // Both are payments - sort by date (newest first)
        final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'All Transactions (${allTransactions.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Transactions are ordered by priority: Unpaid credits first, then partially paid, then fully paid. Payments are shown below their corresponding credit sales.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (allTransactions.isEmpty)
              const Center(
                child: Text('No transactions found'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allTransactions.length,
                itemBuilder: (context, index) {
                  final transaction = allTransactions[index];
                  final isCreditSale = transaction['transaction_type'] == 'credit_sale';
                  final isPayment = transaction['transaction_type'] == 'payment';
                  final isCreditPayment = transaction['transaction_type'] == 'credit_payment';

                  if (isCreditSale) {
                    final sale = transaction;
                    final originalAmount = double.tryParse(sale['total_amount']?.toString() ?? '0') ?? 0.0;
                    final totalPaid = double.tryParse(sale['total_paid']?.toString() ?? '0') ?? 0.0;
                    // Use backend calculated outstanding amount, fallback to manual calculation
                    final outstanding = double.tryParse(sale['outstanding_amount']?.toString() ?? '0') ?? (originalAmount - totalPaid);
                    final isFullyPaid = sale['is_fully_paid'] ?? (outstanding <= 0);
                    final hasOutstanding = outstanding > 0;
                    
                    // Get partial payments for this credit sale
                    final saleId = sale['id'];
                    final partialPayments = allTransactions.where((t) => 
                      t['transaction_type'] == 'payment' && 
                      t['parent_sale_id'] == saleId
                    ).toList();
                    
                    // Sort partial payments by date (newest first)
                    partialPayments.sort((a, b) {
                      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
                      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
                      return dateB.compareTo(dateA);
                    });

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: hasOutstanding 
                              ? [Colors.red[50]!, Colors.red[100]!]
                              : [Colors.green[50]!, Colors.green[100]!],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row with Status
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: hasOutstanding ? Colors.red : Colors.green,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      hasOutstanding ? Icons.warning : Icons.check_circle,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Credit Sale #${sale['id']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'Date: ${_formatDate(DateTime.tryParse(sale['created_at'] ?? ''))}',
                                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                        ),
                                        Text(
                                          'Cashier: ${sale['cashier_name'] ?? 'Unknown'}',
                                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: hasOutstanding ? Colors.red : Colors.green,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (hasOutstanding ? Colors.red : Colors.green).withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      hasOutstanding ? 'UNPAID' : 'PAID',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Product Details Section
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.shopping_cart, color: Colors.blue[600], size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Products Sold on Credit',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Display actual product details
                                    if (sale['products'] != null && (sale['products'] as List).isNotEmpty) ...[
                                      ...(sale['products'] as List).map((product) {
                                        final productName = product['product_name'] ?? 'Unknown Product';
                                        final quantity = int.tryParse(product['quantity'].toString()) ?? 0;
                                        final unitPrice = double.tryParse(product['unit_price'].toString()) ?? 0.0;
                                        final totalPrice = double.tryParse(product['total_price'].toString()) ?? 0.0;
                                        final productImage = product['product_image'];
                                        
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue[100]!),
                                          ),
                                          child: Row(
                                            children: [
                                              // Product Image (if available)
                                              if (productImage != null && productImage.isNotEmpty)
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                    image: DecorationImage(
                                                      image: NetworkImage(productImage),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                )
                                              else
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[200],
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(
                                                    Icons.image,
                                                    color: Colors.blue[600],
                                                    size: 20,
                                                  ),
                                                ),
                                              
                                              const SizedBox(width: 12),
                                              
                                              // Product Details
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      productName,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: Colors.blue[700],
                                                      ),
                                                    ),
                                                    Text(
                                                      'Qty: $quantity × \$${unitPrice.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.blue[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              
                                              // Total Price
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '\$${totalPrice.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Colors.blue[700],
                                                    ),
                                                  ),
                                                  Text(
                                                    'Total',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.blue[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      
                                      const SizedBox(height: 8),
                                      
                                      // Credit Sale Total Summary
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue[200]!),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Credit Sale Total:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[700],
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              '\$${originalAmount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      // Fallback if no products found
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey[300]!),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Credit Sale Total: \$${originalAmount.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Product details not available',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Amount Summary Row
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: hasOutstanding ? Colors.red[200]! : Colors.green[200]!,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Original Amount',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '\$${originalAmount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                              color: hasOutstanding ? Colors.red[700] : Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 50,
                                      color: Colors.grey[300],
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Total Paid',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '\$${totalPaid.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 50,
                                      color: Colors.grey[300],
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Outstanding',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '\$${outstanding.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: hasOutstanding ? Colors.red[600] : Colors.green[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Debug Information (can be removed later)
                              if (true) ...[ // Set to false to hide debug info
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Debug Info:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Raw: original=${sale['total_amount']}, paid=${sale['total_paid']}, outstanding=${sale['outstanding_amount']}, isFullyPaid=${sale['is_fully_paid']}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'Calculated: outstanding=${(originalAmount - totalPaid).toStringAsFixed(2)}, hasOutstanding=$hasOutstanding',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 16),
                              
                              // Partial Payments Section
                              if (partialPayments.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.history, color: Colors.blue[600], size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Payment History (${partialPayments.length} payments)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[700],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...partialPayments.map((payment) {
                                        final amount = double.tryParse(payment['total_amount'].toString()) ?? 0.0;
                                        final paymentMethod = payment['payment_method'] ?? 'Unknown';
                                        final paymentDate = _formatDate(DateTime.tryParse(payment['created_at'] ?? ''));
                                        final paymentCashier = payment['cashier_name'] ?? 'Unknown';
                                        
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue[100]!),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[400],
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '\$${amount.toStringAsFixed(2)} via ${paymentMethod.toUpperCase()}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.blue[700],
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Date: $paymentDate | Cashier: $paymentCashier',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.blue[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.green[600],
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              
                              // Outstanding Balance Warning (if any)
                              if (hasOutstanding) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.red[600], size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Outstanding Balance: \$${outstanding.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              
                              // Action Buttons Row - ALWAYS SHOW RECORD PAYMENT
                              Row(
                                children: [
                                  // Record Payment Button - Always Visible
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showPaymentDialog(
                                        sale['id'],
                                        originalAmount,
                                        outstanding,
                                      ),
                                      icon: const Icon(Icons.payment, size: 20),
                                      label: Text(
                                        hasOutstanding ? 'Record Payment' : 'Add Another Payment',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: hasOutstanding ? Colors.green[600] : Colors.blue[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 3,
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 12),
                                  
                                  // Status Display
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: hasOutstanding ? Colors.red[100] : Colors.green[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: hasOutstanding ? Colors.red[300]! : Colors.green[300]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            hasOutstanding ? Icons.warning : Icons.check_circle,
                                            color: hasOutstanding ? Colors.red[600] : Colors.green[600],
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            hasOutstanding ? 'Payment Required' : 'Credit Fully Paid',
                                            style: TextStyle(
                                              color: hasOutstanding ? Colors.red[700] : Colors.green[700],
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
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
                  } else if (isPayment) {
                    final payment = transaction;
                    final amount = double.tryParse(payment['total_amount'].toString()) ?? 0.0;
                    final originalAmount = double.tryParse(payment['original_credit_amount'].toString()) ?? 0.0;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.green[50],
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[600],
                          child: Icon(Icons.payment, color: Colors.white, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text(
                              'Payment Received',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[600],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PAID',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'For Credit Sale #${payment['parent_sale_id']}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              'Amount: \$${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.green[600],
                              ),
                            ),
                            Text(
                              'Method: ${payment['payment_method'].toString().toUpperCase()}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            Text(
                              'Date: ${_formatDate(DateTime.tryParse(payment['created_at'] ?? ''))}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            Text(
                              'Cashier: ${payment['cashier_name'] ?? 'Unknown'}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green[700],
                              ),
                            ),
                            Text(
                              'Original: \$${originalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (isCreditPayment) {
                    final creditPayment = transaction;
                    final amount = double.tryParse(creditPayment['total_amount'].toString()) ?? 0.0;
                    final originalAmount = double.tryParse(creditPayment['original_credit_amount'].toString()) ?? 0.0;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.payment, color: Colors.white),
                        ),
                        title: Text('Credit Payment for Sale #${creditPayment['parent_sale_id']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Amount: \$${amount.toStringAsFixed(2)}'),
                            Text('Method: ${creditPayment['payment_method']}'),
                            Text('Date: ${_formatDate(DateTime.tryParse(creditPayment['created_at'] ?? ''))}'),
                            Text('Cashier: ${creditPayment['cashier_name'] ?? 'Unknown'}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              'Original: \$${originalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink(); // Should not happen for valid data
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditSalesSection() {
    final creditSales = _transactionsData['credit_sales'] ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Credit Sales (${creditSales.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (creditSales.isEmpty)
              const Center(
                child: Text('No credit sales found'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: creditSales.length,
                itemBuilder: (context, index) {
                  final sale = creditSales[index];
                  final originalAmount = double.tryParse(sale['total_amount'].toString()) ?? 0.0;
                  final totalPaid = double.tryParse(sale['total_paid'].toString()) ?? 0.0;
                  final outstanding = double.tryParse(sale['outstanding_amount'].toString()) ?? 0.0;
                  final isFullyPaid = sale['is_fully_paid'] ?? false;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
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
                                      'Sale #${sale['id']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Date: ${_formatDate(DateTime.tryParse(sale['created_at'] ?? ''))}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Cashier: ${sale['cashier_name'] ?? 'Unknown'}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${originalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (totalPaid > 0)
                                    Text(
                                      'Paid: \$${totalPaid.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (outstanding > 0)
                                    Text(
                                      'Outstanding: \$${outstanding.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (!isFullyPaid) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _showPaymentDialog(
                                    sale['id'],
                                    originalAmount,
                                    outstanding,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Record Payment'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistorySection() {
    final payments = _transactionsData['payments'] ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Payment History (${payments.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (payments.isEmpty)
              const Center(
                child: Text('No payment history found'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  final amount = double.tryParse(payment['total_amount'].toString()) ?? 0.0;
                  final originalAmount = double.tryParse(payment['original_credit_amount'].toString()) ?? 0.0;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.payment, color: Colors.white),
                      ),
                      title: Text('Payment for Sale #${payment['parent_sale_id']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount: \$${amount.toStringAsFixed(2)}'),
                          Text('Method: ${payment['payment_method']}'),
                          Text('Date: ${_formatDate(DateTime.tryParse(payment['created_at'] ?? ''))}'),
                          Text('Cashier: ${payment['cashier_name'] ?? 'Unknown'}'),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'Original: \$${originalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
} 