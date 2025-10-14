import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/models/damaged_product.dart';
import 'package:retail_management/models/product.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:intl/intl.dart';

class DamagedProductsScreen extends StatefulWidget {
  const DamagedProductsScreen({Key? key}) : super(key: key);

  @override
  State<DamagedProductsScreen> createState() => _DamagedProductsScreenState();
}

class _DamagedProductsScreenState extends State<DamagedProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _damagedProducts = [];
  Map<String, dynamic>? _reportData;
  List<Product> _products = [];
  bool _isLoading = true;
  bool _isLoadingReport = false;
  
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedDamageType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final damagedProducts = await _apiService.getDamagedProducts();
      setState(() {
        _damagedProducts = damagedProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load damaged products: $e');
    }
  }

  Future<void> _loadReport() async {
    setState(() => _isLoadingReport = true);
    try {
      final reportData = await _apiService.getDamagedProductsReport(
        startDate: _startDate?.toIso8601String().split('T')[0],
        endDate: _endDate?.toIso8601String().split('T')[0],
        damageType: _selectedDamageType,
      );
      setState(() {
        _reportData = reportData;
        _isLoadingReport = false;
      });
    } catch (e) {
      setState(() => _isLoadingReport = false);
      _showErrorSnackBar('Failed to load report: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive breakpoints
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return Scaffold(
      appBar: BrandedAppBar(
        title: isSmallMobile ? 'Damaged Products' : t(context, 'Damaged Products'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isSmallMobile ? 50 : (isMobile ? 55 : 60)),
          child: Container(
            height: isSmallMobile ? 50 : (isMobile ? 55 : 60),
            child: TabBar(
              controller: _tabController,
              indicatorColor: ThemeAwareColors.getTextColor(context),
              indicatorWeight: isSmallMobile ? 2 : 3,
              indicatorSize: TabBarIndicatorSize.tab,
              isScrollable: false, // Make tabs fill the entire width
              labelPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 12 : (isMobile ? 16 : 20),
                vertical: isSmallMobile ? 1 : (isMobile ? 2 : 3),
              ),
              labelStyle: TextStyle(
                fontSize: isSmallMobile ? 10 : (isMobile ? 11 : 12),
                fontWeight: FontWeight.w600,
                color: ThemeAwareColors.getTextColor(context),
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: isSmallMobile ? 9 : (isMobile ? 10 : 11),
                fontWeight: FontWeight.normal,
                color: ThemeAwareColors.getTextColor(context).withOpacity(0.7),
              ),
              dividerColor: Colors.transparent,
              indicatorPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 6 : (isMobile ? 8 : 10),
              ),
              tabs: [
                Tab(
                  text: 'Records',
                  icon: Icon(
                    Icons.list,
                    size: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                    color: ThemeAwareColors.getTextColor(context),
                  ),
                ),
                Tab(
                  text: 'Report',
                  icon: Icon(
                    Icons.analytics,
                    size: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                    color: ThemeAwareColors.getTextColor(context),
                  ),
                ),
                Tab(
                  text: 'Add New',
                  icon: Icon(
                    Icons.add,
                    size: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                    color: ThemeAwareColors.getTextColor(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecordsTab(),
          _buildReportTab(),
          _buildAddNewTab(),
        ],
      ),
    );
  }

  Widget _buildRecordsTab() {
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_damagedProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined, 
              size: isSmallMobile ? 40 : (isMobile ? 48 : 56), 
              color: Colors.grey
            ),
            SizedBox(height: isSmallMobile ? 8 : 12),
            Text(
              t(context, 'No damaged products found'), 
              style: TextStyle(
                fontSize: isSmallMobile ? 14 : (isMobile ? 15 : 16), 
                color: Colors.grey
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(isSmallMobile ? 4 : (isMobile ? 6 : 8)),
        itemCount: _damagedProducts.length,
        itemBuilder: (context, index) {
          final damagedProduct = _damagedProducts[index];
          return Card(
            margin: EdgeInsets.only(bottom: isSmallMobile ? 4 : (isMobile ? 6 : 8)),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallMobile ? 6 : (isMobile ? 8 : 10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Product Name and Actions
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              damagedProduct['product_name'] ?? 'Unknown Product',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallMobile ? 12 : (isMobile ? 13 : 14),
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: isSmallMobile ? 2 : 3),
                            Row(
                              children: [
                                _buildDamageTypeChip(damagedProduct['damage_type'], isSmallMobile),
                                SizedBox(width: isSmallMobile ? 3 : 4),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallMobile ? 3 : 4,
                                    vertical: isSmallMobile ? 1 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(isSmallMobile ? 2 : 3),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Text(
                                    'Qty: ${damagedProduct['quantity']}',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: isSmallMobile ? 8 : 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton(
                        icon: Icon(
                          Icons.more_vert,
                          size: isSmallMobile ? 14 : 16,
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  size: isSmallMobile ? 12 : 14,
                                ),
                                SizedBox(width: isSmallMobile ? 3 : 4),
                                Text(
                                  t(context, 'Edit'),
                                  style: TextStyle(fontSize: isSmallMobile ? 10 : 11),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete, 
                                  color: Colors.red,
                                  size: isSmallMobile ? 12 : 14,
                                ),
                                SizedBox(width: isSmallMobile ? 3 : 4),
                                Text(
                                  t(context, 'Delete'), 
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: isSmallMobile ? 10 : 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditDialog(damagedProduct);
                          } else if (value == 'delete') {
                            _showDeleteDialog(damagedProduct['id']);
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallMobile ? 4 : 6),
                  
                  // Details Section
                  Container(
                    padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(isSmallMobile ? 3 : 4),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: isSmallMobile ? 10 : 12,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: isSmallMobile ? 3 : 4),
                            Expanded(
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(DateTime.parse(damagedProduct['damage_date'])),
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 9 : 10,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (damagedProduct['damage_reason'] != null) ...[
                          SizedBox(height: isSmallMobile ? 2 : 3),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: isSmallMobile ? 10 : 12,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: isSmallMobile ? 3 : 4),
                              Expanded(
                                child: Text(
                                  damagedProduct['damage_reason'],
                                  style: TextStyle(
                                    fontSize: isSmallMobile ? 9 : 10,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (damagedProduct['estimated_loss'] != null) ...[
                          SizedBox(height: isSmallMobile ? 2 : 3),
                          Row(
                            children: [
                              Icon(
                                Icons.money_off,
                                size: isSmallMobile ? 10 : 12,
                                color: Colors.red[600],
                              ),
                              SizedBox(width: isSmallMobile ? 3 : 4),
                              Expanded(
                                child: Text(
                                  'Loss: \$${(double.tryParse(damagedProduct['estimated_loss'].toString()) ?? 0.0).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: isSmallMobile ? 9 : 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: isSmallMobile ? 2 : 3),
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: isSmallMobile ? 10 : 12,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: isSmallMobile ? 3 : 4),
                            Expanded(
                              child: Text(
                                'Reported by: ${damagedProduct['reported_by_name']}',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 9 : 10,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportTab() {
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallMobile ? 3 : (isMobile ? 4 : 6)),
      child: Column(
        children: [
          _buildReportFilters(isSmallMobile, isMobile),
          SizedBox(height: isSmallMobile ? 4 : 6),
          _isLoadingReport
              ? const Center(child: CircularProgressIndicator())
              : _reportData == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: isSmallMobile ? 36 : (isMobile ? 40 : 48),
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: isSmallMobile ? 4 : 6),
                          Text(
                            t(context, 'Select filters and load report'),
                            style: TextStyle(
                              fontSize: isSmallMobile ? 11 : (isMobile ? 12 : 13),
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : _buildReportContent(isSmallMobile, isMobile),
        ],
      ),
    );
  }

  Widget _buildReportFilters(bool isSmallMobile, bool isMobile) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 10 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: isSmallMobile ? 14 : 16,
                  color: Colors.blue,
                ),
                SizedBox(width: isSmallMobile ? 3 : 4),
                Text(
                  t(context, 'Report Filters'),
                  style: TextStyle(
                    fontSize: isSmallMobile ? 12 : (isMobile ? 13 : 14), 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallMobile ? 6 : 8),
            isMobile
                ? Column(
                    children: [
                      TextButton.icon(
                        onPressed: () => _selectDate(true),
                        icon: Icon(
                          Icons.calendar_today,
                          size: isSmallMobile ? 12 : 14,
                        ),
                        label: Text(
                          _startDate == null 
                              ? 'Start Date' 
                              : DateFormat('MMM dd, yyyy').format(_startDate!),
                          style: TextStyle(fontSize: isSmallMobile ? 10 : 11),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallMobile ? 4 : 6,
                            vertical: isSmallMobile ? 4 : 6,
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallMobile ? 4 : 6),
                      TextButton.icon(
                        onPressed: () => _selectDate(false),
                        icon: Icon(
                          Icons.calendar_today,
                          size: isSmallMobile ? 12 : 14,
                        ),
                        label: Text(
                          _endDate == null 
                              ? 'End Date' 
                              : DateFormat('MMM dd, yyyy').format(_endDate!),
                          style: TextStyle(fontSize: isSmallMobile ? 10 : 11),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallMobile ? 4 : 6,
                            vertical: isSmallMobile ? 4 : 6,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _selectDate(true),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_startDate == null 
                              ? 'Start Date' 
                              : DateFormat('MMM dd, yyyy').format(_startDate!)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _selectDate(false),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_endDate == null 
                              ? 'End Date' 
                              : DateFormat('MMM dd, yyyy').format(_endDate!)),
                        ),
                      ),
                    ],
                  ),
            SizedBox(height: isSmallMobile ? 6 : 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Damage Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmallMobile ? 3 : 4),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallMobile ? 6 : 8,
                  vertical: isSmallMobile ? 4 : 6,
                ),
              ),
              value: _selectedDamageType,
              items: [
                DropdownMenuItem(value: null, child: Text(t(context, 'All Types'))),
                ...DamageType.values.map((type) => DropdownMenuItem(
                  value: type.name,
                  child: Text(
                    type.name.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: isSmallMobile ? 10 : 11),
                  ),
                )),
              ],
              onChanged: (value) {
                setState(() => _selectedDamageType = value);
              },
            ),
            SizedBox(height: isSmallMobile ? 6 : 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadReport,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallMobile ? 8 : 10,
                    vertical: isSmallMobile ? 6 : 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isSmallMobile ? 3 : 4),
                  ),
                ),
                child: Text(
                  t(context, 'Load Report'),
                  style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(bool isSmallMobile, bool isMobile) {
    final summary = _reportData!['summary'];
    final damageTypeBreakdown = _reportData!['damageTypeBreakdown'] as List;
    final topDamagedProducts = _reportData!['topDamagedProducts'] as List;
    final cashierBreakdown = _reportData!['cashierBreakdown'] as List;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          isMobile
              ? Column(
                  children: [
                    _buildSummaryCard(
                      'Total Incidents',
                      summary['total_incidents'].toString(),
                      Icons.warning,
                      Colors.orange,
                      isSmallMobile,
                    ),
                    SizedBox(height: isSmallMobile ? 6 : 8),
                    _buildSummaryCard(
                      'Total Quantity',
                      summary['total_quantity_damaged'].toString(),
                      Icons.inventory_2,
                      Colors.red,
                      isSmallMobile,
                    ),
                    SizedBox(height: isSmallMobile ? 6 : 8),
                    _buildSummaryCard(
                      'Total Loss',
                      '\$${(double.tryParse(summary['total_estimated_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                      Icons.money_off,
                      Colors.red,
                      isSmallMobile,
                    ),
                    SizedBox(height: isSmallMobile ? 6 : 8),
                    _buildSummaryCard(
                      'Top Cashier',
                      cashierBreakdown.isNotEmpty ? cashierBreakdown.first['cashier_name'] ?? 'N/A' : 'N/A',
                      Icons.person,
                      Colors.blue,
                      isSmallMobile,
                    ),
                    SizedBox(height: isSmallMobile ? 6 : 8),
                    _buildSummaryCard(
                      'Avg Loss/Item',
                      '\$${(double.tryParse(summary['avg_loss_per_item']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                      Icons.analytics,
                      Colors.blue,
                      isSmallMobile,
                    ),
                    SizedBox(height: isSmallMobile ? 6 : 8),
                    _buildSummaryCard(
                      'Cashiers Involved',
                      cashierBreakdown.length.toString(),
                      Icons.people,
                      Colors.green,
                      isSmallMobile,
                    ),
                  ],
                )
              : Column(
                  children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Incidents',
                  summary['total_incidents'].toString(),
                  Icons.warning,
                  Colors.orange,
                            isSmallMobile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Total Quantity',
                  summary['total_quantity_damaged'].toString(),
                  Icons.inventory_2,
                  Colors.red,
                            isSmallMobile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Loss',
                  '\$${(double.tryParse(summary['total_estimated_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                  Icons.money_off,
                  Colors.red,
                            isSmallMobile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Top Cashier',
                  cashierBreakdown.isNotEmpty ? cashierBreakdown.first['cashier_name'] ?? 'N/A' : 'N/A',
                  Icons.person,
                  Colors.blue,
                            isSmallMobile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Avg Loss/Item',
                  '\$${(double.tryParse(summary['avg_loss_per_item']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                  Icons.analytics,
                  Colors.blue,
                            isSmallMobile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Cashiers Involved',
                  cashierBreakdown.length.toString(),
                  Icons.people,
                  Colors.green,
                            isSmallMobile,
                ),
              ),
            ],
          ),
                  ],
                ),
          SizedBox(height: isSmallMobile ? 16 : 24),
          
          // Damage Type Breakdown
          Text(
            'Damage Type Breakdown', 
            style: TextStyle(
              fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18), 
              fontWeight: FontWeight.bold
            ),
          ),
          SizedBox(height: isSmallMobile ? 6 : 8),
          isMobile
              ? _buildMobileDamageTypeBreakdown(damageTypeBreakdown.cast<Map<String, dynamic>>(), isSmallMobile)
              : Card(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: damageTypeBreakdown.length,
              itemBuilder: (context, index) {
                final item = damageTypeBreakdown[index];
                return ListTile(
                        title: Text(
                          item['damage_type'].toString().replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(fontSize: isSmallMobile ? 13 : 14),
                        ),
                        subtitle: Text(
                          '${item['incident_count']} incidents, ${item['total_quantity']} items',
                          style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
                        ),
                  trailing: Text(
                    '\$${(double.tryParse(item['total_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: Colors.red,
                            fontSize: isSmallMobile ? 12 : 14,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallMobile ? 8 : 16,
                          vertical: isSmallMobile ? 4 : 8,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: isSmallMobile ? 16 : 24),
          
          // Top Damaged Products
          Text(
            'Top Damaged Products', 
            style: TextStyle(
              fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18), 
              fontWeight: FontWeight.bold
            ),
          ),
          SizedBox(height: isSmallMobile ? 6 : 8),
          isMobile
              ? _buildMobileTopDamagedProducts(topDamagedProducts.cast<Map<String, dynamic>>(), isSmallMobile)
              : Card(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topDamagedProducts.length,
              itemBuilder: (context, index) {
                final item = topDamagedProducts[index];
                return ListTile(
                        title: Text(
                          item['product_name'],
                          style: TextStyle(fontSize: isSmallMobile ? 13 : 14),
                        ),
                        subtitle: Text(
                          '${item['incident_count']} incidents, ${item['total_quantity_damaged']} items',
                          style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
                        ),
                  trailing: Text(
                    '\$${(double.tryParse(item['total_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: Colors.red,
                            fontSize: isSmallMobile ? 12 : 14,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallMobile ? 8 : 16,
                          vertical: isSmallMobile ? 4 : 8,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: isSmallMobile ? 16 : 24),
          
          // Cashier Breakdown
          Text(
            'Cashier Breakdown', 
            style: TextStyle(
              fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18), 
              fontWeight: FontWeight.bold
            ),
          ),
          SizedBox(height: isSmallMobile ? 6 : 8),
          isMobile
              ? _buildMobileCashierBreakdown(cashierBreakdown.cast<Map<String, dynamic>>(), isSmallMobile)
              : Card(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cashierBreakdown.length,
              itemBuilder: (context, index) {
                final item = cashierBreakdown[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                          radius: isSmallMobile ? 14 : 16,
                    child: Text(
                      (item['cashier_name'] ?? 'Unknown')[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                              fontSize: isSmallMobile ? 12 : 14,
                      ),
                    ),
                  ),
                        title: Text(
                          item['cashier_name'] ?? 'Unknown Cashier',
                          style: TextStyle(fontSize: isSmallMobile ? 13 : 14),
                        ),
                        subtitle: Text(
                          '${item['incident_count']} incidents, ${item['total_quantity_damaged']} items',
                          style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
                        ),
                  trailing: Text(
                    '\$${(double.tryParse(item['total_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: Colors.red,
                            fontSize: isSmallMobile ? 12 : 14,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallMobile ? 8 : 16,
                          vertical: isSmallMobile ? 4 : 8,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: isSmallMobile ? 16 : 24),
          
          // Detailed Damaged Products Table
          Text(
            'Detailed Damaged Products', 
            style: TextStyle(
              fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18), 
              fontWeight: FontWeight.bold
            ),
          ),
          SizedBox(height: isSmallMobile ? 6 : 8),
          isMobile
              ? _buildMobileDetailedProductsList(_damagedProducts, isSmallMobile)
              : Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Reason')),
                  DataColumn(label: Text('Loss')),
                  DataColumn(label: Text('Cashier')),
                ],
                rows: _damagedProducts.map((item) => DataRow(
                  cells: [
                    DataCell(Text(item['product_name'] ?? '')),
                    DataCell(Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(item['damage_date'])))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (item['damage_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(item['quantity'].toString())),
                    DataCell(
                      Tooltip(
                        message: item['damage_reason'] ?? '',
                        child: Text(
                          item['damage_reason'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '\$${(double.tryParse(item['estimated_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      Text(
                              (item['reported_by_name'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDamageTypeBreakdown(List<Map<String, dynamic>> breakdown, bool isSmallMobile) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: breakdown.length,
      itemBuilder: (context, index) {
        final item = breakdown[index];
    return Card(
          margin: EdgeInsets.only(bottom: isSmallMobile ? 6 : 8),
      child: Padding(
            padding: EdgeInsets.all(isSmallMobile ? 10 : 12),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Text(
                  item['damage_type'].toString().replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: isSmallMobile ? 13 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallMobile ? 4 : 6),
                Text(
                  '${item['incident_count']} incidents, ${item['total_quantity']} items',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 11 : 12,
                  ),
                ),
                SizedBox(height: isSmallMobile ? 4 : 6),
                Text(
                  '\$${(double.tryParse(item['total_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: isSmallMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileTopDamagedProducts(List<Map<String, dynamic>> topDamagedProducts, bool isSmallMobile) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: topDamagedProducts.length,
      itemBuilder: (context, index) {
        final item = topDamagedProducts[index];
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
                      child: Text(
                        item['product_name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallMobile ? 13 : 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallMobile ? 6 : 8,
                        vertical: isSmallMobile ? 2 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Text(
                        (item['damage_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: isSmallMobile ? 9 : 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 4 : 6),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Incidents: ${item['incident_count']}',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: isSmallMobile ? 2 : 3),
                          Text(
                            'Qty: ${item['total_quantity_damaged']}',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 10 : 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (item['damage_reason'] != null) ...[
                            SizedBox(height: isSmallMobile ? 2 : 3),
                            Text(
                              'Reason: ${item['damage_reason']}',
                              style: TextStyle(
                                fontSize: isSmallMobile ? 10 : 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${(double.tryParse(item['total_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallMobile ? 12 : 14,
                          ),
                        ),
                        SizedBox(height: isSmallMobile ? 2 : 4),
                        Text(
                          item['reported_by_name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: isSmallMobile ? 9 : 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileCashierBreakdown(List<Map<String, dynamic>> cashierBreakdown, bool isSmallMobile) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cashierBreakdown.length,
      itemBuilder: (context, index) {
        final item = cashierBreakdown[index];
        return Card(
          margin: EdgeInsets.only(bottom: isSmallMobile ? 6 : 8),
          child: Padding(
            padding: EdgeInsets.all(isSmallMobile ? 10 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      radius: isSmallMobile ? 14 : 16,
                      child: Text(
                        (item['cashier_name'] ?? 'Unknown')[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallMobile ? 12 : 14,
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 10),
                    Expanded(
                      child: Text(
                        item['cashier_name'] ?? 'Unknown Cashier',
                        style: TextStyle(fontSize: isSmallMobile ? 13 : 14),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 4 : 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Incidents: ${item['incident_count']}',
                        style: TextStyle(
                          fontSize: isSmallMobile ? 10 : 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 10),
                    Expanded(
                      child: Text(
                        'Qty: ${item['total_quantity_damaged']}',
                        style: TextStyle(
                          fontSize: isSmallMobile ? 10 : 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 4 : 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Loss: \$${(double.tryParse(item['total_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: isSmallMobile ? 12 : 14,
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 10),
                    Expanded(
                      child: Text(
                        item['reported_by_name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: isSmallMobile ? 9 : 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDetailedProductsList(List<Map<String, dynamic>> products, bool isSmallMobile) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        return Card(
          margin: EdgeInsets.only(bottom: isSmallMobile ? 6 : 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallMobile ? 8 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['product_name'] ?? 'Unknown Product',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallMobile ? 12 : 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallMobile ? 4 : 6,
                        vertical: isSmallMobile ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(isSmallMobile ? 3 : 4),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Text(
                        (item['damage_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: isSmallMobile ? 8 : 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallMobile ? 3 : 4),
                
                // Details Grid
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(DateTime.parse(item['damage_date']))),
                          SizedBox(height: isSmallMobile ? 1 : 2),
                          _buildDetailRow('Qty', '${item['quantity']}'),
                        ],
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Loss', '\$${(double.tryParse(item['estimated_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}', isRed: true),
                          SizedBox(height: isSmallMobile ? 1 : 2),
                          _buildDetailRow('By', item['reported_by_name']?.toString() ?? 'Unknown'),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Reason (if available)
                if (item['damage_reason'] != null) ...[
                  SizedBox(height: isSmallMobile ? 3 : 4),
                  Container(
                    padding: EdgeInsets.all(isSmallMobile ? 4 : 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(isSmallMobile ? 3 : 4),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: isSmallMobile ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: isSmallMobile ? 4 : 6),
                        Expanded(
                          child: Text(
                            item['damage_reason'],
                            style: TextStyle(
                              fontSize: isSmallMobile ? 9 : 10,
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildDetailRow(String label, String value, {bool isRed = false}) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 9,
              color: isRed ? Colors.red[700] : Colors.grey[800],
              fontWeight: isRed ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isSmallMobile) {
    return Container(
      padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon, 
            color: color, 
            size: isSmallMobile ? 18 : 24,
          ),
          SizedBox(height: isSmallMobile ? 4 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallMobile ? 14 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallMobile ? 3 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallMobile ? 10 : 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewTab() {
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallMobile ? 3 : 4),
      child: _AddDamagedProductForm(onProductAdded: _loadData),
    );
  }

  Widget _buildDamageTypeChip(String damageType, bool isSmallMobile) {
    Color color;
    switch (damageType) {
      case 'broken':
        color = Colors.red;
        break;
      case 'expired':
        color = Colors.orange;
        break;
      case 'defective':
        color = Colors.purple;
        break;
      case 'damaged_package':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        damageType.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: Colors.white, fontSize: isSmallMobile ? 10 : 12),
      ),
      backgroundColor: color,
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? DateTime.now().subtract(const Duration(days: 30)) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showEditDialog(Map<String, dynamic> damagedProduct) {
    // Implementation for edit dialog
    showDialog(
      context: context,
      builder: (context) => _EditDamagedProductDialog(
        damagedProduct: damagedProduct,
        onProductUpdated: _loadData,
      ),
    );
  }

  void _showDeleteDialog(int id) {
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.delete_forever,
              size: isSmallMobile ? 18 : 20,
              color: Colors.red,
            ),
            SizedBox(width: isSmallMobile ? 6 : 8),
            Expanded(
              child: Text(
                'Delete Damaged Product',
                style: TextStyle(
                  fontSize: isSmallMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this damaged product record? This will restore the quantity to stock.',
          style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _apiService.deleteDamagedProduct(id);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Damaged product deleted successfully',
                      style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                    ),
                  ),
                );
              } catch (e) {
                _showErrorSnackBar('Failed to delete: $e');
              }
            },
            child: Text(
              'Delete', 
              style: TextStyle(
                color: Colors.red,
                fontSize: isSmallMobile ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDamagedProductForm extends StatefulWidget {
  final VoidCallback onProductAdded;

  const _AddDamagedProductForm({required this.onProductAdded});

  @override
  State<_AddDamagedProductForm> createState() => _AddDamagedProductFormState();
}

class _AddDamagedProductFormState extends State<_AddDamagedProductForm> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  List<Product> _products = [];
  Product? _selectedProduct;
  DamageType _selectedDamageType = DamageType.broken;
  int _quantity = 1;
  DateTime _damageDate = DateTime.now();
  String _damageReason = '';
  double? _estimatedLoss;
  
  bool _isLoading = false;
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      print('Loading products for damaged products form...');
      final products = await _apiService.getProducts();
      print('Products loaded: ${products.length}');
      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() => _isLoadingProducts = false);
      
      String errorMessage = 'Failed to load products';
      if (e.toString().contains('damaged_quantity')) {
        errorMessage = 'Database migration required. Please run the damaged products migration.';
      } else if (e.toString().contains('Connection refused') || e.toString().contains('Failed host lookup')) {
        errorMessage = 'Cannot connect to server. Please ensure the backend is running.';
      } else {
        errorMessage = 'Failed to load products: $e';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiService.reportDamagedProduct({
        'product_id': _selectedProduct!.id,
        'quantity': _quantity,
        'damage_type': _selectedDamageType.name,
        'damage_date': _damageDate.toIso8601String().split('T')[0],
        'damage_reason': _damageReason.isEmpty ? null : _damageReason,
        'estimated_loss': _estimatedLoss,
      });

      widget.onProductAdded();
      _formKey.currentState!.reset();
      setState(() {
        _selectedProduct = null;
        _quantity = 1;
        _damageDate = DateTime.now();
        _damageReason = '';
        _estimatedLoss = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Damaged product reported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report damaged product: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive breakpoints
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.report_problem,
                size: isSmallMobile ? 14 : 16,
                color: Colors.orange,
              ),
              SizedBox(width: isSmallMobile ? 3 : 4),
              Expanded(
                child: Text(
                  'Report Damaged Product',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallMobile ? 6 : 8),
          
          // Product Selection
          Text(
            'Product *',
            style: TextStyle(
              fontSize: isSmallMobile ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: isSmallMobile ? 3 : 4),
          DropdownButtonFormField<Product>(
            decoration: InputDecoration(
              labelText: 'Select a product',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallMobile ? 3 : 4),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 6 : 8,
                vertical: isSmallMobile ? 4 : 6,
              ),
            ),
            value: _selectedProduct,
            items: _products.map((product) => DropdownMenuItem(
              value: product,
              child: Text(
                '${product.name} (${product.sku}) - Stock: ${product.stockQuantity}',
                style: TextStyle(fontSize: isSmallMobile ? 10 : 11),
              ),
            )).toList(),
            onChanged: (product) {
              setState(() {
                _selectedProduct = product;
                if (product != null && _quantity > product.stockQuantity) {
                  _quantity = product.stockQuantity;
                }
              });
            },
            validator: (value) => value == null ? 'Please select a product' : null,
          ),
          SizedBox(height: isSmallMobile ? 6 : 8),
          
          // Quantity
          Text(
            'Quantity *',
            style: TextStyle(
              fontSize: isSmallMobile ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: isSmallMobile ? 4 : 6),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Enter quantity',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 8 : 10,
                vertical: isSmallMobile ? 6 : 8,
              ),
            ),
            keyboardType: TextInputType.number,
            initialValue: '1',
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter quantity';
              final qty = int.tryParse(value);
              if (qty == null || qty <= 0) return 'Quantity must be a positive number';
              if (_selectedProduct != null && qty > _selectedProduct!.stockQuantity) {
                return 'Quantity cannot exceed available stock (${_selectedProduct!.stockQuantity})';
              }
              return null;
            },
            onChanged: (value) {
              setState(() => _quantity = int.tryParse(value) ?? 1);
            },
          ),
          SizedBox(height: isSmallMobile ? 8 : 12),
          
          // Damage Type
          Text(
            'Damage Type *',
            style: TextStyle(
              fontSize: isSmallMobile ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: isSmallMobile ? 4 : 6),
          DropdownButtonFormField<DamageType>(
            decoration: InputDecoration(
              labelText: 'Select damage type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 8 : 10,
                vertical: isSmallMobile ? 6 : 8,
              ),
            ),
            value: _selectedDamageType,
            items: DamageType.values.map((type) => DropdownMenuItem(
              value: type,
              child: Text(
                type.name.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
              ),
            )).toList(),
            onChanged: (type) {
              setState(() => _selectedDamageType = type!);
            },
          ),
          SizedBox(height: isSmallMobile ? 8 : 12),
          
          // Damage Date
          Text(
            'Damage Date *',
            style: TextStyle(
              fontSize: isSmallMobile ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: isSmallMobile ? 4 : 6),
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _damageDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _damageDate = picked);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Select date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallMobile ? 8 : 10,
                  vertical: isSmallMobile ? 6 : 8,
                ),
              ),
              child: Text(
                DateFormat('MMM dd, yyyy').format(_damageDate),
                style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
              ),
            ),
          ),
          SizedBox(height: isSmallMobile ? 8 : 12),
          
          // Damage Reason
          Text(
            'Damage Reason',
            style: TextStyle(
              fontSize: isSmallMobile ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: isSmallMobile ? 4 : 6),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Describe the damage (optional)',
              hintText: 'Optional description of the damage',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 8 : 10,
                vertical: isSmallMobile ? 6 : 8,
              ),
            ),
            maxLines: 3,
            onChanged: (value) => _damageReason = value,
          ),
          SizedBox(height: isSmallMobile ? 8 : 12),
          
          // Estimated Loss
          Text(
            'Estimated Loss (\$)',
            style: TextStyle(
              fontSize: isSmallMobile ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: isSmallMobile ? 4 : 6),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Enter estimated loss',
              hintText: 'Leave empty to use product cost price × quantity',
              helperText: 'If not specified, will be calculated automatically',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 8 : 10,
                vertical: isSmallMobile ? 6 : 8,
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() => _estimatedLoss = double.tryParse(value));
            },
          ),
          if (_selectedProduct != null && _estimatedLoss == null) ...[
            SizedBox(height: isSmallMobile ? 4 : 6),
            Container(
              padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info,
                    size: isSmallMobile ? 12 : 14,
                    color: Colors.blue[700],
                  ),
                  SizedBox(width: isSmallMobile ? 4 : 6),
                  Expanded(
              child: Text(
                'Auto-calculated loss: \$${(_selectedProduct!.costPrice * _quantity).toStringAsFixed(2)} (${_selectedProduct!.costPrice.toStringAsFixed(2)} × $_quantity)',
                style: TextStyle(
                  color: Colors.blue[700],
                        fontSize: isSmallMobile ? 10 : 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
                ],
              ),
            ),
          ],
          SizedBox(height: isSmallMobile ? 16 : 20),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallMobile ? 10 : 12,
                  vertical: isSmallMobile ? 10 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
                ),
              ),
              child: _isLoading 
                  ? SizedBox(
                      height: isSmallMobile ? 14 : 16,
                      width: isSmallMobile ? 14 : 16,
                      child: const CircularProgressIndicator(color: Colors.white),
                    )
                  : Text(
                      'Report Damaged Product',
                      style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditDamagedProductDialog extends StatefulWidget {
  final Map<String, dynamic> damagedProduct;
  final VoidCallback onProductUpdated;

  const _EditDamagedProductDialog({
    required this.damagedProduct,
    required this.onProductUpdated,
  });

  @override
  State<_EditDamagedProductDialog> createState() => _EditDamagedProductDialogState();
}

class _EditDamagedProductDialogState extends State<_EditDamagedProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  late DamageType _selectedDamageType;
  late int _quantity;
  late DateTime _damageDate;
  late String _damageReason;
  double? _estimatedLoss;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDamageType = DamageType.values.firstWhere(
      (e) => e.name == widget.damagedProduct['damage_type'],
      orElse: () => DamageType.broken,
    );
    _quantity = int.tryParse(widget.damagedProduct['quantity'].toString()) ?? 1;
    _damageDate = DateTime.parse(widget.damagedProduct['damage_date']);
    _damageReason = widget.damagedProduct['damage_reason'] ?? '';
    _estimatedLoss = widget.damagedProduct['estimated_loss'] != null 
        ? double.tryParse(widget.damagedProduct['estimated_loss'].toString())
        : null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.updateDamagedProduct(widget.damagedProduct['id'], {
        'quantity': _quantity,
        'damage_type': _selectedDamageType.name,
        'damage_date': _damageDate.toIso8601String().split('T')[0],
        'damage_reason': _damageReason.isEmpty ? null : _damageReason,
        'estimated_loss': _estimatedLoss,
      });

      widget.onProductUpdated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Damaged product updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update damaged product: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive breakpoints
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.edit,
            size: isSmallMobile ? 18 : 20,
            color: Colors.blue,
          ),
          SizedBox(width: isSmallMobile ? 6 : 8),
          Expanded(
            child: Text(
              'Edit Damaged Product',
              style: TextStyle(
                fontSize: isSmallMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Container(
        width: isSmallMobile ? double.infinity : (isMobile ? 300 : 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quantity
              Text(
                'Quantity *',
                style: TextStyle(
                  fontSize: isSmallMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: isSmallMobile ? 6 : 8),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Enter quantity',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallMobile ? 10 : 12,
                    vertical: isSmallMobile ? 8 : 10,
                  ),
                ),
                keyboardType: TextInputType.number,
                initialValue: _quantity.toString(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter quantity';
                  final qty = int.tryParse(value);
                  if (qty == null || qty <= 0) return 'Quantity must be a positive number';
                  return null;
                },
                onChanged: (value) => _quantity = int.tryParse(value) ?? 1,
              ),
              SizedBox(height: isSmallMobile ? 12 : 16),
              
              // Damage Type
              Text(
                'Damage Type *',
                style: TextStyle(
                  fontSize: isSmallMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: isSmallMobile ? 6 : 8),
              DropdownButtonFormField<DamageType>(
                decoration: InputDecoration(
                  labelText: 'Select damage type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallMobile ? 10 : 12,
                    vertical: isSmallMobile ? 8 : 10,
                  ),
                ),
                value: _selectedDamageType,
                items: DamageType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(
                    type.name.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                  ),
                )).toList(),
                onChanged: (type) {
                  setState(() => _selectedDamageType = type!);
                },
              ),
              SizedBox(height: isSmallMobile ? 12 : 16),
              
              // Damage Date
              Text(
                'Damage Date *',
                style: TextStyle(
                  fontSize: isSmallMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: isSmallMobile ? 6 : 8),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _damageDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _damageDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Select date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallMobile ? 10 : 12,
                      vertical: isSmallMobile ? 8 : 10,
                    ),
                  ),
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(_damageDate),
                    style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                  ),
                ),
              ),
              SizedBox(height: isSmallMobile ? 12 : 16),
              
              // Damage Reason
              Text(
                'Damage Reason',
                style: TextStyle(
                  fontSize: isSmallMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: isSmallMobile ? 6 : 8),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Describe the damage (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallMobile ? 10 : 12,
                    vertical: isSmallMobile ? 8 : 10,
                  ),
                ),
                maxLines: 2,
                initialValue: _damageReason,
                onChanged: (value) => _damageReason = value,
              ),
              SizedBox(height: isSmallMobile ? 12 : 16),
              
              // Estimated Loss
              Text(
                'Estimated Loss (\$)',
                style: TextStyle(
                  fontSize: isSmallMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: isSmallMobile ? 6 : 8),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Enter estimated loss',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallMobile ? 10 : 12,
                    vertical: isSmallMobile ? 8 : 10,
                  ),
                ),
                keyboardType: TextInputType.number,
                initialValue: _estimatedLoss?.toString(),
                onChanged: (value) => _estimatedLoss = double.tryParse(value),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 12 : 16,
              vertical: isSmallMobile ? 8 : 10,
            ),
          ),
          child: _isLoading 
              ? SizedBox(
                  height: isSmallMobile ? 16 : 18,
                  width: isSmallMobile ? 16 : 18,
                  child: const CircularProgressIndicator(color: Colors.white),
                )
              : Text(
                  'Update',
                  style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                ),
        ),
      ],
    );
  }
} 
