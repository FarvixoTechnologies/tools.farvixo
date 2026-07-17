import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/messaging_repository.dart';
import '../firebase_options.dart';

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

  Future<void> init({void Function(String? path)? onOpen}) async {
    _onOpen = onOpen;
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _repo.requestPermission();
      await _repo.getToken();
      await _repo.subscribe('all_users');

      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('FCM foreground: ${msg.notification?.title}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleOpen(initial);
    } catch (e) {
      debugPrint('NotificationService.init: $e');
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
