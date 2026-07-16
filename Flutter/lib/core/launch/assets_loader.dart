import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../widgets/farvixo_logo.dart';

/// Smart Asset Preloading — single Farvixo logo.
class AssetsLoader {
  static const _maxAttempts = 2;

  Future<void> preload() async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        await rootBundle.load(FarvixoLogo.asset);
        return;
      } catch (e) {
        debugPrint('AssetsLoader attempt $attempt failed: $e');
        if (attempt == _maxAttempts) return;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
  }
}
