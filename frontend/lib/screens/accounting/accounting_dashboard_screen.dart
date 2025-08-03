import 'package:flutter/material.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:fl_chart/fl_chart.dart';

class AccountingDashboardScreen extends StatefulWidget {
  const AccountingDashboardScreen({super.key});

  @override
  State<AccountingDashboardScreen> createState() => _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState extends State<AccountingDashboardScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic> _profitLoss = {};
  Map<String, dynamic> _balanceSheet = {};
  Map<String, dynamic> _cashFlowReport = {};
  List<Map<String, dynamic>> _generalLedger = [];
  bool _isLoading = true;

  double parseNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getProfitLoss(),
        _apiService.getBalanceSheet(),
        _apiService.getCashFlowReport(),
        _apiService.getGeneralLedger(),
      ]);
      setState(() {
        _profitLoss = results[0] as Map<String, dynamic>;
        _balanceSheet = results[1] as Map<String, dynamic>;
        _cashFlowReport = results[2] as Map<String, dynamic>;
        _generalLedger = results[3] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'Failed to load accounting dashboard: ')}$e')),
      );
    }
  }

  Widget _buildSummaryCards() {
    final totalIncome = parseNum(_profitLoss['total_income']);
    final totalExpenses = parseNum(_profitLoss['total_expenses']);
    final netProfit = parseNum(_profitLoss['net_profit']);
    final cash = parseNum(_balanceSheet['cash']);
    final receivables = parseNum(_balanceSheet['receivables']);
    final liabilities = parseNum(_balanceSheet['liabilities']);
    final totalInflow = parseNum(_cashFlowReport['total_inflow']);
    final totalOutflow = parseNum(_cashFlowReport['total_outflow']);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildSummaryCard(t(context, 'Total Income'), totalIncome, Icons.attach_money, Colors.green),
        _buildSummaryCard(t(context, 'Total Expenses'), totalExpenses, Icons.money_off, Colors.red),
        _buildSummaryCard(t(context, 'Net Profit'), netProfit, Icons.trending_up, Colors.blue),
        _buildSummaryCard(t(context, 'Cash'), cash, Icons.account_balance_wallet, Colors.teal),
        _buildSummaryCard(t(context, 'Receivables'), receivables, Icons.credit_card, Colors.orange),
        _buildSummaryCard(t(context, 'Liabilities'), liabilities, Icons.receipt_long, Colors.purple),
        _buildSummaryCard(t(context, 'Inflow'), totalInflow, Icons.arrow_downward, Colors.green),
        _buildSummaryCard(t(context, 'Outflow'), totalOutflow, Icons.arrow_upward, Colors.red),
      ],
    );
  }

  Widget _buildSummaryCard(String title, num value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowChart() {
    final inflow = parseNum(_cashFlowReport['total_inflow']);
    final outflow = parseNum(_cashFlowReport['total_outflow']);
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barGroups: [
            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: inflow, color: Colors.green, width: 32)]),
            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: outflow, color: Colors.red, width: 32)]),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return Text(t(context, 'Inflow'), style: TextStyle(fontSize: 12));
                    case 1:
                      return Text(t(context, 'Outflow'), style: TextStyle(fontSize: 12));
                    default:
                      return const SizedBox();
                  }
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

  Widget _buildLedgerTable() {
    return Card(
      margin: const EdgeInsets.only(top: 24),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(t(context, 'Date'))),
            DataColumn(label: Text(t(context, 'Type'))),
            DataColumn(label: Text(t(context, 'Amount'))),
            DataColumn(label: Text(t(context, 'Category'))),
            DataColumn(label: Text(t(context, 'Vendor'))),
            DataColumn(label: Text(t(context, 'Notes'))),
          ],
          rows: _generalLedger.isEmpty
              ? [DataRow(cells: [DataCell(Text(t(context, 'No data'))), DataCell(Text('')), DataCell(Text('')), DataCell(Text('')), DataCell(Text('')), DataCell(Text(''))])]
              : _generalLedger.map<DataRow>((row) {
                  return DataRow(cells: [
                    DataCell(Text(row['date']?.toString().substring(0, 10) ?? '')),
                    DataCell(Text(row['type'] ?? '')),
                    DataCell(Text(parseNum(row['amount']).toStringAsFixed(2))),
                    DataCell(Text(row['category'] ?? '')),
                    DataCell(Text(row['vendor']?.toString() ?? '')),
                    DataCell(Text(row['notes'] ?? '')),
                  ]);
                }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'Accounting Dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  Text(t(context, 'Cash Flow'), style: Theme.of(context).textTheme.titleMedium),
                  _buildCashFlowChart(),
                  _buildLedgerTable(),
                ],
              ),
            ),
    );
  }
} 