import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences with typed keys.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _kOnboardingDone = 'onboarding_done';
  static const _kThemeMode = 'theme_mode';
  static const _kAccentColor = 'accent_color';
  static const _kUserJson = 'user_json';
  static const _kLanguage = 'language';
  static const _kOnboardingGoals = 'onboarding_goals';
  static const _kPreferredContent = 'preferred_content';
  static const _kFeatureAi = 'feature_ai_assistant';
  static const _kFeatureNotifications = 'feature_notifications';
  static const _kFeatureOffline = 'feature_offline';
  static const _kFeatureCloudSync = 'feature_cloud_sync';

  bool get onboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;
  Future<void> setOnboardingDone() => _prefs.setBool(_kOnboardingDone, true);

  String? get themeMode => _prefs.getString(_kThemeMode);
  Future<void> setThemeMode(String mode) => _prefs.setString(_kThemeMode, mode);

  /// Custom accent color stored as a 32-bit ARGB int.
  int? get accentColor => _prefs.getInt(_kAccentColor);
  Future<void> setAccentColor(int value) => _prefs.setInt(_kAccentColor, value);

  String? get language => _prefs.getString(_kLanguage);
  Future<void> setLanguage(String code) => _prefs.setString(_kLanguage, code);

  List<String> get onboardingGoals =>
      _prefs.getStringList(_kOnboardingGoals) ?? [];
  Future<void> setOnboardingGoals(List<String> ids) =>
      _prefs.setStringList(_kOnboardingGoals, ids);

  List<String> get preferredContent =>
      _prefs.getStringList(_kPreferredContent) ?? [];
  Future<void> setPreferredContent(List<String> ids) =>
      _prefs.setStringList(_kPreferredContent, ids);

  bool get featureAiAssistant => _prefs.getBool(_kFeatureAi) ?? true;
  Future<void> setFeatureAiAssistant(bool v) =>
      _prefs.setBool(_kFeatureAi, v);

  bool get featureNotifications =>
      _prefs.getBool(_kFeatureNotifications) ?? true;
  Future<void> setFeatureNotifications(bool v) =>
      _prefs.setBool(_kFeatureNotifications, v);

  bool get featureOffline => _prefs.getBool(_kFeatureOffline) ?? true;
  Future<void> setFeatureOffline(bool v) => _prefs.setBool(_kFeatureOffline, v);

  bool get featureCloudSync => _prefs.getBool(_kFeatureCloudSync) ?? true;
  Future<void> setFeatureCloudSync(bool v) =>
      _prefs.setBool(_kFeatureCloudSync, v);

  static const _kRecentTools = 'recent_tools';
  static const _kFavoriteTools = 'favorite_tools';

  List<String> get recentToolIds => _prefs.getStringList(_kRecentTools) ?? [];
  Future<void> setRecentToolIds(List<String> ids) =>
      _prefs.setStringList(_kRecentTools, ids);

  List<String> get favoriteToolIds =>
      _prefs.getStringList(_kFavoriteTools) ?? [];
  Future<void> setFavoriteToolIds(List<String> ids) =>
      _prefs.setStringList(_kFavoriteTools, ids);

  String? get userJson => _prefs.getString(_kUserJson);
  Future<void> setUserJson(String json) => _prefs.setString(_kUserJson, json);
  Future<void> clearUser() => _prefs.remove(_kUserJson);
}
