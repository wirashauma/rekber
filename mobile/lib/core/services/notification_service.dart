import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String _vapidKey = 'BPxeOxcyPR9_YJJ7Tmi4-Bmjn-IDU2LhF8GQDIgljbO0JPemeEXhFGaiQysQ3aNAiv9hAUZhMIwfcL7BBI21tSE';

  void Function(String route)? onNavigateRequested;

  /// Pure helper to resolve target route from notification data payload
  static String? resolveRouteFromPayload(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;

    final disputeId = data['disputeId']?.toString();
    if (disputeId != null && disputeId.isNotEmpty) {
      return '/dispute/$disputeId';
    }

    final chatId = data['chatId']?.toString();
    if (chatId != null && chatId.isNotEmpty) {
      return '/chat/$chatId';
    }

    final transactionId = data['transactionId']?.toString();
    if (transactionId != null && transactionId.isNotEmpty) {
      final type = data['type']?.toString() ?? '';
      if (type.contains('CHAT')) {
        return '/chat/$transactionId';
      }
      return '/transaction/$transactionId';
    }

    return null;
  }

  Future<void> initialize({void Function(String route)? onNavigate}) async {
    if (onNavigate != null) {
      onNavigateRequested = onNavigate;
    }

    // Request permissions for push notifications
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(details.payload!) as Map<String, dynamic>;
            final route = resolveRouteFromPayload(data);
            if (route != null && onNavigateRequested != null) {
              onNavigateRequested!(route);
            }
          } catch (_) {}
        }
      },
    );

    // Create Android Notification Channel
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          const AndroidNotificationChannel channel = AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            description: 'This channel is used for important notifications.',
            importance: Importance.max,
          );

          await _localNotifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(channel);
        }
      } catch (_) {}
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle background/terminated message open
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final route = resolveRouteFromPayload(message.data);
      if (route != null && onNavigateRequested != null) {
        onNavigateRequested!(route);
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final RemoteNotification? notification = message.notification;
      final AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null && !kIsWeb) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          payload: jsonEncode(message.data),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'This channel is used for important notifications.',
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  }

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken(vapidKey: kIsWeb ? _vapidKey : null);
    } catch (_) {
      return null;
    }
  }

  Stream<String> get onTokenRefresh {
    try {
      return _fcm.onTokenRefresh;
    } catch (_) {
      return const Stream.empty();
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    if (kDebugMode) {
      print('Handling a background message: ${message.messageId}');
    }
  }
}
