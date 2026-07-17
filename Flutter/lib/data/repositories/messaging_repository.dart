import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class MessagingRepository {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? token;

  Future<NotificationSettings> requestPermission() =>
      _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

  Future<String?> getToken() async {
    try {
      token = await _messaging.getToken();
      debugPrint('FCM token: ${token != null ? '${token!.substring(0, 12)}…' : null}');
      return token;
    } catch (e) {
      debugPrint('MessagingRepository.getToken: $e');
      return null;
    }
  }

  Future<void> subscribe(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('MessagingRepository.subscribe($topic): $e');
    }
  }

  Future<void> unsubscribe(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('MessagingRepository.unsubscribe($topic): $e');
    }
  }
}
