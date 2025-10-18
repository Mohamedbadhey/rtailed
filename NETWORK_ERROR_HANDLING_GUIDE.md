# Network Error Handling Implementation Guide

## Overview

This implementation provides comprehensive network error handling for your Flutter retail management app. It includes:

- **Connectivity Detection**: Checks if the device has internet connection
- **Automatic Retry Logic**: Retries failed requests once with a 2-3 second delay
- **User-Friendly Error Messages**: Shows clear, actionable error dialogs
- **Global Application**: Works across all API requests in the app

## Key Features

### 1. Connectivity Checking
- Detects if device is connected to internet before making requests
- Uses multiple methods: connectivity status + actual internet reachability test
- Monitors connectivity changes in real-time

### 2. Error Handling
- **No Internet**: Shows "No internet connection. Please check your connection and try again."
- **Slow Network/Timeout**: Shows "Network is slow. Please try again."
- **Automatic Retry**: Retries once after 2-3 seconds before showing error message

### 3. User Experience
- Non-blocking error dialogs
- Retry buttons for user-initiated retries
- Clear, actionable error messages
- Consistent error handling across the app

## Implementation Details

### Files Created/Modified

1. **`lib/services/network_service.dart`** - Core network service
2. **`lib/services/api_service.dart`** - Updated to use network service
3. **`lib/providers/auth_provider.dart`** - Updated to pass context
4. **`lib/screens/auth/login_screen.dart`** - Updated to handle network errors
5. **`lib/main.dart`** - Initialize network service
6. **`lib/widgets/network_aware_widget.dart`** - Utility widgets and mixins
7. **`lib/screens/test/network_test_screen.dart`** - Test screen for demonstration

### Core Components

#### NetworkService Class
```dart
class NetworkService {
  // Check internet connectivity
  Future<bool> hasInternetConnection()
  
  // Execute request with error handling and retry
  Future<http.Response> executeRequest(
    Future<http.Response> Function() request, {
    int maxRetries = 1,
    Duration retryDelay = const Duration(seconds: 2),
    BuildContext? context,
  })
  
  // Start/stop connectivity monitoring
  void startConnectivityMonitoring()
  void stopConnectivityMonitoring()
}
```

#### NetworkException Class
```dart
class NetworkException implements Exception {
  final String message;
  final NetworkErrorType type;
}

enum NetworkErrorType {
  noConnection,
  slowNetwork,
  httpError,
  timeout,
  unknown,
}
```

## Usage Examples

### 1. Basic API Call with Error Handling

```dart
// In your screen/widget
Future<void> _loadData() async {
  try {
    final data = await _apiService.getProducts(context: context);
    // Handle successful response
  } catch (e) {
    // Network errors are automatically handled by NetworkService
    // Only handle non-network errors here
    if (e is! NetworkException) {
      // Show custom error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}
```

### 2. Using NetworkAwareMixin

```dart
class MyScreen extends StatefulWidget {
  @override
  _MyScreenState createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with NetworkAwareMixin {
  Future<void> _loadData() async {
    await executeNetworkOperation(
      () async {
        final data = await _apiService.getData(context: context);
        setState(() {
          // Update UI with data
        });
      },
      onRetry: _loadData,
      customErrorMessage: 'Failed to load data',
    );
  }
}
```

### 3. Using NetworkAwareWidget

```dart
NetworkAwareWidget.executeWithErrorHandling(
  context,
  () async {
    return await _apiService.getData(context: context);
  },
  onRetry: () {
    // Retry logic
  },
  customErrorMessage: 'Custom error message',
);
```

## Integration Steps

### 1. Update Existing API Calls

For any existing API calls, add the `context` parameter:

```dart
// Before
final products = await _apiService.getProducts();

// After
final products = await _apiService.getProducts(context: context);
```

### 2. Update Error Handling

Replace existing error handling with network-aware handling:

```dart
// Before
try {
  final data = await _apiService.getData();
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}

// After
try {
  final data = await _apiService.getData(context: context);
} catch (e) {
  if (e is! NetworkException) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### 3. Use Mixins for Complex Screens

For screens with multiple API calls, use the `NetworkAwareMixin`:

```dart
class InventoryScreen extends StatefulWidget {
  // ...
}

class _InventoryScreenState extends State<InventoryScreen> with NetworkAwareMixin {
  // All your existing methods can now use executeNetworkOperation
}
```

## Testing

### Manual Testing

1. **No Internet Connection**:
   - Turn off WiFi/mobile data
   - Try any API operation
   - Should see "No internet connection" dialog

2. **Slow Network**:
   - Use network throttling tools
   - Try API operations
   - Should see "Network is slow" dialog with retry option

3. **Server Errors**:
   - API returns error status codes
   - Should show appropriate error messages

### Automated Testing

Use the provided test screen (`NetworkTestScreen`) to test all scenarios:

```dart
// Add to your app routes
'/network-test': (context) => const NetworkTestScreen(),
```

## Error Message Customization

### Custom Error Messages

You can customize error messages for specific operations:

```dart
await executeNetworkOperation(
  () async {
    return await _apiService.getProducts(context: context);
  },
  customErrorMessage: 'Unable to load products. Please check your connection.',
);
```

### Global Error Handling

The system automatically handles:
- `SocketException` → "Network is slow. Please try again."
- `TimeoutException` → "Network is slow. Please try again."
- `HttpException` → "Network error occurred"
- No internet → "No internet connection. Please check your connection and try again."

## Performance Considerations

### Retry Logic
- Default: 1 retry with 2-second delay
- Configurable per request
- Exponential backoff can be added if needed

### Connectivity Monitoring
- Lightweight background monitoring
- Automatically started in `main.dart`
- Can be stopped when app is backgrounded

### Memory Usage
- Singleton pattern for NetworkService
- Minimal memory footprint
- Automatic cleanup of subscriptions

## Troubleshooting

### Common Issues

1. **Context Not Passed**:
   ```dart
   // Error: No context passed
   await _apiService.getProducts();
   
   // Fix: Pass context
   await _apiService.getProducts(context: context);
   ```

2. **Error Dialogs Not Showing**:
   - Ensure context is mounted
   - Check if NetworkService is initialized
   - Verify connectivity permissions

3. **Retry Not Working**:
   - Check if maxRetries > 0
   - Verify retryDelay is reasonable
   - Ensure network conditions improve

### Debug Information

Enable debug logging by checking console output:
- Network connectivity status
- Retry attempts
- Error types and messages
- Request/response details

## Future Enhancements

### Potential Improvements

1. **Exponential Backoff**: Implement exponential backoff for retries
2. **Offline Caching**: Cache responses for offline access
3. **Network Quality Detection**: Detect network quality and adjust behavior
4. **Custom Retry Strategies**: Different retry strategies per operation type
5. **Analytics**: Track network error patterns for optimization

### Configuration Options

```dart
// Future configuration options
NetworkService.configure(
  maxRetries: 2,
  retryDelay: Duration(seconds: 3),
  enableOfflineCaching: true,
  networkQualityThreshold: NetworkQuality.good,
);
```

## Conclusion

This network error handling implementation provides a robust, user-friendly solution for managing network issues in your Flutter app. It automatically handles common network problems while providing clear feedback to users and maintaining a smooth user experience.

The system is designed to be:
- **Non-intrusive**: Works automatically without changing existing code much
- **User-friendly**: Clear, actionable error messages
- **Reliable**: Handles edge cases and provides fallbacks
- **Maintainable**: Clean, well-documented code structure
- **Extensible**: Easy to add new features and customizations
