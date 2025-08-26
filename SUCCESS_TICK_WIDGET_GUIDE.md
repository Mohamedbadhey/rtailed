# QuickAlert Message System Guide

This guide documents the QuickAlert-based message system for the Retail Management POS application. The system provides beautiful, professional alert dialogs for success, error, warning, and info messages.

## 🚀 **Overview**

The message system uses the `quick_alert` package to display:
- **Success Messages** - Green alerts for successful operations
- **Error Messages** - Red alerts for failed operations
- **Warning Messages** - Orange alerts for warnings
- **Info Messages** - Blue alerts for informational content
- **Confirmation Dialogs** - Interactive dialogs with Yes/No options
- **Loading Alerts** - Animated loading indicators

## 📦 **Dependencies**

Add to your `pubspec.yaml`:
```yaml
dependencies:
  quickalert: ^1.1.0
```

## 🎯 **Key Features**

✅ **Professional Design** - Beautiful, modern alert dialogs  
✅ **Multiple Types** - Success, Error, Warning, Info, Loading  
✅ **Auto-dismiss** - Configurable duration with smart auto-close  
✅ **Custom Titles** - Each message can have custom titles  
✅ **Action Buttons** - OK/Cancel buttons with custom text  
✅ **Confirmation Dialogs** - Interactive Yes/No confirmations  
✅ **Loading States** - Animated loading indicators  
✅ **Consistent Styling** - Unified look across all message types  

## 🔧 **Basic Usage**

### 1. Success Messages

```dart
import 'package:retail_management/utils/success_utils.dart';

// Basic success message
SuccessUtils.showSuccessTick(context, 'Operation completed successfully!');

// Success with custom title
SuccessUtils.showSuccessTick(
  context, 
  'Product added successfully!',
  title: 'Product Added!'
);

// Success with custom duration
SuccessUtils.showSuccessTick(
  context, 
  'Data saved successfully!',
  duration: Duration(seconds: 5)
);
```

### 2. Error Messages

```dart
// Basic error message
SuccessUtils.showErrorTick(context, 'Operation failed!');

// Error with custom title
SuccessUtils.showErrorTick(
  context, 
  'Failed to save data. Please try again.',
  title: 'Save Failed'
);

// Error with custom duration
SuccessUtils.showErrorTick(
  context, 
  'Network connection failed.',
  duration: Duration(seconds: 6)
);
```

### 3. Warning Messages

```dart
// Basic warning message
SuccessUtils.showWarningTick(context, 'Please review your input.');

// Warning with custom title
SuccessUtils.showWarningTick(
  context, 
  'Low stock alert: Product running low.',
  title: 'Stock Warning'
);
```

### 4. Info Messages

```dart
// Basic info message
SuccessUtils.showInfoTick(context, 'System maintenance scheduled.');

// Info with custom title
SuccessUtils.showInfoTick(
  context, 
  'Your report is being generated.',
  title: 'Report Status'
);
```

## 🎨 **Advanced Usage**

### 1. Confirmation Dialogs

```dart
SuccessUtils.showConfirm(
  context,
  'Are you sure you want to delete this item?',
  title: 'Confirm Deletion',
  confirmText: 'Delete',
  cancelText: 'Cancel',
  onConfirm: () {
    // Handle confirmation
    print('User confirmed deletion');
  },
  onCancel: () {
    // Handle cancellation
    print('User cancelled deletion');
  },
);
```

### 2. Loading Alerts

```dart
// Show loading
SuccessUtils.showLoading(
  context,
  message: 'Processing your request...',
  title: 'Please Wait'
);

// Hide loading (usually after operation completes)
SuccessUtils.hideLoading(context);
```

### 3. Custom Duration Messages

```dart
// Quick success (2 seconds)
SuccessUtils.showQuickSuccessTick(context, 'Quick operation completed!');

// Long success (5 seconds)
SuccessUtils.showLongSuccessTick(context, 'Complex operation completed!');

// Custom duration
SuccessUtils.showCustomDurationSuccessTick(
  context, 
  'Custom duration message',
  Duration(seconds: 7)
);
```

## 🏪 **POS-Specific Utilities**

### 1. Sale Operations

```dart
// Sale completed successfully
SuccessUtils.showSaleSuccess(context, 'SALE-2024-001');

// Sale failed
SuccessUtils.showSaleError(context, 'Payment gateway timeout');
```

### 2. Product Operations

```dart
// Product added/updated
SuccessUtils.showProductSuccess(context, 'added');
SuccessUtils.showProductSuccess(context, 'updated');

// Product operation failed
SuccessUtils.showProductError(context, 'add', 'Database connection failed');
```

### 3. Customer Operations

```dart
// Customer operation success
SuccessUtils.showCustomerSuccess(context, 'created');
SuccessUtils.showCustomerSuccess(context, 'updated');

// Customer operation failed
SuccessUtils.showOperationError(context, 'create customer', 'Invalid email format');
```

### 4. Inventory Operations

```dart
// Inventory operation success
SuccessUtils.showInventorySuccess(context, 'updated');
SuccessUtils.showInventorySuccess(context, 'restocked');

// Inventory operation failed
SuccessUtils.showOperationError(context, 'update inventory', 'Stock quantity invalid');
```

### 5. Payment Operations

```dart
// Payment success
SuccessUtils.showPaymentSuccess(context, 'processed');

// Payment failed
SuccessUtils.showPaymentError(context, 'Card declined: Insufficient funds');
```

### 6. Notification Operations

```dart
// Notification sent/created
SuccessUtils.showNotificationSuccess(context, 'sent');
SuccessUtils.showNotificationSuccess(context, 'created');

// Notification failed
SuccessUtils.showNotificationError(context, 'Network connection failed');
```

