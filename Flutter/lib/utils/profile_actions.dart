import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_provider.dart';
import '../providers/profile_details_provider.dart';
import '../services/profile_service.dart';
import '../services/supabase_service.dart';

/// Opens the full-screen Edit Profile editor (PROFILE_PAGE.md).
Future<void> showEditProfileDialog(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider);
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to edit your profile')),
    );
    return;
  }
  await context.push('/profile/edit');
}

Future<void> pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider);
  if (user == null || user.isGuest) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to change your photo')),
    );
    return;
  }

  final picker = ImagePicker();
  final xfile = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (xfile == null) return;

  try {
    String url = xfile.path;
    if (SupabaseService.client != null) {
      url = await ProfileService.instance.uploadAvatar(File(xfile.path));
    }
    final next = user.copyWith(avatarUrl: url);
    await ref.read(authProvider.notifier).applyLocalUser(next);
    await ref.read(profileDetailsProvider.notifier).patch(
          (d) => d.copyWith(avatarUrl: url),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }
}
