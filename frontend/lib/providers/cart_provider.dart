import 'package:flutter/foundation.dart';
import 'package:retail_management/models/product.dart';

class CartItem {
  final Product product;
  int quantity;
  double? customTotalPrice; // nullable, if not set use product.costPrice * quantity (total cost)
  String mode; // 'retail' or 'wholesale'

  CartItem({
    required this.product,
    this.quantity = 1,
    this.customTotalPrice,
    this.mode = 'retail',
  });

  double get unitPrice => customTotalPrice != null ? (customTotalPrice! / quantity) : product.price;
  double get total => customTotalPrice ?? (product.price * quantity);
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => [..._items];

  int get itemCount => _items.length;

  double get total {
    return _items.fold(0, (sum, item) => sum + item.total);
  }

  // Check if there's sufficient stock for a product
  bool hasSufficientStock(Product product, int requestedQuantity, String mode) {
    // Get current quantity in cart for this product and mode
    final currentCartQuantity = getQuantityInCart(product, mode);
    
    // Calculate total quantity needed (current cart + new request)
    final totalQuantityNeeded = currentCartQuantity + requestedQuantity;
    
    // Check if available stock is sufficient
    final availableStock = product.stockQuantity - product.damagedQuantity;
    
    print('🔍 Stock Check for ${product.name}:');
    print('   - Available Stock: ${availableStock}');
    print('   - Current in Cart: ${currentCartQuantity}');
    print('   - Requested: ${requestedQuantity}');
    print('   - Total Needed: ${totalQuantityNeeded}');
    print('   - Sufficient: ${availableStock >= totalQuantityNeeded}');
    
    return availableStock >= totalQuantityNeeded;
  }

