import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_provider.dart';
import '../services/profile_service.dart';
import '../services/supabase_service.dart';

/// Shared profile edit + avatar pick helpers for Settings / Profile screens.
Future<void> showEditProfileDialog(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider);
  if (user == null || user.isGuest) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to edit your profile')),
    );
    return;
  }
  if (SupabaseService.client == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile sync unavailable offline')),
    );
    return;
  }

  final controller = TextEditingController(text: user.fullName ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit Profile'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Full name',
          hintText: 'Your display name',
        ),
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (name == null || name.isEmpty || !context.mounted) return;

  try {
    final updated = await ProfileService.instance.updateProfile(fullName: name);
    if (updated != null) {
      await ref.read(authProvider.notifier).applyLocalUser(updated);
    } else {
      await ref.read(authProvider.notifier).applyLocalUser(
            user.copyWith(fullName: name),
          );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }
}

Future<void> pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider);
  if (user == null || user.isGuest) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to change your photo')),
    );
    return;
  }
  if (SupabaseService.client == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avatar upload unavailable offline')),
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
    final url = await ProfileService.instance.uploadAvatar(File(xfile.path));
    final next = user.copyWith(avatarUrl: url);
    await ref.read(authProvider.notifier).applyLocalUser(next);
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
