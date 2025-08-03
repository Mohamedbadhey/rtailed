import 'package:flutter/material.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  String? _categoryFilter;
  String? _vendorFilter;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final expenses = await _apiService.getExpenses();
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'Failed to load expenses: ')}$e')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    return _expenses.where((exp) {
      final matchesCategory = _categoryFilter == null || exp['category'] == _categoryFilter;
      final matchesVendor = _vendorFilter == null || (exp['vendor_name'] ?? '') == _vendorFilter;
      final matchesDate = _dateRange == null || (
        DateTime.parse(exp['date']).isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
        DateTime.parse(exp['date']).isBefore(_dateRange!.end.add(const Duration(days: 1)))
      );
      return matchesCategory && matchesVendor && matchesDate;
    }).toList();
  }

  void _showExpenseDialog({Map<String, dynamic>? expense}) {
    final isEdit = expense != null;
    final _formKey = GlobalKey<FormState>();
    final dateController = TextEditingController(text: expense != null ? expense['date'] : DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final amountController = TextEditingController(text: expense != null ? expense['amount'].toString() : '');
    final categoryController = TextEditingController(text: expense != null ? expense['category'] : '');
    final vendorController = TextEditingController(text: expense != null ? (expense['vendor_name'] ?? '') : '');
    final notesController = TextEditingController(text: expense != null ? (expense['notes'] ?? '') : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Expense' : 'Add Expense'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Date'),
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                    }
                  },
                  validator: (v) => v == null || v.isEmpty ? 'Date required' : null,
                ),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Amount required' : null,
                ),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (v) => v == null || v.isEmpty ? 'Category required' : null,
                ),
                TextFormField(
                  controller: vendorController,
                  decoration: const InputDecoration(labelText: 'Vendor (optional)'),
                ),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final newExpense = {
                  'date': dateController.text,
                  'amount': double.tryParse(amountController.text) ?? 0.0,
                  'category': categoryController.text,
                  'vendor_id': null, // Vendor linking can be added later
                  'notes': notesController.text,
                };
                try {
                  if (isEdit) {
                    await _apiService.updateExpense(expense!['id'], newExpense);
                  } else {
                    await _apiService.addExpense(newExpense);
                  }
                  Navigator.pop(context);
                  _loadExpenses();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${t(context, 'Failed to save expense: ')}$e')),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'Delete Expense')),
        content: Text(t(context, 'Are you sure you want to delete this expense?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _apiService.deleteExpense(id);
                Navigator.pop(context);
                _loadExpenses();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${t(context, 'Failed to delete expense: ')}$e')),
                );
              }
            },
            child: Text(t(context, 'Delete')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final categories = _expenses.map((e) => e['category'] as String).toSet().toList();
    final vendors = _expenses.map((e) => e['vendor_name'] ?? '').where((v) => v.isNotEmpty).toSet().toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownButton<String?>(
          value: _categoryFilter,
          hint: Text(t(context, 'Category')),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('All'))] +
              categories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))).toList(),
          onChanged: (String? v) => setState(() => _categoryFilter = v),
        ),
        DropdownButton<String?>(
          value: _vendorFilter,
          hint: Text(t(context, 'Vendor')),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('All'))] +
              vendors.map((v) => DropdownMenuItem<String?>(value: v, child: Text(v))).toList(),
          onChanged: (String? v) => setState(() => _vendorFilter = v),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(_dateRange == null
              ? 'Date Range'
              : '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'),
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: _dateRange,
            );
            if (picked != null) setState(() => _dateRange = picked);
          },
        ),
        if (_categoryFilter != null || _vendorFilter != null || _dateRange != null)
          TextButton(
            onPressed: () => setState(() {
              _categoryFilter = null;
              _vendorFilter = null;
              _dateRange = null;
            }),
            child: Text(t(context, 'Clear Filters')),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'Expenses')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Expense',
            onPressed: () => _showExpenseDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildFilters(),
                ),
                Expanded(
                  child: _filteredExpenses.isEmpty
                      ? Center(child: Text(t(context, 'No expenses found.')))
                      : ListView.separated(
                          itemCount: _filteredExpenses.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final exp = _filteredExpenses[i];
                            return ListTile(
                              leading: const Icon(Icons.money_off, color: Colors.red),
                              title: Text('${exp['category']} - ${exp['amount']}'),
                              subtitle: Text('${exp['date']}  ${exp['vendor_name'] ?? ''}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showExpenseDialog(expense: exp),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmDelete(exp['id']),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
} 