  // Get current quantity of a product in cart for a specific mode
  int getQuantityInCart(Product product, String mode) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id && item.mode == mode,
    );
    
    if (existingIndex >= 0) {
      return _items[existingIndex].quantity;
    }
    return 0;
  }

  // Get available stock for a product (considering current cart)
  int getAvailableStock(Product product, String mode) {
    final currentCartQuantity = getQuantityInCart(product, mode);
    final availableStock = product.stockQuantity - product.damagedQuantity;
    return availableStock - currentCartQuantity;
  }

  // Get stock status summary for all items in cart
  Map<String, dynamic> getStockStatusSummary() {
    final summary = <String, dynamic>{
      'totalItems': _items.length,
      'itemsWithLowStock': 0,
      'itemsWithInsufficientStock': 0,
      'warnings': <String>[],
    };

    for (final item in _items) {
      final availableStock = getAvailableStock(item.product, item.mode);
      final totalStock = item.product.stockQuantity - item.product.damagedQuantity;
      
      // Check for low stock
      if (totalStock <= item.product.lowStockThreshold) {
        summary['itemsWithLowStock']++;
        summary['warnings'].add('${item.product.name} (${item.mode}): Low stock (${totalStock})');
      }
      
      // Check for insufficient stock
      if (availableStock < 0) {
        summary['itemsWithInsufficientStock']++;
        summary['warnings'].add('${item.product.name} (${item.mode}): Insufficient stock! Available: ${totalStock}, In Cart: ${item.quantity}');
      }
    }

    return summary;
  }

  // Add item with stock validation - returns success status and message
  Map<String, dynamic> addItemWithValidation(Product product, {String mode = 'retail', int quantity = 1}) {
    // Check if there's sufficient stock
    if (!hasSufficientStock(product, quantity, mode)) {
      final availableStock = getAvailableStock(product, mode);
      final currentCartQuantity = getQuantityInCart(product, mode);
      
      String message;
      if (currentCartQuantity > 0) {
        message = 'Insufficient stock! You already have ${currentCartQuantity} ${product.name} in cart. Available: ${availableStock}';
      } else {
        message = 'Insufficient stock! Available: ${availableStock}, Requested: ${quantity}';
      }
      
      print('❌ Stock validation failed: $message');
      return {
        'success': false,
        'message': message,
        'availableStock': availableStock,
        'requestedQuantity': quantity,
        'currentInCart': currentCartQuantity
      };
    }
    
    // Stock is sufficient, add the item
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id && item.mode == mode,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
      print('✅ Updated quantity for ${product.name} (${mode}): ${_items[existingIndex].quantity}');
    } else {
      _items.add(CartItem(product: product, quantity: quantity, mode: mode));
      print('✅ Added ${product.name} (${mode}) to cart: ${quantity}');
    }
    
    notifyListeners();
    
    return {
      'success': true,
      'message': 'Item added successfully',
      'newQuantity': existingIndex >= 0 ? _items[existingIndex].quantity : quantity
    };
  }

  void addItem(Product product, {String mode = 'retail', int quantity = 1}) {
    // Use the new validation method
    final result = addItemWithValidation(product, mode: mode, quantity: quantity);
    
    // If validation failed, this will still add the item (for backward compatibility)
    // But you should use addItemWithValidation in new code
    if (!result['success']) {
      print('⚠️ Warning: Item added despite insufficient stock (backward compatibility)');
    }
    
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id && item.mode == mode,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
      print('🛒 CartProvider: Updated quantity for ${product.name} (${mode}): ${_items[existingIndex].quantity}');
    } else {
      _items.add(CartItem(product: product, quantity: quantity, mode: mode));
      print('🛒 CartProvider: Added ${product.name} (${mode}) to cart: ${quantity}');
    }
    print('🛒 CartProvider: Total items in cart: ${_items.length}');
    notifyListeners();
    print('🛒 CartProvider: Notified listeners after adding item');
  }

  void addItemWithMode(Product product, String mode, int quantity) {
    addItem(product, mode: mode, quantity: quantity);
  }

  void removeItem(Product product) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        _items[existingIndex].quantity--;
      } else {
        _items.removeAt(existingIndex);
      }
      notifyListeners();
    }
  }

  void removeItemCompletely(Product product) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      _items.removeAt(existingIndex);
      notifyListeners();
    }
  }

  void clearCart() {
    print('🛒 CartProvider: Clearing cart - items before: ${_items.length}');
    _items.clear();
    print('🛒 CartProvider: Cart cleared - items after: ${_items.length}');
    notifyListeners();
    print('🛒 CartProvider: Notified listeners after clearing cart');
  }

  void updateQuantity(Product product, int quantity, {String? mode}) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id && (mode == null || item.mode == mode),
    );

    if (existingIndex >= 0) {
      if (quantity > 0) {
        _items[existingIndex].quantity = quantity;
      } else {
        _items.removeAt(existingIndex);
      }
      notifyListeners();
    }
  }

  // Update quantity with stock validation
  Map<String, dynamic> updateQuantityWithValidation(Product product, int newQuantity, {String? mode}) {
    // Find the item to update
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id && (mode == null || item.mode == mode),
    );

    if (existingIndex < 0) {
      return {
        'success': false,
        'message': 'Product not found in cart'
      };
    }

    final currentMode = _items[existingIndex].mode;
    
    // Check if new quantity exceeds available stock
    if (newQuantity > 0) {
      // Calculate total quantity needed (excluding current cart quantity for this item)
      final otherItemsQuantity = _items.where((item) => 
        item.product.id == product.id && item.mode == currentMode && _items.indexOf(item) != existingIndex
      ).fold(0, (sum, item) => sum + item.quantity);
      
      final totalQuantityNeeded = otherItemsQuantity + newQuantity;
      final availableStock = product.stockQuantity - product.damagedQuantity;
      
      if (totalQuantityNeeded > availableStock) {
        final message = 'Insufficient stock! Available: ${availableStock}, Requested: ${newQuantity}';
        print('❌ Quantity update failed: $message');
        return {
          'success': false,
          'message': message,
          'availableStock': availableStock,
          'requestedQuantity': newQuantity
        };
      }
    }

    // Stock is sufficient, update the quantity
    if (newQuantity > 0) {
      _items[existingIndex].quantity = newQuantity;
      print('✅ Updated quantity for ${product.name} (${currentMode}): ${newQuantity}');
    } else {
      _items.removeAt(existingIndex);
      print('✅ Removed ${product.name} (${currentMode}) from cart');
    }
    
    notifyListeners();
    
    return {
      'success': true,
      'message': 'Quantity updated successfully',
      'newQuantity': newQuantity
    };
  }

  bool isInCart(Product product) {
    return _items.any((item) => item.product.id == product.id);
  }

  int getQuantity(Product product) {
    final item = _items.firstWhere(
      (item) => item.product.id == product.id,
      orElse: () => CartItem(product: product, quantity: 0),
    );
    return item.quantity;
  }

  void updateCustomTotalPrice(Product product, double totalPrice) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      _items[existingIndex].customTotalPrice = totalPrice;
      notifyListeners();
    }
  }
} 