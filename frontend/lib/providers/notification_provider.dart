import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:retail_management/models/notification.dart';
import 'package:retail_management/utils/api.dart';
import 'package:retail_management/providers/auth_provider.dart';

class NotificationProvider with ChangeNotifier {
  final AuthProvider _authProvider;
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  NotificationProvider(this._authProvider);

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchMyNotifications({
    bool unreadOnly = false,
    String search = '',
    String type = '',
    String priority = '',
    String senderRole = '',
    String dateFrom = '',
    String dateTo = '',
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = _authProvider.token;
      if (token == null) throw Exception('No authentication token');

      // Build query parameters
      final queryParams = <String, String>{
        'unread_only': unreadOnly.toString(),
      };

      if (search.isNotEmpty) queryParams['search'] = search;
      if (type.isNotEmpty) queryParams['type'] = type;
      if (priority.isNotEmpty) queryParams['priority'] = priority;
      if (senderRole.isNotEmpty) queryParams['sender_role'] = senderRole;
      if (dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

      final uri = Uri.parse('${Api.baseUrl}/api/notifications/my').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notificationsList = data['notifications'] as List;
        
        _notifications = notificationsList.map((json) {
          try {
            return AppNotification.fromJson(json);
          } catch (e) {
            print('Error parsing notification: $e');
            print('Notification data: $json');
            // Return a default notification if parsing fails
            return AppNotification(
              id: json['id'] ?? 0,
              title: json['title'] ?? 'Error loading notification',
              message: json['message'] ?? 'Could not load notification content',
              type: json['type'] ?? 'error',
              priority: json['priority'] ?? 'medium',
              createdBy: json['created_by'] ?? 0,
              createdByName: json['created_by_name'],
              createdAt: DateTime.now(),
              updatedAt: null,
              isRead: json['is_read'] ?? false,
              readAt: null,
              parentId: json['parent_id'],
              direction: json['direction'],
            );
          }
        }).toList();
        
        _unreadCount = data['unread_count'] ?? 0;
      } else {
        throw Exception('Failed to fetch notifications');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final token = _authProvider.token;
      if (token == null) throw Exception('No authentication token');

      final response = await http.put(
        Uri.parse('${Api.baseUrl}/api/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Update local state
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          notifyListeners();
        }
      } else {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final token = _authProvider.token;
      if (token == null) throw Exception('No authentication token');

      final response = await http.put(
        Uri.parse('${Api.baseUrl}/api/notifications/read-all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Update local state
        _notifications = _notifications.map((notification) {
          if (!notification.isRead) {
            return notification.copyWith(
              isRead: true,
              readAt: DateTime.now(),
            );
          }
          return notification;
        }).toList();
        
        _unreadCount = 0;
        notifyListeners();
      } else {
        throw Exception('Failed to mark all notifications as read');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<List<AppNotification>> getThread(int notificationId) async {
    try {
      final token = _authProvider.token;
      if (token == null) throw Exception('No authentication token');

      final response = await http.get(
        Uri.parse('${Api.baseUrl}/api/notifications/$notificationId/thread'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final threadList = data['thread'] as List;
        
        return threadList.map((json) {
          try {
            return AppNotification.fromJson(json);
          } catch (e) {
            print('Error parsing thread notification: $e');
            return AppNotification(
              id: json['id'] ?? 0,
              title: json['title'] ?? 'Error loading notification',
              message: json['message'] ?? 'Could not load notification content',
              type: json['type'] ?? 'error',
              priority: json['priority'] ?? 'medium',
              createdBy: json['created_by'] ?? 0,
              createdByName: json['created_by_name'],
              createdAt: DateTime.now(),
              updatedAt: null,
              isRead: json['is_read'] ?? false,
              readAt: null,
              parentId: json['parent_id'],
              direction: json['direction'],
            );
          }
        }).toList();
      } else {
        throw Exception('Failed to fetch thread');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String message,
    String type = 'info',
    String priority = 'medium',
    List<int>? targetCashiers,
    List<int>? targetAdmins,
    int? parentId,
  }) async {
    try {
      final token = _authProvider.token;
      if (token == null) throw Exception('No authentication token');

      final Map<String, dynamic> body = {
        'title': title,
        'message': message,
        'type': type,
        'priority': priority,
      };

      if (parentId != null) {
        body['parent_id'] = parentId;
        print('=== FRONTEND DEBUG ===');
        print('Adding parent_id to request: $parentId (type: ${parentId.runtimeType})');
      }

      final userRole = _authProvider.user?.role;
      if (userRole == 'admin' || userRole == 'superadmin') {
        if (targetCashiers != null && targetCashiers.isNotEmpty) {
          body['target_cashiers'] = targetCashiers;
        }
      } else if (userRole == 'cashier') {
        // Optionally, allow specifying targetAdmins in the future
      }

      print('=== FRONTEND SEND NOTIFICATION ===');
      print('Request body: $body');
      print('Parent ID in body: ${body['parent_id']}');

      final response = await http.post(
        Uri.parse('${Api.baseUrl}/api/notifications/send'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to send notification');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCashiers() async {
    try {
      final token = _authProvider.token;
      if (token == null) throw Exception('No authentication token');

      final response = await http.get(
        Uri.parse('${Api.baseUrl}/api/notifications/cashiers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['cashiers'] ?? []);
      } else {
        throw Exception('Failed to fetch cashiers');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getNotificationStats() async {
    try {
      final token = _authProvider.token;
      if (token == null) throw Exception('No authentication token');

      final response = await http.get(
        Uri.parse('${Api.baseUrl}/api/notifications/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch notification stats');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }
} 