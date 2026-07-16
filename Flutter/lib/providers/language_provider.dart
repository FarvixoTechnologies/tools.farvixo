import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

/// A language Farvixo can be used in.
class AppLanguage {
  const AppLanguage(this.code, this.name, this.nativeName);

  final String code;
  final String name;
  final String nativeName;
}

/// Languages offered during onboarding / settings.
const supportedLanguages = [
  AppLanguage('en', 'English', 'English'),
  AppLanguage('hi', 'Hindi', 'हिन्दी'),
  AppLanguage('bn', 'Bengali', 'বাংলা'),
  AppLanguage('es', 'Spanish', 'Español'),
  AppLanguage('ar', 'Arabic', 'العربية'),
  AppLanguage('zh', 'Chinese', '中文'),
];

/// Persisted preferred-language code (defaults to English).
final languageProvider =
    StateNotifierProvider<LanguageNotifier, String>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return LanguageNotifier(storage.language, storage.setLanguage);
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier(String? saved, this._persist) : super(saved ?? 'en');

  final Future<void> Function(String) _persist;

  void setLanguage(String code) {
    state = code;
    _persist(code);
  }
}
