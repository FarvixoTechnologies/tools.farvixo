import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'supabase_service.dart';

/// Profile + avatar updates against `profiles` / `avatars` bucket.
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  bool get _ready {
    final client = SupabaseService.client;
    return client != null && client.auth.currentUser != null;
  }

  String? get _uid => SupabaseService.client?.auth.currentUser?.id;

  Future<AppUser?> updateProfile({String? fullName}) async {
    if (!_ready || fullName == null) return null;
    final uid = _uid!;
    final name = fullName.trim();
    if (name.isEmpty) return null;
    try {
      await SupabaseService.client!.from('profiles').update({
        'full_name': name,
      }).eq('id', uid);
      await SupabaseService.client!.auth.updateUser(
        UserAttributes(data: {'full_name': name}),
      );
      return _currentAsAppUser(fullName: name);
    } catch (e) {
      debugPrint('ProfileService.updateProfile failed: $e');
      rethrow;
    }
  }

  Future<String> uploadAvatar(File file) async {
    if (!_ready) {
      throw StateError('Sign in required to upload an avatar');
    }
    final uid = _uid!;
    final name = file.path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : 'jpg';
    final safeExt = (ext.isEmpty || ext.length > 5) ? 'jpg' : ext;
    final path = '$uid/avatar.$safeExt';
    try {
      final bytes = await file.readAsBytes();
      await SupabaseService.client!.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$safeExt',
            ),
          );
      final url =
          SupabaseService.client!.storage.from('avatars').getPublicUrl(path);
      final publicUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      await SupabaseService.client!.from('profiles').update({
        'avatar_url': publicUrl,
      }).eq('id', uid);
      await SupabaseService.client!.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );
      return publicUrl;
    } catch (e) {
      debugPrint('ProfileService.uploadAvatar failed: $e');
      rethrow;
    }
  }

  AppUser? _currentAsAppUser({String? fullName, String? avatarUrl}) {
    final u = SupabaseService.client?.auth.currentUser;
    if (u == null) return null;
    final meta = u.userMetadata ?? {};
    return AppUser(
      id: u.id,
      email: u.email ?? '',
      fullName: fullName ??
          (meta['full_name'] as String?) ??
          (meta['name'] as String?),
      avatarUrl: avatarUrl ??
          (meta['avatar_url'] as String?) ??
          (meta['picture'] as String?),
      plan: (meta['plan'] as String?) ?? 'free',
    );
  }
}
