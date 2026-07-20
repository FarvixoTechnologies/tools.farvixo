/// Immutable scanner/privacy preferences for the QR module. Persisted as flat
/// SharedPreferences keys by [QrSettingsNotifier].
class QrSettings {
  const QrSettings({
    this.sound = true,
    this.vibration = true,
    this.autoOpenLinks = false,
    this.privateMode = false,
    this.offlineOnly = false,
    this.biometricLock = false,
    this.retentionDays = 0,
  });

  /// Play a beep on a successful scan.
  final bool sound;

  /// Haptic feedback on a successful scan.
  final bool vibration;

  /// Automatically open safe links after scanning (OFF by default for safety).
  final bool autoOpenLinks;

  /// Scan without saving to history.
  final bool privateMode;

  /// Never perform any network reputation lookups (heuristics only).
  final bool offlineOnly;

  /// Require biometric/device auth before opening history.
  final bool biometricLock;

  /// Auto-delete history older than N days. 0 = keep forever. Allowed: 7/30/90.
  final int retentionDays;

  QrSettings copyWith({
    bool? sound,
    bool? vibration,
    bool? autoOpenLinks,
    bool? privateMode,
    bool? offlineOnly,
    bool? biometricLock,
    int? retentionDays,
  }) =>
      QrSettings(
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        autoOpenLinks: autoOpenLinks ?? this.autoOpenLinks,
        privateMode: privateMode ?? this.privateMode,
        offlineOnly: offlineOnly ?? this.offlineOnly,
        biometricLock: biometricLock ?? this.biometricLock,
        retentionDays: retentionDays ?? this.retentionDays,
      );
}
