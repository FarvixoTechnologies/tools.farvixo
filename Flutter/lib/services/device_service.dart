import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';
import 'supabase_service.dart';

class UserDevice {
  const UserDevice({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.lastActive,
    required this.createdAt,
    required this.isCurrent,
  });

  final String id;
  final String? deviceName;
  final String? platform;
  final DateTime lastActive;
  final DateTime createdAt;
  final bool isCurrent;

  factory UserDevice.fromRow(Map<String, dynamic> row, String? currentId) {
    return UserDevice(
      id: row['id'] as String,
      deviceName: row['device_name'] as String?,
      platform: row['platform'] as String?,
      lastActive: DateTime.tryParse(row['last_active'] as String? ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      isCurrent: currentId != null && row['id'] == currentId,
    );
  }
}

/// Registers / lists / revokes rows in `user_devices`.
class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  final _deviceInfo = DeviceInfoPlugin();

  bool get _ready {
    final client = SupabaseService.client;
    return client != null && client.auth.currentUser != null;
  }

  String? get _uid => SupabaseService.client?.auth.currentUser?.id;

  Future<String> _ensureInstallKey(StorageService storage) async {
    final existing = storage.deviceInstallKey;
    if (existing != null && existing.isNotEmpty) return existing;
    final r = Random.secure();
    final key = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
    await storage.setDeviceInstallKey(key);
    return key;
  }

  Future<void> registerCurrentDevice({StorageService? storage}) async {
    if (!_ready || storage == null) return;
    final uid = _uid!;
    final platform = _platformLabel();
    final name = await _deviceName();
    final deviceKey = await _ensureInstallKey(storage);
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      // Prefer upsert on (user_id, device_key) — unique partial index in schema.
      final row = await SupabaseService.client!
          .from('user_devices')
          .upsert(
            {
              'user_id': uid,
              'device_key': deviceKey,
              'device_name': name,
              'platform': platform,
              'last_active': now,
            },
            onConflict: 'user_id,device_key',
          )
          .select('id')
          .maybeSingle();

      var id = row?['id'] as String?;

      // Fallback if partial unique / onConflict is unavailable on older DBs.
      if (id == null) {
        final existing = await SupabaseService.client!
            .from('user_devices')
            .select('id')
            .eq('user_id', uid)
            .eq('device_key', deviceKey)
            .maybeSingle();
        if (existing != null) {
          id = existing['id'] as String?;
          await SupabaseService.client!.from('user_devices').update({
            'device_name': name,
            'platform': platform,
            'last_active': now,
          }).eq('id', id!).eq('user_id', uid);
        } else {
          final inserted = await SupabaseService.client!
              .from('user_devices')
              .insert({
                'user_id': uid,
                'device_key': deviceKey,
                'device_name': name,
                'platform': platform,
                'last_active': now,
              })
              .select('id')
              .single();
          id = inserted['id'] as String?;
        }
      }

      if (id != null) {
        await storage.setCurrentDeviceRowId(id);
      }
    } catch (e) {
      debugPrint('DeviceService.registerCurrentDevice failed: $e');
    }
  }

  Future<List<UserDevice>> list({StorageService? storage}) async {
    if (!_ready) return const [];
    try {
      final rows = await SupabaseService.client!
          .from('user_devices')
          .select()
          .eq('user_id', _uid!)
          .order('last_active', ascending: false);
      final currentId = storage?.currentDeviceRowId;
      return (rows as List)
          .map((r) =>
              UserDevice.fromRow(Map<String, dynamic>.from(r as Map), currentId))
          .toList();
    } catch (e) {
      debugPrint('DeviceService.list failed: $e');
      return const [];
    }
  }

  Future<void> revoke(String deviceId, {StorageService? storage}) async {
    if (!_ready) return;
    try {
      await SupabaseService.client!
          .from('user_devices')
          .delete()
          .eq('id', deviceId)
          .eq('user_id', _uid!);
      if (storage?.currentDeviceRowId == deviceId) {
        await storage?.setCurrentDeviceRowId(null);
      }
    } catch (e) {
      debugPrint('DeviceService.revoke failed: $e');
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  Future<String> _deviceName() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = await _deviceInfo.androidInfo;
        return '${a.brand} ${a.model}'.trim();
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await _deviceInfo.iosInfo;
        return i.name;
      }
      if (defaultTargetPlatform == TargetPlatform.windows) {
        final w = await _deviceInfo.windowsInfo;
        return w.computerName;
      }
    } catch (e) {
      debugPrint('DeviceService._deviceName: $e');
    }
    return '${_platformLabel()} device';
  }
}