### 7. Business Operations

```dart
// Business operation success
SuccessUtils.showBusinessSuccess(context, 'created');
SuccessUtils.showBusinessSuccess(context, 'updated');

// Business operation failed
SuccessUtils.showOperationError(context, 'update business', 'Invalid business details');
```

## 🔄 **Generic Message Display**

### 1. Any Message Type

```dart
import 'package:quickalert/quickalert.dart';

// Show any type of message
SuccessUtils.showMessage(
  context,
  'Your custom message here',
  messageType: QuickAlertType.success, // or error, warning, info
  title: 'Custom Title',
  duration: Duration(seconds: 4)
);
```

### 2. Direct QuickAlert Usage

```dart
import 'package:quickalert/quickalert.dart';

QuickAlert.show(
  context: context,
  type: QuickAlertType.success,
  title: 'Custom Title',
  text: 'Your message content here',
  confirmBtnText: 'OK',
  confirmBtnColor: Colors.green,
  showConfirmBtn: true,
  showCancelBtn: false,
  autoCloseDuration: Duration(seconds: 3),
);
```

## 🎭 **Message Types Reference**

| Type | Color | Icon | Use Case |
|------|-------|------|----------|
| `QuickAlertType.success` | Green | ✓ | Successful operations |
| `QuickAlertType.error` | Red | ✗ | Failed operations, errors |
| `QuickAlertType.warning` | Orange | ⚠ | Warnings, confirmations |
| `QuickAlertType.info` | Blue | ℹ | Information, status updates |
| `QuickAlertType.confirm` | Blue | ? | User confirmations |
| `QuickAlertType.loading` | Blue | ⟳ | Loading states |

## ⚙️ **Configuration Options**

### 1. Button Configuration

```dart
QuickAlert.show(
  context: context,
  type: QuickAlertType.success,
  title: 'Title',
  text: 'Message',
  confirmBtnText: 'OK',           // Custom confirm button text
  cancelBtnText: 'Cancel',        // Custom cancel button text
  confirmBtnColor: Colors.green,  // Custom confirm button color
  cancelBtnColor: Colors.grey,    // Custom cancel button color
  showConfirmBtn: true,           // Show/hide confirm button
  showCancelBtn: false,           // Show/hide cancel button
);
```

### 2. Timing Configuration

```dart
QuickAlert.show(
  context: context,
  type: QuickAlertType.success,
  title: 'Title',
  text: 'Message',
  autoCloseDuration: Duration(seconds: 5),  // Auto-close after 5 seconds
);
```

### 3. Callback Configuration

```dart
QuickAlert.show(
  context: context,
  type: QuickAlertType.confirm,
  title: 'Confirm',
  text: 'Are you sure?',
  onConfirmBtnTap: () {
    // Handle confirm button tap
    Navigator.pop(context);
    // Your logic here
  },
  onCancelBtnTap: () {
    // Handle cancel button tap
    Navigator.pop(context);
    // Your logic here
  },
);
```

## 🧪 **Testing and Demo**

Use the `MessageDemoWidget` to test all message types:

```dart
// Navigate to demo widget
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const MessageDemoWidget()),
);
```

The demo includes:
- All message types (Success, Error, Warning, Info)
- Confirmation dialogs
- Loading alerts
- Direct QuickAlert usage examples
- Real-world POS scenarios

## 🔄 **Migration from Custom Widget**

If you were using the previous custom `SuccessTickWidget`:

### Before (Custom Widget)
```dart
import '../widgets/success_tick_widget.dart';

SweetAlert.showSuccess(context, 'Message');
```

### After (QuickAlert)
```dart
import 'package:retail_management/utils/success_utils.dart';

SuccessUtils.showSuccessTick(context, 'Message');
```

## 🎨 **Customization**

### 1. Theme Colors

The system automatically uses appropriate colors for each message type:
- **Success**: Green (`Colors.green`)
- **Error**: Red (`Colors.red`)
- **Warning**: Orange (`Colors.orange`)
- **Info**: Blue (`Colors.blue`)

### 2. Button Styling

Buttons automatically inherit the message type color and can be customized:

```dart
QuickAlert.show(
  context: context,
  type: QuickAlertType.success,
  title: 'Title',
  text: 'Message',
  confirmBtnColor: Colors.deepPurple,  // Custom color
  confirmBtnText: 'Continue',          // Custom text
);
```

## 🚨 **Best Practices**

1. **Use Appropriate Types**: Match message type to content (success for success, error for errors)
2. **Clear Titles**: Provide descriptive titles that summarize the message
3. **Concise Content**: Keep message content clear and actionable
4. **Consistent Duration**: Use standard durations (3s for success, 4s for warnings/errors)
5. **User Actions**: Provide clear action buttons for confirmation dialogs
6. **Loading States**: Show loading for operations that take time
7. **Error Details**: Include helpful error information when possible

## 🔍 **Troubleshooting**

### Common Issues

1. **Package Not Found**
   ```bash
   flutter pub get
   ```

2. **Context Issues**
   - Ensure you have a valid `BuildContext`
   - Use `context.mounted` check for async operations

3. **Navigation Issues**
   - Always call `Navigator.pop(context)` in callbacks if needed
   - Handle context properly in async operations

## 📚 **Additional Resources**

- [QuickAlert Package Documentation](https://pub.dev/packages/quickalert)
- [Flutter Alert Dialogs](https://docs.flutter.dev/cookbook/design/alert-dialogs)
- [Material Design Guidelines](https://material.io/design/components/dialogs.html)

---

**Note**: This system provides a professional, consistent user experience across all POS operations. All existing success and error messages in the application have been updated to use this new system.
