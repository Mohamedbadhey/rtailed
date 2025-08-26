import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';

class SuccessUtils {
  /// Show a success message with QuickAlert
  static void showSuccessTick(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? title,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: title ?? 'Success!',
      text: message,
      confirmBtnText: 'OK',
      confirmBtnColor: Colors.green,
      showConfirmBtn: true,
      showCancelBtn: false,
      autoCloseDuration: duration,
    );
  }

  /// Show a success message with QuickAlert (shorter duration)
  static void showQuickSuccessTick(
    BuildContext context,
    String message, {
    String? title,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: title ?? 'Success!',
      text: message,
      confirmBtnText: 'OK',
      confirmBtnColor: Colors.green,
      showConfirmBtn: true,
      showCancelBtn: false,
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  /// Show a success message with QuickAlert (longer duration)
  static void showLongSuccessTick(
    BuildContext context,
    String message, {
    String? title,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: title ?? 'Success!',
      text: message,
      confirmBtnText: 'OK',
      confirmBtnColor: Colors.green,
      showConfirmBtn: true,
      showCancelBtn: false,
      autoCloseDuration: const Duration(seconds: 5),
    );
  }

  /// Show a success message with custom duration
  static void showCustomDurationSuccessTick(
    BuildContext context,
    String message,
    Duration duration, {
    String? title,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: title ?? 'Success!',
      text: message,
      confirmBtnText: 'OK',
      confirmBtnColor: Colors.green,
      showConfirmBtn: true,
      showCancelBtn: false,
      autoCloseDuration: duration,
    );
  }

  /// Show error message with QuickAlert
  static void showErrorTick(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? title,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.error,
      title: title ?? 'Error!',
      text: message,
      confirmBtnText: 'OK',
      confirmBtnColor: Colors.red,
      showConfirmBtn: true,
      showCancelBtn: false,
      autoCloseDuration: duration,
    );
  }

  /// Show warning message with QuickAlert
  static void showWarningTick(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? title,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.warning,
      title: title ?? 'Warning!',
      text: message,
      confirmBtnText: 'OK',
      confirmBtnColor: Colors.orange,
      showConfirmBtn: true,
      showCancelBtn: false,
      autoCloseDuration: duration,
    );
  }

  /// Show info message with QuickAlert
  static void showInfoTick(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? title,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.info,
      title: title ?? 'Information',
      text: message,
      confirmBtnText: 'OK',
      confirmBtnColor: Colors.blue,
      showConfirmBtn: true,
      showCancelBtn: false,
      autoCloseDuration: duration,
    );
  }

  /// Show success message for common POS operations
  static void showSaleSuccess(BuildContext context, String saleId) {
    showSuccessTick(
      context,
      'Sale completed successfully!\nSale ID: $saleId',
      duration: const Duration(seconds: 4),
      title: 'Sale Complete!',
    );
  }

  /// Show success message for product operations
  static void showProductSuccess(BuildContext context, String operation) {
    showSuccessTick(
      context,
      'Product $operation successfully!',
      title: 'Product $operation!',
    );
  }

  /// Show success message for customer operations
  static void showCustomerSuccess(BuildContext context, String operation) {
    showSuccessTick(
      context,
      'Customer $operation successfully!',
      title: 'Customer $operation!',
    );
  }

  /// Show success message for inventory operations
  static void showInventorySuccess(BuildContext context, String operation) {
    showSuccessTick(
      context,
      'Inventory $operation successfully!',
      title: 'Inventory $operation!',
    );
  }

  /// Show success message for payment operations
  static void showPaymentSuccess(BuildContext context, String operation) {
    showSuccessTick(
      context,
      'Payment $operation successfully!',
      title: 'Payment $operation!',
    );
  }

  /// Show success message for notification operations
  static void showNotificationSuccess(BuildContext context, String operation) {
    showSuccessTick(
      context,
      'Notification $operation successfully!',
      title: 'Notification $operation!',
    );
  }

  /// Show success message for business operations
  static void showBusinessSuccess(BuildContext context, String operation) {
    showSuccessTick(
      context,
      'Business $operation successfully!',
      title: 'Business $operation!',
    );
  }

  /// Show error message for common operations
  static void showOperationError(BuildContext context, String operation, String errorDetails) {
    showErrorTick(
      context,
      'Failed to $operation.\n\nError: $errorDetails',
      duration: const Duration(seconds: 5),
      title: 'Operation Failed',
    );
  }

  /// Show error message for product operations
  static void showProductError(BuildContext context, String operation, String errorDetails) {
    showErrorTick(
      context,
      'Product $operation failed.\n\nError: $errorDetails',
      duration: const Duration(seconds: 5),
      title: 'Product Operation Failed',
    );
  }

  /// Show error message for sale operations
  static void showSaleError(BuildContext context, String errorDetails) {
    showErrorTick(
      context,
      'Sale processing failed.\n\nError: $errorDetails',
      duration: const Duration(seconds: 5),
      title: 'Sale Failed',
    );
  }

  /// Show error message for payment operations
  static void showPaymentError(BuildContext context, String errorDetails) {
    showErrorTick(
      context,
      'Payment processing failed.\n\nError: $errorDetails',
      duration: const Duration(seconds: 5),
      title: 'Payment Failed',
    );
  }

  /// Show error message for notification operations
  static void showNotificationError(BuildContext context, String errorDetails) {
    showErrorTick(
      context,
      'Failed to send notification.\n\nError: $errorDetails',
      duration: const Duration(seconds: 5),
      title: 'Notification Failed',
    );
  }

  /// Show warning message for common operations
  static void showOperationWarning(BuildContext context, String operation, String warningDetails) {
    showWarningTick(
      context,
      'Warning: $operation\n\n$warningDetails',
      duration: const Duration(seconds: 4),
      title: 'Warning',
    );
  }

  /// Show info message for common operations
  static void showOperationInfo(BuildContext context, String operation, String infoDetails) {
    showInfoTick(
      context,
      '$operation\n\n$infoDetails',
      duration: const Duration(seconds: 4),
      title: 'Information',
    );
  }

  /// Generic method to show any type of message
  static void showMessage(
    BuildContext context,
    String message, {
    QuickAlertType messageType = QuickAlertType.success,
    Duration? duration,
    String? title,
  }) {
    final defaultDuration = duration ?? (messageType == QuickAlertType.error || messageType == QuickAlertType.warning 
        ? const Duration(seconds: 4) 
        : const Duration(seconds: 3));
    
    QuickAlert.show(
      context: context,
      type: messageType,
      title: title,
      text: message,
      confirmBtnText: 'OK',
      confirmBtnColor: _getColorForType(messageType),
      showConfirmBtn: true,
      showCancelBtn: false,
      autoCloseDuration: defaultDuration,
    );
  }

  /// Show confirmation dialog with Yes/No buttons
  static void showConfirm(
    BuildContext context,
    String message, {
    String? title,
    String confirmText = 'Yes',
    String cancelText = 'No',
    QuickAlertType messageType = QuickAlertType.warning,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    QuickAlert.show(
      context: context,
      type: messageType,
      title: title ?? 'Confirm',
      text: message,
      confirmBtnText: confirmText,
      cancelBtnText: cancelText,
      confirmBtnColor: _getColorForType(messageType),
      showConfirmBtn: true,
      showCancelBtn: true,
      onConfirmBtnTap: () {
        Navigator.pop(context);
        onConfirm?.call();
      },
      onCancelBtnTap: () {
        Navigator.pop(context);
        onCancel?.call();
      },
    );
  }

  /// Get appropriate color for each message type
  static Color _getColorForType(QuickAlertType type) {
    switch (type) {
      case QuickAlertType.success:
        return Colors.green;
      case QuickAlertType.error:
        return Colors.red;
      case QuickAlertType.warning:
        return Colors.orange;
      case QuickAlertType.info:
        return Colors.blue;
      case QuickAlertType.confirm:
        return Colors.blue;
      case QuickAlertType.loading:
        return Colors.blue;
      case QuickAlertType.custom:
        return Colors.blue;
    }
  }

  /// Show loading alert
  static void showLoading(
    BuildContext context, {
    String message = 'Loading...',
    String? title,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      title: title,
      text: message,
      showConfirmBtn: false,
      showCancelBtn: false,
    );
  }

  /// Hide loading alert
  static void hideLoading(BuildContext context) {
    Navigator.pop(context);
  }
}
