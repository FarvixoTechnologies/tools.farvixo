import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class MessagingRepository {
  FirebaseMessaging? _messaging;
  String? token;

  bool get _ready => Firebase.apps.isNotEmpty;

  FirebaseMessaging? get _msg {
    if (!_ready) return null;
    return _messaging ??= FirebaseMessaging.instance;
  }

  Future<NotificationSettings> requestPermission() async {
    final m = _msg;
    if (m == null) {
      return const NotificationSettings(
        authorizationStatus: AuthorizationStatus.notDetermined,
        alert: AppleNotificationSetting.disabled,
        announcement: AppleNotificationSetting.disabled,
        badge: AppleNotificationSetting.disabled,
        carPlay: AppleNotificationSetting.disabled,
        criticalAlert: AppleNotificationSetting.disabled,
        lockScreen: AppleNotificationSetting.disabled,
        notificationCenter: AppleNotificationSetting.disabled,
        showPreviews: AppleShowPreviewSetting.never,
        sound: AppleNotificationSetting.disabled,
        timeSensitive: AppleNotificationSetting.disabled,
        providesAppNotificationSettings: AppleNotificationSetting.disabled,
      );
    }
    return m.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  /// Current permission status without showing any system dialog.
  Future<NotificationSettings> settings() async {
    final m = _msg;
    if (m == null) {
      return const NotificationSettings(
        authorizationStatus: AuthorizationStatus.denied,
        alert: AppleNotificationSetting.disabled,
        announcement: AppleNotificationSetting.disabled,
        badge: AppleNotificationSetting.disabled,
        carPlay: AppleNotificationSetting.disabled,
        criticalAlert: AppleNotificationSetting.disabled,
        lockScreen: AppleNotificationSetting.disabled,
        notificationCenter: AppleNotificationSetting.disabled,
        showPreviews: AppleShowPreviewSetting.never,
        sound: AppleNotificationSetting.disabled,
        timeSensitive: AppleNotificationSetting.disabled,
        providesAppNotificationSettings: AppleNotificationSetting.disabled,
      );
    }
    return m.getNotificationSettings();
  }

  Future<String?> getToken() async {
    try {
      final m = _msg;
      if (m == null) return null;
      // Never let a stalled Play Services call hang the caller.
      token = await m.getToken().timeout(const Duration(seconds: 10));
      debugPrint(
          'FCM token: ${token != null ? '${token!.substring(0, 12)}…' : null}');
      return token;
    } catch (e) {
      debugPrint('MessagingRepository.getToken: $e');
      return null;
    }
  }

  Future<void> subscribe(String topic) async {
    try {
      final m = _msg;
      if (m == null) return;
      await m.subscribeToTopic(topic).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('MessagingRepository.subscribe($topic): $e');
    }
  }

  Future<void> unsubscribe(String topic) async {
    try {
      final m = _msg;
      if (m == null) return;
      await m.unsubscribeFromTopic(topic).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('MessagingRepository.unsubscribe($topic): $e');
    }
  }
}
