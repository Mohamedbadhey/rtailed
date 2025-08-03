import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/models/product.dart';
import 'package:retail_management/models/customer.dart';
import 'package:retail_management/models/sale.dart';
import 'package:retail_management/providers/cart_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/widgets/custom_text_field.dart';
import 'package:retail_management/widgets/branded_header.dart';
import 'package:retail_management/utils/api.dart';
import 'package:retail_management/utils/translate.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  bool _isLoading = true;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _saleMode = 'retail'; // 'retail' or 'wholesale'

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _apiService.getProducts();
      setState(() {
        _products = products;
        _filteredProducts = products;
        _categories = ['All', ...products.map((p) => p.categoryName ?? 'Uncategorized').toSet().toList()];
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'error_loading_products')}: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _products.where((product) {
        // Search filter
        final searchMatch = _searchController.text.isEmpty ||
            product.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            (product.sku?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false);

        // Category filter
        final categoryMatch = _selectedCategory == 'All' ||
            (product.categoryName ?? 'Uncategorized') == _selectedCategory;

        // Only show products with stock
        final stockMatch = product.stockQuantity > 0;

        return searchMatch && categoryMatch && stockMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 768;
        
        if (isMobile) {
          // Mobile layout - stacked vertically
          return Column(
            children: [
              Expanded(
                flex: 2,
                child: _buildProductSection(isMobile),
              ),
              Container(
                height: 1,
                color: Colors.grey[300],
              ),
              Expanded(
                flex: 1,
                child: _buildCartSection(isMobile),
              ),
            ],
          );
        } else {
          // Desktop/Tablet layout - side by side
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildProductSection(isMobile),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 1,
                child: _buildCartSection(isMobile),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildProductSection(bool isMobile) {
    return Column(
      children: [
        // Branded Header
        Consumer<BrandingProvider>(
          builder: (context, brandingProvider, child) {
            return BrandedHeader(
              subtitle: t(context, 'Point of Sale'),
              logoSize: isMobile ? 50 : 60,
            );
          },
        ),
        Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            children: [
              if (isMobile) ...[
                // Mobile layout - stacked filters
                CustomTextField(
                  controller: _searchController,
                  labelText: t(context, 'search_products'),
                  prefixIcon: const Icon(Icons.search),
                  onChanged: (value) {
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(
                                category,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value!;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: _loadProducts,
                        tooltip: t(context, 'refresh_products'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Desktop/Tablet layout - horizontal filters
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _searchController,
                        labelText: t(context, 'search_products'),
                        prefixIcon: const Icon(Icons.search),
                        onChanged: (value) {
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        underline: const SizedBox(),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: _loadProducts,
                        tooltip: t(context, 'refresh_products'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            t(context, 'no_products_found'),
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.all(isMobile ? 8 : 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 2 : 3,
                        childAspectRatio: isMobile ? 0.7 : 0.8,
                        crossAxisSpacing: isMobile ? 8 : 16,
                        mainAxisSpacing: isMobile ? 8 : 16,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(_filteredProducts[index], isMobile);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product, bool isMobile) {
    final isLowStock = product.stockQuantity <= product.lowStockThreshold;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          if (product.stockQuantity > 0) {
            final mode = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(t(context, 'select_sale_mode')),
                content: Text(t(context, 'is_this_sale_retail_or_wholesale')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop('retail'),
                    child: Text(t(context, 'retail')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop('wholesale'),
                    child: Text(t(context, 'wholesale')),
                  ),
                ],
              ),
            );
            if (mode == 'retail') {
              context.read<CartProvider>().addItem(product, mode: 'retail', quantity: 1);
            } else if (mode == 'wholesale') {
              final qty = await showDialog<int>(
                context: context,
                builder: (context) {
                  final controller = TextEditingController();
                  return AlertDialog(
                    title: Text(t(context, 'wholesale_quantity')),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t(context, 'quantity'),
                        hintText: t(context, 'enter_wholesale_quantity'),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(t(context, 'cancel')),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final q = int.tryParse(controller.text);
                          if (q != null && q > 0 && q <= product.stockQuantity) {
                            Navigator.of(context).pop(q);
                          }
                        },
                        child: Text(t(context, 'add')),
                      ),
                    ],
                  );
                },
              );
              if (qty != null && qty > 0 && qty <= product.stockQuantity) {
                context.read<CartProvider>().addItemWithMode(product, 'wholesale', qty);
              }
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(
                              Api.getFullImageUrl(product.imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.image,
                                    size: isMobile ? 32 : 48,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.image,
                              size: isMobile ? 32 : 48,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  if (isLowStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 4 : 6,
                          vertical: isMobile ? 1 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t(context, 'low'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 8 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (product.stockQuantity == 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 4 : 6,
                          vertical: isMobile ? 1 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t(context, 'out'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 8 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 12 : 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${t(context, 'cost')}: ${product.costPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${t(context, 'stock')}: ${product.stockQuantity}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isMobile ? 10 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSection(bool isMobile) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(isMobile ? 0 : 16),
                  bottomRight: Radius.circular(isMobile ? 0 : 16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'shopping_cart'),
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${cart.items.length} ${t(context, 'items')}',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cart.items.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          cart.clearCart();
                        },
                        tooltip: t(context, 'clear_cart'),
                        padding: EdgeInsets.all(isMobile ? 4 : 8),
                        constraints: BoxConstraints(
                          minWidth: isMobile ? 32 : 40,
                          minHeight: isMobile ? 32 : 40,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Cart Items
            Expanded(
              child: cart.items.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: isMobile ? 48 : 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              t(context, 'cart_is_empty'),
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t(context, 'add_products_to_get_started'),
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(isMobile ? 8 : 12),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        final customPriceController = TextEditingController(
                          text: item.customPrice != null && item.customPrice != item.product.costPrice
                            ? item.customPrice!.toStringAsFixed(2)
                            : '',
                        );
                        bool isInvalid = false;
                        return StatefulBuilder(
                          builder: (context, setItemState) {
                            return Card(
                              margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(isMobile ? 8 : 12),
                                leading: Container(
                                  width: isMobile ? 40 : 50,
                                  height: isMobile ? 40 : 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: (item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            Api.getFullImageUrl(item.product.imageUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(
                                                Icons.image,
                                                size: isMobile ? 16 : 20,
                                                color: Colors.grey,
                                              );
                                            },
                                          ),
                                        )
                                      : Icon(
                                          Icons.image,
                                          size: isMobile ? 16 : 20,
                                          color: Colors.grey,
                                        ),
                                ),
                                title: Text(
                                  item.product.name,
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${t(context, 'cost')}: ${item.product.costPrice.toStringAsFixed(2)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      onPressed: () {
                                        cart.removeItem(item.product);
                                      },
                                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                                      constraints: BoxConstraints(
                                        minWidth: isMobile ? 28 : 32,
                                        minHeight: isMobile ? 28 : 32,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        final newQuantity = await showDialog<int>(
                                          context: context,
                                          builder: (context) {
                                            final controller = TextEditingController(text: item.quantity.toString());
                                            return AlertDialog(
                                              title: Text(t(context, 'set_quantity')),
                                              content: TextField(
                                                controller: controller,
                                                keyboardType: TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText: t(context, 'quantity'),
                                                  hintText: t(context, 'enter_quantity'),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(),
                                                  child: Text(t(context, 'cancel')),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    final qty = int.tryParse(controller.text);
                                                    if (qty != null && qty > 0 && qty <= item.product.stockQuantity) {
                                                      Navigator.of(context).pop(qty);
                                                    }
                                                  },
                                                  child: Text(t(context, 'set')),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                        if (newQuantity != null && newQuantity > 0 && newQuantity <= item.product.stockQuantity) {
                                          cart.updateQuantity(item.product, newQuantity);
                                        }
                                      },
                                      child: Text(
                                      '${item.quantity}',
                                      style: TextStyle(
                                        fontSize: isMobile ? 14 : 16,
                                        fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed: () {
                                        cart.addItem(item.product);
                                      },
                                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                                      constraints: BoxConstraints(
                                        minWidth: isMobile ? 28 : 32,
                                        minHeight: isMobile ? 28 : 32,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            
            // Total and Checkout
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t(context, 'total'),
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${cart.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: cart.items.isEmpty ? null : () {
                        _showCheckoutDialog(context, cart);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        t(context, 'checkout'),
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCheckoutDialog(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CheckoutDialog(cart: cart, saleMode: _saleMode),
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  final CartProvider cart;
  final String saleMode;

  const _CheckoutDialog({required this.cart, required this.saleMode});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  String _selectedPaymentMethod = 'evc';
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _newCustomerNameController = TextEditingController();
  final TextEditingController _newCustomerPhoneController = TextEditingController();
  bool _showNewCustomerFields = false;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  final Map<int, TextEditingController> _customPriceControllers = {};
  final List<String> _paymentMethods = [
    'evc',
    'edahab',
    'merchant',
    'credit',
  ];
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _customersLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() { _customersLoading = true; });
    try {
      final customers = await _apiService.getCustomers();
      setState(() {
        _customers = customers;
        _customersLoading = false;
      });
    } catch (e) {
      setState(() { _customersLoading = false; });
    }
  }

  @override
  void dispose() {
    _customPriceControllers.values.forEach((c) => c.dispose());
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _newCustomerNameController.dispose();
    _newCustomerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _processSale() async {
    setState(() {
      _isLoading = true;
    });
    try {
      Customer? customer;
      // If new customer fields are shown and name is filled, create new customer
      if (_showNewCustomerFields && _newCustomerNameController.text.trim().isNotEmpty) {
        final customerData = {
          'name': _newCustomerNameController.text.trim(),
          'email': '${_newCustomerNameController.text.trim().toLowerCase().replaceAll(' ', '.')}@retail.com',
          'phone': _newCustomerPhoneController.text.trim(),
        };
        customer = await _apiService.createCustomer(customerData);
      } else if (_selectedCustomer != null) {
        customer = _selectedCustomer;
      } else if (_customerNameController.text.trim().isNotEmpty) {
        // Check if name matches existing
        final match = _customers.firstWhere(
          (c) => c.name.toLowerCase() == _customerNameController.text.trim().toLowerCase(),
          orElse: () => Customer(id: '', name: '', email: ''),
        );
        if (match.id?.isNotEmpty == true) {
          customer = match;
        } else {
          // Create new customer
          final customerData = {
            'name': _customerNameController.text.trim(),
            'email': '${_customerNameController.text.trim().toLowerCase().replaceAll(' ', '.')}@retail.com',
            'phone': _customerPhoneController.text.trim(),
          };
          customer = await _apiService.createCustomer(customerData);
        }
      }
      // If blank, treat as walk-in
      final customerId = customer?.id;
      final saleData = {
        if (customerId != null && customerId.isNotEmpty) 'customer_id': int.parse(customerId),
        'payment_method': _selectedPaymentMethod,
        'total_amount': widget.cart.items.fold(0.0, (sum, item) {
          final controller = _customPriceControllers[item.product.id];
          final price = double.tryParse(controller?.text ?? '') ?? 0.0;
          return sum + ((price) * item.quantity);
        }),
        'sale_mode': widget.saleMode,
        'items': widget.cart.items.map((item) {
          final controller = _customPriceControllers[item.product.id];
          final price = double.tryParse(controller?.text ?? '') ?? 0.0;
          return {
            'product_id': item.product.id,
            'quantity': item.quantity,
            'unit_price': price,
            'mode': item.mode,
          };
        }).toList(),
        if (_selectedPaymentMethod == 'credit' || (customer != null && (_customerPhoneController.text.trim().isNotEmpty || _newCustomerPhoneController.text.trim().isNotEmpty)))
          'customer_phone': customer == null ? '' : (_newCustomerPhoneController.text.trim().isNotEmpty ? _newCustomerPhoneController.text.trim() : _customerPhoneController.text.trim()),
      };
      final sale = await _apiService.createSale(saleData);
      widget.cart.clearCart();
      setState(() { _isLoading = false; });
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t(context, 'sale_completed_successfully')}: ${sale['sale_id']}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t(context, 'error_processing_sale')}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 600;
        final maxHeight = MediaQuery.of(context).size.height * 0.9;
        
        // Move these inside the builder so they are in scope for the widget tree
        final combinedCost = widget.cart.items.fold(0.0, (sum, item) => sum + (item.product.costPrice * item.quantity));
        final combinedCustomTotal = widget.cart.items.fold(0.0, (sum, item) {
          final controller = _customPriceControllers[item.product.id];
          final price = double.tryParse(controller?.text ?? '');
          return sum + ((price ?? 0.0) * item.quantity);
        });
        final isCombinedValid = combinedCustomTotal >= combinedCost && widget.cart.items.every((item) {
          final controller = _customPriceControllers[item.product.id];
          final price = double.tryParse(controller?.text ?? '');
          return controller != null && controller.text.isNotEmpty && price != null;
        });

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * (isMobile ? 0.95 : 0.9),
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 500,
              maxHeight: maxHeight,
            ),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.green.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.payment, color: Colors.white, size: isMobile ? 20 : 24),
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(context, 'checkout'),
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              t(context, 'complete_your_sale'),
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white, size: isMobile ? 20 : 24),
                        padding: EdgeInsets.all(isMobile ? 4 : 8),
                        constraints: BoxConstraints(
                          minWidth: isMobile ? 32 : 40,
                          minHeight: isMobile ? 32 : 40,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 24),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Summary
                        Container(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t(context, 'order_summary'),
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 20, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                              SizedBox(height: isMobile ? 8 : 12),
                              Divider(thickness: 1.2),
                              Text(
                                t(context, 'enter_custom_prices'),
                                style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                              ),
                              SizedBox(height: isMobile ? 8 : 12),
                              SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: widget.cart.items.map((item) {
                                    final id = item.product.id!;
                                    double defaultPrice = widget.saleMode == 'wholesale' && item.product.wholesalePrice != null && item.product.wholesalePrice! > 0
                                      ? item.product.wholesalePrice!
                                      : item.product.price;
                                    if (!_customPriceControllers.containsKey(id)) {
                                      _customPriceControllers[id] = TextEditingController(
                                        text: item.customPrice != null && item.customPrice != item.product.costPrice
                                          ? item.customPrice!.toStringAsFixed(2)
                                          : defaultPrice.toStringAsFixed(2),
                                      );
                                    }
                                    final controller = _customPriceControllers[id]!;
                                    bool isInvalid = false;
                                    return StatefulBuilder(
                                      builder: (context, setItemState) {
                                        return Padding(
                                          padding: EdgeInsets.only(bottom: isMobile ? 6 : 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${item.product.name} x${item.quantity}',
                                                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${t(context, 'cost')}: ${item.product.costPrice.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: isMobile ? 12 : 14,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 110,
                                                    child: TextFormField(
                                                      controller: controller,
                                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                      decoration: InputDecoration(
                                                        labelText: t(context, 'custom_price'),
                                                        hintText: t(context, 'enter_custom_price'),
                                                        prefixIcon: Icon(Icons.attach_money, color: Colors.green[700]),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        isDense: true,
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                        errorText: (controller.text.isEmpty || isInvalid) ? '${t(context, 'required_min_cost_quantity')}: ${(item.product.costPrice * item.quantity).toStringAsFixed(2)}' : null,
                                                        focusedBorder: OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color: (controller.text.isEmpty || isInvalid) ? Colors.red : Colors.green,
                                                            width: 2,
                                                          ),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        helperText: t(context, 'must_be_min_cost_quantity'),
                                                      ),
                                                      style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold),
                                                      onChanged: (value) {
                                                        final price = double.tryParse(value);
                                                        final minTotal = item.product.costPrice * item.quantity;
                                                        final valid = price != null && (price * item.quantity) >= minTotal;
                                                        setItemState(() => isInvalid = !valid);
                                                        setState(() {
                                                          widget.cart.updateCustomPrice(item.product, valid ? price! : item.product.costPrice);
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                '\$${item.total.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: isMobile ? 14 : 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    t(context, 'total'),
                                    style: TextStyle(
                                      fontSize: isMobile ? 16 : 18, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                  Text(
                                    '\$${widget.cart.total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: isMobile ? 18 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 24),

                        // Payment Method
                        Text(
                          t(context, 'payment_method'),
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        SizedBox(height: isMobile ? 6 : 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
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
                                  style: TextStyle(fontSize: isMobile ? 14 : 16),
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
                        SizedBox(height: isMobile ? 16 : 24),

                        // Customer Name (always visible)
                        Text(
                          t(context, 'customer_name'),
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        SizedBox(height: isMobile ? 6 : 8),
                        _customersLoading
                          ? Center(child: CircularProgressIndicator())
                          : Autocomplete<Customer>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text == '') {
                                  return _customers;
                                }
                                return _customers.where((Customer option) {
                                  return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              displayStringForOption: (Customer option) => option.name,
                              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                                controller.text = _selectedCustomer?.name ?? _customerNameController.text;
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: t(context, 'customer_name_optional'),
                                    border: const OutlineInputBorder(),
                                    hintText: t(context, 'select_or_enter_customer_name'),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 12 : 16,
                                      vertical: isMobile ? 12 : 16,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCustomer = null;
                                      _customerNameController.text = value;
                                    });
                                  },
                                );
                              },
                              onSelected: (Customer selection) {
                                setState(() {
                                  _selectedCustomer = selection;
                                  _customerNameController.text = selection.name;
                                  _customerPhoneController.text = selection.phone ?? '';
                                });
                              },
                            ),
                        SizedBox(height: isMobile ? 12 : 16),

                        // Customer Phone (only for credit)
                        if (_selectedPaymentMethod == 'credit') ...[
                          SizedBox(height: isMobile ? 6 : 8),
                          Text(
                            t(context, 'customer_phone'),
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          SizedBox(height: isMobile ? 6 : 8),
                          TextFormField(
                            controller: _customerPhoneController,
                            decoration: InputDecoration(
                              labelText: t(context, 'customer_phone'),
                              border: const OutlineInputBorder(),
                              hintText: t(context, 'required_for_credit_sales'),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 12 : 16,
                              ),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          SizedBox(height: isMobile ? 8 : 12),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showNewCustomerFields = !_showNewCustomerFields;
                                  });
                                },
                                child: Text(_showNewCustomerFields ? t(context, 'cancel_new_customer') : t(context, 'new_customer')),
                              ),
                            ],
                          ),
                          if (_showNewCustomerFields) ...[
                            SizedBox(height: isMobile ? 8 : 12),
                            TextFormField(
                              controller: _newCustomerNameController,
                              decoration: InputDecoration(
                                labelText: t(context, 'new_customer_name'),
                                border: const OutlineInputBorder(),
                                hintText: t(context, 'enter_new_customer_name'),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16,
                                  vertical: isMobile ? 12 : 16,
                                ),
                              ),
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            TextFormField(
                              controller: _newCustomerPhoneController,
                              decoration: InputDecoration(
                                labelText: t(context, 'new_customer_phone'),
                                border: const OutlineInputBorder(),
                                hintText: t(context, 'enter_phone_optional'),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16,
                                  vertical: isMobile ? 12 : 16,
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ],

                        // Show error message if combined custom total is less than combined cost
                        if (!isCombinedValid)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              '${t(context, 'total_entered_amount_must_be_at_least_combined_cost')}: ${combinedCost.toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          t(context, 'cancel'),
                          style: TextStyle(fontSize: isMobile ? 14 : 16),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading || !isCombinedValid ? null : _processSale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: isMobile ? 16 : 20,
                                width: isMobile ? 16 : 20,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                t(context, 'complete_sale'),
                                style: TextStyle(fontSize: isMobile ? 14 : 16),
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
} 