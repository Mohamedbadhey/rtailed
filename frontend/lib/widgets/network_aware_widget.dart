import 'package:flutter/material.dart';
import 'package:retail_management/services/network_service.dart';
import 'package:retail_management/utils/success_utils.dart';

/// A utility widget that provides network-aware operations
class NetworkAwareWidget extends StatelessWidget {
  final Widget child;
  final Future<void> Function()? onRetry;
  final String? retryMessage;

  const NetworkAwareWidget({
    super.key,
    required this.child,
    this.onRetry,
    this.retryMessage,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }

  /// Execute a network operation with error handling
  static Future<T?> executeWithErrorHandling<T>(
    BuildContext context,
    Future<T> Function() operation, {
    VoidCallback? onRetry,
    String? customErrorMessage,
    String? operation,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (e is NetworkException) {
        // Network errors are already handled by NetworkService
        return null;
      } else {
        // Show custom error for non-network errors using SuccessUtils
        if (context.mounted) {
          SuccessUtils.showOperationError(
            context,
            operation ?? 'operation',
            customErrorMessage ?? e.toString(),
          );
        }
        return null;
      }
    }
  }

  static void _showErrorDialog(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            if (onRetry != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                child: const Text('Retry'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

/// A mixin that provides network-aware functionality to StatefulWidgets
mixin NetworkAwareMixin<T extends StatefulWidget> on State<T> {
  /// Execute a network operation with automatic error handling
  Future<R?> executeNetworkOperation<R>(
    Future<R> Function() operation, {
    VoidCallback? onRetry,
    String? customErrorMessage,
    String? operation,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (e is NetworkException) {
        // Network errors are already handled by NetworkService
        return null;
      } else {
        // Show custom error for non-network errors using SuccessUtils
        if (mounted) {
          SuccessUtils.showOperationError(
            context,
            operation ?? 'operation',
            customErrorMessage ?? e.toString(),
          );
        }
        return null;
      }
    }
  }

  void _showErrorDialog(
    String message, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            if (onRetry != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                child: const Text('Retry'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

/// Example usage in a screen:
/// 
/// ```dart
/// class MyScreen extends StatefulWidget {
///   @override
///   _MyScreenState createState() => _MyScreenState();
/// }
/// 
/// class _MyScreenState extends State<MyScreen> with NetworkAwareMixin {
///   Future<void> _loadData() async {
///     await executeNetworkOperation(
///       () async {
///         // Your network operation here
///         final data = await apiService.getData();
///         setState(() {
///           // Update UI with data
///         });
///       },
///       onRetry: _loadData,
///       customErrorMessage: 'Failed to load data',
///     );
///   }
/// }
/// ```
