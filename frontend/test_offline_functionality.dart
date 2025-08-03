import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/offline_provider.dart';
import 'lib/services/offline_data_service.dart';
import 'lib/services/offline_database.dart';
import 'lib/models/product.dart';
import 'lib/models/customer.dart';
import 'lib/models/sale.dart';

class OfflineFunctionalityTest extends StatefulWidget {
  const OfflineFunctionalityTest({Key? key}) : super(key: key);

  @override
  State<OfflineFunctionalityTest> createState() => _OfflineFunctionalityTestState();
}

class _OfflineFunctionalityTestState extends State<OfflineFunctionalityTest> {
  final OfflineDataService _dataService = OfflineDataService();
  final OfflineDatabase _offlineDb = OfflineDatabase();
  List<String> _testResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _testResults.clear();
    });

    try {
      // Test 1: Database initialization
      await _testDatabaseInitialization();
      
      // Test 2: Offline data operations
      await _testOfflineDataOperations();
      
      // Test 3: Sync queue functionality
      await _testSyncQueue();
      
      // Test 4: Data integrity
      await _testDataIntegrity();

    } catch (e) {
      _addTestResult('❌ Test failed with error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testDatabaseInitialization() async {
    _addTestResult('🔧 Testing database initialization...');
    
    try {
      final db = await _offlineDb.database;
      _addTestResult('✅ Database initialized successfully');
      
      // Test table creation
      final tables = await db.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
      final tableNames = tables.map((t) => t['name'] as String).toList();
      
      final requiredTables = ['products', 'customers', 'sales', 'sync_queue', 'businesses'];
      final missingTables = requiredTables.where((table) => !tableNames.contains(table)).toList();
      
      if (missingTables.isEmpty) {
        _addTestResult('✅ All required tables created successfully');
      } else {
        _addTestResult('❌ Missing tables: ${missingTables.join(', ')}');
      }
    } catch (e) {
      _addTestResult('❌ Database initialization failed: $e');
    }
  }

  Future<void> _testOfflineDataOperations() async {
    _addTestResult('📝 Testing offline data operations...');
    
    try {
      // Test product creation
      final testProduct = Product(
        id: null,
        name: 'Test Product',
        description: 'Test Description',
        price: 10.0,
        cost: 5.0,
        quantity: 100,
        categoryId: 1,
        businessId: 1,
        imageUrl: null,
        barcode: '123456789',
      );
      
      final createdProduct = await _dataService.createProduct(testProduct);
      if (createdProduct != null) {
        _addTestResult('✅ Product created offline successfully');
      } else {
        _addTestResult('❌ Product creation failed');
      }
      
      // Test customer creation
      final testCustomer = Customer(
        id: null,
        name: 'Test Customer',
        email: 'test@example.com',
        phone: '1234567890',
        address: 'Test Address',
        businessId: 1,
      );
      
      final createdCustomer = await _dataService.createCustomer(testCustomer);
      if (createdCustomer != null) {
        _addTestResult('✅ Customer created offline successfully');
      } else {
        _addTestResult('❌ Customer creation failed');
      }
      
      // Test data retrieval
      final products = await _dataService.getProducts();
      final customers = await _dataService.getCustomers();
      
      _addTestResult('✅ Retrieved ${products.length} products and ${customers.length} customers from offline storage');
      
    } catch (e) {
      _addTestResult('❌ Offline data operations failed: $e');
    }
  }

  Future<void> _testSyncQueue() async {
    _addTestResult('🔄 Testing sync queue functionality...');
    
    try {
      // Check pending sync items
      final pendingItems = await _offlineDb.getPendingSyncItems(1);
      _addTestResult('✅ Found ${pendingItems.length} pending sync items');
      
      // Test sync queue operations
      if (pendingItems.isNotEmpty) {
        final firstItem = pendingItems.first;
        await _offlineDb.updateSyncQueueStatus(firstItem['id'], 'processing');
        _addTestResult('✅ Sync queue status update successful');
        
        await _offlineDb.incrementRetryCount(firstItem['id']);
        _addTestResult('✅ Retry count increment successful');
      }
      
    } catch (e) {
      _addTestResult('❌ Sync queue test failed: $e');
    }
  }

  Future<void> _testDataIntegrity() async {
    _addTestResult('🔒 Testing data integrity...');
    
    try {
      // Test hash generation
      final testData = {'name': 'Test', 'value': 123};
      final hash = _offlineDb.generateHash(testData);
      
      if (hash.isNotEmpty) {
        _addTestResult('✅ Hash generation successful');
      } else {
        _addTestResult('❌ Hash generation failed');
      }
      
      // Test soft delete
      final products = await _offlineDb.getProductsByBusiness(1);
      if (products.isNotEmpty) {
        await _offlineDb.markAsDeleted('products', products.first['id']);
        _addTestResult('✅ Soft delete functionality working');
      }
      
    } catch (e) {
      _addTestResult('❌ Data integrity test failed: $e');
    }
  }

  void _addTestResult(String result) {
    setState(() {
      _testResults.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Functionality Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runTests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Functionality Test Results',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Consumer<OfflineProvider>(
                  builder: (context, offlineProvider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connection: ${offlineProvider.isOnline ? "Online" : "Offline"}'),
                        Text('Sync Status: ${offlineProvider.syncStatus}'),
                        Text('Pending Items: ${offlineProvider.pendingSyncItems}'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Test results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _testResults.length,
                    itemBuilder: (context, index) {
                      final result = _testResults[index];
                      final isSuccess = result.contains('✅');
                      final isError = result.contains('❌');
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isSuccess ? Icons.check_circle : (isError ? Icons.error : Icons.info),
                            color: isSuccess ? Colors.green : (isError ? Colors.red : Colors.blue),
                          ),
                          title: Text(
                            result,
                            style: TextStyle(
                              color: isError ? Colors.red : null,
                              fontWeight: isSuccess || isError ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Test runner
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
      ],
      child: const MaterialApp(
        home: OfflineFunctionalityTest(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
} 