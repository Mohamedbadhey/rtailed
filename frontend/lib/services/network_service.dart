import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:retail_management/utils/success_utils.dart';

/// Network service that handles connectivity checking and error handling
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isConnected = true;
  Timer? _retryTimer;

  /// Check if device has internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      // Check connectivity status
      final connectivityResult = await _connectivity.checkConnectivity();
      
      // If no connectivity at all
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Try to reach a reliable endpoint to verify actual internet access
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        // If DNS lookup fails, try a simple HTTP request
        try {
          final response = await http.get(
            Uri.parse('https://httpbin.org/status/200'),
          ).timeout(const Duration(seconds: 5));
          return response.statusCode == 200;
        } catch (e) {
          return false;
        }
      }
    } catch (e) {
      return false;
    }
  }

  /// Start monitoring connectivity changes
  void startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _isConnected = result != ConnectivityResult.none;
      },
    );
  }

  /// Stop monitoring connectivity changes
  void stopConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
  }

  /// Get current connectivity status
  bool get isConnected => _isConnected;

  /// Execute HTTP request with network error handling and retry logic
  Future<http.Response> executeRequest(
    Future<http.Response> Function() request, {
    int maxRetries = 1,
    Duration retryDelay = const Duration(seconds: 2),
    BuildContext? context,
  }) async {
    // Check connectivity before making request
    if (!await hasInternetConnection()) {
      if (context != null) {
        _showNoInternetDialog(context);
      }
      throw NetworkException('No internet connection', NetworkErrorType.noConnection);
    }

    int attempts = 0;
    Exception? lastException;

    while (attempts <= maxRetries) {
      try {
        final response = await request();
        return response;
      } on SocketException catch (e) {
        lastException = e;
        if (attempts < maxRetries) {
          await Future.delayed(retryDelay);
          attempts++;
          continue;
        }
        
        if (context != null) {
          _showNetworkSlowDialog(context);
        }
        throw NetworkException('Network is slow. Please try again.', NetworkErrorType.slowNetwork);
      } on TimeoutException catch (e) {
        lastException = e;
        if (attempts < maxRetries) {
          await Future.delayed(retryDelay);
          attempts++;
          continue;
        }
        
        if (context != null) {
          _showNetworkSlowDialog(context);
        }
        throw NetworkException('Network is slow. Please try again.', NetworkErrorType.slowNetwork);
      } on HttpException catch (e) {
        lastException = e;
        if (attempts < maxRetries) {
          await Future.delayed(retryDelay);
          attempts++;
          continue;
        }
        
        if (context != null) {
          _showNetworkSlowDialog(context);
        }
        throw NetworkException('Network error occurred', NetworkErrorType.httpError);
      } catch (e) {
        lastException = e as Exception;
        if (attempts < maxRetries) {
          await Future.delayed(retryDelay);
          attempts++;
          continue;
        }
        
        if (context != null) {
          _showNetworkSlowDialog(context);
        }
        throw NetworkException('Network error occurred', NetworkErrorType.unknown);
      }
    }

    // This should never be reached, but just in case
    throw NetworkException('Network error occurred', NetworkErrorType.unknown);
  }

  /// Show no internet connection dialog using SuccessUtils
  void _showNoInternetDialog(BuildContext context) {
    SuccessUtils.showErrorTick(
      context,
      'No internet connection. Please check your connection and try again.',
      duration: const Duration(seconds: 5),
      title: 'No Internet Connection',
    );
  }

  /// Show network slow dialog using SuccessUtils
  void _showNetworkSlowDialog(BuildContext context) {
    SuccessUtils.showWarningTick(
      context,
      'Network is slow. Please try again.',
      duration: const Duration(seconds: 4),
      title: 'Network Issue',
    );
  }
}

/// Network exception class
class NetworkException implements Exception {
  final String message;
  final NetworkErrorType type;

  NetworkException(this.message, this.type);

  @override
  String toString() => message;
}

/// Network error types
enum NetworkErrorType {
  noConnection,
  slowNetwork,
  httpError,
  timeout,
  unknown,
}

/// Network error handler utility
class NetworkErrorHandler {
  /// Handle network errors and show appropriate messages using SuccessUtils
  static void handleError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    String? operation,
  }) {
    if (error is NetworkException) {
      switch (error.type) {
        case NetworkErrorType.noConnection:
          SuccessUtils.showErrorTick(
            context,
            'No internet connection. Please check your connection and try again.',
            duration: const Duration(seconds: 5),
            title: 'No Internet Connection',
          );
          break;
        case NetworkErrorType.slowNetwork:
        case NetworkErrorType.httpError:
        case NetworkErrorType.timeout:
          SuccessUtils.showWarningTick(
            context,
            'Network is slow. Please try again.',
            duration: const Duration(seconds: 4),
            title: 'Network Issue',
          );
          break;
        case NetworkErrorType.unknown:
          SuccessUtils.showOperationError(
            context,
            operation ?? 'operation',
            error.message,
          );
          break;
      }
    } else if (error is SocketException) {
      SuccessUtils.showWarningTick(
        context,
        'Network is slow. Please try again.',
        duration: const Duration(seconds: 4),
        title: 'Network Issue',
      );
    } else if (error is TimeoutException) {
      SuccessUtils.showWarningTick(
        context,
        'Network is slow. Please try again.',
        duration: const Duration(seconds: 4),
        title: 'Network Issue',
      );
    } else {
      SuccessUtils.showOperationError(
        context,
        operation ?? 'operation',
        'An unexpected error occurred',
      );
    }
  }

  static void _showNoInternetDialog(BuildContext context) {
    SuccessUtils.showErrorTick(
      context,
      'No internet connection. Please check your connection and try again.',
      duration: const Duration(seconds: 5),
      title: 'No Internet Connection',
    );
  }

  static void _showNetworkSlowDialog(BuildContext context, {VoidCallback? onRetry}) {
    SuccessUtils.showWarningTick(
      context,
      'Network is slow. Please try again.',
      duration: const Duration(seconds: 4),
      title: 'Network Issue',
    );
  }

  static void _showGenericErrorDialog(BuildContext context, String message, {VoidCallback? onRetry}) {
    SuccessUtils.showErrorTick(
      context,
      message,
      duration: const Duration(seconds: 4),
      title: 'Error',
    );
  }
}
