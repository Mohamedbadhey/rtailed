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

  Widget _buildSummaryCards(bool isSmallMobile, bool isMobile) {
    final totalIncome = parseNum(_profitLoss['total_income']);
    final totalExpenses = parseNum(_profitLoss['total_expenses']);
    final netProfit = parseNum(_profitLoss['net_profit']);
    final cash = parseNum(_balanceSheet['cash']);
    final receivables = parseNum(_balanceSheet['receivables']);
    final liabilities = parseNum(_balanceSheet['liabilities']);
    final totalInflow = parseNum(_cashFlowReport['total_inflow']);
    final totalOutflow = parseNum(_cashFlowReport['total_outflow']);
    
    return GridView.count(
      crossAxisCount: isSmallMobile ? 2 : (isMobile ? 2 : 3),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: isSmallMobile ? 8 : (isMobile ? 12 : 16),
      mainAxisSpacing: isSmallMobile ? 8 : (isMobile ? 12 : 16),
      childAspectRatio: isSmallMobile ? 1.8 : (isMobile ? 2.0 : 2.2),
      children: [
        _buildSummaryCard(t(context, 'Total Income'), totalIncome, Icons.attach_money, Colors.green, isSmallMobile),
        _buildSummaryCard(t(context, 'Total Expenses'), totalExpenses, Icons.money_off, Colors.red, isSmallMobile),
        _buildSummaryCard(t(context, 'Net Profit'), netProfit, Icons.trending_up, Colors.blue, isSmallMobile),
        _buildSummaryCard(t(context, 'Cash'), cash, Icons.account_balance_wallet, Colors.teal, isSmallMobile),
        _buildSummaryCard(t(context, 'Receivables'), receivables, Icons.credit_card, Colors.orange, isSmallMobile),
        _buildSummaryCard(t(context, 'Liabilities'), liabilities, Icons.receipt_long, Colors.purple, isSmallMobile),
        _buildSummaryCard(t(context, 'Inflow'), totalInflow, Icons.arrow_downward, Colors.green, isSmallMobile),
        _buildSummaryCard(t(context, 'Outflow'), totalOutflow, Icons.arrow_upward, Colors.red, isSmallMobile),
      ],
    );
  }

  Widget _buildSummaryCard(String title, num value, IconData icon, Color color, bool isSmallMobile) {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12)),
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 10 : 16)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
              ),
              child: Icon(
                icon, 
                color: color, 
                size: isSmallMobile ? 18 : 22,
              ),
            ),
            SizedBox(width: isSmallMobile ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallMobile ? 10 : 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isSmallMobile ? 2 : 4),
                  Text(
                    '${value.toStringAsFixed(2)}', 
                    style: TextStyle(
                      fontSize: isSmallMobile ? 14 : 16, 
                      color: color, 
                      fontWeight: FontWeight.bold
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

  Widget _buildCashFlowChart(bool isSmallMobile, bool isMobile) {
    final inflow = parseNum(_cashFlowReport['total_inflow']);
    final outflow = parseNum(_cashFlowReport['total_outflow']);
    return SizedBox(
      height: isSmallMobile ? 150 : (isMobile ? 160 : 180),
      child: BarChart(
        BarChartData(
          barGroups: [
            BarChartGroupData(
              x: 0, 
              barRods: [
                BarChartRodData(
                  toY: inflow, 
                  color: Colors.green, 
                  width: isSmallMobile ? 24 : (isMobile ? 28 : 32)
                )
              ]
            ),
            BarChartGroupData(
              x: 1, 
              barRods: [
                BarChartRodData(
                  toY: outflow, 
                  color: Colors.red, 
                  width: isSmallMobile ? 24 : (isMobile ? 28 : 32)
                )
              ]
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return Text(
                        t(context, 'Inflow'), 
                        style: TextStyle(fontSize: isSmallMobile ? 10 : 12)
                      );
                    case 1:
                      return Text(
                        t(context, 'Outflow'), 
                        style: TextStyle(fontSize: isSmallMobile ? 10 : 12)
                      );
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

  Widget _buildLedgerTable(bool isSmallMobile, bool isMobile) {
    return Card(
      margin: EdgeInsets.only(top: isSmallMobile ? 16 : 24),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12)),
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'General Ledger'),
              style: TextStyle(
                fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallMobile ? 8 : 12),
            isMobile
                ? _buildMobileLedgerList(_generalLedger, isSmallMobile)
                : SingleChildScrollView(
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
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLedgerList(List<Map<String, dynamic>> ledger, bool isSmallMobile) {
    if (ledger.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isSmallMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            t(context, 'No data'),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isSmallMobile ? 12 : 14,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ledger.length,
      itemBuilder: (context, index) {
        final row = ledger[index];
        final amount = parseNum(row['amount']);
        final isPositive = row['type']?.toString().toLowerCase() == 'income';
        
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
                            row['date']?.toString().substring(0, 10) ?? 'Unknown Date',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallMobile ? 12 : 13,
                            ),
                          ),
                          SizedBox(height: isSmallMobile ? 2 : 4),
                          Text(
                            row['type'] ?? 'Unknown Type',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: isSmallMobile ? 2 : 4),
                          Text(
                            row['category'] ?? 'No Category',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
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
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallMobile ? 14 : 16,
                          ),
                        ),
                        SizedBox(height: isSmallMobile ? 2 : 4),
                        if (row['vendor'] != null)
                          Text(
                            row['vendor'].toString(),
                            style: TextStyle(
                              fontSize: isSmallMobile ? 9 : 10,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.end,
                          ),
                      ],
                    ),
                  ],
                ),
                if (row['notes'] != null && row['notes'].toString().isNotEmpty) ...[
                  SizedBox(height: isSmallMobile ? 4 : 6),
                  Text(
                    'Notes: ${row['notes']}',
                    style: TextStyle(
                      fontSize: isSmallMobile ? 9 : 10,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive breakpoints
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSmallMobile ? 'Accounting' : t(context, 'Accounting Dashboard'),
          style: TextStyle(fontSize: isSmallMobile ? 16 : 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: isSmallMobile ? 18 : 20,
            ),
            tooltip: 'Refresh',
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 12 : 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(isSmallMobile, isMobile),
                  SizedBox(height: isSmallMobile ? 16 : 24),
                  Text(
                    t(context, 'Cash Flow'), 
                    style: TextStyle(
                      fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isSmallMobile ? 8 : 12),
                  _buildCashFlowChart(isSmallMobile, isMobile),
                  SizedBox(height: isSmallMobile ? 16 : 24),
                  _buildLedgerTable(isSmallMobile, isMobile),
                ],
              ),
            ),
    );
  }
} 