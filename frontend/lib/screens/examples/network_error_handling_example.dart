import 'package:flutter/material.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/services/network_service.dart';
import 'package:retail_management/widgets/network_aware_widget.dart';
import 'package:retail_management/utils/success_utils.dart';

/// Example screen showing how to use network error handling with SuccessUtils
class NetworkErrorHandlingExample extends StatefulWidget {
  const NetworkErrorHandlingExample({super.key});

  @override
  State<NetworkErrorHandlingExample> createState() => _NetworkErrorHandlingExampleState();
}

class _NetworkErrorHandlingExampleState extends State<NetworkErrorHandlingExample> with NetworkAwareMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _products = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Error Handling Example'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Network Error Handling Examples',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loadProductsWithMixin,
                      child: const Text('Load Products (Using Mixin)'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loadProductsWithWidget,
                      child: const Text('Load Products (Using Widget)'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loadProductsWithDirectCall,
                      child: const Text('Load Products (Direct API Call)'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testLogin,
                      child: const Text('Test Login'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Turn off your internet connection\n'
                      '2. Try any of the buttons above\n'
                      '3. You should see "No Internet Connection" error using SuccessUtils\n'
                      '4. Turn internet back on and try again\n'
                      '5. You should see "Network is slow" warning if connection is poor',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_products.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Products Loaded',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              return ListTile(
                                title: Text(product.name ?? 'Unknown'),
                                subtitle: Text('Price: \$${product.price ?? 0}'),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Example 1: Using NetworkAwareMixin
  Future<void> _loadProductsWithMixin() async {
    setState(() {
      _isLoading = true;
    });

    await executeNetworkOperation(
      () async {
        final products = await _apiService.getProducts(context: context);
        setState(() {
          _products = products;
        });
        // Show success message using SuccessUtils
        if (mounted) {
          SuccessUtils.showProductSuccess(context, 'loaded');
        }
      },
      operation: 'load products',
      customErrorMessage: 'Failed to load products from server',
    );

    setState(() {
      _isLoading = false;
    });
  }

  /// Example 2: Using NetworkAwareWidget
  Future<void> _loadProductsWithWidget() async {
    setState(() {
      _isLoading = true;
    });

    await NetworkAwareWidget.executeWithErrorHandling(
      context,
      () async {
        final products = await _apiService.getProducts(context: context);
        setState(() {
          _products = products;
        });
        // Show success message using SuccessUtils
        if (mounted) {
          SuccessUtils.showProductSuccess(context, 'loaded');
        }
      },
      operation: 'load products',
      customErrorMessage: 'Failed to load products from server',
    );

    setState(() {
      _isLoading = false;
    });
  }

  /// Example 3: Direct API call with manual error handling
  Future<void> _loadProductsWithDirectCall() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _apiService.getProducts(context: context);
      setState(() {
        _products = products;
      });
      // Show success message using SuccessUtils
      if (mounted) {
        SuccessUtils.showProductSuccess(context, 'loaded');
      }
    } catch (e) {
      // Network errors are already handled by NetworkService
      // Only handle non-network errors here
      if (e is! NetworkException) {
        if (mounted) {
          SuccessUtils.showProductError(context, 'load', e.toString());
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Example 4: Login with network error handling
  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // This will fail with invalid credentials, but network errors are handled
      await _apiService.login('test@example.com', 'password', context: context);
      if (mounted) {
        SuccessUtils.showSuccessTick(context, 'Login successful!');
      }
    } catch (e) {
      // Network errors are already handled by NetworkService
      // Only handle non-network errors here
      if (e is! NetworkException) {
        if (mounted) {
          SuccessUtils.showOperationError(context, 'login', e.toString());
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

/// Example of how to integrate in existing screens
class ExistingScreenExample extends StatefulWidget {
  const ExistingScreenExample({super.key});

  @override
  State<ExistingScreenExample> createState() => _ExistingScreenExampleState();
}

class _ExistingScreenExampleState extends State<ExistingScreenExample> with NetworkAwareMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _data = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    await executeNetworkOperation(
      () async {
        final data = await _apiService.getProducts(context: context);
        setState(() {
          _data = data;
        });
      },
      operation: 'load data',
      customErrorMessage: 'Failed to load data from server',
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Existing Screen Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _data.length,
              itemBuilder: (context, index) {
                final item = _data[index];
                return ListTile(
                  title: Text(item.name ?? 'Unknown'),
                  subtitle: Text('Price: \$${item.price ?? 0}'),
                );
              },
            ),
    );
  }
}
