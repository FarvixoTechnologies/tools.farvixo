import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import 'app_providers.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ThemeModeNotifier(storage.themeMode, storage.setThemeMode);
});

/// Custom accent color that recolors buttons, links, highlights, the AI orb
/// and the bottom-nav selection across the app.
final accentColorProvider =
    StateNotifierProvider<AccentColorNotifier, Color>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AccentColorNotifier(storage.accentColor, storage.setAccentColor);
});

/// Preset accent swatches shown in the appearance picker.
class AccentPresets {
  AccentPresets._();

  static const violet = AppColors.brandPrimary; // default
  static const magenta = AppColors.brandMagenta;
  static const gold = AppColors.goldPremium;
  static const blue = Color(0xFF3B82F6);
  static const cyan = Color(0xFF06B6D4);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF97316);
  static const rose = Color(0xFFF43F5E);

  static const all = <Color>[
    violet,
    magenta,
    blue,
    cyan,
    green,
    orange,
    rose,
    gold,
  ];
}

class AccentColorNotifier extends StateNotifier<Color> {
  AccentColorNotifier(int? saved, this._persist)
      : super(saved != null ? Color(saved) : AccentPresets.violet);

  final Future<void> Function(int) _persist;

  void setColor(Color color) {
    state = color;
    _persist(color.toARGB32());
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(String? saved, this._persist)
      : super(_fromString(saved));

  final Future<void> Function(String) _persist;

  static ThemeMode _fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setMode(ThemeMode mode) {
    state = mode;
    _persist(mode.name);
  }
}
