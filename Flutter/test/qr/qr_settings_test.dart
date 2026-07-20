import 'package:farvixo_all/features/tools/scanner/models/qr_settings.dart';
import 'package:farvixo_all/features/tools/scanner/providers/qr_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults are safe-by-default', () {
    const s = QrSettings();
    expect(s.sound, isTrue);
    expect(s.vibration, isTrue);
    expect(s.autoOpenLinks, isFalse); // must default OFF for safety
    expect(s.privateMode, isFalse);
    expect(s.biometricLock, isFalse);
    expect(s.retentionDays, 0);
  });

  test('reads persisted values on construction', () async {
    SharedPreferences.setMockInitialValues({
      'qr_sound': false,
      'qr_auto_open': true,
      'qr_retention_days': 30,
    });
    final prefs = await SharedPreferences.getInstance();
    final notifier = QrSettingsNotifier(prefs);
    expect(notifier.state.sound, isFalse);
    expect(notifier.state.autoOpenLinks, isTrue);
    expect(notifier.state.retentionDays, 30);
    expect(notifier.state.vibration, isTrue); // unset → default
  });

  test('setters update state and persist', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = QrSettingsNotifier(prefs);

    notifier.setPrivateMode(true);
    notifier.setRetentionDays(90);
    notifier.setVibration(false);

    expect(notifier.state.privateMode, isTrue);
    expect(notifier.state.retentionDays, 90);
    expect(prefs.getBool('qr_private_mode'), isTrue);
    expect(prefs.getInt('qr_retention_days'), 90);
    expect(prefs.getBool('qr_vibration'), isFalse);

    // A fresh notifier over the same prefs restores the values.
    final restored = QrSettingsNotifier(prefs);
    expect(restored.state.privateMode, isTrue);
    expect(restored.state.retentionDays, 90);
  });
}
