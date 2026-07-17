import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreMirrorRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> upsertUser(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return;
    try {
      await _db.collection('users').doc(id).set(
        {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FirestoreMirrorRepository.upsertUser: $e');
      rethrow;
    }
  }

  Future<void> patchUser(String userId, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(userId).set(
        {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FirestoreMirrorRepository.patchUser: $e');
      rethrow;
    }
  }
}
