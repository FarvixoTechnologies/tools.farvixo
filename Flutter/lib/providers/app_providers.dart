import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_chat_history_service.dart';
import '../services/ai_service.dart';
import '../services/api_service.dart';
import '../services/farvixo_api_client.dart';
import '../services/secure_storage_service.dart';
import '../services/storage_service.dart';

/// Overridden in main() with the real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(sharedPreferencesProvider)),
);

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final farvixoApiClientProvider = Provider<FarvixoApiClient>(
  (ref) => FarvixoApiClient(),
);

final aiServiceProvider = Provider<AiService>((ref) => AiService());

final aiChatHistoryProvider = Provider<AiChatHistoryService>((ref) {
  return AiChatHistoryService(ref.watch(sharedPreferencesProvider));
});
