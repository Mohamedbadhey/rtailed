import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/pdf_export_service.dart';

class CustomerInvoiceScreen extends StatefulWidget {
  const CustomerInvoiceScreen({Key? key}) : super(key: key);

  @override
  State<CustomerInvoiceScreen> createState() => _CustomerInvoiceScreenState();
}

class _CustomerInvoiceScreenState extends State<CustomerInvoiceScreen> {
  final ApiService _apiService = ApiService();
  
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isGeneratingInvoice = false;
  Map<String, dynamic>? _customerData;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic>? _summary;
  Set<int> _selectedTransactionIds = {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final customers = await _apiService.getCustomers();
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load customers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCustomerTransactions() async {
    if (_selectedCustomer == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _apiService.getCustomerTransactions(
        customerId: int.parse(_selectedCustomer!.id!),
        startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
      );

      setState(() {
        _customerData = data['customer'];
        _transactions = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
        _summary = data['summary'];
        // Auto-select all transactions by default
        _selectedTransactionIds = _transactions.map((tx) => tx['id'] as int).toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load customer transactions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateInvoice() async {
    if (_selectedCustomer == null || _selectedTransactionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer and choose at least one transaction'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingInvoice = true;
    });

    try {
      // Get business data - we need to get the current user's business ID
      final user = context.read<AuthProvider>().user;
      if (user?.businessId == null) {
        throw Exception('Business ID not found');
      }
      
      final businessData = await _apiService.getBusinessDetails(user!.businessId!);
      
      // Filter transactions based on selection
      final selectedTransactions = _transactions.where(
        (tx) => _selectedTransactionIds.contains(tx['id'])
      ).toList();
      
      // Generate and save PDF using the same method as inventory screen
      final result = await PdfExportService.exportCustomerInvoiceToPdf(
        customerData: _customerData!,
        transactions: selectedTransactions,
        fileName: 'customer_invoice_${_selectedCustomer!.name}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        businessInfo: businessData,
        startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
      );

      if (mounted) {
        if (result is Map<String, dynamic>) {
          if (result['success'] == true) {
            String message = 'Customer Invoice generated successfully!';
            if (result['userFriendlyPath'] != null) {
              message += '\nSaved to: ${result['userFriendlyPath']}';
            } else if (result['directory'] != null && result['directory'] != 'Browser Downloads') {
              message += '\nSaved to: ${result['directory']}';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            throw Exception(result['message'] ?? 'Failed to save PDF');
          }
        } else {
          // Fallback for old return type
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer Invoice generated successfully! $result'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isGeneratingInvoice = false;
      });
    }
  }

  void _toggleTransactionSelection(int transactionId) {
    setState(() {
      if (_selectedTransactionIds.contains(transactionId)) {
        _selectedTransactionIds.remove(transactionId);
      } else {
        _selectedTransactionIds.add(transactionId);
      }
    });
  }

  void _selectAllTransactions() {
    setState(() {
      _selectedTransactionIds = _transactions.map((tx) => tx['id'] as int).toSet();
    });
  }

  void _deselectAllTransactions() {
    setState(() {
      _selectedTransactionIds.clear();
    });
  }

  List<Map<String, dynamic>> get _selectedTransactions {
    return _transactions.where(
      (tx) => _selectedTransactionIds.contains(tx['id'])
    ).toList();
  }

  double get _selectedTotalAmount {
    return _selectedTransactions.fold(0.0, (sum, tx) {
      final amount = tx['total_amount'];
      if (amount == null) return sum;
      if (amount is num) return sum + amount.toDouble();
      if (amount is String) return sum + (double.tryParse(amount) ?? 0.0);
      return sum;
    });
  }

  int get _selectedTransactionCount {
    return _selectedTransactions.length;
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0.00';
    if (amount is num) return amount.toStringAsFixed(2);
    if (amount is String) {
      final parsed = double.tryParse(amount);
      return parsed?.toStringAsFixed(2) ?? '0.00';
    }
    return '0.00';
  }

  Widget _buildDateSelector(String title, DateTime? date, Function(DateTime?) onDateSelected) {
    return ListTile(
      title: Text(title),
      subtitle: Text(date != null 
          ? DateFormat('yyyy-MM-dd').format(date)
          : 'All time'),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: title == 'End Date' && _startDate != null ? _startDate! : DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (selectedDate != null) {
          onDateSelected(selectedDate);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Invoice'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Customer Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Customer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Customer>(
                      value: _selectedCustomer,
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                        border: OutlineInputBorder(),
                      ),
                      items: _customers.map((customer) {
                        return DropdownMenuItem<Customer>(
                          value: customer,
                          child: Text(customer.name),
                        );
                      }).toList(),
                      onChanged: (Customer? newValue) {
                        setState(() {
                          _selectedCustomer = newValue;
                          _customerData = null;
                          _transactions = [];
                          _summary = null;
                          _selectedTransactionIds.clear();
                        });
                        if (newValue != null) {
                          _loadCustomerTransactions();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Date Range Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date Range (Optional)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        if (isWide) {
                          // Wide layout: side by side
                          return Row(
                            children: [
                              Expanded(
                                child: _buildDateSelector(
                                  'Start Date',
                                  _startDate,
                                  (date) {
                                    setState(() {
                                      _startDate = date;
                                    });
                                    if (_selectedCustomer != null) {
                                      _loadCustomerTransactions();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDateSelector(
                                  'End Date',
                                  _endDate,
                                  (date) {
                                    setState(() {
                                      _endDate = date;
                                    });
                                    if (_selectedCustomer != null) {
                                      _loadCustomerTransactions();
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Narrow layout: stacked
                          return Column(
                            children: [
                              _buildDateSelector(
                                'Start Date',
                                _startDate,
                                (date) {
                                  setState(() {
                                    _startDate = date;
                                  });
                                  if (_selectedCustomer != null) {
                                    _loadCustomerTransactions();
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildDateSelector(
                                'End Date',
                                _endDate,
                                (date) {
                                  setState(() {
                                    _endDate = date;
                                  });
                                  if (_selectedCustomer != null) {
                                    _loadCustomerTransactions();
                                  }
                                },
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 400;
                        return Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                });
                                if (_selectedCustomer != null) {
                                  _loadCustomerTransactions();
                                }
                              },
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear Dates'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                final now = DateTime.now();
                                setState(() {
                                  _startDate = DateTime(now.year, now.month, 1);
                                  _endDate = now;
                                });
                                if (_selectedCustomer != null) {
                                  _loadCustomerTransactions();
                                }
                              },
                              icon: const Icon(Icons.calendar_month, size: 16),
                              label: const Text('This Month'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Transaction Summary
            if (_selectedCustomer != null && _summary != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;
                          
                          if (isMobile) {
                            // Mobile layout: title on top, buttons below
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Transaction Summary',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_transactions.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildMobileButtons(),
                                ],
                              ],
                            );
                          } else {
                            // Desktop layout: title and buttons side by side
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Transaction Summary',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_transactions.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _selectAllTransactions,
                                        icon: const Icon(Icons.select_all, size: 16),
                                        label: const Text('Select All'),
                                      ),
                                      TextButton.icon(
                                        onPressed: _deselectAllTransactions,
                                        icon: const Icon(Icons.deselect, size: 16),
                                        label: const Text('Deselect All'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final screenWidth = constraints.maxWidth;
                          final isMobile = screenWidth < 600; // More realistic mobile breakpoint
                          final isSmallMobile = screenWidth < 400;
                          
                          if (isMobile) {
                            // Mobile layout: 2x2 grid with compact spacing
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryCard(
                                        'Selected Amount',
                                        '\$${_selectedTotalAmount.toStringAsFixed(2)}',
                                        Colors.green,
                                        isMobile: true,
                                        isSmallMobile: isSmallMobile,
                                      ),
                                    ),
                                    SizedBox(width: isSmallMobile ? 4 : 6),
                                    Expanded(
                                      child: _buildSummaryCard(
                                        'Selected Transactions',
                                        '$_selectedTransactionCount / ${_transactions.length}',
                                        Colors.blue,
                                        isMobile: true,
                                        isSmallMobile: isSmallMobile,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallMobile ? 4 : 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryCard(
                                        'Total Available',
                                        '\$${_formatAmount(_summary!['total_amount'])}',
                                        Colors.grey,
                                        isMobile: true,
                                        isSmallMobile: isSmallMobile,
                                      ),
                                    ),
                                    SizedBox(width: isSmallMobile ? 4 : 6),
                                    Expanded(
                                      child: _buildSummaryCard(
                                        'All Transactions',
                                        '${_summary!['total_transactions'] ?? 0}',
                                        Colors.grey,
                                        isMobile: true,
                                        isSmallMobile: isSmallMobile,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          } else {
                            // Desktop/Tablet layout: 2x2 grid
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryCard(
                                        'Selected Amount',
                                        '\$${_selectedTotalAmount.toStringAsFixed(2)}',
                                        Colors.green,
                                        isMobile: false,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSummaryCard(
                                        'Selected Transactions',
                                        '$_selectedTransactionCount / ${_transactions.length}',
                                        Colors.blue,
                                        isMobile: false,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryCard(
                                        'Total Available',
                                        '\$${_formatAmount(_summary!['total_amount'])}',
                                        Colors.grey,
                                        isMobile: false,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSummaryCard(
                                        'All Transactions',
                                        '${_summary!['total_transactions'] ?? 0}',
                                        Colors.grey,
                                        isMobile: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_transactions.isNotEmpty) ...[
                        const Text(
                          'Select Transactions:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 600;
                            return Container(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.5 : 0.4),
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _transactions.length,
                                itemBuilder: (context, index) {
                                  final tx = _transactions[index];
                                  final isSelected = _selectedTransactionIds.contains(tx['id']);
                                  
                                  if (isMobile) {
                                    // Mobile-optimized layout
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.green.shade50 : null,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: ListTile(
                                        leading: Checkbox(
                                          value: isSelected,
                                          onChanged: (bool? value) {
                                            _toggleTransactionSelection(tx['id']);
                                          },
                                          activeColor: Colors.green,
                                        ),
                                        title: Text(
                                          'Transaction #${tx['id']}',
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              '${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(tx['created_at']))}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            Text(
                                              '\$${_formatAmount(tx['total_amount'])}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (tx['payment_method'] != null && tx['payment_method'].toString().isNotEmpty)
                                              Text(
                                                'Payment: ${tx['payment_method']}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            const SizedBox(height: 6),
                                            _buildProductsList(tx['items'] as List<dynamic>? ?? []),
                                          ],
                                        ),
                                        isThreeLine: true,
                                      ),
                                    );
                                  } else {
                                    // Desktop layout (original)
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.green.shade50 : null,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: CheckboxListTile(
                                        value: isSelected,
                                        onChanged: (bool? value) {
                                          _toggleTransactionSelection(tx['id']);
                                        },
                                        title: Text(
                                          'Transaction #${tx['id']}',
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(tx['created_at']))}'),
                                            Text(
                                              '\$${_formatAmount(tx['total_amount'])}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            _buildProductsList(tx['items'] as List<dynamic>? ?? []),
                                          ],
                                        ),
                                        secondary: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.receipt,
                                              color: isSelected ? Colors.green : Colors.grey,
                                            ),
                                            Text(
                                              tx['payment_method'] ?? '',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        activeColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        const Text(
                          'No transactions found for the selected date range.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Generate Invoice Button
            if (_selectedCustomer != null && _selectedTransactionIds.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingInvoice ? null : _generateInvoice,
                  icon: _isGeneratingInvoice 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 400;
                      return Text(
                        _isGeneratingInvoice 
                            ? 'Generating...' 
                            : isWide 
                                ? 'Generate Invoice PDF ($_selectedTransactionCount transactions)'
                                : 'Generate PDF ($_selectedTransactionCount)',
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

            // Loading Indicator
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList(List<dynamic> items) {
    if (items.isEmpty) {
      return const Text(
        'No items',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Show first 2 products on mobile, 3 on desktop, then "and X more" if there are more
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxItems = isMobile ? 2 : 3;
    final displayItems = items.take(maxItems).toList();
    final remainingCount = items.length - maxItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayItems.map((item) {
          final productName = item['product_name'] ?? 'Unknown Product';
          final quantity = item['quantity'] ?? 0;
          final price = _formatAmount(item['price']);
          
          // Shorter format for mobile
          final displayText = isMobile 
              ? '• $productName (${quantity}x \$${price})'
              : '• $productName (Qty: $quantity, Price: \$${price})';
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                color: Colors.grey,
              ),
            ),
          );
        }).toList(),
        if (remainingCount > 0)
          Text(
            '  and $remainingCount more item${remainingCount > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildMobileButtons() {
    final isSmallMobile = MediaQuery.of(context).size.width < 400;
    
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: isSmallMobile ? 4 : 6,
      runSpacing: 4,
      children: [
        ElevatedButton.icon(
          onPressed: _selectAllTransactions,
          icon: Icon(
            Icons.select_all, 
            size: isSmallMobile ? 14 : 16,
          ),
          label: Text(
            isSmallMobile ? 'All' : 'Select All',
            style: TextStyle(
              fontSize: isSmallMobile ? 12 : 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 8 : 12,
              vertical: isSmallMobile ? 6 : 8,
            ),
            minimumSize: Size(0, isSmallMobile ? 32 : 36),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _deselectAllTransactions,
          icon: Icon(
            Icons.deselect, 
            size: isSmallMobile ? 14 : 16,
          ),
          label: Text(
            isSmallMobile ? 'None' : 'Deselect All',
            style: TextStyle(
              fontSize: isSmallMobile ? 12 : 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 8 : 12,
              vertical: isSmallMobile ? 6 : 8,
            ),
            minimumSize: Size(0, isSmallMobile ? 32 : 36),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, {bool isMobile = false, bool isSmallMobile = false}) {
    // Shorten titles for mobile
    String shortTitle = title;
    if (isMobile) {
      switch (title) {
        case 'Selected Amount':
          shortTitle = 'Selected';
          break;
        case 'Selected Transactions':
          shortTitle = 'Selected';
          break;
        case 'Total Available':
          shortTitle = 'Available';
          break;
        case 'All Transactions':
          shortTitle = 'All';
          break;
      }
    }
    
    return Container(
      padding: EdgeInsets.all(isSmallMobile ? 6 : (isMobile ? 8 : 16)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmallMobile ? 4 : (isMobile ? 6 : 8)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            shortTitle,
            style: TextStyle(
              fontSize: isSmallMobile ? 9 : (isMobile ? 10 : 14),
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isSmallMobile ? 2 : (isMobile ? 3 : 8)),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallMobile ? 11 : (isMobile ? 12 : 20),
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
