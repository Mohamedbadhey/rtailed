import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../services/api_service.dart';
import '../../services/pdf_export_service.dart';
import '../../utils/success_utils.dart';

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
      // Get business data
      final businessData = await _apiService.getBusinessDetails();
      
      // Filter transactions based on selection
      final selectedTransactions = _transactions.where(
        (tx) => _selectedTransactionIds.contains(tx['id'])
      ).toList();
      
      // Generate PDF
      final pdfBytes = await PdfExportService.generateCustomerInvoice(
        customerData: _customerData!,
        transactions: selectedTransactions,
        businessData: businessData,
        startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
      );

      // Save and show success
      await SuccessUtils.showPdfSuccess(
        context: context,
        pdfBytes: pdfBytes,
        fileName: 'customer_invoice_${_selectedCustomer!.name}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        title: 'Customer Invoice Generated',
        message: 'Invoice for ${_selectedCustomer!.name} has been generated successfully!',
      );

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
    return _selectedTransactions.fold(0.0, (sum, tx) => sum + (tx['total_amount'] ?? 0.0));
  }

  int get _selectedTransactionCount {
    return _selectedTransactions.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Invoice'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
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
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('Start Date'),
                            subtitle: Text(_startDate != null 
                                ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                : 'All time'),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  _startDate = date;
                                });
                                if (_selectedCustomer != null) {
                                  _loadCustomerTransactions();
                                }
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('End Date'),
                            subtitle: Text(_endDate != null 
                                ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                : 'All time'),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: _startDate ?? DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  _endDate = date;
                                });
                                if (_selectedCustomer != null) {
                                  _loadCustomerTransactions();
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                            });
                            if (_selectedCustomer != null) {
                              _loadCustomerTransactions();
                            }
                          },
                          child: const Text('Clear Dates'),
                        ),
                        TextButton(
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
                          child: const Text('This Month'),
                        ),
                      ],
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
                      Row(
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
                            Row(
                              children: [
                                TextButton(
                                  onPressed: _selectAllTransactions,
                                  child: const Text('Select All'),
                                ),
                                TextButton(
                                  onPressed: _deselectAllTransactions,
                                  child: const Text('Deselect All'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Selected Amount',
                              '\$${_selectedTotalAmount.toStringAsFixed(2)}',
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSummaryCard(
                              'Selected Transactions',
                              '$_selectedTransactionCount / ${_transactions.length}',
                              Colors.blue,
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
                              '\$${_summary!['total_amount']?.toStringAsFixed(2) ?? '0.00'}',
                              Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSummaryCard(
                              'All Transactions',
                              '${_summary!['total_transactions'] ?? 0}',
                              Colors.grey,
                            ),
                          ),
                        ],
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
                        Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              final isSelected = _selectedTransactionIds.contains(tx['id']);
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (bool? value) {
                                  _toggleTransactionSelection(tx['id']);
                                },
                                title: Text('Transaction #${tx['id']}'),
                                subtitle: Text('${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(tx['created_at']))} - \$${tx['total_amount']?.toStringAsFixed(2) ?? '0.00'}'),
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
                              );
                            },
                          ),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingInvoice ? null : _generateInvoice,
                  icon: _isGeneratingInvoice 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(_isGeneratingInvoice 
                      ? 'Generating...' 
                      : 'Generate Invoice PDF ($_selectedTransactionCount transactions)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
