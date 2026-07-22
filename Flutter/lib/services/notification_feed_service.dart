import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.type = 'system',
    required this.isRead,
    required this.createdAt,
    this.path,
  });

  final String id;
  final String title;
  final String? body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  /// Optional deep-link path carried by a push message.
  final String? path;

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      body: row['body'] as String?,
      type: row['type'] as String? ?? 'system',
      isRead: row['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      path: row['path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
        'path': path,
      };

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        path: path,
      );
}

/// On-device notification inbox — every push that reaches the device is
/// persisted here (SharedPreferences), so the bell shows REAL notifications
/// even before login and fully offline. Capped at the newest 50.
class LocalNotificationStore {
  LocalNotificationStore._();
  static final LocalNotificationStore instance = LocalNotificationStore._();

  static const _key = 'local_notifications_v1';
  static const _seededKey = 'local_notifications_seeded';
  static const _max = 50;

  final _controller = StreamController<List<AppNotification>>.broadcast();
  List<AppNotification> _items = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _items = [
          for (final e in (jsonDecode(raw) as List))
            AppNotification.fromRow(Map<String, dynamic>.from(e as Map)),
        ];
      }
      // One-time real welcome entry so a fresh install isn't empty.
      if (!(prefs.getBool(_seededKey) ?? false)) {
        if (_items.isEmpty) {
          _items = [
            AppNotification(
              id: 'welcome',
              title: 'Welcome to Farvixo! 👋',
              body:
                  'Explore 140+ tools and the AI Assistant — all in one app.',
              type: 'system',
              isRead: false,
              createdAt: DateTime.now(),
            ),
          ];
        }
        await prefs.setBool(_seededKey, true);
        await _persist(prefs);
      }
    } catch (e) {
      debugPrint('LocalNotificationStore.load: $e');
    }
    _loaded = true;
  }

  Future<void> _persist([SharedPreferences? prefs]) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(
          _key, jsonEncode([for (final n in _items) n.toJson()]));
    } catch (e) {
      debugPrint('LocalNotificationStore.persist: $e');
    }
  }

  void _emit() => _controller.add(List.unmodifiable(_items));

  /// Current items (loads first if needed) followed by every change.
  Stream<List<AppNotification>> stream() async* {
    await _ensureLoaded();
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  /// Record an incoming FCM message. De-duplicates on messageId.
  Future<void> addFromMessage(RemoteMessage message,
      {bool read = false}) async {
    await _ensureLoaded();
    final title = message.notification?.title ??
        message.data['title'] as String?;
    final body =
        message.notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;
    final id = message.messageId ??
        'push-${DateTime.now().millisecondsSinceEpoch}';
    if (_items.any((n) => n.id == id)) return;
    _items.insert(
      0,
      AppNotification(
        id: id,
        title: title ?? 'Farvixo',
        body: body,
        type: message.data['type'] as String? ?? 'push',
        isRead: read,
        createdAt: message.sentTime ?? DateTime.now(),
        path: message.data['path'] as String? ??
            message.data['deep_link'] as String?,
      ),
    );
    if (_items.length > _max) _items = _items.sublist(0, _max);
    await _persist();
    _emit();
  }

  Future<void> markRead(String id) async {
    await _ensureLoaded();
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0 || _items[idx].isRead) return;
    _items[idx] = _items[idx].copyWith(isRead: true);
    await _persist();
    _emit();
  }

  Future<void> markAllRead() async {
    await _ensureLoaded();
    _items = [for (final n in _items) n.copyWith(isRead: true)];
    await _persist();
    _emit();
  }
}

/// In-app notifications — merges the on-device inbox (real received pushes,
/// works logged-out and offline) with Supabase `notifications` rows when the
/// user is signed in.
class NotificationFeedService {
  NotificationFeedService._();
  static final NotificationFeedService instance = NotificationFeedService._();

  bool get _ready {
    final client = SupabaseService.client;
    return client != null && client.auth.currentUser != null;
  }

  String? get _uid => SupabaseService.client?.auth.currentUser?.id;

  Future<void> markRead(String id) async {
    await LocalNotificationStore.instance.markRead(id);
    if (!_ready) return;
    try {
      await SupabaseService.client!
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', _uid!);
    } catch (e) {
      debugPrint('NotificationFeed.markRead failed: $e');
    }
  }

  Future<void> markAllRead() async {
    await LocalNotificationStore.instance.markAllRead();
    if (!_ready) return;
    try {
      await SupabaseService.client!
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _uid!)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('NotificationFeed.markAllRead failed: $e');
    }
  }

  /// Live merged stream: local inbox always; Supabase rows joined in while
  /// signed in. Sorted newest-first, de-duplicated by id.
  Stream<List<AppNotification>> live() {
    final local = LocalNotificationStore.instance.stream();
    if (!_ready) return local;

    final controller = StreamController<List<AppNotification>>();
    var localItems = <AppNotification>[];
    var remoteItems = <AppNotification>[];

    void emit() {
      final seen = <String>{};
      final all = [
        for (final n in [...remoteItems, ...localItems])
          if (seen.add(n.id)) n,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) controller.add(all);
    }

    final subLocal = local.listen((v) {
      localItems = v;
      emit();
    });
    final subRemote = SupabaseService.client!
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid!)
        .order('created_at', ascending: false)
        .map((rows) => [
              for (final r in rows)
                AppNotification.fromRow(Map<String, dynamic>.from(r)),
            ])
        .listen(
      (v) {
        remoteItems = v;
        emit();
      },
      onError: (Object e) {
        debugPrint('NotificationFeed.live error: $e');
      },
    );

    controller.onCancel = () async {
      await subLocal.cancel();
      await subRemote.cancel();
    };
    return controller.stream;
  }
}

/// Live merged list (real device inbox + Supabase when signed in).
final notificationsListProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  return NotificationFeedService.instance.live();
});

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationsListProvider).maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
