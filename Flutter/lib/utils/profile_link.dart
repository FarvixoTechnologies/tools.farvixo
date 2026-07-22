import '../../config/app_config.dart';
import '../../models/profile_details.dart';
import '../../models/user_model.dart';

/// Canonical Farvixo profile share / QR payload.
class ProfileLink {
  ProfileLink._();

  static const webOrigin = 'https://tools.farvixo.com';

  /// Public web profile URL encoded into My QR.
  static String forUser({
    required AppUser? user,
    required ProfileDetails details,
  }) {
    if (user == null || user.isGuest) {
      return webOrigin;
    }
    final username = details.username.trim().replaceFirst(RegExp(r'^@'), '');
    if (username.isNotEmpty) {
      return '$webOrigin/u/${Uri.encodeComponent(username)}';
    }
    return '$webOrigin/u/${Uri.encodeComponent(user.id)}';
  }

  /// Human-readable share text for the system share sheet.
  static String shareText({
    required String displayName,
    required String url,
  }) {
    final name = displayName.trim().isEmpty ? AppConfig.appName : displayName;
    return 'Connect with $name on Farvixo\n$url';
  }

  /// Short handle shown under the QR (`@username`).
  static String handle({
    required AppUser? user,
    required ProfileDetails details,
  }) {
    final username = details.username.trim().replaceFirst(RegExp(r'^@'), '');
    if (username.isNotEmpty) return '@$username';
    if (user != null && !user.isGuest) {
      final id = user.id;
      if (id.length <= 8) return '@$id';
      return '@${id.substring(0, 8)}';
    }
    return '@guest';
  }
}
