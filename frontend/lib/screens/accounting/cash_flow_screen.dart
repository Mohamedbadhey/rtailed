import 'package:flutter/material.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _cashFlows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCashFlows();
  }

  Future<void> _loadCashFlows() async {
    setState(() => _isLoading = true);
    try {
      final cashFlows = await _apiService.getCashFlows();
      setState(() {
        _cashFlows = cashFlows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'Failed to load cash flows: ')}$e')),
      );
    }
  }

  void _showCashFlowDialog() {
    final _formKey = GlobalKey<FormState>();
    String type = 'in';
    final amountController = TextEditingController();
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final referenceController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'Add Cash Flow')),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                                DropdownMenuItem(value: 'in', child: Text(t(context, 'Inflow'))),
            DropdownMenuItem(value: 'out', child: Text(t(context, 'Outflow'))),
                  ],
                  onChanged: (v) => type = v ?? 'in',
                ),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Amount required' : null,
                ),
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
                  controller: referenceController,
                  decoration: const InputDecoration(labelText: 'Reference (optional)'),
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
            child: Text(t(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final newCashFlow = {
                  'type': type,
                  'amount': double.tryParse(amountController.text) ?? 0.0,
                  'date': dateController.text,
                  'reference': referenceController.text,
                  'notes': notesController.text,
                };
                try {
                  await _apiService.addCashFlow(newCashFlow);
                  Navigator.pop(context);
                  _loadCashFlows();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${t(context, 'Failed to add cash flow: ')}$e')),
                  );
                }
              }
            },
            child: Text(t(context, 'Add')),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    // Group by date, sum inflow/outflow
    final Map<String, double> inflowByDate = {};
    final Map<String, double> outflowByDate = {};
    for (final cf in _cashFlows) {
      final date = cf['date'];
      final amount = (cf['amount'] ?? 0).toDouble();
      if (cf['type'] == 'in') {
        inflowByDate[date] = (inflowByDate[date] ?? 0) + amount;
      } else {
        outflowByDate[date] = (outflowByDate[date] ?? 0) + amount;
      }
    }
    final allDates = <String>{...inflowByDate.keys, ...outflowByDate.keys}.toList()..sort();
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          barGroups: List.generate(allDates.length, (i) {
            final date = allDates[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: inflowByDate[date] ?? 0,
                  color: Colors.green,
                  width: 8,
                ),
                BarChartRodData(
                  toY: -(outflowByDate[date] ?? 0),
                  color: Colors.red,
                  width: 8,
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= allDates.length) return const SizedBox();
                  return Text(allDates[idx].substring(5), style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'Cash Flow')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Cash Flow',
            onPressed: _showCashFlowDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildChart(),
                ),
                const Divider(),
                Expanded(
                  child: _cashFlows.isEmpty
                      ? Center(child: Text(t(context, 'No cash flow records found.')))
                      : ListView.separated(
                          itemCount: _cashFlows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final cf = _cashFlows[i];
                            return ListTile(
                              leading: Icon(
                                cf['type'] == 'in' ? Icons.arrow_downward : Icons.arrow_upward,
                                color: cf['type'] == 'in' ? Colors.green : Colors.red,
                              ),
                              title: Text('${cf['type'] == 'in' ? 'Inflow' : 'Outflow'} - ${cf['amount']}'),
                              subtitle: Text('${cf['date']}  ${cf['reference'] ?? ''}'),
                              trailing: Text(cf['notes'] ?? ''),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
} 