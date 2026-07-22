import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Displays real system-tray notifications for FCM messages that arrive while
/// the app is in the FOREGROUND (background/terminated messages with a
/// `notification` payload are shown by the OS automatically).
///
/// Android uses flutter_local_notifications with a dedicated high-importance
/// channel; iOS uses FCM's native foreground presentation (configured in
/// [NotificationService]) so banners are never duplicated.
class LocalNotificationsService {
  LocalNotificationsService._();
  static final LocalNotificationsService instance =
      LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  void Function(String? path)? _onOpen;

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'farvixo_general',
    'General',
    description: 'Product updates, tips and activity',
    importance: Importance.high,
  );

  Future<void> init({void Function(String? path)? onOpen}) async {
    if (_ready) return;
    _onOpen = onOpen;
    try {
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      // Permission is requested centrally after the splash screen — never
      // let the plugin trigger its own prompt here.
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: darwinInit),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          _onOpen?.call(
              (payload != null && payload.isNotEmpty) ? payload : null);
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      _ready = true;
    } catch (e) {
      debugPrint('LocalNotificationsService.init: $e');
    }
  }

  /// Show a tray notification for a foreground [RemoteMessage] (Android only —
  /// iOS banners come from FCM's native foreground presentation).
  Future<void> showRemoteMessage(RemoteMessage message) async {
    if (!_ready || kIsWeb || !Platform.isAndroid) return;
    final n = message.notification;
    final title = n?.title ?? message.data['title'] as String?;
    final body = n?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;
    final path = message.data['path'] as String? ??
        message.data['deep_link'] as String?;
    try {
      await _plugin.show(
        message.messageId?.hashCode ?? message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: path,
      );
    } catch (e) {
      debugPrint('LocalNotificationsService.show: $e');
    }
  }
}
