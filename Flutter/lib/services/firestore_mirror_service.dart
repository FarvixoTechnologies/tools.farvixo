import 'package:flutter/foundation.dart';

import '../data/repositories/firestore_mirror_repository.dart';
import '../models/user_model.dart';

/// Optional Firestore mirror of Supabase users — NOT auth source of truth.
class FirestoreMirrorService {
  FirestoreMirrorService._();
  static final FirestoreMirrorService instance = FirestoreMirrorService._();

  final FirestoreMirrorRepository _repo = FirestoreMirrorRepository();

  Future<void> upsertUser(AppUser user) async {
    if (user.isGuest) return;
    try {
      await _repo.upsertUser({
        'id': user.id,
        'email': user.email,
        'fullName': user.fullName,
        'avatarUrl': user.avatarUrl,
        'plan': user.plan,
        'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
        'source': 'supabase',
      });
    } catch (e) {
      debugPrint('FirestoreMirrorService.upsertUser: $e');
    }
  }

  Future<void> clearLastSeen(String userId) async {
    try {
      await _repo.patchUser(userId, {
        'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
        'loggedOut': true,
      });
    } catch (e) {
      debugPrint('FirestoreMirrorService.clearLastSeen: $e');
    }
  }
}
