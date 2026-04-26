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

  double get unitPrice {
    if (customTotalPrice != null) return customTotalPrice! / quantity;
    return (mode == 'wholesale' && product.wholesalePrice != null && product.wholesalePrice! > 0)
        ? product.wholesalePrice!
        : product.price;
  }
  
  double get total {
    if (customTotalPrice != null) return customTotalPrice!;
    return unitPrice * quantity;
  }
  bool get hasCustomTotal => customTotalPrice != null;
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => [..._items];

  int get itemCount => _items.length;

  double get total {
    return _items.fold(0.0, (sum, item) {
      final t = item.customTotalPrice;
      return sum + (t != null ? t : (item.product.price * item.quantity));
    });
  } // total uses customTotalPrice when set, otherwise fallback to selling price * qty
  
  void clearCustomTotalPrice(Product product) {
    final existingIndex = _items.indexWhere((i) => i.product.id == product.id);
    if (existingIndex >= 0) {
      _items[existingIndex].customTotalPrice = null;
      notifyListeners();
    }
  }

  // Check if there's sufficient stock for a product
  bool hasSufficientStock(Product product, int requestedQuantity, String mode) {
    // Get current quantity in cart for this product and mode
    final currentCartQuantity = getQuantityInCart(product, mode);
    
    // Calculate total quantity needed (current cart + new request)
    final totalQuantityNeeded = currentCartQuantity + requestedQuantity;
    
    // Check if available stock is sufficient
    final availableStock = product.stockQuantity;
    
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
    final availableStock = product.stockQuantity.toInt();
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
      final totalStock = item.product.stockQuantity;
      
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
      // Remove from current position and insert at the top (index 0)
      final existingItem = _items.removeAt(existingIndex);
      existingItem.quantity += quantity;
      existingItem.customTotalPrice = null; // Reset custom price when qty changes
      _items.insert(0, existingItem);
    } else {
      // New item, insert at the top (index 0)
      _items.insert(0, CartItem(product: product, quantity: quantity, mode: mode));
    }
    
    notifyListeners();
    
    return {
      'success': true,
      'message': 'Item added successfully',
      'newQuantity': existingIndex >= 0 ? _items[existingIndex].quantity : quantity
    };
  }

  void addItem(Product product, {String mode = 'retail', int quantity = 1}) {
    // Use the validation method which also handles moving items to the top
    addItemWithValidation(product, mode: mode, quantity: quantity);
    
    // Force an additional notification after a small delay if needed for UI sync
    Future.delayed(const Duration(milliseconds: 50), () {
      notifyListeners();
    });
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
        _items[existingIndex].customTotalPrice = null; // Reset custom price when qty changes
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
        _items.clear();
        notifyListeners();
        // Force an additional notification after a small delay
    Future.delayed(const Duration(milliseconds: 50), () {
            notifyListeners();
    });
  }

  void updateQuantity(Product product, int quantity, {String? mode}) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id && (mode == null || item.mode == mode),
    );

    if (existingIndex >= 0) {
      if (quantity > 0) {
        if (_items[existingIndex].quantity != quantity) {
          _items[existingIndex].quantity = quantity;
          _items[existingIndex].customTotalPrice = null; // Reset custom price when qty changes
        }
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
      final availableStock = product.stockQuantity;
      
      if (totalQuantityNeeded > availableStock) {
        final message = 'Insufficient stock! Available: ${availableStock}, Requested: ${newQuantity}';
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
      if (_items[existingIndex].quantity != newQuantity) {
        _items[existingIndex].quantity = newQuantity;
        _items[existingIndex].customTotalPrice = null; // Reset custom price when qty changes
      }
          } else {
      _items.removeAt(existingIndex);
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