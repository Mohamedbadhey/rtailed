import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/settings_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/services/api_service.dart';

import 'package:retail_management/widgets/branded_header.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/theme.dart';

import 'manage_cashiers_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();

  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  String _selectedCurrency = 'USD';
  bool _isLoading = false;
  Map<String, dynamic> _systemInfo = {};
  
  // Credit section variables
  bool _showCreditSection = false;
  List<Map<String, dynamic>> _creditCustomers = [];
  bool _creditLoading = false;
  String? _creditError;

  @override
  void initState() {
    super.initState();
    _loadSystemInfo();
  }

  Future<void> _loadSystemInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _apiService.getProducts();
      final customers = await _apiService.getCustomers();
      final sales = await _apiService.getSales();

      setState(() {
        _systemInfo = {
          'totalProducts': products.length,
          'totalCustomers': customers.length,
          'totalSales': sales.length,
          'databaseSize': '${products.length + customers.length + sales.length} records',
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Credit section methods
  Future<void> _loadCreditCustomers() async {
    setState(() {
      _creditLoading = true;
      _creditError = null;
    });

    try {
      final customers = await _apiService.getCreditCustomers();
      print('Credit customers data: $customers'); // Debug log
      setState(() {
        _creditCustomers = customers;
        _creditLoading = false;
      });
    } catch (e) {
      print('Error loading credit customers: $e'); // Debug log
      setState(() {
        _creditError = 'Error: $e';
        _creditLoading = false;
      });
    }
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
      if (_showCreditSection) {
        _loadCreditCustomers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Responsive breakpoints
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 12 : 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branded Header
          Consumer<BrandingProvider>(
            builder: (context, brandingProvider, child) {
              return BrandedHeader(
                subtitle: isSmallMobile ? 'Manage your account' : 'Manage your account and preferences',
                logoSize: isSmallMobile ? 50 : (isMobile ? 55 : 60),
              );
            },
          ),
          SizedBox(height: isSmallMobile ? 16 : (isMobile ? 20 : 24)),
          _buildPreferencesSection(isSmallMobile, isMobile),
          SizedBox(height: isSmallMobile ? 16 : (isMobile ? 20 : 24)),
          _buildCreditSection(isSmallMobile, isMobile),
          SizedBox(height: isSmallMobile ? 16 : (isMobile ? 20 : 24)),
          _buildSystemSection(isSmallMobile, isMobile),
        ],
      ),
    );
  }



  Widget _buildPreferencesSection(bool isSmallMobile, bool isMobile) {
    final settings = Provider.of<SettingsProvider>(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 14 : 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  size: isSmallMobile ? 20 : (isMobile ? 22 : 24),
                  color: Colors.blue,
                ),
                SizedBox(width: isSmallMobile ? 6 : 8),
            Text(
              t(context, 'Preferences'),
                  style: TextStyle(
                    fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18),
                fontWeight: FontWeight.bold,
              ),
            ),
              ],
            ),
            SizedBox(height: isSmallMobile ? 12 : 16),
            SwitchListTile(
              title: Text(
                t(context, 'Dark Mode'),
                style: TextStyle(fontSize: isSmallMobile ? 14 : 16),
              ),
              subtitle: Text(
                t(context, 'Enable dark theme'),
                style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
              ),
              value: settings.themeMode == ThemeMode.dark,
              onChanged: (value) {
                settings.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
              },
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 8 : 16,
                vertical: isSmallMobile ? 4 : 8,
              ),
            ),
            SwitchListTile(
              title: Text(
                t(context, 'Notifications'),
                style: TextStyle(fontSize: isSmallMobile ? 14 : 16),
              ),
              subtitle: Text(
                t(context, 'Enable push notifications'),
                style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
              ),
              value: settings.notificationsEnabled,
              onChanged: (value) {
                settings.setNotificationsEnabled(value);
              },
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 8 : 16,
                vertical: isSmallMobile ? 4 : 8,
              ),
            ),
            ListTile(
              title: Text(
                t(context, 'Language'),
                style: TextStyle(fontSize: isSmallMobile ? 14 : 16),
              ),
              subtitle: Text(
                settings.language,
                style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: isSmallMobile ? 16 : 20,
              ),
              onTap: () {
                _showLanguageDialog(settings);
              },
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 8 : 16,
                vertical: isSmallMobile ? 4 : 8,
              ),
            ),
            ListTile(
              title: Text(
                t(context, 'Currency'),
                style: TextStyle(fontSize: isSmallMobile ? 14 : 16),
              ),
              subtitle: Text(
                settings.currency,
                style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: isSmallMobile ? 16 : 20,
              ),
              onTap: () {
                _showCurrencyDialog(settings);
              },
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 8 : 16,
                vertical: isSmallMobile ? 4 : 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditSection(bool isSmallMobile, bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 14 : 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.credit_card, 
                  color: Colors.orange,
                  size: isSmallMobile ? 20 : (isMobile ? 22 : 24),
                ),
                SizedBox(width: isSmallMobile ? 6 : 8),
                Expanded(
                  child: Text(
                  t(context, 'Credit Management'),
                    style: TextStyle(
                      fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.credit_card, 
                      color: Colors.orange,
                      size: isSmallMobile ? 18 : 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _showCreditSection = !_showCreditSection;
                      });
                      if (_showCreditSection) {
                        _loadCreditCustomers();
                      }
                    },
                    tooltip: 'Toggle Credit Section',
                    padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
                    constraints: BoxConstraints(
                      minWidth: isSmallMobile ? 32 : 40,
                      minHeight: isSmallMobile ? 32 : 40,
                    ),
                  ),
                ),
              ],
            ),
            if (_showCreditSection) ...[
              SizedBox(height: isSmallMobile ? 12 : 16),
              
              // Credit Summary Cards
              _buildCreditSummaryCards(isSmallMobile, isMobile),
              
              SizedBox(height: isSmallMobile ? 12 : 16),
              
              // Credit Section Content (same as dashboard)
              Container(
                padding: EdgeInsets.all(isSmallMobile ? 10 : (isMobile ? 12 : 16)),
                decoration: BoxDecoration(
                  color: ThemeAwareColors.getCardColor(context),
                  borderRadius: BorderRadius.circular(isSmallMobile ? 8 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeAwareColors.getShadowColor(context),
                      blurRadius: isSmallMobile ? 6 : 10,
                      offset: Offset(0, isSmallMobile ? 1 : 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.credit_card, color: Colors.orange, size: isSmallMobile ? 20 : 24),
                        SizedBox(width: isSmallMobile ? 6 : 8),
                        Text(
                          t(context, 'Credit Customers'),
                          style: TextStyle(
                            fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallMobile ? 12 : 16),
                    _creditLoading
                        ? Center(child: CircularProgressIndicator())
                        : _creditError != null
                            ? Text(_creditError!, style: TextStyle(color: Colors.red))
                            : _creditCustomers.isEmpty
                                ? Text(t(context, 'No credit customers found.'))
                                : SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: isSmallMobile ? 8 : 16,
                                      columns: [
                                        DataColumn(
                                          label: Text(
                                            'Customer',
                                            style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Phone',
                                            style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Credit Sales',
                                            style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Outstanding',
                                            style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Email',
                                            style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Actions',
                                            style: TextStyle(fontSize: isSmallMobile ? 10 : 12),
                                          ),
                                        ),
                                      ],
                                      rows: _creditCustomers.map((customer) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(
                                              customer['name'] ?? '',
                                              style: TextStyle(fontSize: isSmallMobile ? 9 : 11),
                                            )),
                                            DataCell(Text(
                                              customer['phone'] ?? '',
                                              style: TextStyle(fontSize: isSmallMobile ? 9 : 11),
                                            )),
                                            DataCell(Text(
                                              '${customer['credit_sales_count'] ?? 0}',
                                              style: TextStyle(fontSize: isSmallMobile ? 9 : 11),
                                            )),
                                            DataCell(Text(
                                              '\$${(double.tryParse((customer['outstanding_amount'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: isSmallMobile ? 9 : 11),
                                            )),
                                            DataCell(Text(
                                              customer['email'] ?? '',
                                              style: TextStyle(fontSize: isSmallMobile ? 9 : 11),
                                            )),
                                            DataCell(
                                              IconButton(
                                                icon: Icon(
                                                  Icons.visibility,
                                                  size: isSmallMobile ? 18 : 20,
                                                ),
                                                onPressed: () => _showCustomerTransactions(customer),
                                                padding: EdgeInsets.all(isSmallMobile ? 4 : 8),
                                                constraints: BoxConstraints(
                                                  minWidth: isSmallMobile ? 32 : 40,
                                                  minHeight: isSmallMobile ? 32 : 40,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
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
  }

  // Credit Summary Cards
  Widget _buildCreditSummaryCards(bool isSmallMobile, bool isMobile) {
    // Calculate summary from credit customers data
    double totalCredit = 0;
    double totalPaid = 0;
    double totalOutstanding = 0;
    int fullyPaidCredits = 0;
    int partiallyPaidCredits = 0;
    int unpaidCredits = 0;

    for (var customer in _creditCustomers) {
      totalCredit += double.tryParse((customer['total_credit_amount'] ?? 0).toString()) ?? 0.0;
      totalPaid += double.tryParse((customer['total_paid_amount'] ?? 0).toString()) ?? 0.0;
      totalOutstanding += double.tryParse((customer['outstanding_amount'] ?? 0).toString()) ?? 0.0;
      
      final outstanding = double.tryParse((customer['outstanding_amount'] ?? 0).toString()) ?? 0.0;
      final totalPaidAmount = double.tryParse((customer['total_paid_amount'] ?? 0).toString()) ?? 0.0;
      
      if (outstanding <= 0) {
        fullyPaidCredits++;
      } else if (totalPaidAmount > 0) {
        partiallyPaidCredits++;
      } else {
        unpaidCredits++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Credit Overview',
          style: TextStyle(
            fontSize: isSmallMobile ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: ThemeAwareColors.getSecondaryTextColor(context),
          ),
        ),
        SizedBox(height: isSmallMobile ? 8 : 12),
        
        // First row of summary cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Credit',
                '\$${totalCredit.toStringAsFixed(2)}',
                Icons.credit_card,
                Colors.orange,
                isSmallMobile,
                isMobile,
              ),
            ),
            SizedBox(width: isSmallMobile ? 8 : 16),
            Expanded(
              child: _buildSummaryCard(
                'Total Paid',
                '\$${totalPaid.toStringAsFixed(2)}',
                Icons.payment,
                Colors.green,
                isSmallMobile,
                isMobile,
              ),
            ),
            SizedBox(width: isSmallMobile ? 8 : 16),
            Expanded(
              child: _buildSummaryCard(
                'Outstanding',
                '\$${totalOutstanding.toStringAsFixed(2)}',
                Icons.warning,
                Colors.red,
                isSmallMobile,
                isMobile,
              ),
            ),
          ],
        ),
        
        SizedBox(height: isSmallMobile ? 8 : 12),
        
        // Second row of summary cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Fully Paid',
                '$fullyPaidCredits',
                Icons.check_circle,
                Colors.green,
                isSmallMobile,
                isMobile,
              ),
            ),
            SizedBox(width: isSmallMobile ? 8 : 16),
            Expanded(
              child: _buildSummaryCard(
                'Partially Paid',
                '$partiallyPaidCredits',
                Icons.pending,
                Colors.orange,
                isSmallMobile,
                isMobile,
              ),
            ),
            SizedBox(width: isSmallMobile ? 8 : 16),
            Expanded(
              child: _buildSummaryCard(
                'Unpaid',
                '$unpaidCredits',
                Icons.error,
                Colors.red,
                isSmallMobile,
                isMobile,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isSmallMobile, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isSmallMobile ? 20 : 24),
          SizedBox(height: isSmallMobile ? 2 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallMobile ? 10 : 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallMobile ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallMobile ? 12 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCreditCustomersList(List<Map<String, dynamic>> customers, bool isSmallMobile) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        
        // Calculate customer credit status
        final outstanding = double.tryParse((customer['outstanding_amount'] ?? 0).toString()) ?? 0.0;
        final totalPaid = double.tryParse((customer['total_paid_amount'] ?? 0).toString()) ?? 0.0;
        final totalCredit = double.tryParse((customer['total_credit_amount'] ?? 0).toString()) ?? 0.0;
        
        final isFullyPaid = outstanding <= 0;
        final hasOutstanding = outstanding > 0;
        final isPartiallyPaid = totalPaid > 0 && outstanding > 0;
        
        // Determine status color and icon
        Color statusColor;
        IconData statusIcon;
        String statusText;
        
        if (isFullyPaid) {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          statusText = 'PAID';
        } else if (isPartiallyPaid) {
          statusColor = Colors.orange;
          statusIcon = Icons.pending;
          statusText = 'PARTIAL';
        } else {
          statusColor = Colors.red;
          statusIcon = Icons.warning;
          statusText = 'UNPAID';
        }
        
        return Card(
          margin: EdgeInsets.only(bottom: isSmallMobile ? 6 : 8),
          elevation: 2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallMobile ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Info Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallMobile ? 14 : 16,
                              ),
                            ),
                            SizedBox(height: isSmallMobile ? 2 : 4),
                            Text(
                              '📱 ${customer['phone'] ?? 'No phone'}',
                              style: TextStyle(
                                fontSize: isSmallMobile ? 11 : 12,
                                color: ThemeAwareColors.getSecondaryTextColor(context),
                              ),
                            ),
                            SizedBox(height: isSmallMobile ? 2 : 4),
                            Text(
                              '📧 ${customer['email'] ?? 'No email'}',
                              style: TextStyle(
                                fontSize: isSmallMobile ? 11 : 12,
                                color: ThemeAwareColors.getSecondaryTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Status Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallMobile ? 6 : 8,
                          vertical: isSmallMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon,
                              color: statusColor,
                              size: isSmallMobile ? 12 : 14,
                            ),
                            SizedBox(width: isSmallMobile ? 2 : 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: isSmallMobile ? 9 : 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isSmallMobile ? 8 : 10),
                  
                  // Credit Summary Row
                  Container(
                    padding: EdgeInsets.all(isSmallMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: ThemeAwareColors.getInputFillColor(context),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ThemeAwareColors.getBorderColor(context)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Credit Sales',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 9 : 10,
                                  color: ThemeAwareColors.getSecondaryTextColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${customer['credit_sales_count'] ?? 0}',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 12 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey[300],
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Total Credit',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 9 : 10,
                                  color: ThemeAwareColors.getSecondaryTextColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '\$${totalCredit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 12 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey[300],
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Total Paid',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 9 : 10,
                                  color: ThemeAwareColors.getSecondaryTextColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '\$${totalPaid.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 12 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey[300],
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Outstanding',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 9 : 10,
                                  color: ThemeAwareColors.getSecondaryTextColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '\$${outstanding.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 12 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: hasOutstanding ? Colors.red[700] : Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: isSmallMobile ? 8 : 10),
                  
                  // Action Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showCustomerTransactions(customer),
                        icon: Icon(
                          Icons.visibility,
                          size: isSmallMobile ? 14 : 16,
                        ),
                        label: Text(
                          'View Transactions',
                          style: TextStyle(
                            fontSize: isSmallMobile ? 11 : 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallMobile ? 12 : 16,
                            vertical: isSmallMobile ? 6 : 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemSection(bool isSmallMobile, bool isMobile) {
    final user = context.read<AuthProvider>().user;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 14 : 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info,
                  size: isSmallMobile ? 20 : (isMobile ? 22 : 24),
                  color: Colors.purple,
                ),
                SizedBox(width: isSmallMobile ? 6 : 8),
            Text(
              t(context, 'System Information'),
                  style: TextStyle(
                    fontSize: isSmallMobile ? 16 : (isMobile ? 17 : 18),
                fontWeight: FontWeight.bold,
              ),
            ),
              ],
            ),
            SizedBox(height: isSmallMobile ? 12 : 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [

                  _buildSystemInfoTile(
                    t(context, 'Total Products'),
                    '${_systemInfo['totalProducts'] ?? 0}',
                    Icons.inventory,
                    Colors.blue,
                    isSmallMobile,
                  ),
                  _buildSystemInfoTile(
                    t(context, 'Total Customers'),
                    '${_systemInfo['totalCustomers'] ?? 0}',
                    Icons.people,
                    Colors.orange,
                    isSmallMobile,
                  ),
                  _buildSystemInfoTile(
                    t(context, 'Total Sales'),
                    '${_systemInfo['totalSales'] ?? 0}',
                    Icons.point_of_sale,
                    Colors.green,
                    isSmallMobile,
                  ),
                  _buildSystemInfoTile(
                    t(context, 'Database Size'),
                    _systemInfo['databaseSize'] ?? 'Unknown',
                    Icons.data_usage,
                    Colors.purple,
                    isSmallMobile,
                  ),
                  SizedBox(height: isSmallMobile ? 12 : 16),
                  if (user != null && (user.role == 'admin' || user.role == 'superadmin' || user.role == 'manager')) ...[
                    ListTile(
                      leading: Icon(
                        Icons.people, 
                        color: Colors.indigo,
                        size: isSmallMobile ? 20 : 22,
                      ),
                      title: Text(
                        t(context, 'Manage Cashiers'),
                        style: TextStyle(fontSize: isSmallMobile ? 14 : 16),
                      ),
                      subtitle: Text(
                        t(context, 'Create and manage cashier accounts for your business'),
                        style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: isSmallMobile ? 16 : 20,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ManageCashiersScreen()),
                        );
                      },
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallMobile ? 8 : 16,
                        vertical: isSmallMobile ? 4 : 8,
                    ),
                    ),
                    SizedBox(height: isSmallMobile ? 12 : 16),
                  ],

                  Divider(height: isSmallMobile ? 8 : 16),
                  SizedBox(height: isSmallMobile ? 12 : 16),

                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoTile(String title, String value, IconData icon, Color color, bool isSmallMobile) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(value),
      trailing: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallMobile ? 8 : 16,
        vertical: isSmallMobile ? 4 : 8,
      ),
    );
  }

  void _showLanguageDialog([SettingsProvider? settings]) {
    final currentLanguage = settings?.language ?? 'English';
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.language,
              size: isSmallMobile ? 18 : 20,
              color: Colors.blue,
            ),
            SizedBox(width: isSmallMobile ? 6 : 8),
            Text(
              t(context, 'Select Language'),
              style: TextStyle(
                fontSize: isSmallMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          width: isSmallMobile ? double.infinity : (isMobile ? 250 : 300),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['English', 'Somali'].map((language) {
            return ListTile(
                title: Text(
                  language,
                  style: TextStyle(fontSize: isSmallMobile ? 14 : 16),
                ),
                trailing: currentLanguage == language ? Icon(
                  Icons.check,
                  size: isSmallMobile ? 18 : 20,
                  color: Colors.green,
                ) : null,
              onTap: () {
                settings?.setLanguage(language);
                setState(() {
                  _selectedLanguage = language;
                });
                Navigator.pop(context);
              },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallMobile ? 8 : 16,
                  vertical: isSmallMobile ? 4 : 8,
                ),
            );
          }).toList(),
          ),
        ),
      ),
    );
  }

  void _showCurrencyDialog([SettingsProvider? settings]) {
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.attach_money,
              size: isSmallMobile ? 18 : 20,
              color: Colors.green,
            ),
            SizedBox(width: isSmallMobile ? 6 : 8),
            Text(
              t(context, 'Select Currency'),
              style: TextStyle(
                fontSize: isSmallMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          width: isSmallMobile ? double.infinity : (isMobile ? 250 : 300),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['USD', 'EUR', 'GBP', 'JPY'].map((currency) {
            return ListTile(
                title: Text(
                  currency,
                  style: TextStyle(fontSize: isSmallMobile ? 14 : 16),
                ),
                trailing: (settings?.currency ?? _selectedCurrency) == currency ? Icon(
                  Icons.check,
                  size: isSmallMobile ? 18 : 20,
                  color: Colors.green,
                ) : null,
              onTap: () {
                if (settings != null) settings.setCurrency(currency);
                setState(() { _selectedCurrency = currency; });
                Navigator.of(context).pop();
              },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallMobile ? 8 : 16,
                  vertical: isSmallMobile ? 4 : 8,
                ),
            );
          }).toList(),
          ),
        ),
      ),
    );
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