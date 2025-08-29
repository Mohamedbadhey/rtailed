// Test file to demonstrate stock validation functionality
// This shows how the CartProvider now handles insufficient stock

import 'package:flutter/material.dart';
import 'package:retail_management/models/product.dart';
import 'package:retail_management/providers/cart_provider.dart';

void main() {
  runApp(StockValidationTestApp());
}

class StockValidationTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Validation Test',
      home: StockValidationTestScreen(),
    );
  }
}

class StockValidationTestScreen extends StatefulWidget {
  @override
  _StockValidationTestScreenState createState() => _StockValidationTestScreenState();
}

class _StockValidationTestScreenState extends State<StockValidationTestScreen> {
  late CartProvider cartProvider;
  late Product testProduct;

  @override
  void initState() {
    super.initState();
    
    // Create a test product with limited stock
    testProduct = Product(
      id: 1,
      name: 'Test Product',
      price: 10.0,
      costPrice: 5.0,
      stockQuantity: 5,  // Only 5 in stock
      damagedQuantity: 0,
      lowStockThreshold: 3,
    );
    
    cartProvider = CartProvider();
  }

  void testStockValidation() {
    print('🧪 ===== TESTING STOCK VALIDATION =====');
    
    // Test 1: Add 3 items (should succeed)
    print('\n📦 Test 1: Adding 3 items (should succeed)');
    final result1 = cartProvider.addItemWithValidation(testProduct, mode: 'retail', quantity: 3);
    print('Result: ${result1['success']} - ${result1['message']}');
    
    // Test 2: Try to add 3 more (should fail - only 2 available)
    print('\n📦 Test 2: Adding 3 more items (should fail - insufficient stock)');
    final result2 = cartProvider.addItemWithValidation(testProduct, mode: 'retail', quantity: 3);
    print('Result: ${result2['success']} - ${result2['message']}');
    
    // Test 3: Check available stock
    print('\n📦 Test 3: Checking available stock');
    final availableStock = cartProvider.getAvailableStock(testProduct, 'retail');
    print('Available stock: $availableStock');
    
    // Test 4: Get stock status summary
    print('\n📦 Test 4: Stock status summary');
    final summary = cartProvider.getStockStatusSummary();
    print('Total items: ${summary['totalItems']}');
    print('Items with low stock: ${summary['itemsWithLowStock']}');
    print('Items with insufficient stock: ${summary['itemsWithInsufficientStock']}');
    print('Warnings: ${summary['warnings']}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stock Validation Test'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock Validation Test',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Text('Test Product: ${testProduct.name}'),
            Text('Stock: ${testProduct.stockQuantity}'),
            Text('Damaged: ${testProduct.damagedQuantity}'),
            Text('Available: ${testProduct.stockQuantity - testProduct.damagedQuantity}'),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: testStockValidation,
              child: Text('Run Stock Validation Test'),
            ),
            SizedBox(height: 16),
            Text('Check console for test results'),
          ],
        ),
      ),
    );
  }
}
