import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Result of a local cache wipe (auth/user prefs are preserved).
class CacheCleanupResult {
  const CacheCleanupResult({
    required this.deletedBytes,
    required this.deletedEntries,
  });

  final int deletedBytes;
  final int deletedEntries;

  String get humanSize {
    if (deletedBytes < 1024) return '$deletedBytes B';
    if (deletedBytes < 1024 * 1024) {
      return '${(deletedBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(deletedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Clears temporary app caches without touching SharedPreferences / secure storage.
class CacheCleanupService {
  CacheCleanupService._();
  static final CacheCleanupService instance = CacheCleanupService._();

  Future<CacheCleanupResult> clearTemporaryCache() async {
    if (kIsWeb) {
      // Web has no durable temp directory we own; report a no-op success.
      return const CacheCleanupResult(deletedBytes: 0, deletedEntries: 0);
    }

    var bytes = 0;
    var entries = 0;

    Future<void> wipeDir(Directory? dir) async {
      if (dir == null || !await dir.exists()) return;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        try {
          if (entity is File) {
            bytes += await entity.length();
            await entity.delete();
            entries++;
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
            entries++;
          }
        } catch (e) {
          debugPrint('CacheCleanupService skip ${entity.path}: $e');
        }
      }
    }

    try {
      await wipeDir(await getTemporaryDirectory());
    } catch (e) {
      debugPrint('CacheCleanupService.getTemporaryDirectory: $e');
    }

    try {
      final support = await getApplicationSupportDirectory();
      final cache = Directory('${support.path}/cache');
      await wipeDir(cache);
    } catch (e) {
      debugPrint('CacheCleanupService.supportCache: $e');
    }

    return CacheCleanupResult(deletedBytes: bytes, deletedEntries: entries);
  }
}
