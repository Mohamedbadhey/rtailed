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

  double get unitPrice => customTotalPrice != null ? (customTotalPrice! / quantity) : product.costPrice;
  double get total => customTotalPrice ?? (product.costPrice * quantity);
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => [..._items];

  int get itemCount => _items.length;

  double get total {
    return _items.fold(0, (sum, item) => sum + item.total);
  }

  void addItem(Product product, {String mode = 'retail', int quantity = 1}) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id && item.mode == mode,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity, mode: mode));
    }
    notifyListeners();
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
    _items.clear();
    notifyListeners();
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