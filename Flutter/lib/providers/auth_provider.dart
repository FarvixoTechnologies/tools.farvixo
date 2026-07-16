import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/biometric_service.dart';
import '../services/secure_storage_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import 'app_providers.dart';

/// Thrown with a user-friendly message when authentication fails.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

final biometricServiceProvider =
    Provider<BiometricService>((ref) => BiometricService());

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier(
    ref.watch(storageServiceProvider),
    ref.watch(secureStorageProvider),
  );
});

/// Authentication — Supabase when configured (same project as Next.js).
/// Guest + biometric quick-unlock remain local.
class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier(this._storage, this._secure) : super(null) {
    _restore();
    _bindAuthListener();
  }

  final StorageService _storage;
  final SecureStorageService _secure;
  StreamSubscription<AuthState>? _authSub;

  void _bindAuthListener() {
    final client = SupabaseService.client;
    if (client == null) return;
    _authSub = client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session == null) {
        // Preserve guest / don't clear biometric vault on remote sign-out race.
        if (state != null && !state!.isGuest) {
          await _clearLocalSession(keepBiometric: true);
          if (mounted) state = null;
        }
        return;
      }
      final user = _mapUser(session.user);
      await _persistSession(user, session, provider: 'supabase');
    });
  }

  // ------------------------------------------------------------ session

  Future<void> _restore() async {
    final client = SupabaseService.client;
    if (client != null) {
      final session = client.auth.currentSession;
      if (session != null) {
        final user = _mapUser(session.user);
        await _persistSession(user, session, provider: 'supabase');
        return;
      }
    }

    final json = _storage.userJson;
    if (json == null) return;
    try {
      final user = AppUser.fromJson(jsonDecode(json) as Map<String, dynamic>);
      if (user.isGuest) {
        if (mounted) state = user;
        return;
      }
      // Stale non-guest without Supabase session → clear.
      if (client != null) {
        await _storage.clearUser();
        return;
      }
      if (mounted) state = user;
    } catch (_) {
      await _storage.clearUser();
    }
  }

  AppUser _mapUser(User user) {
    final meta = user.userMetadata ?? {};
    final fullName = (meta['full_name'] as String?) ??
        (meta['name'] as String?) ??
        (meta['display_name'] as String?);
    final avatar = (meta['avatar_url'] as String?) ??
        (meta['picture'] as String?);
    final plan = (meta['plan'] as String?) ?? 'free';
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      fullName: fullName,
      avatarUrl: avatar,
      plan: plan,
    );
  }

  Future<void> _persistSession(
    AppUser user,
    Session? session, {
    required String provider,
  }) async {
    if (session != null) {
      await _secure.setAccessToken(session.accessToken);
      await _secure.setRefreshToken(session.refreshToken ?? '');
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        await _secure.setSessionExpiry(
          DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
        );
      }
    }
    await _secure.setUserId(user.id);
    await _secure.setLoginProvider(provider);
    final json = jsonEncode(user.toJson());
    await _storage.setUserJson(json);
    if (!user.isGuest) await _secure.setLastUserJson(json);
    if (mounted) state = user;
    _logEvent('login_success', provider);
  }

  Future<void> _clearLocalSession({required bool keepBiometric}) async {
    final last = keepBiometric ? await _secure.lastUserJson : null;
    final bio = keepBiometric && await _secure.biometricEnabled;
    await _storage.clearUser();
    await _secure.clearAll();
    if (last != null) await _secure.setLastUserJson(last);
    if (bio) await _secure.setBiometricEnabled(true);
  }

  void _requireSupabase() {
    if (!SupabaseService.isAvailable || SupabaseService.client == null) {
      throw const AuthException(
        'Sign-in is unavailable. Add SUPABASE_URL and SUPABASE_ANON_KEY to Flutter/.env',
      );
    }
  }

  String _authErrorMessage(Object e) {
    if (e is AuthException) return e.message;
    if (e is AuthApiException) return e.message;
    final s = e.toString();
    if (s.contains('Invalid login credentials')) {
      return 'Invalid email or password.';
    }
    return s.replaceFirst('Exception: ', '');
  }

  // ------------------------------------------------------- email & phone

  Future<void> signIn(
    String email,
    String password, {
    bool rememberMe = true,
  }) async {
    _logEvent('login_started', 'email');
    _requireSupabase();
    try {
      final res = await SupabaseService.client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.session == null || res.user == null) {
        throw const AuthException('Sign-in failed. Please try again.');
      }
      await _persistSession(
        _mapUser(res.user!),
        res.session,
        provider: 'email',
      );
    } catch (e) {
      _logEvent('login_failed', 'email');
      throw AuthException(_authErrorMessage(e));
    }
  }

  Future<void> signUp(String name, String email, String password) async {
    _logEvent('login_started', 'signup');
    _requireSupabase();
    try {
      final res = await SupabaseService.client!.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': name.trim()},
        emailRedirectTo: kIsWeb ? null : AppConfig.authRedirectUrl,
      );
      if (res.user == null) {
        throw const AuthException('Sign-up failed. Please try again.');
      }
      if (res.session != null) {
        await _persistSession(
          _mapUser(res.user!),
          res.session,
          provider: 'email',
        );
      } else {
        throw const AuthException(
          'Check your email to confirm your account, then sign in.',
        );
      }
    } catch (e) {
      _logEvent('login_failed', 'signup');
      throw AuthException(_authErrorMessage(e));
    }
  }

  /// Passwordless email magic link — same Supabase flow as Next.js `signInWithOtp`.
  Future<void> sendEmailMagicLink(String email) async {
    _logEvent('magic_link_sent', 'email');
    _requireSupabase();
    try {
      await SupabaseService.client!.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: kIsWeb ? null : AppConfig.authRedirectUrl,
      );
    } catch (e) {
      _logEvent('login_failed', 'email_magic_link');
      throw AuthException(_authErrorMessage(e));
    }
  }

  /// Verify email OTP token (when Supabase sends a 6-digit code instead of link).
  Future<void> verifyEmailOtp(String email, String token) async {
    _requireSupabase();
    try {
      final res = await SupabaseService.client!.auth.verifyOTP(
        type: OtpType.email,
        email: email.trim(),
        token: token.trim(),
      );
      if (res.session == null || res.user == null) {
        throw const AuthException('Invalid or expired code. Try again.');
      }
      await _persistSession(
        _mapUser(res.user!),
        res.session,
        provider: 'email',
      );
    } catch (e) {
      _logEvent('login_failed', 'email_otp');
      throw AuthException(_authErrorMessage(e));
    }
  }

  /// Phone OTP — still local mock until SMS provider is configured in Supabase.
  Future<void> sendOtp(String phone) async {
    _logEvent('otp_sent', 'phone');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    debugPrint('MOCK OTP for $phone: 123456');
  }

  Future<void> verifyOtp(String phone, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (code != '123456') {
      _logEvent('login_failed', 'phone');
      throw const AuthException('Invalid or expired code. Try again.');
    }
    await _persistSession(
      AppUser(
        id: 'phone-${phone.hashCode}',
        email: '$phone@phone.farvixo.com',
      ),
      null,
      provider: 'phone',
    );
  }

  // ------------------------------------------------------- social login

  /// [provider] is 'google' | 'github' | 'apple'.
  /// Uses Supabase OAuth + PKCE (same Google provider as Next.js web).
  Future<void> signInWithProvider(String provider) async {
    _logEvent('login_started', provider);
    _requireSupabase();

    final oauthProvider = switch (provider) {
      'google' => OAuthProvider.google,
      'github' => OAuthProvider.github,
      'apple' => OAuthProvider.apple,
      _ => throw AuthException('Unknown provider: $provider'),
    };

    final client = SupabaseService.client!;
    final completer = Completer<Session>();
    late final StreamSubscription<AuthState> sub;

    sub = client.auth.onAuthStateChange.listen((data) {
      if (data.session != null &&
          (data.event == AuthChangeEvent.signedIn ||
              data.event == AuthChangeEvent.tokenRefreshed)) {
        if (!completer.isCompleted) completer.complete(data.session!);
      }
    });

    try {
      final launched = await client.auth.signInWithOAuth(
        oauthProvider,
        redirectTo: kIsWeb ? null : AppConfig.authRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException('Could not open Google sign-in.');
      }

      final session = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () =>
            throw const AuthException('Google sign-in timed out or was cancelled.'),
      );

      await _persistSession(
        _mapUser(session.user),
        session,
        provider: provider,
      );
    } catch (e) {
      _logEvent('login_failed', provider);
      throw AuthException(_authErrorMessage(e));
    } finally {
      await sub.cancel();
    }
  }

  // -------------------------------------------------------------- guest

  Future<void> continueAsGuest() async {
    await _persistSession(
      const AppUser(id: 'guest', email: 'guest@farvixo.com', isGuest: true),
      null,
      provider: 'guest',
    );
  }

  // ----------------------------------------------------------- biometric

  Future<bool> get canUseBiometricLogin async {
    if (!await _secure.biometricEnabled) return false;
    return await _secure.lastUserJson != null;
  }

  Future<void> enableBiometricLogin() async {
    await _secure.setBiometricEnabled(true);
    _logEvent('biometric_enabled');
  }

  Future<void> signInWithBiometrics() async {
    final json = await _secure.lastUserJson;
    if (json == null) {
      throw const AuthException('No saved account. Sign in manually first.');
    }
    // Prefer active Supabase session if still valid.
    final session = SupabaseService.client?.auth.currentSession;
    if (session != null) {
      await _persistSession(
        _mapUser(session.user),
        session,
        provider: 'biometric',
      );
      return;
    }
    final user = AppUser.fromJson(jsonDecode(json) as Map<String, dynamic>);
    await _persistSession(user, null, provider: 'biometric');
  }

  // ------------------------------------------------------ password reset

  Future<void> sendPasswordReset(String email) async {
    _logEvent('password_reset_requested');
    _requireSupabase();
    try {
      await SupabaseService.client!.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : AppConfig.authRedirectUrl,
      );
    } catch (e) {
      throw AuthException(_authErrorMessage(e));
    }
  }

  Future<void> verifyResetCode(String email, String code) async {
    // Supabase uses email magic link for reset; local 6-digit mock kept for UI flow.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code != '123456') {
      throw const AuthException('Invalid or expired code. Try again.');
    }
  }

  Future<void> completePasswordReset(String email, String newPassword) async {
    _requireSupabase();
    try {
      await SupabaseService.client!.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _logEvent('password_reset_completed');
    } catch (e) {
      throw AuthException(_authErrorMessage(e));
    }
  }

  // -------------------------------------------------------------- logout

  Future<void> signOut() async {
    _logEvent('logout');
    try {
      await SupabaseService.client?.auth.signOut();
    } catch (_) {}
    if (mounted) state = null;
    await _clearLocalSession(keepBiometric: true);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _logEvent(String event, [String? provider]) {
    debugPrint('auth_event: $event${provider == null ? '' : ' ($provider)'}');
  }
}
