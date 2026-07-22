import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/messaging_repository.dart';
import '../firebase_options.dart';
import 'local_notifications_service.dart';
import 'notification_feed_service.dart';

/// Top-level background handler — must be a top-level or static function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background: ${message.messageId} ${message.data}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final MessagingRepository _repo = MessagingRepository();
  void Function(String? path)? _onOpen;

  String? get token => _repo.token;

  /// Wires up FCM handlers and (best-effort) token/topics WITHOUT showing
  /// the system permission dialog. The dialog is deferred to
  /// [requestPermissionIfNeeded], called once the splash screen has exited,
  /// so the very first thing a new user sees is never a permission prompt.
  Future<void> init({void Function(String? path)? onOpen}) async {
    _onOpen = onOpen;
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Real tray notifications for foreground messages: Android via
      // flutter_local_notifications, iOS via FCM's native presentation.
      await LocalNotificationsService.instance
          .init(onOpen: (path) => _onOpen?.call(path));
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('FCM foreground: ${msg.notification?.title}');
        LocalNotificationsService.instance.showRemoteMessage(msg);
        LocalNotificationStore.instance.addFromMessage(msg);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        // Arrived while backgrounded and was tapped — record as read.
        LocalNotificationStore.instance.addFromMessage(msg, read: true);
        _handleOpen(msg);
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await LocalNotificationStore.instance
            .addFromMessage(initial, read: true);
        _handleOpen(initial);
      }

      // Token + topic work without the runtime permission on Android (the
      // permission only gates *displaying* notifications). On iOS this may
      // fail before permission is granted — it is retried after the prompt.
      await _repo.getToken();
      await _repo.subscribe('all_users');
    } catch (e) {
      debugPrint('NotificationService.init: $e');
    }
  }

  /// Ask for notification permission only if the user has never been asked
  /// (status "not determined"). Called after the splash screen exits.
  /// Refreshes the token/topic afterwards so iOS registers correctly.
  Future<void> requestPermissionIfNeeded() async {
    try {
      // Firebase is initialized in main() before runApp. If it still isn't
      // ready after splash, give one short grace tick then skip quietly —
      // a long poll here leaves pending timers in widget tests and stalls
      // devices without Play Services.
      if (Firebase.apps.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (Firebase.apps.isEmpty) return;
      final settings = await _repo.settings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        await _repo.requestPermission();
      }
      await _repo.getToken();
      await _repo.subscribe('all_users');
    } catch (e) {
      debugPrint('NotificationService.requestPermissionIfNeeded: $e');
    }
  }

  void _handleOpen(RemoteMessage message) {
    final path = message.data['path'] as String? ??
        message.data['deep_link'] as String?;
    _onOpen?.call(path);
  }

  Future<void> syncPlanTopic(String plan) async {
    await _repo.unsubscribe('plan_free');
    await _repo.unsubscribe('plan_pro');
    await _repo.unsubscribe('plan_enterprise');
    final topic = plan == 'pro' || plan == 'enterprise'
        ? 'plan_pro'
        : 'plan_free';
    await _repo.subscribe(topic);
  }

  Future<void> clearTopics() async {
    await _repo.unsubscribe('all_users');
    await _repo.unsubscribe('plan_free');
    await _repo.unsubscribe('plan_pro');
    await _repo.unsubscribe('plan_enterprise');
  }
}
