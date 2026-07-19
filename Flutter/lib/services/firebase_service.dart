import '../core/firebase/firebase_bootstrap.dart';
import 'analytics_service.dart';

/// Compatibility facade — prefer [FirebaseBootstrap] for new code.
class FirebaseService {
  FirebaseService._();

  static bool get ready => FirebaseBootstrap.ready;

  static Future<void> init({
    void Function(String? path)? onNotificationOpen,
  }) =>
      FirebaseBootstrap.init(onNotificationOpen: onNotificationOpen);

  static Future<void> applyAnalyticsCollection(bool enabled) =>
      AnalyticsService.instance.setCollectionEnabled(enabled);
}
