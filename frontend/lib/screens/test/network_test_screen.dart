import 'package:flutter/material.dart';
import 'package:retail_management/services/network_service.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/widgets/network_aware_widget.dart';

/// Test screen to demonstrate network error handling
class NetworkTestScreen extends StatefulWidget {
  const NetworkTestScreen({super.key});

  @override
  State<NetworkTestScreen> createState() => _NetworkTestScreenState();
}

class _NetworkTestScreenState extends State<NetworkTestScreen> with NetworkAwareMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String _status = 'Ready to test';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Error Handling Test'),
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
                      'Network Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _testConnection,
                      child: const Text('Test Connection'),
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
                      'API Tests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _testHealthCheck,
                            child: const Text('Health Check'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _testProducts,
                            child: const Text('Get Products'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _testLogin,
                            child: const Text('Test Login'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _testInvalidEndpoint,
                            child: const Text('Invalid Endpoint'),
                          ),
                        ),
                      ],
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
                      'Network Simulation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To test network error handling:\n'
                      '1. Turn off your internet connection\n'
                      '2. Try any of the API tests above\n'
                      '3. You should see "No internet connection" dialog\n'
                      '4. Turn internet back on and try again\n'
                      '5. You should see automatic retry behavior',
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
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing connection...';
    });

    try {
      final hasConnection = await NetworkService().hasInternetConnection();
      setState(() {
        _status = hasConnection 
            ? '✅ Connected to internet' 
            : '❌ No internet connection';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Connection test failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testHealthCheck() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing health check...';
    });

    await executeNetworkOperation(
      () async {
        final isHealthy = await _apiService.checkConnection(context: context);
        setState(() {
          _status = isHealthy 
              ? '✅ API is healthy' 
              : '❌ API is not responding';
        });
      },
      onRetry: _testHealthCheck,
      customErrorMessage: 'Health check failed',
    );

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testProducts() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing products API...';
    });

    await executeNetworkOperation(
      () async {
        final products = await _apiService.getProducts(context: context);
        setState(() {
          _status = '✅ Retrieved ${products.length} products';
        });
      },
      onRetry: _testProducts,
      customErrorMessage: 'Failed to load products',
    );

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing login API...';
    });

    await executeNetworkOperation(
      () async {
        try {
          await _apiService.login('test@example.com', 'password', context: context);
          setState(() {
            _status = '✅ Login API responded (credentials may be invalid)';
          });
        } catch (e) {
          // This is expected for invalid credentials
          setState(() {
            _status = '✅ Login API responded (invalid credentials as expected)';
          });
        }
      },
      onRetry: _testLogin,
      customErrorMessage: 'Login test failed',
    );

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testInvalidEndpoint() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing invalid endpoint...';
    });

    await executeNetworkOperation(
      () async {
        // This will trigger a network error
        await _apiService.checkConnection(context: context);
        setState(() {
          _status = '✅ Invalid endpoint test completed';
        });
      },
      onRetry: _testInvalidEndpoint,
      customErrorMessage: 'Invalid endpoint test failed',
    );

    setState(() {
      _isLoading = false;
    });
  }
}

/// Example of how to integrate network error handling in existing screens
class ExampleUsageScreen extends StatefulWidget {
  const ExampleUsageScreen({super.key});

  @override
  State<ExampleUsageScreen> createState() => _ExampleUsageScreenState();
}

class _ExampleUsageScreenState extends State<ExampleUsageScreen> with NetworkAwareMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    await executeNetworkOperation(
      () async {
        final products = await _apiService.getProducts(context: context);
        setState(() {
          _products = products;
        });
      },
      onRetry: _loadProducts,
      customErrorMessage: 'Failed to load products. Please try again.',
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Example Usage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadProducts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ListTile(
                  title: Text(product.name ?? 'Unknown'),
                  subtitle: Text('Price: \$${product.price ?? 0}'),
                );
              },
            ),
    );
  }
}
