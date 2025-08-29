import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import 'package:retail_management/utils/success_utils.dart';

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
    print('🛍️ ===== POS LOAD PRODUCTS AND CATEGORIES START =====');
    setState(() {
      _isLoading = true;
    });

    try {
      print('🛍️ Calling API service to get products...');
      final products = await _apiService.getProducts();
      print('🛍️ ✅ API call successful, loaded ${products.length} products');
      
      // Debug: Print image URLs for products with images
      print('🛍️ Analyzing product images...');
      int productsWithImages = 0;
      int productsWithoutImages = 0;
      
      for (final product in products) {
        print('🛍️ Product: ${product.name} (ID: ${product.id})');
        print('🛍️   - Image URL from API: ${product.imageUrl ?? 'NULL'}');
        print('🛍️   - Stock Quantity: ${product.stockQuantity}');
        
        if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
          productsWithImages++;
          final fullUrl = Api.getFullImageUrl(product.imageUrl);
          print('🛍️   - Full image URL: $fullUrl');
        } else {
          productsWithoutImages++;
          print('🛍️   - No image URL');
        }
      }
      
      print('🛍️ Summary: $productsWithImages products with images, $productsWithoutImages without images');
      
      // Load categories separately to show all available categories
      List<String> allCategories = ['All'];
      try {
        final categoriesData = await _apiService.getCategories();
        final categoryNames = categoriesData.map((cat) => cat['name'] as String).toList();
        allCategories.addAll(categoryNames);
        print('🛍️ ✅ Loaded ${categoryNames.length} categories from API');
        
        // Add "Uncategorized" if there are products without categories
        if (products.any((p) => p.categoryName == null || p.categoryName!.isEmpty)) {
          allCategories.add('Uncategorized');
        }
      } catch (e) {
        print('🛍️ ⚠️ Failed to load categories, falling back to product-based categories: $e');
        // Fallback to product-based categories if API fails
        allCategories.addAll(products.map((p) => p.categoryName ?? 'Uncategorized').toSet().toList());
      }
      
      setState(() {
        _products = products;
        _filteredProducts = products;
        _categories = allCategories;
        _isLoading = false;
      });
      print('🛍️ ✅ State updated, applying filters...');
      _applyFilters();
      print('🛍️ ===== POS LOAD PRODUCTS AND CATEGORIES END (SUCCESS) =====');
    } catch (e) {
      print('🛍️ ❌ Error loading products: $e');
      print('🛍️ Error stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'error_loading_products')}: $e')),
        );
      }
      print('🛍️ ===== POS LOAD PRODUCTS AND CATEGORIES END (ERROR) =====');
    }
  }

  /// Refresh the entire POS interface
  /// This method reloads products to show updated stock quantities
  /// and refreshes the filtered product list
  Future<void> refreshPOS() async {
    print('🔄 POS Refresh requested');
    await _loadProducts();
    print('🔄 POS Refresh completed');
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
        final isSmallMobile = constraints.maxWidth <= 480;
        
        if (isMobile) {
          // Mobile layout - full screen products with floating cart icon
          return Stack(
            children: [
              // Full screen products section
              _buildProductSection(isMobile, isSmallMobile),
              
              // Floating cart icon
              Positioned(
                top: isSmallMobile ? 16 : 20,
                right: isSmallMobile ? 16 : 20,
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    return GestureDetector(
                      onTap: () {
                        _showMobileCartDialog(context, cart);
                      },
                      child: Container(
                        width: isSmallMobile ? 56 : 64,
                        height: isSmallMobile ? 56 : 64,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(
                                Icons.shopping_cart,
                                color: Colors.white,
                                size: isSmallMobile ? 24 : 28,
                              ),
                            ),
                                                              if (cart.items.isNotEmpty)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: Text(
                                          '${cart.items.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        } else {
          // Desktop/Tablet layout - side by side
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildProductSection(isMobile, isSmallMobile),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 1,
                child: _buildCartSection(isMobile, isSmallMobile),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildProductSection(bool isMobile, bool isSmallMobile) {
    return Column(
      children: [
        // Ultra-compact Branded Header for mobile
        Consumer<BrandingProvider>(
          builder: (context, brandingProvider, child) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 8 : (isMobile ? 12 : 16),
                vertical: isSmallMobile ? 6 : (isMobile ? 8 : 12),
              ),
              child: Row(
                children: [
                  // Compact logo
                  Container(
                    width: isSmallMobile ? 28 : (isMobile ? 36 : 60),
                    height: isSmallMobile ? 28 : (isMobile ? 36 : 60),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.point_of_sale,
                      color: Colors.white,
                      size: isSmallMobile ? 16 : (isMobile ? 20 : 40),
                    ),
                  ),
                  SizedBox(width: isSmallMobile ? 8 : 12),
                  // Compact title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Point of Sale',
                          style: TextStyle(
                            fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 24),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        if (isMobile) Text(
                          'Tap products to add to cart',
                          style: TextStyle(
                            fontSize: isSmallMobile ? 10 : 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Compact filter section for mobile
        if (isMobile) ...[
        Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 6 : 8,
              vertical: isSmallMobile ? 4 : 6,
            ),
            child: Row(
            children: [
                // Compact search field
                Expanded(
                  flex: 3,
                  child: Container(
                    height: isSmallMobile ? 36 : 40,
                    child: TextField(
                  controller: _searchController,
                      decoration: InputDecoration(
                        hintText: t(context, 'search_products'),
                        prefixIcon: Icon(Icons.search, size: isSmallMobile ? 16 : 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallMobile ? 8 : 10,
                          vertical: isSmallMobile ? 8 : 10,
                        ),
                        isDense: true,
                      ),
                  onChanged: (value) {
                    _applyFilters();
                  },
                ),
                  ),
                ),
                SizedBox(width: isSmallMobile ? 6 : 8),
                // Compact category dropdown
                    Expanded(
                  flex: 2,
                      child: Container(
                    height: isSmallMobile ? 36 : 40,
                    padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          underline: const SizedBox(),
                          isExpanded: true,
                      isDense: true,
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(
                                category,
                                overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: isSmallMobile ? 11 : 12),
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
                SizedBox(width: isSmallMobile ? 6 : 8),
                // Compact refresh button
                    Container(
                  height: isSmallMobile ? 36 : 40,
                  width: isSmallMobile ? 36 : 40,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                    icon: Icon(Icons.refresh, color: Colors.blue, size: isSmallMobile ? 16 : 18),
                        onPressed: () async {
                          await refreshPOS(); // This will also refresh categories
                        },
                        tooltip: t(context, 'refresh_products') + ' (Stock quantities, categories)',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: isSmallMobile ? 36 : 40,
                      minHeight: isSmallMobile ? 36 : 40,
                    ),
                      ),
                    ),
                  ],
            ),
                ),
              ] else ...[
          // Desktop/Tablet layout - keep original padding
          Padding(
            padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 12 : 16)),
            child: Column(
              children: [
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
                        onPressed: () async {
                          await refreshPOS(); // This will also refresh categories
                        },
                        tooltip: t(context, 'refresh_products') + ' (Stock quantities, categories)',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        ],
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
                            size: isSmallMobile ? 32 : 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: isSmallMobile ? 6 : 16),
                          Text(
                            t(context, 'no_products_found'),
                            style: TextStyle(
                              fontSize: isSmallMobile ? 13 : 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.all(isSmallMobile ? 4 : (isMobile ? 6 : 16)),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isSmallMobile ? 2 : (isMobile ? 2 : 3),
                        childAspectRatio: isSmallMobile ? 0.65 : (isMobile ? 0.7 : 0.8), // Better proportions for mobile
                        crossAxisSpacing: isSmallMobile ? 6 : (isMobile ? 8 : 16),
                        mainAxisSpacing: isSmallMobile ? 6 : (isMobile ? 8 : 16),
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(_filteredProducts[index], isMobile, isSmallMobile);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product, bool isMobile, bool isSmallMobile) {
    final isLowStock = product.stockQuantity <= product.lowStockThreshold;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          if (product.stockQuantity > 0) {
            final mode = await showDialog<String>(
              context: context,
              builder: (context) => LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth <= 600;
                  final isSmallMobile = constraints.maxWidth <= 480;
                  
                  return AlertDialog(
                    title: Text(
                      t(context, 'select_sale_mode'),
                      style: TextStyle(fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20)),
                    ),
                    content: Text(
                      t(context, 'is_this_sale_retail_or_wholesale'),
                      style: TextStyle(fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18)),
                    ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop('retail'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallMobile ? 8 : 12,
                            vertical: isSmallMobile ? 6 : 8,
                          ),
                        ),
                        child: Text(
                          t(context, 'retail'),
                          style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                        ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop('wholesale'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallMobile ? 8 : 12,
                            vertical: isSmallMobile ? 6 : 8,
                          ),
                        ),
                        child: Text(
                          t(context, 'wholesale'),
                          style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
            if (mode == 'retail') {
              print('🛒 POS: Adding product as RETAIL: ${product.name}');
              
              // Use stock validation
              final result = context.read<CartProvider>().addItemWithValidation(
                product, 
                mode: 'retail', 
                quantity: 1
              );
              
              if (!result['success']) {
                // Show insufficient stock message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              } else {
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} added to cart (Retail)'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else if (mode == 'wholesale') {
              print('🛒 POS: Adding product as WHOLESALE: ${product.name}');
              final qty = await showDialog<int>(
                context: context,
                builder: (context) {
                  final controller = TextEditingController();
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth <= 600;
                      final isSmallMobile = constraints.maxWidth <= 480;
                      
                  return AlertDialog(
                        title: Text(
                          t(context, 'wholesale_quantity'),
                          style: TextStyle(fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20)),
                        ),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t(context, 'quantity'),
                        hintText: t(context, 'enter_wholesale_quantity'),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isSmallMobile ? 8 : 12,
                              vertical: isSmallMobile ? 10 : 12,
                      ),
                          ),
                          style: TextStyle(fontSize: isSmallMobile ? 14 : 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallMobile ? 8 : 12,
                                vertical: isSmallMobile ? 6 : 8,
                              ),
                            ),
                            child: Text(
                              t(context, 'cancel'),
                              style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                            ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final q = int.tryParse(controller.text);
                          if (q != null && q > 0) {
                            // Check stock validation before allowing
                            final cartProvider = context.read<CartProvider>();
                            final availableStock = cartProvider.getAvailableStock(product, 'wholesale');
                            if (q <= availableStock) {
                              Navigator.of(context).pop(q);
                            } else {
                              // Show insufficient stock message in dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Insufficient stock! Available: $availableStock'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallMobile ? 8 : 12,
                                vertical: isSmallMobile ? 6 : 8,
                              ),
                            ),
                            child: Text(
                              'add',
                              style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
              if (qty != null && qty > 0) {
                print('🛒 POS: Adding wholesale item: ${product.name} x $qty (mode: wholesale)');
                
                // Use stock validation
                final result = context.read<CartProvider>().addItemWithValidation(
                  product, 
                  mode: 'wholesale', 
                  quantity: qty
                );
                
                if (!result['success']) {
                  // Show insufficient stock message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message']),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                } else {
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} x $qty added to cart (Wholesale)'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
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
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  print('🖼️ ✅ POS: Image loaded successfully for product "${product.name}"');
                                  return child;
                                }
                                final progress = loadingProgress.expectedTotalBytes != null 
                                    ? (loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).toStringAsFixed(1)
                                    : 'Unknown';
                                print('🖼️ 📥 POS: Loading image for product "${product.name}": $progress%');
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('🖼️ ❌ POS: Image error for product "${product.name}"');
                                print('🖼️ ❌ Error: $error');
                                print('🖼️ ❌ Stack trace: $stackTrace');
                                print('🖼️ ❌ Image URL: ${Api.getFullImageUrl(product.imageUrl)}');
                                return Center(
                                  child: Icon(
                                    Icons.image,
                                    size: isSmallMobile ? 20 : (isMobile ? 28 : 48),
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.image,
                              size: isSmallMobile ? 20 : (isMobile ? 28 : 48),
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
                          horizontal: isSmallMobile ? 2 : (isMobile ? 3 : 6),
                          vertical: isSmallMobile ? 1 : (isMobile ? 1 : 2),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t(context, 'low'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallMobile ? 6 : (isMobile ? 7 : 10),
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
                          horizontal: isSmallMobile ? 2 : (isMobile ? 3 : 6),
                          vertical: isSmallMobile ? 1 : (isMobile ? 1 : 2),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t(context, 'out'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallMobile ? 6 : (isMobile ? 7 : 10),
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
                padding: EdgeInsets.all(isSmallMobile ? 4 : (isMobile ? 6 : 8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallMobile ? 11 : (isMobile ? 12 : 14),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallMobile ? 3 : 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t(context, 'cost')}: ${product.costPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${t(context, 'price')}: ${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.purple[700],
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16),
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallMobile ? 3 : 4),
                    Text(
                      '${t(context, 'stock')}: ${product.stockQuantity}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isSmallMobile ? 9 : (isMobile ? 10 : 12),
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

  Widget _buildCartSection(bool isMobile, bool isSmallMobile) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return Column(
          children: [
            // Ultra-compact cart header for mobile
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallMobile ? 4 : (isMobile ? 6 : 16),
                vertical: isSmallMobile ? 4 : (isMobile ? 6 : 12),
              ),
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
                    padding: EdgeInsets.all(isSmallMobile ? 2 : (isMobile ? 3 : 8)),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: isSmallMobile ? 12 : (isMobile ? 16 : 24),
                    ),
                  ),
                  SizedBox(width: isSmallMobile ? 4 : 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'shopping_cart'),
                          style: TextStyle(
                            fontSize: isSmallMobile ? 11 : (isMobile ? 13 : 20),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: isSmallMobile ? 1 : 2),
                        Text(
                          '${cart.items.length} ${t(context, 'items')}',
                          style: TextStyle(
                            fontSize: isSmallMobile ? 8 : (isMobile ? 9 : 14),
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.clear, color: Colors.white, size: isSmallMobile ? 12 : 16),
                        onPressed: () {
                          cart.clearCart();
                        },
                        tooltip: t(context, 'clear_cart'),
                        padding: EdgeInsets.all(isSmallMobile ? 1 : 3),
                        constraints: BoxConstraints(
                          minWidth: isSmallMobile ? 18 : (isMobile ? 24 : 40),
                          minHeight: isSmallMobile ? 18 : (isMobile ? 24 : 40),
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
                              size: isSmallMobile ? 20 : (isMobile ? 28 : 64),
                              color: Colors.grey,
                            ),
                            SizedBox(height: isSmallMobile ? 6 : 10),
                            Text(
                              t(context, 'cart_is_empty'),
                              style: TextStyle(
                                fontSize: isSmallMobile ? 11 : (isMobile ? 13 : 18),
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: isSmallMobile ? 3 : 6),
                            Text(
                              t(context, 'add_products_to_get_started'),
                              style: TextStyle(
                                fontSize: isSmallMobile ? 9 : (isMobile ? 10 : 14),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(isSmallMobile ? 1 : (isMobile ? 2 : 12)),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        final customPriceController = TextEditingController(
                          text: item.customTotalPrice != null && item.customTotalPrice != (item.product.costPrice * item.quantity)
                            ? item.customTotalPrice!.toStringAsFixed(2)
                            : '',
                        );
                        bool isInvalid = false;
                        return StatefulBuilder(
                          builder: (context, setItemState) {
                            return Card(
                              margin: EdgeInsets.only(bottom: isSmallMobile ? 1 : (isMobile ? 2 : 8)),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(isSmallMobile ? 3 : (isMobile ? 4 : 12)),
                                leading: Container(
                                  width: isSmallMobile ? 24 : (isMobile ? 32 : 50),
                                  height: isSmallMobile ? 24 : (isMobile ? 32 : 50),
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
                                                size: isSmallMobile ? 12 : (isMobile ? 16 : 20),
                                                color: Colors.grey,
                                              );
                                            },
                                          ),
                                        )
                                      : Icon(
                                          Icons.image,
                                          size: isSmallMobile ? 12 : (isMobile ? 16 : 20),
                                          color: Colors.grey,
                                        ),
                                ),
                                title: Text(
                                  item.product.name,
                                  style: TextStyle(
                                    fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${t(context, 'cost')}: ${item.product.costPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16),
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${t(context, 'price')}: ${item.product.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16),
                                        color: Colors.purple[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove, size: isSmallMobile ? 14 : 18),
                                      onPressed: () {
                                        cart.removeItem(item.product);
                                      },
                                      padding: EdgeInsets.all(isSmallMobile ? 2 : (isMobile ? 4 : 8)),
                                      constraints: BoxConstraints(
                                        minWidth: isSmallMobile ? 24 : (isMobile ? 28 : 32),
                                        minHeight: isSmallMobile ? 24 : (isMobile ? 28 : 32),
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
                                        if (newQuantity != null && newQuantity > 0) {
                                          // Use stock validation for quantity updates
                                          final result = cart.updateQuantityWithValidation(
                                            item.product, 
                                            newQuantity, 
                                            mode: item.mode
                                          );
                                          
                                          if (!result['success']) {
                                            // Show insufficient stock message
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(result['message']),
                                                backgroundColor: Colors.red,
                                                duration: Duration(seconds: 3),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: Text(
                                      '${item.quantity}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16),
                                        fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add, size: isSmallMobile ? 14 : 18),
                                      onPressed: () {
                                        // Use stock validation for adding more of the same item
                                        final result = cart.addItemWithValidation(
                                          item.product, 
                                          mode: item.mode, 
                                          quantity: 1
                                        );
                                        
                                        if (!result['success']) {
                                          // Show insufficient stock message
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(result['message']),
                                              backgroundColor: Colors.red,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      },
                                      padding: EdgeInsets.all(isSmallMobile ? 2 : (isMobile ? 4 : 8)),
                                      constraints: BoxConstraints(
                                        minWidth: isSmallMobile ? 24 : (isMobile ? 28 : 32),
                                        minHeight: isSmallMobile ? 24 : (isMobile ? 28 : 32),
                                      ),
                                    ),
                                    SizedBox(width: isSmallMobile ? 2 : 4),
                                    IconButton(
                                      icon: Icon(Icons.delete, size: isSmallMobile ? 14 : 18, color: Colors.red),
                                      onPressed: () {
                                        cart.removeItemCompletely(item.product);
                                      },
                                      padding: EdgeInsets.all(isSmallMobile ? 2 : (isMobile ? 4 : 8)),
                                      constraints: BoxConstraints(
                                        minWidth: isSmallMobile ? 24 : (isMobile ? 28 : 32),
                                        minHeight: isSmallMobile ? 24 : (isMobile ? 28 : 32),
                                      ),
                                      tooltip: t(context, 'remove_item'),
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
            
            // Ultra-compact Total and Checkout for mobile
            Container(
              padding: EdgeInsets.all(isSmallMobile ? 6 : (isMobile ? 8 : 16)),
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
                          fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${cart.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 20),
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallMobile ? 8 : 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: cart.items.isEmpty ? null : () {
                        _showCheckoutDialog(context, cart);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: isSmallMobile ? 8 : (isMobile ? 10 : 16)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 1,
                      ),
                      child: Text(
                        t(context, 'checkout'),
                        style: TextStyle(
                          fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 18),
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
      builder: (context) => _CheckoutDialog(
        cart: cart, 
        saleMode: _saleMode,
        onSaleCompleted: () async {
          // Refresh the POS after successful sale
          await _loadProducts();
        },
      ),
    );
  }

  void _showMobileCartDialog(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _MobileCartDialog(cart: cart, onCheckout: () {
        Navigator.of(context).pop();
        _showCheckoutDialog(context, cart);
      }),
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  final CartProvider cart;
  final String saleMode;
  final VoidCallback onSaleCompleted;

  const _CheckoutDialog({
    required this.cart, 
    required this.saleMode,
    required this.onSaleCompleted,
  });

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
    // Ensure new customer fields are hidden by default
    _showNewCustomerFields = false;
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
    
    // Validate credit sales require customer selection
    if (_selectedPaymentMethod == 'credit') {
      if (!_isCustomerSetupValidForCredit()) {
        setState(() { _isLoading = false; });
        
        String errorMessage = 'Credit sales require:\n';
        if (_selectedCustomer == null && 
            _customerNameController.text.trim().isEmpty && 
            _newCustomerNameController.text.trim().isEmpty) {
          errorMessage += '• A customer to be selected, OR\n• A new customer to be created';
        } else {
          errorMessage += '• A valid phone number for the customer';
        }
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Customer Setup Required'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }
    
    // Validate stock quantities for each cart item
    final stockValidationErrors = <String>[];
    for (final item in widget.cart.items) {
      final availableStock = item.product.stockQuantity - item.product.damagedQuantity;
      if (item.quantity > availableStock) {
        stockValidationErrors.add('${item.product.name} (${item.mode}): Quantity ${item.quantity} exceeds available stock ${availableStock}');
      }
    }
    
    if (stockValidationErrors.isNotEmpty) {
      setState(() { _isLoading = false; });
      // Show stock validation errors
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Stock Validation Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The following items exceed available stock:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              ...stockValidationErrors.map((error) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('• $error', style: TextStyle(color: Colors.red[700])),
              )).toList(),
              SizedBox(height: 16),
              Text(
                'Please reduce quantities or remove items before proceeding.',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Validate each product's custom price before processing
    final validationErrors = <String>[];
    for (final item in widget.cart.items) {
      final controller = _customPriceControllers[item.product.id];
      final customTotalPrice = double.tryParse(controller?.text ?? '');
      final requiredTotalPrice = item.product.costPrice * item.quantity;
      
      if (controller == null || controller.text.isEmpty) {
        validationErrors.add('${item.product.name}: Custom price is required');
      } else if (customTotalPrice == null) {
        validationErrors.add('${item.product.name}: Invalid price format');
      } else if (customTotalPrice < requiredTotalPrice) {
        validationErrors.add('${item.product.name}: Price \$${customTotalPrice.toStringAsFixed(2)} is below cost \$${requiredTotalPrice.toStringAsFixed(2)}');
      }
    }
    
    if (validationErrors.isNotEmpty) {
      setState(() { _isLoading = false; });
      // Show validation errors
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pricing Validation Errors'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: validationErrors.map((error) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('• $error', style: TextStyle(color: Colors.red[700])),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
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
      
      // Debug logging for cart items
      print('🛒 POS: Cart items for sale:');
      print('  - Cart items: ${widget.cart.items.length}');
      print('  - Item details:');
      for (final item in widget.cart.items) {
        print('    * ${item.product.name}: mode=${item.mode}, qty=${item.quantity}');
      }
      print('  - Note: Each item maintains its individual mode (retail/wholesale)');
      
      // Check for same product with different modes
      final productIds = widget.cart.items.map((item) => item.product.id).toSet();
      if (productIds.length < widget.cart.items.length) {
        print('  - 🔍 Same product detected with different modes!');
        final groupedByProduct = <int, List<CartItem>>{};
        for (final item in widget.cart.items) {
          if (item.product.id != null) {
            groupedByProduct.putIfAbsent(item.product.id!, () => []).add(item);
          }
        }
        for (final entry in groupedByProduct.entries) {
          if (entry.value.length > 1) {
            print('    * Product ID ${entry.key} (${entry.value.first.product.name}):');
            for (final item in entry.value) {
              print('      - ${item.mode} mode: qty=${item.quantity}');
            }
          }
        }
      }
      
      final saleData = {
        if (customerId != null && customerId.toString().isNotEmpty) 'customer_id': customerId is int ? customerId : int.tryParse(customerId.toString()) ?? 0,
        'payment_method': _selectedPaymentMethod,
        'total_amount': widget.cart.items.fold(0.0, (sum, item) {
          final controller = _customPriceControllers[item.product.id];
          final totalPrice = double.tryParse(controller?.text ?? '') ?? 0.0;
          // Use total price directly, don't multiply by quantity again
          return sum + (totalPrice > 0 ? totalPrice : (item.product.costPrice * item.quantity));
        }),
        // Note: sale_mode is not set - each item maintains its individual mode
        'items': widget.cart.items.map((item) {
          final controller = _customPriceControllers[item.product.id];
          final totalPrice = double.tryParse(controller?.text ?? '') ?? 0.0;
          // Calculate unit price from total price
          final unitPrice = totalPrice > 0 ? totalPrice / item.quantity : item.product.costPrice;
          return {
            'product_id': item.product.id,
            'quantity': item.quantity,
            'unit_price': unitPrice,
            'mode': item.mode, // This is already correct - individual item mode
          };
        }).toList(),
        if (_selectedPaymentMethod == 'credit' || (customer != null && (_customerPhoneController.text.trim().isNotEmpty || _newCustomerPhoneController.text.trim().isNotEmpty)))
          'customer_phone': customer == null ? '' : (_newCustomerPhoneController.text.trim().isNotEmpty ? _newCustomerPhoneController.text.trim() : _customerPhoneController.text.trim()),
      };
      final sale = await _apiService.createSale(saleData);
      
      // Clear the cart
      widget.cart.clearCart();
      
      setState(() { _isLoading = false; });
      Navigator.of(context).pop();
      
      // Call the callback to refresh the main POS screen
      widget.onSaleCompleted();
      
      // Show success message and inform user that POS has been refreshed
      SuccessUtils.showSaleSuccess(context, sale['sale_id'].toString());
      
      // Show additional message about POS refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ POS refreshed with updated stock quantities'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      SuccessUtils.showSaleError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 600;
        final isSmallMobile = constraints.maxWidth <= 480;
        final maxHeight = MediaQuery.of(context).size.height * (isSmallMobile ? 0.95 : 0.9);
        
        // Move these inside the builder so they are in scope for the widget tree
        final combinedCost = widget.cart.items.fold(0.0, (sum, item) => sum + (item.product.costPrice * item.quantity));
        final combinedCustomTotal = widget.cart.items.fold(0.0, (sum, item) {
          final controller = _customPriceControllers[item.product.id];
          final totalPrice = double.tryParse(controller?.text ?? '');
          // Use total price directly, don't multiply by quantity
          return sum + (totalPrice ?? (item.product.costPrice * item.quantity));
        });
        
        // Validate each individual product's custom price
        final isCombinedValid = widget.cart.items.every((item) {
          final controller = _customPriceControllers[item.product.id];
          final customTotalPrice = double.tryParse(controller?.text ?? '');
          final requiredTotalPrice = item.product.costPrice * item.quantity;
          
          // Each product must have a custom price entered and it must be >= required cost
          return controller != null && 
                 controller.text.isNotEmpty && 
                 customTotalPrice != null && 
                 customTotalPrice >= requiredTotalPrice;
        });

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * (isSmallMobile ? 0.98 : (isMobile ? 0.95 : 0.9)),
            constraints: BoxConstraints(
              maxWidth: isSmallMobile ? double.infinity : (isMobile ? double.infinity : 500),
              maxHeight: maxHeight,
            ),
            padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 16 : 24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(isSmallMobile ? 10 : (isMobile ? 12 : 16)),
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
                        padding: EdgeInsets.all(isSmallMobile ? 4 : (isMobile ? 6 : 8)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.payment, color: Colors.white, size: isSmallMobile ? 18 : (isMobile ? 20 : 24)),
                      ),
                      SizedBox(width: isSmallMobile ? 6 : (isMobile ? 8 : 12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(context, 'checkout'),
                              style: TextStyle(
                                fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              t(context, 'complete_your_sale'),
                              style: TextStyle(
                                fontSize: isSmallMobile ? 10 : (isMobile ? 12 : 14),
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isLoading ? null : () {
                          widget.cart.clearCart();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.clear_all, color: Colors.white, size: isSmallMobile ? 18 : (isMobile ? 20 : 24)),
                        padding: EdgeInsets.all(isSmallMobile ? 2 : (isMobile ? 4 : 8)),
                        constraints: BoxConstraints(
                          minWidth: isSmallMobile ? 28 : (isMobile ? 32 : 40),
                          minHeight: isSmallMobile ? 28 : (isMobile ? 32 : 40),
                        ),
                        tooltip: 'Clear all items',
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white, size: isSmallMobile ? 18 : (isMobile ? 20 : 24)),
                        padding: EdgeInsets.all(isSmallMobile ? 2 : (isMobile ? 4 : 8)),
                        constraints: BoxConstraints(
                          minWidth: isSmallMobile ? 28 : (isMobile ? 32 : 40),
                          minHeight: isSmallMobile ? 28 : (isMobile ? 32 : 40),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallMobile ? 12 : (isMobile ? 16 : 24)),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Summary
                        Container(
                          padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 12 : 16)),
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
                                  fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20), 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                              SizedBox(height: isSmallMobile ? 6 : (isMobile ? 8 : 12)),
                              Divider(thickness: 1.2),
                              Text(
                                t(context, 'enter_custom_prices'),
                                style: TextStyle(fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18), fontWeight: FontWeight.bold, color: Colors.blue[700]),
                              ),
                              SizedBox(height: isSmallMobile ? 6 : (isMobile ? 8 : 12)),
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
                                        text: '', // Start with blank field instead of pre-filled price
                                      );
                                    }
                                    final controller = _customPriceControllers[id]!;
                                    bool isInvalid = false;
                                    
                                    // Calculate if this product's price is valid
                                    if (controller.text.isNotEmpty) {
                                      final customTotalPrice = double.tryParse(controller.text);
                                      final requiredTotalPrice = item.product.costPrice * item.quantity;
                                      isInvalid = customTotalPrice == null || customTotalPrice < requiredTotalPrice;
                                    } else {
                                      isInvalid = true; // Empty field is invalid
                                    }
                                    return StatefulBuilder(
                                      builder: (context, setItemState) {
                                        return Padding(
                                          padding: EdgeInsets.only(bottom: isSmallMobile ? 4 : (isMobile ? 6 : 8)),
                                          child: isSmallMobile 
                                            ? Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${item.product.name} x${item.quantity}',
                                                    style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            '${t(context, 'cost')}: ${item.product.costPrice.toStringAsFixed(2)}',
                                                            style: TextStyle(
                                                              fontSize: isSmallMobile ? 12 : 14,
                                                              color: Colors.green[700],
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          SizedBox(width: 16),
                                                          Text(
                                                            '${t(context, 'price')}: ${item.product.price.toStringAsFixed(2)}',
                                                            style: TextStyle(
                                                              fontSize: isSmallMobile ? 12 : 14,
                                                              color: Colors.purple[700],
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          Spacer(),
                                                          Text(
                                                            '\$${item.total.toStringAsFixed(2)}',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: isSmallMobile ? 12 : 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: TextFormField(
                                                      controller: controller,
                                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                      decoration: InputDecoration(
                                                        labelText: 'Total Price',
                                                        hintText: 'Enter total price for all quantities',
                                                        prefixIcon: Icon(Icons.attach_money, color: Colors.green[700], size: isSmallMobile ? 16 : 18),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        isDense: true,
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isSmallMobile ? 8 : 10),
                                                        errorText: (controller.text.isEmpty || isInvalid) ? 'Required minimum total: ${(item.product.costPrice * item.quantity).toStringAsFixed(2)}' : null,
                                                        focusedBorder: OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color: (controller.text.isEmpty || isInvalid) ? Colors.red : Colors.green,
                                                            width: 2,
                                                          ),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        helperText: 'Must be at least the total cost for all quantities',
                                                      ),
                                                      style: TextStyle(fontSize: isSmallMobile ? 12 : 14, fontWeight: FontWeight.bold),
                                                      onChanged: (value) {
                                                        final totalPrice = double.tryParse(value);
                                                        final minTotal = item.product.costPrice * item.quantity;
                                                        final valid = totalPrice != null && totalPrice >= minTotal;
                                                        setItemState(() => isInvalid = !valid);
                                                        if (valid && totalPrice != null) {
                                                          setState(() {
                                                            widget.cart.updateCustomTotalPrice(item.product, totalPrice);
                                                          });
                                                        }
                                                        // Force rebuild to update validation state
                                                        setState(() {});
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Row(
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
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${t(context, 'cost')}: ${item.product.costPrice.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          fontSize: isMobile ? 14 : 16,
                                                          color: Colors.green[700],
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${t(context, 'price')}: ${item.product.price.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          fontSize: isMobile ? 14 : 16,
                                                          color: Colors.purple[700],
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(
                                                    width: 110,
                                                    child: TextFormField(
                                                      controller: controller,
                                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                      decoration: InputDecoration(
                                                        labelText: 'Total Price',
                                                        hintText: 'Enter total price for all quantities',
                                                        prefixIcon: Icon(Icons.attach_money, color: Colors.green[700]),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        isDense: true,
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                        errorText: (controller.text.isEmpty || isInvalid) ? 'Required minimum total: ${(item.product.costPrice * item.quantity).toStringAsFixed(2)}' : null,
                                                        focusedBorder: OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color: (controller.text.isEmpty || isInvalid) ? Colors.red : Colors.green,
                                                            width: 2,
                                                          ),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        helperText: 'Must be at least the total cost for all quantities',
                                                      ),
                                                      style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold),
                                                      onChanged: (value) {
                                                        final totalPrice = double.tryParse(value);
                                                        final minTotal = item.product.costPrice * item.quantity;
                                                        final valid = totalPrice != null && totalPrice >= minTotal;
                                                        setState(() => isInvalid = !valid);
                                                        if (valid && totalPrice != null) {
                                                          setState(() {
                                                            widget.cart.updateCustomTotalPrice(item.product, totalPrice);
                                                          });
                                                        }
                                                        // Force rebuild to update validation state
                                                        setState(() {});
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
                              
                              // Validation Summary
                              if (!isCombinedValid) ...[
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    border: Border.all(color: Colors.red[200]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.warning, color: Colors.red[700], size: 16),
                                          SizedBox(width: 8),
                                          Text(
                                            'Pricing Validation Required',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      ...widget.cart.items.map((item) {
                                        final controller = _customPriceControllers[item.product.id];
                                        final customTotalPrice = double.tryParse(controller?.text ?? '');
                                        final requiredTotalPrice = item.product.costPrice * item.quantity;
                                        final isValid = controller != null && 
                                                       controller.text.isNotEmpty && 
                                                       customTotalPrice != null && 
                                                       customTotalPrice >= requiredTotalPrice;
                                        
                                        if (isValid) return SizedBox.shrink();
                                        
                                        return Padding(
                                          padding: EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            '• ${item.product.name}: Need \$${requiredTotalPrice.toStringAsFixed(2)} minimum',
                                            style: TextStyle(
                                              color: Colors.red[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      }).where((widget) => widget != SizedBox.shrink()),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16),
                              ],
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t(context, 'total'),
                                        style: TextStyle(
                                          fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18), 
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                      if (isCombinedValid)
                                        Text(
                                          '${widget.cart.items.length} products validated ✓',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        )
                                      else
                                        Text(
                                          '${widget.cart.items.where((item) {
                                            final controller = _customPriceControllers[item.product.id];
                                            final customTotalPrice = double.tryParse(controller?.text ?? '');
                                            final requiredTotalPrice = item.product.costPrice * item.quantity;
                                            return controller != null && 
                                                   controller.text.isNotEmpty && 
                                                   customTotalPrice != null && 
                                                   customTotalPrice >= requiredTotalPrice;
                                          }).length}/${widget.cart.items.length} products validated',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    '\$${widget.cart.total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isSmallMobile ? 12 : (isMobile ? 16 : 24)),

                        // Payment Method
                        Text(
                          t(context, 'payment_method'),
                          style: TextStyle(
                            fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16), 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        SizedBox(height: isSmallMobile ? 4 : (isMobile ? 6 : 8)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 6 : (isMobile ? 8 : 12)),
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
                                  style: TextStyle(fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16)),
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
                        SizedBox(height: isSmallMobile ? 12 : (isMobile ? 16 : 24)),

                        // Customer Name (always visible)
                        Row(
                          children: [
                            Text(
                              t(context, 'customer_name'),
                              style: TextStyle(
                                fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16), 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            if (_selectedPaymentMethod == 'credit')
                              Text(
                                ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16),
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: isSmallMobile ? 4 : (isMobile ? 6 : 8)),
                        _customersLoading
                          ? Center(child: CircularProgressIndicator())
                          : Row(
                              children: [
                                Expanded(
                                  child: Autocomplete<Customer>(
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
                                          labelText: _selectedPaymentMethod == 'credit' 
                                              ? '${t(context, 'customer_name')} *'
                                              : t(context, 'customer_name_optional'),
                                          border: const OutlineInputBorder(),
                                          hintText: _selectedPaymentMethod == 'credit' 
                                              ? 'Select or enter customer name (required for credit)'
                                              : t(context, 'select_or_enter_customer_name'),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: isSmallMobile ? 8 : (isMobile ? 12 : 16),
                                            vertical: isSmallMobile ? 10 : (isMobile ? 12 : 16),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          print('🔄 Customer name changed to: $value');
                                          setState(() {
                                            _selectedCustomer = null;
                                            _customerNameController.text = value;
                                            // Clear phone when manually typing customer name
                                            _customerPhoneController.text = '';
                                            // DON'T automatically show new customer fields - let user choose
                                            // _showNewCustomerFields = false; // Keep existing customer mode
                                          });
                                          print('✅ Phone field cleared, selectedCustomer set to null, staying in existing customer mode');
                                        },
                                      );
                                    },
                                    onSelected: (Customer selection) {
                                      print('🔄 Customer selected: ${selection.name} with phone: ${selection.phone}');
                                      setState(() {
                                        _selectedCustomer = selection;
                                        _customerNameController.text = selection.name;
                                        // Only populate phone if it's not empty
                                        if (selection.phone != null && selection.phone!.trim().isNotEmpty) {
                                          _customerPhoneController.text = selection.phone!;
                                          print('✅ Phone field populated with: ${selection.phone}');
                                        } else {
                                          _customerPhoneController.text = '';
                                          print('⚠️ Customer has no phone number, phone field cleared');
                                        }
                                        // Hide new customer fields when selecting existing customer
                                        _showNewCustomerFields = false;
                                      });
                                      print('✅ Phone field updated to: ${_customerPhoneController.text}');
                                    },
                                  ),
                                ),
                                if (_selectedCustomer != null) ...[
                                  SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _clearCustomerSelection,
                                    icon: Icon(Icons.clear, color: Colors.red),
                                    tooltip: 'Clear customer selection',
                                    padding: EdgeInsets.all(8),
                                    constraints: BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        SizedBox(height: isSmallMobile ? 8 : (isMobile ? 12 : 16)),

                        // Customer Phone (only for credit)
                        if (_selectedPaymentMethod == 'credit') ...[
                          SizedBox(height: isSmallMobile ? 4 : (isMobile ? 6 : 8)),
                          Text(
                            t(context, 'customer_phone'),
                            style: TextStyle(
                              fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16), 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          SizedBox(height: isSmallMobile ? 4 : (isMobile ? 6 : 8)),

                          // Customer phone field (always visible for credit sales)
                          if (_shouldShowExistingCustomerFields()) ...[
                            TextFormField(
                              controller: _customerPhoneController,
                              decoration: InputDecoration(
                                labelText: '${t(context, 'customer_phone')} *',
                                border: const OutlineInputBorder(),
                                hintText: t(context, 'required_for_credit_sales'),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallMobile ? 8 : (isMobile ? 12 : 16),
                                  vertical: isSmallMobile ? 10 : (isMobile ? 12 : 16),
                                ),
                                prefixIcon: Icon(Icons.phone, size: isSmallMobile ? 18 : 20),
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                            SizedBox(height: isSmallMobile ? 6 : (isMobile ? 8 : 12)),
                          ],
                          
                          // New Customer Button - Always show when credit is selected
                          if (_shouldShowNewCustomerButton()) ...[
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_showNewCustomerFields) {
                                        // Cancel new customer - show existing customer fields
                                        _showNewCustomerFields = false;
                                        // Clear new customer fields
                                        _newCustomerNameController.text = '';
                                        _newCustomerPhoneController.text = '';
                                      } else {
                                        // Show new customer fields - hide existing customer fields
                                        _showNewCustomerFields = true;
                                        // Clear existing customer selection
                                        _selectedCustomer = null;
                                        _customerNameController.text = '';
                                        _customerPhoneController.text = '';
                                      }
                                    });
                                    print('🔄 New customer fields toggled: $_showNewCustomerFields');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallMobile ? 8 : 12,
                                      vertical: isSmallMobile ? 8 : 10,
                                    ),
                                  ),
                                  child: Text(
                                    _showNewCustomerFields ? t(context, 'cancel_new_customer') : t(context, 'new_customer'),
                                    style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallMobile ? 6 : (isMobile ? 8 : 12)),
                          ],
                          
                          // New Customer Fields
                          if (_showNewCustomerFields) ...[
                            SizedBox(height: isSmallMobile ? 6 : (isMobile ? 8 : 12)),
                            TextFormField(
                              controller: _newCustomerNameController,
                              decoration: InputDecoration(
                                labelText: _selectedPaymentMethod == 'credit' 
                                    ? '${t(context, 'new_customer_name')} *'
                                    : t(context, 'new_customer_name'),
                                border: const OutlineInputBorder(),
                                hintText: t(context, 'enter_new_customer_name'),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallMobile ? 8 : (isMobile ? 12 : 16),
                                  vertical: isSmallMobile ? 10 : (isMobile ? 12 : 16),
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallMobile ? 6 : (isMobile ? 8 : 12)),
                            TextFormField(
                              controller: _newCustomerPhoneController,
                              decoration: InputDecoration(
                                labelText: _selectedPaymentMethod == 'credit' 
                                    ? '${t(context, 'new_customer_phone')} *'
                                    : t(context, 'new_customer_phone'),
                                border: const OutlineInputBorder(),
                                hintText: _selectedPaymentMethod == 'credit' 
                                    ? t(context, 'required_for_credit_sales')
                                    : t(context, 'enter_phone_optional'),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallMobile ? 8 : (isMobile ? 12 : 16),
                                  vertical: isSmallMobile ? 10 : (isMobile ? 12 : 16),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ],
                        ],

                        // Show customer setup status for credit sales
                        if (_selectedPaymentMethod == 'credit') ...[
                          SizedBox(height: isSmallMobile ? 6 : (isMobile ? 8 : 12)),
                          Container(
                            padding: EdgeInsets.all(isSmallMobile ? 8 : (isMobile ? 10 : 12)),
                            decoration: BoxDecoration(
                              color: _isCustomerSetupValidForCredit() ? Colors.green[50] : Colors.red[50],
                              border: Border.all(
                                color: _isCustomerSetupValidForCredit() ? Colors.green[300]! : Colors.red[300]!,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isCustomerSetupValidForCredit() ? Icons.check_circle : Icons.error,
                                  color: _isCustomerSetupValidForCredit() ? Colors.green[700] : Colors.red[700],
                                  size: isSmallMobile ? 16 : 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isCustomerSetupValidForCredit() 
                                        ? 'Customer setup complete ✓'
                                        : 'Customer setup incomplete - Please select or create a customer with phone number',
                                    style: TextStyle(
                                      color: _isCustomerSetupValidForCredit() ? Colors.green[700] : Colors.red[700],
                                      fontSize: isSmallMobile ? 12 : 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Show error message if combined custom total is less than combined cost
                        if (!isCombinedValid)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: isSmallMobile ? 6 : (isMobile ? 8 : 12)),
                            child: Text(
                              '${t(context, 'total_entered_amount_must_be_at_least_combined_cost')}: ${combinedCost.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.red[900], 
                                fontWeight: FontWeight.bold, 
                                fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16)
                              ),
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
                          padding: EdgeInsets.symmetric(vertical: isSmallMobile ? 10 : (isMobile ? 12 : 16)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          t(context, 'cancel'),
                          style: TextStyle(fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16)),
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : (isMobile ? 12 : 16)),
                    Expanded(
                      child: Tooltip(
                        message: !isCombinedValid ? 'Fix pricing validation errors to continue' : 'Complete the sale',
                        child: ElevatedButton(
                          onPressed: _isLoading || !isCombinedValid ? null : _processSale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isSmallMobile ? 10 : (isMobile ? 12 : 16)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: isSmallMobile ? 14 : (isMobile ? 16 : 20),
                                width: isSmallMobile ? 14 : (isMobile ? 16 : 20),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                t(context, 'complete_sale'),
                                style: TextStyle(fontSize: isSmallMobile ? 12 : (isMobile ? 14 : 16)),
                              ),
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

  // Helper method to validate customer setup for credit sales
  bool _isCustomerSetupValidForCredit() {
    // Check if we have a valid customer setup
    if (_selectedCustomer != null) {
      // Selected customer must have a phone number
      final phone = _selectedCustomer!.phone;
      return phone != null && phone.trim().isNotEmpty && _isValidPhoneNumber(phone);
    } else if (_showNewCustomerFields) {
      // New customer fields must have both name and phone
      final name = _newCustomerNameController.text.trim();
      final phone = _newCustomerPhoneController.text.trim();
      return name.isNotEmpty && phone.isNotEmpty && _isValidPhoneNumber(phone);
    } else if (_customerNameController.text.trim().isNotEmpty) {
      // Existing customer name must have phone number
      final phone = _customerPhoneController.text.trim();
      return phone.isNotEmpty && _isValidPhoneNumber(phone);
    }
    return false;
  }

  // Helper method to get current customer phone number
  String? _getCurrentCustomerPhone() {
    if (_selectedCustomer != null) {
      return _selectedCustomer!.phone;
    } else if (_showNewCustomerFields) {
      return _newCustomerPhoneController.text.trim();
    } else if (_customerNameController.text.trim().isNotEmpty) {
      return _customerPhoneController.text.trim();
    }
    return null;
  }

  // Helper method to validate phone number format
  bool _isValidPhoneNumber(String phone) {
    // Just check if it contains only digits
    return RegExp(r'^\d+$').hasMatch(phone);
  }

  // Helper method to get formatted phone number for display
  String _formatPhoneNumber(String phone) {
    // Remove any non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Format based on length
    if (digitsOnly.length == 10) {
      return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    } else if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      return '+1 (${digitsOnly.substring(1, 4)}) ${digitsOnly.substring(4, 7)}-${digitsOnly.substring(7)}';
    } else if (digitsOnly.length == 7) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3)}';
    }
    
    return phone; // Return as-is if no specific format matches
  }

  // Method to reset customer fields
  void _resetCustomerFields() {
    setState(() {
      _selectedCustomer = null;
      _customerNameController.text = '';
      _customerPhoneController.text = '';
      _newCustomerNameController.text = '';
      _newCustomerPhoneController.text = '';
      _showNewCustomerFields = false;
    });
  }

  // Method to clear customer selection
  void _clearCustomerSelection() {
    setState(() {
      _selectedCustomer = null;
      _customerNameController.text = '';
      _customerPhoneController.text = '';
      // DON'T automatically show new customer fields - stay in existing customer mode
      // _showNewCustomerFields = true;
    });
    print('🔄 Customer selection cleared, staying in existing customer mode');
  }

  // Method to determine if existing customer fields should be visible
  bool _shouldShowExistingCustomerFields() {
    return _selectedPaymentMethod == 'credit';
  }

  // Method to determine if new customer fields should be visible
  bool _shouldShowNewCustomerFields() {
    return _showNewCustomerFields;
  }

  // Method to determine if new customer button should be visible
  bool _shouldShowNewCustomerButton() {
    return _selectedPaymentMethod == 'credit';
  }


} 

class _MobileCartDialog extends StatefulWidget {
  final CartProvider cart;
  final VoidCallback onCheckout;

  const _MobileCartDialog({required this.cart, required this.onCheckout});

  @override
  State<_MobileCartDialog> createState() => _MobileCartDialogState();
}

class _MobileCartDialogState extends State<_MobileCartDialog> {
  // Method to check if cart is valid for checkout (stock quantities)
  bool _isCartValidForCheckout() {
    for (final item in widget.cart.items) {
      final availableStock = item.product.stockQuantity - item.product.damagedQuantity;
      if (item.quantity > availableStock) {
        return false;
      }
    }
    return true;
  }

  // Method to get cart validation summary
  Map<String, dynamic> _getCartValidationSummary() {
    final summary = <String, dynamic>{
      'isValid': true,
      'totalItems': widget.cart.items.length,
      'validItems': 0,
      'invalidItems': <Map<String, dynamic>>[],
      'warnings': <String>[],
    };

    for (final item in widget.cart.items) {
      final availableStock = item.product.stockQuantity - item.product.damagedQuantity;
      
      if (item.quantity > availableStock) {
        summary['isValid'] = false;
        summary['invalidItems'].add({
          'productName': item.product.name,
          'mode': item.mode,
          'quantity': item.quantity,
          'totalStock': availableStock,
          'shortage': item.quantity - availableStock,
        });
      } else {
        summary['validItems']++;
        
        // Add low stock warnings
        if (availableStock <= item.product.lowStockThreshold) {
          summary['warnings'].add('${item.product.name} (${item.mode}): Low stock (${availableStock})');
        }
      }
    }

    return summary;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallMobile = constraints.maxWidth <= 480;
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.all(isSmallMobile ? 16 : 20),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(isSmallMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.shopping_cart,
                          color: Colors.white,
                          size: isSmallMobile ? 20 : 24,
                        ),
                      ),
                      SizedBox(width: isSmallMobile ? 8 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shopping Cart',
                              style: TextStyle(
                                fontSize: isSmallMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${widget.cart.items.length} items',
                              style: TextStyle(
                                fontSize: isSmallMobile ? 12 : 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          widget.cart.clearCart();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(
                          Icons.clear_all,
                          color: Colors.white,
                          size: isSmallMobile ? 20 : 24,
                        ),
                        tooltip: 'Clear all items',
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: isSmallMobile ? 20 : 24,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallMobile ? 16 : 20),
                
                // Cart Items
                Expanded(
                  child: widget.cart.items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: isSmallMobile ? 48 : 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: isSmallMobile ? 12 : 16),
                              Text(
                                'Cart is empty',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 16 : 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: isSmallMobile ? 8 : 12),
                              Text(
                                'Add products to get started',
                                style: TextStyle(
                                  fontSize: isSmallMobile ? 12 : 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: widget.cart.items.length,
                          itemBuilder: (context, index) {
                            final item = widget.cart.items[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: isSmallMobile ? 8 : 12),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(isSmallMobile ? 8 : 12),
                                leading: Container(
                                  width: isSmallMobile ? 40 : 50,
                                  height: isSmallMobile ? 40 : 50,
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
                                                size: isSmallMobile ? 16 : 20,
                                                color: Colors.grey,
                                              );
                                            },
                                          ),
                                        )
                                      : Icon(
                                          Icons.image,
                                          size: isSmallMobile ? 16 : 20,
                                          color: Colors.grey,
                                        ),
                                ),
                                title: Text(
                                  item.product.name,
                                  style: TextStyle(
                                    fontSize: isSmallMobile ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${t(context, 'cost')}: ${item.product.costPrice.toStringAsFixed(2)} x ${item.quantity}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 12 : 14,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${t(context, 'price')}: ${item.product.price.toStringAsFixed(2)} x ${item.quantity}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 12 : 14,
                                        color: Colors.purple[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove, size: isSmallMobile ? 16 : 18),
                                      onPressed: () {
                                        widget.cart.removeItem(item.product);
                                        setState(() {});
                                      },
                                      padding: EdgeInsets.all(isSmallMobile ? 4 : 8),
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: TextStyle(
                                        fontSize: isSmallMobile ? 14 : 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add, size: isSmallMobile ? 16 : 18),
                                      onPressed: () {
                                        // Use stock validation for adding more of the same item
                                        final result = widget.cart.addItemWithValidation(
                                          item.product, 
                                          mode: item.mode, 
                                          quantity: 1
                                        );
                                        
                                        if (!result['success']) {
                                          // Show insufficient stock message
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(result['message']),
                                              backgroundColor: Colors.red,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                        
                                        setState(() {});
                                      },
                                      padding: EdgeInsets.all(isSmallMobile ? 4 : 8),
                                    ),
                                    SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.delete, size: isSmallMobile ? 16 : 18, color: Colors.red),
                                      onPressed: () {
                                        widget.cart.removeItemCompletely(item.product);
                                        setState(() {});
                                      },
                                      padding: EdgeInsets.all(isSmallMobile ? 4 : 8),
                                      tooltip: 'Remove item',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                
                // Total and Checkout
                if (widget.cart.items.isNotEmpty) ...[
                  SizedBox(height: isSmallMobile ? 16 : 20),
                  Container(
                    padding: EdgeInsets.all(isSmallMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total:',
                              style: TextStyle(
                                fontSize: isSmallMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${widget.cart.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: isSmallMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallMobile ? 12 : 16),
                        
                        // Stock Validation Status
                        Builder(
                          builder: (context) {
                            final cartValidation = _getCartValidationSummary();
                            final hasStockIssues = !cartValidation['isValid'];
                            final hasWarnings = cartValidation['warnings'].isNotEmpty;
                            
                            if (!hasStockIssues && !hasWarnings) return SizedBox.shrink();
                            
                            return Container(
                              margin: EdgeInsets.only(bottom: isSmallMobile ? 8 : 12),
                              padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
                              decoration: BoxDecoration(
                                color: hasStockIssues ? Colors.red[50] : Colors.orange[50],
                                border: Border.all(
                                  color: hasStockIssues ? Colors.red[300]! : Colors.orange[300]!,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        hasStockIssues ? Icons.error : Icons.warning,
                                        color: hasStockIssues ? Colors.red[700] : Colors.orange[700],
                                        size: isSmallMobile ? 16 : 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        hasStockIssues ? 'Stock Issues Detected' : 'Low Stock Warnings',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: hasStockIssues ? Colors.red[700] : Colors.orange[700],
                                          fontSize: isSmallMobile ? 12 : 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (hasStockIssues) ...[
                                    SizedBox(height: 8),
                                    ...cartValidation['invalidItems'].map<Widget>((item) => 
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '• ${item['productName']} (${item['mode']}): Need ${item['quantity']}, Available ${item['totalStock']}',
                                          style: TextStyle(
                                            color: Colors.red[600],
                                            fontSize: isSmallMobile ? 10 : 12,
                                          ),
                                        ),
                                      ),
                                    ).toList(),
                                  ],
                                  if (hasWarnings) ...[
                                    SizedBox(height: 8),
                                    ...cartValidation['warnings'].map<Widget>((warning) => 
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '• $warning',
                                          style: TextStyle(
                                            color: Colors.orange[600],
                                            fontSize: isSmallMobile ? 10 : 12,
                                          ),
                                        ),
                                      ),
                                    ).toList(),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isCartValidForCheckout() ? widget.onCheckout : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isCartValidForCheckout() ? Colors.green : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isSmallMobile ? 12 : 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _isCartValidForCheckout() ? 'Continue to Checkout' : 'Fix Stock Issues to Continue',
                              style: TextStyle(
                                fontSize: isSmallMobile ? 14 : 16,
                                fontWeight: FontWeight.bold,
                              ),
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
} 