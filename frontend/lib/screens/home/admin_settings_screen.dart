import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/screens/home/settings_screen.dart';
import 'package:retail_management/screens/home/damaged_products_screen.dart';
import 'package:retail_management/screens/home/sales_management_screen.dart';
import 'package:retail_management/screens/accounting/accounting_dashboard_screen.dart';
import 'package:retail_management/screens/home/store_management_screen.dart';
import 'package:retail_management/screens/home/customer_invoice_screen.dart';

import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/services/api_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _creditCustomers = [];
  bool _creditLoading = false;
  String? _creditError;
  bool _showCreditSection = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final isAdmin = user != null && user.role == 'admin';
    final isCashier = user != null && user.role == 'cashier';
    
    // Number of tabs: General Settings, Damages, Credit, Sales Management, Store Management (not for cashiers), Customer Invoice, and optionally Accounting for admins
    final tabCount = isCashier ? 5 : (isAdmin ? 7 : 6);
    _tabController = TabController(length: tabCount, vsync: this);
    _loadCreditCustomers();
  }

  Future<void> _loadCreditCustomers() async {
    setState(() {
      _creditLoading = true;
      _creditError = null;
    });

    try {
      final customers = await _apiService.getCreditCustomers();
      setState(() {
        _creditCustomers = customers;
        _creditLoading = false;
      });
    } catch (e) {
      setState(() {
        _creditError = 'Error loading credit customers: $e';
        _creditLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user != null && user.role == 'admin';
    final isCashier = user != null && user.role == 'cashier';

    // Responsive breakpoints
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    final isTablet = MediaQuery.of(context).size.width > 768 && MediaQuery.of(context).size.width <= 1200;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSmallMobile ? 'Settings' : t(context, 'Settings'),
          style: TextStyle(fontSize: isSmallMobile ? 16 : 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isSmallMobile || isMobile,
          labelPadding: EdgeInsets.symmetric(
            horizontal: isSmallMobile ? 8 : (isMobile ? 12 : 16),
            vertical: isSmallMobile ? 4 : (isMobile ? 6 : 8),
          ),
          indicatorSize: isSmallMobile || isMobile ? TabBarIndicatorSize.label : TabBarIndicatorSize.tab,
          tabs: [
            Tab(
              icon: Icon(
                Icons.settings,
                size: isSmallMobile ? 18 : (isMobile ? 20 : 24),
              ),
              text: isSmallMobile ? 'General' : t(context, 'General'),
            ),
            Tab(
              icon: Icon(
                Icons.warning,
                size: isSmallMobile ? 18 : (isMobile ? 20 : 24),
              ),
              text: isSmallMobile ? 'Damages' : t(context, 'Damages'),
            ),
            Tab(
              icon: Icon(
                Icons.credit_card,
                size: isSmallMobile ? 18 : (isMobile ? 20 : 24),
              ),
              text: isSmallMobile ? 'Credit' : t(context, 'Credit Management'),
            ),
            Tab(
              icon: Icon(
                Icons.receipt,
                size: isSmallMobile ? 18 : (isMobile ? 20 : 24),
              ),
              text: isSmallMobile ? 'Sales' : t(context, 'Sales Management'),
            ),
            if (!isCashier)
              Tab(
                icon: Icon(
                  Icons.store,
                  size: isSmallMobile ? 18 : (isMobile ? 20 : 24),
                ),
                text: isSmallMobile ? 'Stores' : t(context, 'Store Management'),
              ),
            Tab(
              icon: Icon(
                Icons.receipt_long,
                size: isSmallMobile ? 18 : (isMobile ? 20 : 24),
              ),
              text: isSmallMobile ? 'Invoice' : t(context, 'Customer Invoice'),
            ),
            if (isAdmin)
              Tab(
                icon: Icon(
                  Icons.account_balance,
                  size: isSmallMobile ? 18 : (isMobile ? 20 : 24),
                ),
                text: isSmallMobile ? 'Accounting' : t(context, 'Accounting'),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // General Settings
          const SettingsScreen(),
          
          // Damages
          const DamagedProductsScreen(),
          
          // Credit
          _buildCreditTab(),
          
          // Sales Management
          const SalesManagementScreen(),
          
          // Store Management (not for cashiers)
          if (!isCashier)
            const StoreManagementScreen(),
          
          // Customer Invoice
          const CustomerInvoiceScreen(),
          
          // Accounting (only for admins)
          if (isAdmin)
            const AccountingDashboardScreen(),
        ],
      ),
    );
  }

  Widget _buildCreditTab() {
    // Responsive breakpoints
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 12 : 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 14 : 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.credit_card, 
                        color: Colors.orange,
                        size: isSmallMobile ? 20 : (isMobile ? 22 : 24),
                      ),
                      SizedBox(width: isSmallMobile ? 6 : 8),
                      Expanded(
                        child: Text(
                          isSmallMobile ? 'Credit Management' : t(context, 'Credit Management'),
                          style: TextStyle(
                            fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.credit_card, 
                            color: Colors.orange,
                            size: isSmallMobile ? 18 : 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _showCreditSection = !_showCreditSection;
                            });
                            if (_showCreditSection) {
                              _loadCreditCustomers();
                            }
                          },
                          tooltip: 'Toggle Credit Section',
                          padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
                          constraints: BoxConstraints(
                            minWidth: isSmallMobile ? 32 : 40,
                            minHeight: isSmallMobile ? 32 : 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showCreditSection) ...[
                    SizedBox(height: isSmallMobile ? 12 : 16),
                    _creditLoading
                        ? Center(child: CircularProgressIndicator())
                        : _creditError != null
                            ? Container(
                                padding: EdgeInsets.all(isSmallMobile ? 12 : 16),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Text(
                                  _creditError!,
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: isSmallMobile ? 12 : 14,
                                  ),
                                ),
                              )
                            : _creditCustomers.isEmpty
                                ? Container(
                                    padding: EdgeInsets.all(isSmallMobile ? 16 : 20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                                      border: Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: Center(
                                      child: Text(
                                        t(context, 'No credit customers found.'),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: isSmallMobile ? 12 : 14,
                                        ),
                                      ),
                                    ),
                                  )
                                : isMobile
                                    ? _buildMobileCreditCustomersList(_creditCustomers, isSmallMobile)
                                : SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Customer')),
                                        DataColumn(label: Text('Phone')),
                                        DataColumn(label: Text('Credit Sales')),
                                        DataColumn(label: Text('Outstanding')),
                                        DataColumn(label: Text('Email')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows: _creditCustomers.map((customer) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(customer['name'] ?? '')),
                                            DataCell(Text(customer['phone'] ?? '')),
                                            DataCell(Text('${customer['credit_sales_count'] ?? 0}')),
                                            DataCell(Text('\$${(double.tryParse((customer['outstanding_amount'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}')),
                                            DataCell(Text(customer['email'] ?? '')),
                                            DataCell(
                                              IconButton(
                                                icon: Icon(Icons.visibility),
                                                onPressed: () => _showCustomerTransactions(customer),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCreditCustomersList(List<Map<String, dynamic>> customers, bool isSmallMobile) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return Card(
          margin: EdgeInsets.only(bottom: isSmallMobile ? 6 : 8),
          child: Padding(
            padding: EdgeInsets.all(isSmallMobile ? 10 : 12),
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
                            customer['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallMobile ? 14 : 16,
                            ),
                          ),
                          SizedBox(height: isSmallMobile ? 2 : 4),
                          Text(
                            '📱 ${customer['phone'] ?? 'No phone'}',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 11 : 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: isSmallMobile ? 2 : 4),
                          Text(
                            '📧 ${customer['email'] ?? 'No email'}',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 11 : 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallMobile ? 6 : 8,
                            vertical: isSmallMobile ? 2 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            '${customer['credit_sales_count'] ?? 0} sales',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: isSmallMobile ? 10 : 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallMobile ? 4 : 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallMobile ? 6 : 8,
                            vertical: isSmallMobile ? 2 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Text(
                            '\$${(double.tryParse((customer['outstanding_amount'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: isSmallMobile ? 10 : 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 8 : 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showCustomerTransactions(customer),
                      icon: Icon(
                        Icons.visibility,
                        size: isSmallMobile ? 14 : 16,
                      ),
                      label: Text(
                        'View Details',
                        style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallMobile ? 8 : 12,
                          vertical: isSmallMobile ? 6 : 8,
                        ),
                        minimumSize: Size(
                          isSmallMobile ? 80 : 100,
                          isSmallMobile ? 28 : 32,
                        ),
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
      _loadCreditCustomers();
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

    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.payment,
                    size: isSmallMobile ? 18 : 20,
                    color: Colors.green,
                  ),
                  SizedBox(width: isSmallMobile ? 6 : 8),
                  Expanded(
                    child: Text(
                      'Record Payment',
                      style: TextStyle(
                        fontSize: isSmallMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Container(
                width: isSmallMobile ? double.infinity : (isMobile ? 300 : 400),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Container(
                      padding: EdgeInsets.all(isSmallMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Original Credit: \$${originalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                          SizedBox(height: isSmallMobile ? 4 : 6),
                          Text(
                            'Outstanding: \$${outstandingAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallMobile ? 12 : 16),
                  TextField(
                    controller: _paymentAmountController,
                      decoration: InputDecoration(
                      labelText: 'Payment Amount',
                      prefixText: '\$',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallMobile ? 10 : 12,
                          vertical: isSmallMobile ? 8 : 10,
                        ),
                    ),
                    keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: isSmallMobile ? 14 : 16),
                  ),
                    SizedBox(height: isSmallMobile ? 12 : 16),
                  Container(
                      padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 10 : 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
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
                              style: TextStyle(fontSize: isSmallMobile ? 14 : 16),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _makePayment(saleId, originalAmount, outstandingAmount, _selectedPaymentMethod);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallMobile ? 12 : 16,
                      vertical: isSmallMobile ? 8 : 10,
                    ),
                  ),
                  child: Text(
                    'Record Payment',
                    style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                  ),
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
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return Dialog(
      child: Container(
        width: isSmallMobile ? double.infinity : (isMobile ? double.infinity : 800),
        height: isSmallMobile ? double.infinity : (isMobile ? double.infinity : 600),
        padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 16 : 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person, 
                  color: Colors.blue,
                  size: isSmallMobile ? 20 : (isMobile ? 22 : 24),
                ),
                SizedBox(width: isSmallMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Credit Transactions - ${widget.customer['name']}',
                    style: TextStyle(
                      fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    size: isSmallMobile ? 18 : 20,
                  ),
                  padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                  constraints: BoxConstraints(
                    minWidth: isSmallMobile ? 28 : 32,
                    minHeight: isSmallMobile ? 28 : 32,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallMobile ? 12 : 16),
            
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

    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;

    return isMobile
        ? Column(
            children: [
              _buildSummaryCard(
                'Total Credit',
                '\$${totalCredit.toStringAsFixed(2)}',
                Icons.credit_card,
                Colors.orange,
                isSmallMobile,
              ),
              SizedBox(height: isSmallMobile ? 6 : 8),
              _buildSummaryCard(
                'Total Paid',
                '\$${totalPaid.toStringAsFixed(2)}',
                Icons.payment,
                Colors.green,
                isSmallMobile,
              ),
              SizedBox(height: isSmallMobile ? 6 : 8),
              _buildSummaryCard(
                'Outstanding',
                '\$${totalOutstanding.toStringAsFixed(2)}',
                Icons.warning,
                Colors.red,
                isSmallMobile,
              ),
            ],
          )
        : Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Credit',
            '\$${totalCredit.toStringAsFixed(2)}',
            Icons.credit_card,
            Colors.orange,
                  isSmallMobile,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Total Paid',
            '\$${totalPaid.toStringAsFixed(2)}',
            Icons.payment,
            Colors.green,
                  isSmallMobile,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Outstanding',
            '\$${totalOutstanding.toStringAsFixed(2)}',
            Icons.warning,
            Colors.red,
                  isSmallMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isSmallMobile) {
    return Container(
      padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon, 
            color: color, 
            size: isSmallMobile ? 18 : 24,
          ),
          SizedBox(height: isSmallMobile ? 3 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallMobile ? 10 : 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallMobile ? 3 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallMobile ? 12 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditSalesSection() {
    final creditSales = _transactionsData['credit_sales'] ?? [];
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 14 : 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shopping_cart, 
                  color: Colors.blue,
                  size: isSmallMobile ? 18 : 20,
                ),
                SizedBox(width: isSmallMobile ? 6 : 8),
                Text(
                  'Credit Sales (${creditSales.length})',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallMobile ? 12 : 16),
            if (creditSales.isEmpty)
              Container(
                padding: EdgeInsets.all(isSmallMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Center(
                  child: Text(
                    'No credit sales found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isSmallMobile ? 12 : 14,
                    ),
                  ),
                ),
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
                    margin: EdgeInsets.only(bottom: isSmallMobile ? 6 : 8),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallMobile ? 10 : 12),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isSmallMobile ? 13 : 14,
                                      ),
                                    ),
                                    SizedBox(height: isSmallMobile ? 2 : 4),
                                    Text(
                                      'Date: ${_formatDate(DateTime.tryParse(sale['created_at'] ?? ''))}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 10 : 12,
                                        color: Colors.grey[600],
                                    ),
                                    ),
                                    SizedBox(height: isSmallMobile ? 2 : 4),
                                    Text(
                                      'Cashier: ${sale['cashier_name'] ?? 'Unknown'}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 10 : 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${originalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallMobile ? 14 : 16,
                                    ),
                                  ),
                                  if (totalPaid > 0) ...[
                                    SizedBox(height: isSmallMobile ? 2 : 4),
                                    Text(
                                      'Paid: \$${totalPaid.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: isSmallMobile ? 10 : 12,
                                      ),
                                    ),
                                  ],
                                  if (outstanding > 0) ...[
                                    SizedBox(height: isSmallMobile ? 2 : 4),
                                    Text(
                                      'Outstanding: \$${outstanding.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: isSmallMobile ? 10 : 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          if (!isFullyPaid) ...[
                            SizedBox(height: isSmallMobile ? 6 : 8),
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallMobile ? 8 : 12,
                                      vertical: isSmallMobile ? 6 : 8,
                                    ),
                                    minimumSize: Size(
                                      isSmallMobile ? 80 : 100,
                                      isSmallMobile ? 28 : 32,
                                    ),
                                  ),
                                  child: Text(
                                    'Record Payment',
                                    style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
                                  ),
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
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 14 : 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment, 
                  color: Colors.green,
                  size: isSmallMobile ? 18 : 20,
                ),
                SizedBox(width: isSmallMobile ? 6 : 8),
                Text(
                  'Payment History (${payments.length})',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallMobile ? 12 : 16),
            if (payments.isEmpty)
              Container(
                padding: EdgeInsets.all(isSmallMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Center(
                  child: Text(
                    'No payment history found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isSmallMobile ? 12 : 14,
                    ),
                  ),
                ),
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
                    margin: EdgeInsets.only(bottom: isSmallMobile ? 6 : 8),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallMobile ? 10 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                        backgroundColor: Colors.green,
                                radius: isSmallMobile ? 12 : 16,
                                child: Icon(
                                  Icons.payment, 
                                  color: Colors.white,
                                  size: isSmallMobile ? 14 : 18,
                                ),
                              ),
                              SizedBox(width: isSmallMobile ? 8 : 12),
                              Expanded(
                                child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                                    Text(
                                      'Payment for Sale #${payment['parent_sale_id']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isSmallMobile ? 13 : 14,
                                      ),
                                    ),
                                    SizedBox(height: isSmallMobile ? 4 : 6),
                                    Text(
                                      'Amount: \$${amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 11 : 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    SizedBox(height: isSmallMobile ? 2 : 3),
                                    Text(
                                      'Method: ${payment['payment_method']}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 11 : 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: isSmallMobile ? 2 : 3),
                                    Text(
                                      'Date: ${_formatDate(DateTime.tryParse(payment['created_at'] ?? ''))}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 11 : 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: isSmallMobile ? 2 : 3),
                                    Text(
                                      'Cashier: ${payment['cashier_name'] ?? 'Unknown'}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 11 : 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                                      fontSize: isSmallMobile ? 14 : 16,
                            ),
                          ),
                                  SizedBox(height: isSmallMobile ? 2 : 4),
                          Text(
                            'Original: \$${originalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: isSmallMobile ? 9 : 10,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ],
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