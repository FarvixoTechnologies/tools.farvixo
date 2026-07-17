/// Holds a deep-link path from FCM until GoRouter can navigate.
class PendingDeepLink {
  PendingDeepLink._();
  static String? path;

  static void set(String? value) {
    if (value == null || value.isEmpty) return;
    path = value.startsWith('/') ? value : '/$value';
  }

  static String? take() {
    final v = path;
    path = null;
    return v;
  }
}
