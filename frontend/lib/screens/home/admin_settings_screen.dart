import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/screens/home/settings_screen.dart';
import 'package:retail_management/screens/home/damaged_products_screen.dart';
import 'package:retail_management/screens/accounting/accounting_dashboard_screen.dart';


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

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final isAdmin = user != null && user.role == 'admin';
    
    // Number of tabs: General Settings, Damages, Credit, and optionally Accounting for admins
    final tabCount = isAdmin ? 4 : 3;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'Settings')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              icon: Icon(Icons.settings),
              text: t(context, 'General'),
            ),
            Tab(
              icon: Icon(Icons.warning),
              text: t(context, 'Damages'),
            ),
            Tab(
              icon: Icon(Icons.credit_card),
              text: t(context, 'Credit'),
            ),
            if (isAdmin)
              Tab(
                icon: Icon(Icons.account_balance),
                text: t(context, 'Accounting'),
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
          
          // Accounting (only for admins)
          if (isAdmin)
            const AccountingDashboardScreen(),
        ],
      ),
    );
  }

  Widget _buildCreditTab() {
    return RefreshIndicator(
      onRefresh: _loadCreditCustomers,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.credit_card, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        t(context, 'Credit Customers'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _creditLoading
                      ? Center(child: CircularProgressIndicator())
                      : _creditError != null
                          ? Text(_creditError!, style: TextStyle(color: Colors.red))
                          : _creditCustomers.isEmpty
                              ? Text(t(context, 'No credit customers found.'))
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
              ),
            ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Credit Transactions - ${widget.customer['name']}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary
                      if (_transactionsData['summary'] != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Summary',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryItem(
                                        'Total Credit',
                                        '\$${(double.tryParse((_transactionsData['summary']['total_credit_amount'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildSummaryItem(
                                        'Total Paid',
                                        '\$${(double.tryParse((_transactionsData['summary']['total_paid_amount'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildSummaryItem(
                                        'Outstanding',
                                        '\$${(double.tryParse((_transactionsData['summary']['total_outstanding'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}',
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Credit Sales
                      Text(
                        'Credit Sales',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...(_transactionsData['credit_sales'] ?? []).map<Widget>((sale) {
                        final outstanding = double.tryParse((sale['outstanding_amount'] ?? 0).toString()) ?? 0.0;
                        final totalPaid = double.tryParse((sale['total_paid'] ?? 0).toString()) ?? 0.0;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Sale #${sale['id']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '\$${(double.tryParse((sale['total_amount'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Date: ${sale['created_at']?.toString().split(' ')[0] ?? 'N/A'}'),
                                Text('Cashier: ${sale['cashier_name'] ?? 'N/A'}'),
                                Text('Status: ${sale['status'] ?? 'N/A'}'),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('Paid: \$${totalPaid.toStringAsFixed(2)}'),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Outstanding: \$${outstanding.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: outstanding > 0 ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (outstanding > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _paymentAmountController,
                                          decoration: const InputDecoration(
                                            labelText: 'Payment Amount',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          _selectedSaleId = sale['id'];
                                          _makePayment(
                                            sale['id'],
                                            double.tryParse((sale['total_amount'] ?? 0).toString()) ?? 0.0,
                                            outstanding,
                                            'cash',
                                          );
                                        },
                                        child: const Text('Pay'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}