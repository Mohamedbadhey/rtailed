import 'package:flutter/material.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _vendors = [];
  List<String> _categories = [];
  bool _isLoading = true;
  String? _categoryFilter;
  String? _vendorFilter; // vendor name for filtering
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getVendors(),
        _apiService.getExpenseCategories(),
      ]);
      _vendors = results[0];
      _categories = (results[1]).map((e) => (e['name'] ?? '').toString()).where((s) => s.isNotEmpty).cast<String>().toList()..sort();
    } catch (e) {
      // Ignore and proceed; UI can still function with manual entries
    } finally {
      await _loadExpenses();
    }
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final startDate = _dateRange != null ? DateFormat('yyyy-MM-dd').format(_dateRange!.start) : null;
      final endDate = _dateRange != null ? DateFormat('yyyy-MM-dd').format(_dateRange!.end) : null;
      final expenses = await _apiService.getExpenses(
        startDate: startDate,
        endDate: endDate,
        category: _categoryFilter,
        vendor: _vendorFilter,
      );
      
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

  // Results are server-filtered; keep as pass-through for any local tweaks if needed
  List<Map<String, dynamic>> get _filteredExpenses => _expenses;

  void _showExpenseDialog({Map<String, dynamic>? expense}) {
    final isEdit = expense != null;
    final _formKey = GlobalKey<FormState>();
    final dateController = TextEditingController(text: expense != null ? expense['date'] : DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final amountController = TextEditingController(text: expense != null ? expense['amount'].toString() : '');
    final categoryController = TextEditingController(text: expense != null ? expense['category'] : '');
    final vendorItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('None')),
      ..._vendors.map((v) => DropdownMenuItem<int?> (
            value: v['id'] as int?,
            child: Text((v['name'] ?? '').toString()),
          )),
    ];
    final selectedVendorId = ValueNotifier<int?>(expense != null ? expense['vendor_id'] as int? : null);
    final notesController = TextEditingController(text: expense != null ? (expense['notes'] ?? '') : '');

  // Build category choices dynamically from existing expenses
  final categories = _expenses
      .map((e) => (e['category'] ?? '') as String)
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  final selectedCategory = ValueNotifier<String?>(
      expense != null ? expense['category'] : (categories.isNotEmpty ? categories.first : null));
  final useCustomCategory = ValueNotifier<bool>(categories.isEmpty);
  

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
                // Category selection with dropdown + custom option
                ValueListenableBuilder<bool>(
                  valueListenable: useCustomCategory,
                  builder: (context, custom, _) {
                    if (custom) {
                      return TextFormField(
                        controller: categoryController,
                        decoration: const InputDecoration(labelText: 'Category'),
                        validator: (v) => v == null || v.isEmpty ? 'Category required' : null,
                      );
                    }
                    return ValueListenableBuilder<String?>(
                      valueListenable: selectedCategory,
                      builder: (context, selected, __) => DropdownButtonFormField<String>(
                        value: selected,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [
                          ...categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                          const DropdownMenuItem<String>(value: '__custom__', child: Text('Custom...')),
                        ],
                        onChanged: (val) {
                          if (val == '__custom__') {
                            useCustomCategory.value = true;
                          } else {
                            selectedCategory.value = val;
                          }
                        },
                        validator: (v) => (v != null && v.isNotEmpty) ? null : 'Category required',
                      ),
                    );
                  },
                ),

                // Vendor dropdown
                ValueListenableBuilder<int?>(
                  valueListenable: selectedVendorId,
                  builder: (context, vendorId, _) => DropdownButtonFormField<int?>(
                    value: vendorId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Vendor (optional)'),
                    items: vendorItems,
                    onChanged: (val) => selectedVendorId.value = val,
                  ),
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
                final categoryValue = useCustomCategory.value
                    ? categoryController.text
                    : (selectedCategory.value ?? categoryController.text);
                final newExpense = {
                  'date': dateController.text,
                  'amount': double.tryParse(amountController.text) ?? 0.0,
                  'category': categoryValue,
                  'vendor_id': selectedVendorId.value,
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
    final categories = _categories.isNotEmpty
        ? _categories
        : _expenses.map((e) => (e['category'] ?? '') as String).where((s) => s.isNotEmpty).toSet().toList();
    final vendorNames = _vendors.map((v) => (v['name'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownButton<String?>(
          value: _categoryFilter,
          hint: Text(t(context, 'Category')),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('All'))] +
              categories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))).toList(),
          onChanged: (String? v) {
            setState(() => _categoryFilter = v);
            _loadExpenses();
          },
        ),
        DropdownButton<String?>(
          value: _vendorFilter,
          hint: Text(t(context, 'Vendor')),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('All'))] +
              vendorNames.map((v) => DropdownMenuItem<String?>(value: v, child: Text(v))).toList(),
          onChanged: (String? v) {
            setState(() => _vendorFilter = v);
            _loadExpenses();
          },
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
            if (picked != null) {
              setState(() => _dateRange = picked);
              _loadExpenses();
            }
          },
        ),
        PopupMenuButton<String>(
          tooltip: 'Quick Ranges',
          icon: const Icon(Icons.schedule),
          onSelected: (v) {
            final now = DateTime.now();
            DateTime start;
            DateTime end;
            if (v == 'this_month') {
              start = DateTime(now.year, now.month, 1);
              end = DateTime(now.year, now.month + 1, 0);
            } else if (v == 'last_month') {
              final lastMonth = DateTime(now.year, now.month - 1, 1);
              start = lastMonth;
              end = DateTime(lastMonth.year, lastMonth.month + 1, 0);
            } else if (v == 'this_year') {
              start = DateTime(now.year, 1, 1);
              end = DateTime(now.year, 12, 31);
            } else if (v == 'last_year') {
              start = DateTime(now.year - 1, 1, 1);
              end = DateTime(now.year - 1, 12, 31);
            } else {
              return;
            }
            setState(() => _dateRange = DateTimeRange(start: start, end: end));
            _loadExpenses();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'this_month', child: Text('This Month')),
            const PopupMenuItem(value: 'last_month', child: Text('Last Month')),
            const PopupMenuItem(value: 'this_year', child: Text('This Year')),
            const PopupMenuItem(value: 'last_year', child: Text('Last Year')),
          ],
        ),
        
        if (_categoryFilter != null || _vendorFilter != null || _dateRange != null)
          TextButton(
            onPressed: () {
              setState(() {
                _categoryFilter = null;
                _vendorFilter = null;
                _dateRange = null;
              });
              _loadExpenses();
            },
            child: Text(t(context, 'Clear Filters')),
          ),
      ],
    );
  }

  double get _totalSpent => _filteredExpenses.fold<double>(0.0, (sum, e) => sum + (double.tryParse(e['amount'].toString()) ?? 0.0));

  Map<String, double> get _totalsByCategory {
    final map = <String, double>{};
    for (final e in _filteredExpenses) {
      final cat = (e['category'] ?? 'Uncategorized').toString();
      final amt = double.tryParse(e['amount'].toString()) ?? 0.0;
      map[cat] = (map[cat] ?? 0.0) + amt;
    }
    return map;
  }

  Widget _buildSummary() {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    final byCat = _totalsByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.summarize, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 16 : 18)),
                const Spacer(),
                Text('Total: ' + _totalSpent.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            if (byCat.isEmpty)
              const Text('No data for selected filters')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: byCat.take(6).map((e) => Chip(
                  avatar: const Icon(Icons.label, size: 16),
                  label: Text('${e.key}: ${e.value.toStringAsFixed(2)}'),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: getBrandedPrimaryColor(context), foregroundColor: Colors.white,
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
                _buildSummary(),
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