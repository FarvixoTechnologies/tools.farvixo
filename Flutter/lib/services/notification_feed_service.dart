import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_service.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.type = 'system',
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      body: row['body'] as String?,
      type: row['type'] as String? ?? 'system',
      isRead: row['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// In-app notifications from Supabase `notifications` (+ offline demo fallback).
class NotificationFeedService {
  NotificationFeedService._();
  static final NotificationFeedService instance = NotificationFeedService._();

  bool get _ready {
    final client = SupabaseService.client;
    return client != null && client.auth.currentUser != null;
  }

  String? get _uid => SupabaseService.client?.auth.currentUser?.id;

  Future<List<AppNotification>> list() async {
    if (!_ready) return _fallback;
    try {
      final rows = await SupabaseService.client!
          .from('notifications')
          .select()
          .eq('user_id', _uid!)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .map((r) => AppNotification.fromRow(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('NotificationFeed.list failed: $e');
      return _fallback;
    }
  }

  Future<int> unreadCount() async {
    if (!_ready) {
      return _fallback.where((n) => !n.isRead).length;
    }
    try {
      final rows = await SupabaseService.client!
          .from('notifications')
          .select('id')
          .eq('user_id', _uid!)
          .eq('is_read', false);
      return (rows as List).length;
    } catch (e) {
      debugPrint('NotificationFeed.unreadCount failed: $e');
      return 0;
    }
  }

  Future<void> markRead(String id) async {
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

  /// Realtime stream of notification rows for the current user.
  Stream<List<AppNotification>> live() {
    if (!_ready) {
      return Stream.value(_fallback);
    }
    final uid = _uid!;
    return SupabaseService.client!
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((rows) {
      return rows
          .map((r) => AppNotification.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    }).handleError((e) {
      debugPrint('NotificationFeed.live error: $e');
    });
  }

  static final _fallback = [
    AppNotification(
      id: 'local-welcome',
      title: 'Welcome to Farvixo!',
      body: 'Explore 120+ tools and the AI Assistant — all in one app.',
      type: 'system',
      isRead: false,
      createdAt: DateTime.now(),
    ),
    AppNotification(
      id: 'local-ai',
      title: 'AI Assistant is ready',
      body: 'Ask anything — write, summarize, translate and more.',
      type: 'ai',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];
}

/// Live list (realtime when signed in; static fallback offline).
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
