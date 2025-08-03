import 'package:flutter/material.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:intl/intl.dart';

class PayablesScreen extends StatefulWidget {
  const PayablesScreen({super.key});

  @override
  State<PayablesScreen> createState() => _PayablesScreenState();
}

class _PayablesScreenState extends State<PayablesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _payables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayables();
  }

  Future<void> _loadPayables() async {
    setState(() => _isLoading = true);
    try {
      final payables = await _apiService.getPayables();
      setState(() {
        _payables = payables;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'Failed to load payables: ')}$e')),
      );
    }
  }

  void _showPayableDialog({Map<String, dynamic>? payable}) {
    final isEdit = payable != null;
    final _formKey = GlobalKey<FormState>();
    final vendorController = TextEditingController(text: payable != null ? (payable['vendor_name'] ?? '') : '');
    final amountController = TextEditingController(text: payable != null ? payable['amount'].toString() : '');
    final dueDateController = TextEditingController(text: payable != null ? payable['due_date'] : DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final statusController = TextEditingController(text: payable != null ? (payable['status'] ?? 'unpaid') : 'unpaid');
    final notesController = TextEditingController(text: payable != null ? (payable['notes'] ?? '') : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Payable' : 'Add Payable'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: vendorController,
                  decoration: const InputDecoration(labelText: 'Vendor'),
                  validator: (v) => v == null || v.isEmpty ? 'Vendor required' : null,
                ),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Amount required' : null,
                ),
                TextFormField(
                  controller: dueDateController,
                  decoration: const InputDecoration(labelText: 'Due Date'),
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(dueDateController.text) ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                    }
                  },
                  validator: (v) => v == null || v.isEmpty ? 'Due date required' : null,
                ),
                DropdownButtonFormField<String>(
                  value: statusController.text,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                                DropdownMenuItem(value: 'unpaid', child: Text(t(context, 'Unpaid'))),
            DropdownMenuItem(value: 'paid', child: Text(t(context, 'Paid'))),
            DropdownMenuItem(value: 'overdue', child: Text(t(context, 'Overdue'))),
                  ],
                  onChanged: (v) => statusController.text = v ?? 'unpaid',
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
                final newPayable = {
                  'vendor_id': null, // Vendor linking can be added later
                  'amount': double.tryParse(amountController.text) ?? 0.0,
                  'due_date': dueDateController.text,
                  'status': statusController.text,
                  'notes': notesController.text,
                };
                try {
                  if (isEdit) {
                    await _apiService.updatePayable(payable!['id'], newPayable);
                  } else {
                    await _apiService.addPayable(newPayable);
                  }
                  Navigator.pop(context);
                  _loadPayables();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${t(context, 'Failed to save payable: ')}$e')),
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
        title: Text(t(context, 'Delete Payable')),
        content: Text(t(context, 'Are you sure you want to delete this payable?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _apiService.deletePayable(id);
                Navigator.pop(context);
                _loadPayables();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${t(context, 'Failed to delete payable: ')}$e')),
                );
              }
            },
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'Accounts Payable')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Payable',
            onPressed: () => _showPayableDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payables.isEmpty
              ? Center(child: Text(t(context, 'No payables found.')))
              : ListView.separated(
                  itemCount: _payables.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = _payables[i];
                    return ListTile(
                      leading: const Icon(Icons.receipt_long, color: Colors.orange),
                      title: Text('${p['vendor_name'] ?? ''} - ${p['amount']}'),
                      subtitle: Text('${t(context, 'Due: ')}${p['due_date']} | ${t(context, 'Status: ')}${p['status']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showPayableDialog(payable: p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(p['id']),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
} 