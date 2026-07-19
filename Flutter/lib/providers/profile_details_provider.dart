import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_details.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
import 'language_provider.dart';

/// Extended editable profile fields for the signed-in (or guest) user.
final profileDetailsProvider =
    StateNotifierProvider<ProfileDetailsNotifier, ProfileDetails>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final user = ref.watch(authProvider);
  final lang = ref.watch(languageProvider);
  return ProfileDetailsNotifier(storage, user, lang);
});

class ProfileDetailsNotifier extends StateNotifier<ProfileDetails> {
  ProfileDetailsNotifier(this._storage, this._user, String langCode)
      : super(_load(_storage, _user, langCode));

  final StorageService _storage;
  final AppUser? _user;

  static ProfileDetails _load(
    StorageService storage,
    AppUser? user,
    String langCode,
  ) {
    final uid = user?.id ?? 'guest';
    final raw = storage.profileDetailsJson(uid);
    ProfileDetails base = ProfileDetails.empty();
    if (raw != null) {
      try {
        base = ProfileDetails.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    final display = base.displayName.isNotEmpty
        ? base.displayName
        : (user?.displayName ?? '');
    final username = base.username.isNotEmpty
        ? base.username
        : _defaultUsername(user);
    final language = base.language.isNotEmpty
        ? base.language
        : (supportedLanguages
                .where((l) => l.code == langCode)
                .map((l) => l.name)
                .firstOrNull ??
            'English');
    final timezone = base.timezone.isNotEmpty
        ? base.timezone
        : DateTime.now().timeZoneName;
    final avatar = base.avatarUrl ?? user?.avatarUrl;

    return base.copyWith(
      displayName: display,
      username: username,
      language: language,
      timezone: timezone,
      avatarUrl: avatar,
    );
  }

  static String _defaultUsername(AppUser? user) {
    if (user == null || user.isGuest) return 'guest';
    final base = (user.fullName ?? user.email.split('@').first)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return base.isEmpty ? 'user' : base;
  }

  Future<void> save(ProfileDetails next) async {
    final uid = _user?.id ?? 'guest';
    state = next;
    await _storage.setProfileDetailsJson(uid, jsonEncode(next.toJson()));
  }

  Future<void> patch(ProfileDetails Function(ProfileDetails) fn) async {
    await save(fn(state));
  }

  Future<void> removeAvatar() async {
    await save(state.copyWith(clearAvatar: true));
  }

  Future<void> removeCover() async {
    await save(state.copyWith(clearCover: true));
  }
}
