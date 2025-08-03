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
    return Scaffold(
      appBar: BrandedAppBar(
        title: t(context, 'Damaged Products'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Records', icon: Icon(Icons.list)),
            Tab(text: 'Report', icon: Icon(Icons.analytics)),
            Tab(text: 'Add New', icon: Icon(Icons.add)),
          ],
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_damagedProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(t(context, 'No damaged products found'), style: const TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _damagedProducts.length,
        itemBuilder: (context, index) {
          final damagedProduct = _damagedProducts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                damagedProduct['product_name'] ?? 'Unknown Product',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDamageTypeChip(damagedProduct['damage_type']),
                      const SizedBox(width: 8),
                      Text('${t(context, 'Qty: ')}${damagedProduct['quantity']}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                                      Text('${t(context, 'Date: ')}${DateFormat('MMM dd, yyyy').format(DateTime.parse(damagedProduct['damage_date']))}'),
                  if (damagedProduct['damage_reason'] != null)
                                          Text('${t(context, 'Reason: ')}${damagedProduct['damage_reason']}'),
                  if (damagedProduct['estimated_loss'] != null)
                                          Text('${t(context, 'Loss: \$')}${(double.tryParse(damagedProduct['estimated_loss'].toString()) ?? 0.0).toStringAsFixed(2)}', 
                         style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                      Text('${t(context, 'Reported by: ')}${damagedProduct['reported_by_name']}'),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit),
                        const SizedBox(width: 8),
                        Text(t(context, 'Edit')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(t(context, 'Delete'), style: const TextStyle(color: Colors.red)),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildReportFilters(),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _reportData == null
                    ? Center(child: Text(t(context, 'Select filters and load report')))
                    : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, 'Report Filters'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
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
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Damage Type',
                border: OutlineInputBorder(),
              ),
              value: _selectedDamageType,
              items: [
                DropdownMenuItem(value: null, child: Text(t(context, 'All Types'))),
                ...DamageType.values.map((type) => DropdownMenuItem(
                  value: type.name,
                  child: Text(type.name.replaceAll('_', ' ').toUpperCase()),
                )),
              ],
              onChanged: (value) {
                setState(() => _selectedDamageType = value);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadReport,
                child: Text(t(context, 'Load Report')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    final summary = _reportData!['summary'];
    final damageTypeBreakdown = _reportData!['damageTypeBreakdown'] as List;
    final topDamagedProducts = _reportData!['topDamagedProducts'] as List;
    final cashierBreakdown = _reportData!['cashierBreakdown'] as List;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Incidents',
                  summary['total_incidents'].toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Total Quantity',
                  summary['total_quantity_damaged'].toString(),
                  Icons.inventory_2,
                  Colors.red,
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
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Top Cashier',
                  cashierBreakdown.isNotEmpty ? cashierBreakdown.first['cashier_name'] ?? 'N/A' : 'N/A',
                  Icons.person,
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
                  'Avg Loss/Item',
                  '\$${(double.tryParse(summary['avg_loss_per_item']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                  Icons.analytics,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Cashiers Involved',
                  cashierBreakdown.length.toString(),
                  Icons.people,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Damage Type Breakdown
          const Text('Damage Type Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: damageTypeBreakdown.length,
              itemBuilder: (context, index) {
                final item = damageTypeBreakdown[index];
                return ListTile(
                  title: Text(item['damage_type'].toString().replaceAll('_', ' ').toUpperCase()),
                  subtitle: Text('${item['incident_count']} incidents, ${item['total_quantity']} items'),
                  trailing: Text(
                    '\$${(double.tryParse(item['total_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // Top Damaged Products
          const Text('Top Damaged Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topDamagedProducts.length,
              itemBuilder: (context, index) {
                final item = topDamagedProducts[index];
                return ListTile(
                  title: Text(item['product_name']),
                  subtitle: Text('${item['incident_count']} incidents, ${item['total_quantity_damaged']} items'),
                  trailing: Text(
                    '\$${(double.tryParse(item['total_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // Cashier Breakdown
          const Text('Cashier Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cashierBreakdown.length,
              itemBuilder: (context, index) {
                final item = cashierBreakdown[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      (item['cashier_name'] ?? 'Unknown')[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(item['cashier_name'] ?? 'Unknown Cashier'),
                  subtitle: Text('${item['incident_count']} incidents, ${item['total_quantity_damaged']} items'),
                  trailing: Text(
                    '\$${(double.tryParse(item['total_loss']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // Detailed Damaged Products Table
          const Text('Detailed Damaged Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
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
                        item['reported_by_name'] ?? '',
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _AddDamagedProductForm(onProductAdded: _loadData),
    );
  }

  Widget _buildDamageTypeChip(String damageType) {
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
        style: const TextStyle(color: Colors.white, fontSize: 10),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Damaged Product'),
        content: const Text('Are you sure you want to delete this damaged product record? This will restore the quantity to stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _apiService.deleteDamagedProduct(id);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Damaged product deleted successfully')),
                );
              } catch (e) {
                _showErrorSnackBar('Failed to delete: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report Damaged Product', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          // Product Selection
          DropdownButtonFormField<Product>(
            decoration: const InputDecoration(
              labelText: 'Product *',
              border: OutlineInputBorder(),
            ),
            value: _selectedProduct,
            items: _products.map((product) => DropdownMenuItem(
              value: product,
              child: Text('${product.name} (${product.sku}) - Stock: ${product.stockQuantity}'),
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
          const SizedBox(height: 16),
          
          // Quantity
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Quantity *',
              border: OutlineInputBorder(),
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
          const SizedBox(height: 16),
          
          // Damage Type
          DropdownButtonFormField<DamageType>(
            decoration: const InputDecoration(
              labelText: 'Damage Type *',
              border: OutlineInputBorder(),
            ),
            value: _selectedDamageType,
            items: DamageType.values.map((type) => DropdownMenuItem(
              value: type,
              child: Text(type.name.replaceAll('_', ' ').toUpperCase()),
            )).toList(),
            onChanged: (type) {
              setState(() => _selectedDamageType = type!);
            },
          ),
          const SizedBox(height: 16),
          
          // Damage Date
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
              decoration: const InputDecoration(
                labelText: 'Damage Date *',
                border: OutlineInputBorder(),
              ),
              child: Text(DateFormat('MMM dd, yyyy').format(_damageDate)),
            ),
          ),
          const SizedBox(height: 16),
          
          // Damage Reason
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Damage Reason',
              border: OutlineInputBorder(),
              hintText: 'Optional description of the damage',
            ),
            maxLines: 3,
            onChanged: (value) => _damageReason = value,
          ),
          const SizedBox(height: 16),
          
          // Estimated Loss
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Estimated Loss (\$)',
              border: OutlineInputBorder(),
              hintText: 'Leave empty to use product cost price × quantity',
              helperText: 'If not specified, will be calculated automatically',
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() => _estimatedLoss = double.tryParse(value));
            },
          ),
          if (_selectedProduct != null && _estimatedLoss == null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Auto-calculated loss: \$${(_selectedProduct!.costPrice * _quantity).toStringAsFixed(2)} (${_selectedProduct!.costPrice.toStringAsFixed(2)} × $_quantity)',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Report Damaged Product'),
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
    return AlertDialog(
      title: const Text('Edit Damaged Product'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Product: ${widget.damagedProduct['product_name']}'),
              const SizedBox(height: 16),
              
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 16),
              
              DropdownButtonFormField<DamageType>(
                decoration: const InputDecoration(
                  labelText: 'Damage Type *',
                  border: OutlineInputBorder(),
                ),
                value: _selectedDamageType,
                items: DamageType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.name.replaceAll('_', ' ').toUpperCase()),
                )).toList(),
                onChanged: (type) => _selectedDamageType = type!,
              ),
              const SizedBox(height: 16),
              
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
                  decoration: const InputDecoration(
                    labelText: 'Damage Date *',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(DateFormat('MMM dd, yyyy').format(_damageDate)),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Damage Reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                initialValue: _damageReason,
                onChanged: (value) => _damageReason = value,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Estimated Loss (\$)',
                  border: OutlineInputBorder(),
                  hintText: 'Leave empty to use product cost price × quantity',
                  helperText: 'If not specified, will be calculated automatically',
                ),
                keyboardType: TextInputType.number,
                initialValue: _estimatedLoss?.toString(),
                onChanged: (value) => _estimatedLoss = double.tryParse(value),
              ),
              if (_estimatedLoss == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Auto-calculated loss: \$${(widget.damagedProduct['product_cost'] != null ? double.tryParse(widget.damagedProduct['product_cost'].toString()) ?? 0 : 0) * _quantity}',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Update'),
        ),
      ],
    );
  }
} 