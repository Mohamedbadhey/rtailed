# Network Error Handling with SuccessUtils Integration Guide

## Overview

This implementation integrates network error handling with your existing `SuccessUtils` to provide consistent error messaging across your app. Instead of showing cryptic `ClientException` errors, users will see clear, actionable messages using your existing QuickAlert dialogs.

## Key Features

### ✅ **Integrated with SuccessUtils**
- Uses your existing `SuccessUtils.showErrorTick()` for network errors
- Uses `SuccessUtils.showWarningTick()` for slow network issues
- Uses `SuccessUtils.showOperationError()` for custom error messages
- Maintains consistent UI/UX with your existing error handling

### ✅ **Smart Error Detection**
- **No Internet**: Shows "No internet connection. Please check your connection and try again."
- **Slow Network**: Shows "Network is slow. Please try again."
- **ClientException**: Automatically converted to user-friendly messages
- **Timeout**: Handled gracefully with retry options

### ✅ **Automatic Retry Logic**
- Retries failed requests once after 2-3 seconds
- Only shows error dialog after retry fails
- User can manually retry if needed

## How It Works

### **Before (ClientException Error):**
```
ClientException: Failed to fetch, uri=https://rtailed-production.up.railway.app/api/auth/login
```

### **After (User-Friendly Message):**
```
"No Internet Connection" dialog with:
"No internet connection. Please check your connection and try again."
```

## Usage Examples

### **1. Simple API Call (Automatic Error Handling)**
```dart
// Just add context parameter - everything else is automatic!
try {
  final products = await _apiService.getProducts(context: context);
  // Handle success
} catch (e) {
  // Network errors are handled automatically
  // Only handle non-network errors here
  if (e is! NetworkException) {
    SuccessUtils.showOperationError(context, 'load products', e.toString());
  }
}
```

### **2. Login with Network Error Handling**
```dart
Future<void> _login() async {
  try {
    await context.read<AuthProvider>().loginWithIdentifier(
      username,
      password,
      context: context, // This enables network error handling
    );
    // Login successful
  } catch (e) {
    // Network errors are handled automatically
    // Only handle non-network errors here
    if (e is! NetworkException) {
      SuccessUtils.showOperationError(context, 'login', e.toString());
    }
  }
}
```

### **3. Using NetworkAwareMixin (Recommended for Complex Screens)**
```dart
class InventoryScreen extends StatefulWidget {
  // ...
}

class _InventoryScreenState extends State<InventoryScreen> with NetworkAwareMixin {
  Future<void> _loadProducts() async {
    await executeNetworkOperation(
      () async {
        final products = await _apiService.getProducts(context: context);
        setState(() {
          // Update UI with products
        });
        // Show success message
        SuccessUtils.showProductSuccess(context, 'loaded');
      },
      operation: 'load products',
      customErrorMessage: 'Failed to load products from server',
    );
  }
}
```

### **4. Using NetworkAwareWidget**
```dart
await NetworkAwareWidget.executeWithErrorHandling(
  context,
  () async {
    final data = await _apiService.getData(context: context);
    // Handle success
  },
  operation: 'load data',
  customErrorMessage: 'Failed to load data from server',
);
```

## Integration Steps

### **Step 1: Update Existing API Calls**
For any existing API calls, add the `context` parameter:

```dart
// Before
final products = await _apiService.getProducts();

// After
final products = await _apiService.getProducts(context: context);
```

### **Step 2: Update Error Handling**
Replace existing error handling with network-aware handling:

```dart
// Before
try {
  final data = await _apiService.getData();
} catch (e) {
  SuccessUtils.showOperationError(context, 'operation', e.toString());
}

// After
try {
  final data = await _apiService.getData(context: context);
} catch (e) {
  // Network errors are handled automatically
  // Only handle non-network errors here
  if (e is! NetworkException) {
    SuccessUtils.showOperationError(context, 'operation', e.toString());
  }
}
```

### **Step 3: Use Mixins for Complex Screens**
For screens with multiple API calls, use the `NetworkAwareMixin`:

```dart
class MyScreen extends StatefulWidget {
  // ...
}

class _MyScreenState extends State<MyScreen> with NetworkAwareMixin {
  // All your existing methods can now use executeNetworkOperation
}
```

## Error Message Types

### **Network Errors (Handled Automatically)**
- **No Internet**: `SuccessUtils.showErrorTick()` with "No Internet Connection" title
- **Slow Network**: `SuccessUtils.showWarningTick()` with "Network Issue" title
- **Timeout**: `SuccessUtils.showWarningTick()` with "Network Issue" title
- **ClientException**: `SuccessUtils.showWarningTick()` with "Network Issue" title

### **Application Errors (Handle Manually)**
- **Invalid Credentials**: `SuccessUtils.showOperationError()` with custom message
- **Server Errors**: `SuccessUtils.showOperationError()` with custom message
- **Validation Errors**: `SuccessUtils.showOperationError()` with custom message

## Testing

### **Manual Testing Steps:**
1. **Turn off internet** → Try any API operation → Should see "No Internet Connection" error using SuccessUtils
2. **Turn internet back on** → Try again → Should work normally
3. **Use slow network** → Try API operations → Should see "Network Issue" warning
4. **Test retry functionality** → Should automatically retry once before showing error

### **Test Screen:**
Use the example screen at `lib/screens/examples/network_error_handling_example.dart` to test all scenarios.

## Benefits

### **For Users:**
- **Clear Messages**: No more cryptic `ClientException` errors
- **Actionable Guidance**: Know exactly what to do (check connection, try again)
- **Consistent Experience**: Same error style across the entire app
- **Automatic Recovery**: App tries to recover automatically

### **For Developers:**
- **Minimal Changes**: Just add `context` parameter to existing API calls
- **Consistent Error Handling**: Same pattern across all screens
- **Easy Integration**: Works with existing SuccessUtils
- **Maintainable**: Centralized network error handling

## Common Patterns

### **Pattern 1: Simple API Call**
```dart
try {
  final result = await _apiService.method(context: context);
  // Handle success
} catch (e) {
  if (e is! NetworkException) {
    SuccessUtils.showOperationError(context, 'operation', e.toString());
  }
}
```

### **Pattern 2: With Success Message**
```dart
try {
  final result = await _apiService.method(context: context);
  SuccessUtils.showSuccessTick(context, 'Operation completed successfully!');
} catch (e) {
  if (e is! NetworkException) {
    SuccessUtils.showOperationError(context, 'operation', e.toString());
  }
}
```

### **Pattern 3: Using Mixin**
```dart
await executeNetworkOperation(
  () async {
    final result = await _apiService.method(context: context);
    SuccessUtils.showSuccessTick(context, 'Operation completed!');
  },
  operation: 'operation name',
  customErrorMessage: 'Custom error message',
);
```

## Migration Guide

### **For Existing Screens:**
1. **Add context parameter** to all API service calls
2. **Update error handling** to check for `NetworkException`
3. **Test with no internet** to verify error messages
4. **Consider using NetworkAwareMixin** for complex screens

### **For New Screens:**
1. **Use NetworkAwareMixin** for easy network error handling
2. **Pass context** to all API service methods
3. **Follow the patterns** shown in examples
4. **Test network scenarios** during development

## Conclusion

This implementation provides a seamless integration between network error handling and your existing SuccessUtils, ensuring users get clear, actionable error messages instead of cryptic technical errors. The system automatically handles network issues while allowing you to maintain control over application-specific error handling.

The result is a better user experience with minimal changes to your existing codebase.
