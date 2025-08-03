// Test file to verify frontend data display
// This file contains test cases for the deleted data functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_management/utils/type_converter.dart';

void main() {
  group('TypeConverter Tests', () {
    test('should convert LinkedMap to Map<String, dynamic>', () {
      // Simulate data from backend
      final linkedMapData = {
        'id': 1,
        'name': 'Test Product',
        'price': 100.0,
        'is_deleted': 1,
        'business_id': 6,
      };
      
      final result = TypeConverter.safeToMap(linkedMapData);
      
      expect(result, isA<Map<String, dynamic>>());
      expect(result['id'], equals(1));
      expect(result['name'], equals('Test Product'));
      expect(result['price'], equals(100.0));
      expect(result['is_deleted'], equals(true)); // Should be converted to bool
      expect(result['business_id'], equals(6));
    });
    
    test('should convert list of LinkedMaps to List<Map<String, dynamic>>', () {
      final linkedMapList = [
        {'id': 1, 'name': 'Product 1', 'is_deleted': 1},
        {'id': 2, 'name': 'Product 2', 'is_deleted': 0},
      ];
      
      final result = TypeConverter.safeToList(linkedMapList);
      
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.length, equals(2));
      expect(result[0]['id'], equals(1));
      expect(result[0]['is_deleted'], equals(true));
      expect(result[1]['is_deleted'], equals(false));
    });
    
    test('should handle null values safely', () {
      final result = TypeConverter.safeToMap(null);
      expect(result, equals({}));
      
      final listResult = TypeConverter.safeToList(null);
      expect(listResult, equals([]));
    });
    
    test('should convert numeric strings to doubles', () {
      final data = {
        'price': '100.50',
        'quantity': '5',
        'amount': 200.75,
      };
      
      final result = TypeConverter.safeToMap(data);
      
      expect(result['price'], isA<double>());
      expect(result['price'], equals(100.50));
      expect(result['quantity'], isA<double>());
      expect(result['quantity'], equals(5.0));
      expect(result['amount'], isA<double>());
      expect(result['amount'], equals(200.75));
    });
    
    test('should convert MySQL boolean values', () {
      final data = {
        'is_active': 1,
        'is_deleted': 0,
        'is_read': '1',
        'is_visible': '0',
      };
      
      final result = TypeConverter.safeToMap(data);
      
      expect(result['is_active'], equals(true));
      expect(result['is_deleted'], equals(false));
      expect(result['is_read'], equals(true));
      expect(result['is_visible'], equals(false));
    });
  });
  
  group('Data Display Tests', () {
    test('should format deleted item display name correctly', () {
      // Test user display
      final userData = {'id': 1, 'username': 'testuser', 'email': 'test@example.com'};
      final userDisplayName = _getDisplayName(userData, 'user');
      expect(userDisplayName, equals('testuser'));
      
      // Test product display
      final productData = {'id': 1, 'name': 'Test Product', 'sku': 'SKU001'};
      final productDisplayName = _getDisplayName(productData, 'product');
      expect(productDisplayName, equals('Test Product'));
      
      // Test sale display
      final saleData = {'id': 1, 'total_amount': 150.0};
      final saleDisplayName = _getDisplayName(saleData, 'sale');
      expect(saleDisplayName, equals('Sale #1 - \$150.00'));
    });
    
    test('should handle missing data gracefully', () {
      final emptyData = {};
      final displayName = _getDisplayName(emptyData, 'user');
      expect(displayName, equals('Unknown User'));
    });
  });
}

// Helper function to simulate the display name logic from the frontend
String _getDisplayName(Map<String, dynamic> item, String type) {
  switch (type) {
    case 'user':
      return item['username'] ?? 'Unknown User';
    case 'product':
      return item['name'] ?? 'Unknown Product';
    case 'sale':
      final id = item['id'] ?? 'Unknown';
      final amount = TypeConverter.safeToDouble(item['total_amount']).toStringAsFixed(2);
      return 'Sale #$id - \$$amount';
    case 'customer':
      return item['name'] ?? 'Unknown Customer';
    case 'category':
      return item['name'] ?? 'Unknown Category';
    default:
      return 'Unknown Item';
  }
} 