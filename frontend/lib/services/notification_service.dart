import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request notification permissions
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        if (status != PermissionStatus.granted) {
          print('🔔 Notification permission denied');
          return;
        }
      }

      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = true;
      print('🔔 Notification service initialized successfully');
    } catch (e) {
      print('🔔 Error initializing notification service: $e');
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.payload}');
    
    if (response.payload != null && response.payload!.isNotEmpty) {
      _openPdfFile(response.payload!);
    }
  }

  /// Open PDF file using system default app
  static Future<void> _openPdfFile(String filePath) async {
    try {
      print('🔔 Opening PDF file: $filePath');
      
      if (Platform.isAndroid) {
        // For Android, use file:// URI
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('🔔 PDF opened successfully');
        } else {
          print('🔔 Could not launch PDF file');
        }
      } else if (Platform.isIOS) {
        // For iOS, use file:// URI
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('🔔 PDF opened successfully');
        } else {
          print('🔔 Could not launch PDF file');
        }
      }
    } catch (e) {
      print('🔔 Error opening PDF file: $e');
    }
  }

  /// Show PDF download notification
  static Future<void> showPdfDownloadNotification({
    required String fileName,
    required String filePath,
    required String location,
  }) async {
    try {
      await initialize();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'pdf_downloads',
        'PDF Downloads',
        channelDescription: 'Notifications for downloaded PDF files',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        actions: [
          AndroidNotificationAction(
            'open',
            'Open PDF',
            icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          AndroidNotificationAction(
            'dismiss',
            'Dismiss',
            icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        ],
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Generate unique notification ID based on timestamp
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifications.show(
        notificationId,
        '📄 PDF Downloaded Successfully!',
        '$fileName has been saved to $location\nTap to open the PDF file',
        platformChannelSpecifics,
        payload: filePath, // Pass file path as payload
      );

      print('🔔 PDF download notification shown for: $fileName');
    } catch (e) {
      print('🔔 Error showing PDF download notification: $e');
    }
  }

  /// Show simple notification (fallback)
  static Future<void> showSimpleNotification({
    required String title,
    required String body,
  }) async {
    try {
      await initialize();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'general',
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifications.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
      );

      print('🔔 Simple notification shown: $title');
    } catch (e) {
      print('🔔 Error showing simple notification: $e');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('🔔 All notifications cancelled');
    } catch (e) {
      print('🔔 Error cancelling notifications: $e');
    }
  }

  /// Cancel specific notification
  static Future<void> cancelNotification(int notificationId) async {
    try {
      await _notifications.cancel(notificationId);
      print('🔔 Notification $notificationId cancelled');
    } catch (e) {
      print('🔔 Error cancelling notification $notificationId: $e');
    }
  }
}
