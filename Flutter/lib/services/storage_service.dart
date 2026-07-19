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
  static const _kAiStreaming = 'pref_ai_streaming';
  static const _kAiSaveHistory = 'pref_ai_save_history';

  bool get onboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;
  Future<void> setOnboardingDone() => _prefs.setBool(_kOnboardingDone, true);

  String? get themeMode => _prefs.getString(_kThemeMode);
  Future<void> setThemeMode(String mode) => _prefs.setString(_kThemeMode, mode);

  /// Custom accent color stored as a 32-bit ARGB int.
  int? get accentColor => _prefs.getInt(_kAccentColor);
  Future<void> setAccentColor(int value) => _prefs.setInt(_kAccentColor, value);

  /// User-saved custom accent swatches (ARGB ints as strings).
  static const _kCustomAccentPalette = 'custom_accent_palette';

  List<int> get customAccentColors {
    final raw = _prefs.getStringList(_kCustomAccentPalette) ?? const [];
    return [
      for (final s in raw)
        if (int.tryParse(s) != null) int.parse(s),
    ];
  }

  Future<void> setCustomAccentColors(List<int> colors) =>
      _prefs.setStringList(
        _kCustomAccentPalette,
        [for (final c in colors) c.toString()],
      );

  // ---- Appearance › Home + Bottom layout ----
  static const _kHomeLayout = 'appearance_home_layout';
  static const _kHomeShowHero = 'appearance_home_show_hero';
  static const _kHomeShowQuick = 'appearance_home_show_quick';
  static const _kBottomStyle = 'appearance_bottom_style';
  static const _kBottomLabels = 'appearance_bottom_labels';
  static const _kBottomAiOrb = 'appearance_bottom_ai_orb';
  static const _kBottomBlur = 'appearance_bottom_blur';

  String? get homeLayoutMode => _prefs.getString(_kHomeLayout);
  Future<void> setHomeLayoutMode(String mode) =>
      _prefs.setString(_kHomeLayout, mode);

  bool get homeShowHero => _prefs.getBool(_kHomeShowHero) ?? true;
  Future<void> setHomeShowHero(bool v) => _prefs.setBool(_kHomeShowHero, v);

  bool get homeShowQuickActions => _prefs.getBool(_kHomeShowQuick) ?? true;
  Future<void> setHomeShowQuickActions(bool v) =>
      _prefs.setBool(_kHomeShowQuick, v);

  String? get bottomNavStyle => _prefs.getString(_kBottomStyle);
  Future<void> setBottomNavStyle(String style) =>
      _prefs.setString(_kBottomStyle, style);

  bool get bottomShowLabels => _prefs.getBool(_kBottomLabels) ?? true;
  Future<void> setBottomShowLabels(bool v) =>
      _prefs.setBool(_kBottomLabels, v);

  bool get bottomShowAiOrb => _prefs.getBool(_kBottomAiOrb) ?? true;
  Future<void> setBottomShowAiOrb(bool v) =>
      _prefs.setBool(_kBottomAiOrb, v);

  bool get bottomBlur => _prefs.getBool(_kBottomBlur) ?? true;
  Future<void> setBottomBlur(bool v) => _prefs.setBool(_kBottomBlur, v);

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

  bool get aiStreamingEnabled => _prefs.getBool(_kAiStreaming) ?? true;
  Future<void> setAiStreamingEnabled(bool v) =>
      _prefs.setBool(_kAiStreaming, v);

  bool get aiSaveHistoryEnabled => _prefs.getBool(_kAiSaveHistory) ?? true;
  Future<void> setAiSaveHistoryEnabled(bool v) =>
      _prefs.setBool(_kAiSaveHistory, v);

  bool get featureNotifications =>
      _prefs.getBool(_kFeatureNotifications) ?? true;
  Future<void> setFeatureNotifications(bool v) =>
      _prefs.setBool(_kFeatureNotifications, v);

  bool get featureOffline => _prefs.getBool(_kFeatureOffline) ?? true;
  Future<void> setFeatureOffline(bool v) => _prefs.setBool(_kFeatureOffline, v);

  bool get featureCloudSync => _prefs.getBool(_kFeatureCloudSync) ?? true;
  Future<void> setFeatureCloudSync(bool v) =>
      _prefs.setBool(_kFeatureCloudSync, v);

  // ---- app preference toggles (Settings › Preferences) ----
  static const _kSound = 'pref_sound_enabled';
  static const _kAnimations = 'pref_animations_enabled';

  bool get soundEnabled => _prefs.getBool(_kSound) ?? true;
  Future<void> setSoundEnabled(bool v) => _prefs.setBool(_kSound, v);

  bool get animationsEnabled => _prefs.getBool(_kAnimations) ?? true;
  Future<void> setAnimationsEnabled(bool v) =>
      _prefs.setBool(_kAnimations, v);

  // ---- enterprise settings toggles ----
  static const _kPush = 'pref_push_notifications';
  static const _kEmailNotif = 'pref_email_notifications';
  static const _kMarketing = 'pref_marketing_notifications';
  static const _kToolUpdates = 'pref_tool_updates';
  static const _kAiUpdates = 'pref_ai_updates';
  static const _kDownloadsNotif = 'pref_downloads_notifications';
  static const _kAnalytics = 'pref_analytics';
  static const _kPersonalization = 'pref_personalization';
  static const _kWifiOnlyDownloads = 'pref_wifi_only_downloads';
  static const _kAutoDeleteDownloads = 'pref_auto_delete_downloads';
  static const _kReduceMotion = 'pref_reduce_motion';
  static const _kBoldText = 'pref_bold_text';
  static const _kHighContrast = 'pref_high_contrast';
  static const _kHaptics = 'pref_haptics';

  bool get pushNotifications => _prefs.getBool(_kPush) ?? true;
  Future<void> setPushNotifications(bool v) => _prefs.setBool(_kPush, v);

  bool get emailNotifications => _prefs.getBool(_kEmailNotif) ?? true;
  Future<void> setEmailNotifications(bool v) =>
      _prefs.setBool(_kEmailNotif, v);

  bool get marketingNotifications => _prefs.getBool(_kMarketing) ?? false;
  Future<void> setMarketingNotifications(bool v) =>
      _prefs.setBool(_kMarketing, v);

  bool get toolUpdates => _prefs.getBool(_kToolUpdates) ?? true;
  Future<void> setToolUpdates(bool v) => _prefs.setBool(_kToolUpdates, v);

  bool get aiUpdates => _prefs.getBool(_kAiUpdates) ?? true;
  Future<void> setAiUpdates(bool v) => _prefs.setBool(_kAiUpdates, v);

  bool get downloadsNotifications => _prefs.getBool(_kDownloadsNotif) ?? true;
  Future<void> setDownloadsNotifications(bool v) =>
      _prefs.setBool(_kDownloadsNotif, v);

  bool get analyticsEnabled => _prefs.getBool(_kAnalytics) ?? true;
  Future<void> setAnalyticsEnabled(bool v) => _prefs.setBool(_kAnalytics, v);

  bool get personalizationEnabled => _prefs.getBool(_kPersonalization) ?? true;
  Future<void> setPersonalizationEnabled(bool v) =>
      _prefs.setBool(_kPersonalization, v);

  bool get wifiOnlyDownloads => _prefs.getBool(_kWifiOnlyDownloads) ?? false;
  Future<void> setWifiOnlyDownloads(bool v) =>
      _prefs.setBool(_kWifiOnlyDownloads, v);

  bool get autoDeleteDownloads => _prefs.getBool(_kAutoDeleteDownloads) ?? false;
  Future<void> setAutoDeleteDownloads(bool v) =>
      _prefs.setBool(_kAutoDeleteDownloads, v);

  bool get reduceMotion => _prefs.getBool(_kReduceMotion) ?? false;
  Future<void> setReduceMotion(bool v) => _prefs.setBool(_kReduceMotion, v);

  bool get boldText => _prefs.getBool(_kBoldText) ?? false;
  Future<void> setBoldText(bool v) => _prefs.setBool(_kBoldText, v);

  bool get highContrast => _prefs.getBool(_kHighContrast) ?? false;
  Future<void> setHighContrast(bool v) => _prefs.setBool(_kHighContrast, v);

  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? true;
  Future<void> setHapticsEnabled(bool v) => _prefs.setBool(_kHaptics, v);

  /// Clears app preference keys (keeps onboarding + device install keys).
  Future<void> resetAppPreferences() async {
    const keys = [
      _kThemeMode,
      _kAccentColor,
      _kCustomAccentPalette,
      _kHomeLayout,
      _kHomeShowHero,
      _kHomeShowQuick,
      _kBottomStyle,
      _kBottomLabels,
      _kBottomAiOrb,
      _kBottomBlur,
      _kLanguage,
      _kSound,
      _kAnimations,
      _kPush,
      _kEmailNotif,
      _kMarketing,
      _kToolUpdates,
      _kAiUpdates,
      _kDownloadsNotif,
      _kAnalytics,
      _kPersonalization,
      _kWifiOnlyDownloads,
      _kAutoDeleteDownloads,
      _kReduceMotion,
      _kBoldText,
      _kHighContrast,
      _kHaptics,
      _kFeatureAi,
      _kAiStreaming,
      _kAiSaveHistory,
      _kFeatureNotifications,
      _kFeatureOffline,
      _kFeatureCloudSync,
      _kPreferredContent,
    ];
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  /// Wipes all SharedPreferences (full local reset).
  Future<void> factoryResetPreferences() => _prefs.clear();

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

  /// Extended profile identity JSON, keyed per user id.
  static const _kProfileDetailsPrefix = 'profile_details_';

  String? profileDetailsJson(String userId) =>
      _prefs.getString('$_kProfileDetailsPrefix$userId');

  Future<void> setProfileDetailsJson(String userId, String json) =>
      _prefs.setString('$_kProfileDetailsPrefix$userId', json);

  static const _kDeviceRowId = 'current_user_device_row_id';
  static const _kDeviceKey = 'current_device_install_key';

  String? get currentDeviceRowId => _prefs.getString(_kDeviceRowId);
  Future<void> setCurrentDeviceRowId(String? id) async {
    if (id == null || id.isEmpty) {
      await _prefs.remove(_kDeviceRowId);
    } else {
      await _prefs.setString(_kDeviceRowId, id);
    }
  }

  /// Stable per-install id used as `user_devices.device_key`.
  String? get deviceInstallKey => _prefs.getString(_kDeviceKey);
  Future<void> setDeviceInstallKey(String key) =>
      _prefs.setString(_kDeviceKey, key);
}
