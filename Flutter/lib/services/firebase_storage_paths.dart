/// Firebase Storage path helpers (farvixo-production-2026).
/// Buckets/prefixes: avatars, documents, uploads, images, temporary.
class FirebaseStoragePaths {
  FirebaseStoragePaths._();

  static String avatar(String userId, String fileName) =>
      'avatars/$userId/$fileName';

  static String document(String userId, String fileName) =>
      'documents/$userId/$fileName';

  static String upload(String userId, String fileName) =>
      'uploads/$userId/$fileName';

  static String image(String userId, String fileName) =>
      'images/$userId/$fileName';

  static String temporary(String userId, String fileName) =>
      'temporary/$userId/$fileName';
}
