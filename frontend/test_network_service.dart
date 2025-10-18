import 'package:flutter/material.dart';
import 'package:retail_management/services/network_service.dart';

/// Simple test to verify network service is working
void main() {
  runApp(const NetworkServiceTestApp());
}

class NetworkServiceTestApp extends StatelessWidget {
  const NetworkServiceTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Service Test',
      home: const NetworkServiceTestScreen(),
    );
  }
}

class NetworkServiceTestScreen extends StatefulWidget {
  const NetworkServiceTestScreen({super.key});

  @override
  State<NetworkServiceTestScreen> createState() => _NetworkServiceTestScreenState();
}

class _NetworkServiceTestScreenState extends State<NetworkServiceTestScreen> {
  final NetworkService _networkService = NetworkService();
  String _status = 'Ready to test';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _networkService.startConnectivityMonitoring();
  }

  @override
  void dispose() {
    _networkService.stopConnectivityMonitoring();
    super.dispose();
  }

  Future<void> _testConnectivity() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing connectivity...';
    });

    try {
      final hasConnection = await _networkService.hasInternetConnection();
      setState(() {
        _status = hasConnection 
            ? '✅ Connected to internet' 
            : '❌ No internet connection';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Service Test'),
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
                      onPressed: _isLoading ? null : _testConnectivity,
                      child: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test Connectivity'),
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
                      '1. Click "Test Connectivity" to check internet connection\n'
                      '2. Turn off your internet and test again\n'
                      '3. Turn internet back on and test again\n'
                      '4. The status should update accordingly',
                      style: TextStyle(fontSize: 14),
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
}
