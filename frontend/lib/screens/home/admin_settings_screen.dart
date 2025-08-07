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
  bool _showCreditSection = false;

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
              text: t(context, 'Credit Management'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.credit_card, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        t(context, 'Credit Management'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.credit_card, color: Colors.orange),
                          onPressed: () {
                            setState(() {
                              _showCreditSection = !_showCreditSection;
                            });
                            if (_showCreditSection) {
                              _loadCreditCustomers();
                            }
                          },
                          tooltip: 'Toggle Credit Section',
                        ),
                      ),
                    ],
                  ),
                  if (_showCreditSection) ...[
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
                ],
              ),
            ),
          ),
        ],
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

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Credit',
            '\$${totalCredit.toStringAsFixed(2)}',
            Icons.credit_card,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Total Paid',
            '\$${totalPaid.toStringAsFixed(2)}',
            Icons.payment,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Outstanding',
            '\$${totalOutstanding.toStringAsFixed(2)}',
            Icons.warning,
            Colors.red,
          ),
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