import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_bootstrap.dart';
import '../services/analytics_service.dart';
import '../services/crashlytics_service.dart';
import '../services/firestore_mirror_service.dart';
import '../services/notification_service.dart';
import '../services/remote_config_service.dart';

final firebaseReadyProvider = Provider<bool>((ref) => FirebaseBootstrap.ready);

final analyticsServiceProvider =
    Provider<AnalyticsService>((ref) => AnalyticsService.instance);

final crashlyticsServiceProvider =
    Provider<CrashlyticsService>((ref) => CrashlyticsService.instance);

final remoteConfigServiceProvider =
    Provider<RemoteConfigService>((ref) => RemoteConfigService.instance);

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService.instance);

final firestoreMirrorServiceProvider =
    Provider<FirestoreMirrorService>((ref) => FirestoreMirrorService.instance);

final maintenanceModeProvider = Provider<bool>(
  (ref) => RemoteConfigService.instance.maintenanceMode,
);

final announcementBannerProvider = Provider<String>(
  (ref) => RemoteConfigService.instance.announcementBanner,
);
