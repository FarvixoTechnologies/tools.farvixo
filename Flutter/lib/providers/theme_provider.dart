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
  static const indigo = Color(0xFF6366F1);
  static const cyan = Color(0xFF06B6D4);
  static const teal = Color(0xFF14B8A6);
  static const green = Color(0xFF22C55E);
  static const lime = Color(0xFF84CC16);
  static const orange = Color(0xFFF97316);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFF43F5E);
  static const pink = Color(0xFFEC4899);
  static const red = Color(0xFFEF4444);
  static const slate = Color(0xFF64748B);
  static const white = Color(0xFFE2E8F0);

  static const all = <Color>[
    violet,
    magenta,
    indigo,
    blue,
    cyan,
    teal,
    green,
    lime,
    amber,
    gold,
    orange,
    rose,
    pink,
    red,
    slate,
    white,
  ];
}

/// User-saved custom accent colors for the palette picker.
final customAccentPaletteProvider =
    StateNotifierProvider<CustomAccentPaletteNotifier, List<Color>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return CustomAccentPaletteNotifier(
    storage.customAccentColors,
    storage.setCustomAccentColors,
  );
});

class CustomAccentPaletteNotifier extends StateNotifier<List<Color>> {
  CustomAccentPaletteNotifier(List<int> saved, this._persist)
      : super([for (final c in saved) Color(c)]);

  final Future<void> Function(List<int>) _persist;
  static const _max = 16;

  Future<void> add(Color color) async {
    final argb = color.toARGB32();
    if (state.any((c) => c.toARGB32() == argb)) return;
    final next = [color, ...state].take(_max).toList();
    state = next;
    await _persist([for (final c in next) c.toARGB32()]);
  }

  Future<void> remove(Color color) async {
    final argb = color.toARGB32();
    final next = [for (final c in state) if (c.toARGB32() != argb) c];
    state = next;
    await _persist([for (final c in next) c.toARGB32()]);
  }
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
