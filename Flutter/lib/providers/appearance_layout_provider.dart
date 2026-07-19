import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import '../services/storage_service.dart';

/// Bottom navigation visual style.
enum BottomNavStyle {
  floating,
  docked,
  minimal;

  String get label => switch (this) {
        BottomNavStyle.floating => 'Floating',
        BottomNavStyle.docked => 'Docked',
        BottomNavStyle.minimal => 'Minimal',
      };

  String get description => switch (this) {
        BottomNavStyle.floating => 'Pill bar with rounded corners',
        BottomNavStyle.docked => 'Full-width bar at the bottom',
        BottomNavStyle.minimal => 'Thin icons-only strip',
      };

  static BottomNavStyle fromId(String? id) => switch (id) {
        'docked' => BottomNavStyle.docked,
        'minimal' => BottomNavStyle.minimal,
        _ => BottomNavStyle.floating,
      };
}

/// Home screen density / layout mode.
enum HomeLayoutMode {
  full,
  compact,
  contentFirst;

  String get label => switch (this) {
        HomeLayoutMode.full => 'Full',
        HomeLayoutMode.compact => 'Compact',
        HomeLayoutMode.contentFirst => 'Content first',
      };

  String get description => switch (this) {
        HomeLayoutMode.full => 'Hero, quick actions, categories',
        HomeLayoutMode.compact => 'Tighter spacing, smaller hero',
        HomeLayoutMode.contentFirst => 'Skip hero, jump to tools',
      };

  static HomeLayoutMode fromId(String? id) => switch (id) {
        'compact' => HomeLayoutMode.compact,
        'contentFirst' => HomeLayoutMode.contentFirst,
        _ => HomeLayoutMode.full,
      };
}

@immutable
class AppearanceLayout {
  const AppearanceLayout({
    this.homeLayout = HomeLayoutMode.full,
    this.homeShowHero = true,
    this.homeShowQuickActions = true,
    this.bottomStyle = BottomNavStyle.floating,
    this.bottomShowLabels = true,
    this.bottomShowAiOrb = true,
    this.bottomBlur = true,
  });

  final HomeLayoutMode homeLayout;
  final bool homeShowHero;
  final bool homeShowQuickActions;
  final BottomNavStyle bottomStyle;
  final bool bottomShowLabels;
  final bool bottomShowAiOrb;
  final bool bottomBlur;

  bool get effectiveShowHero =>
      homeShowHero && homeLayout != HomeLayoutMode.contentFirst;

  AppearanceLayout copyWith({
    HomeLayoutMode? homeLayout,
    bool? homeShowHero,
    bool? homeShowQuickActions,
    BottomNavStyle? bottomStyle,
    bool? bottomShowLabels,
    bool? bottomShowAiOrb,
    bool? bottomBlur,
  }) {
    return AppearanceLayout(
      homeLayout: homeLayout ?? this.homeLayout,
      homeShowHero: homeShowHero ?? this.homeShowHero,
      homeShowQuickActions: homeShowQuickActions ?? this.homeShowQuickActions,
      bottomStyle: bottomStyle ?? this.bottomStyle,
      bottomShowLabels: bottomShowLabels ?? this.bottomShowLabels,
      bottomShowAiOrb: bottomShowAiOrb ?? this.bottomShowAiOrb,
      bottomBlur: bottomBlur ?? this.bottomBlur,
    );
  }

  factory AppearanceLayout.fromStorage(StorageService storage) {
    return AppearanceLayout(
      homeLayout: HomeLayoutMode.fromId(storage.homeLayoutMode),
      homeShowHero: storage.homeShowHero,
      homeShowQuickActions: storage.homeShowQuickActions,
      bottomStyle: BottomNavStyle.fromId(storage.bottomNavStyle),
      bottomShowLabels: storage.bottomShowLabels,
      bottomShowAiOrb: storage.bottomShowAiOrb,
      bottomBlur: storage.bottomBlur,
    );
  }
}

final appearanceLayoutProvider =
    StateNotifierProvider<AppearanceLayoutNotifier, AppearanceLayout>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AppearanceLayoutNotifier(storage);
});

class AppearanceLayoutNotifier extends StateNotifier<AppearanceLayout> {
  AppearanceLayoutNotifier(this._storage)
      : super(AppearanceLayout.fromStorage(_storage));

  final StorageService _storage;

  Future<void> setHomeLayout(HomeLayoutMode mode) async {
    state = state.copyWith(homeLayout: mode);
    await _storage.setHomeLayoutMode(mode.name);
  }

  Future<void> setHomeShowHero(bool value) async {
    state = state.copyWith(homeShowHero: value);
    await _storage.setHomeShowHero(value);
  }

  Future<void> setHomeShowQuickActions(bool value) async {
    state = state.copyWith(homeShowQuickActions: value);
    await _storage.setHomeShowQuickActions(value);
  }

  Future<void> setBottomStyle(BottomNavStyle style) async {
    state = state.copyWith(bottomStyle: style);
    await _storage.setBottomNavStyle(style.name);
  }

  Future<void> setBottomShowLabels(bool value) async {
    state = state.copyWith(bottomShowLabels: value);
    await _storage.setBottomShowLabels(value);
  }

  Future<void> setBottomShowAiOrb(bool value) async {
    state = state.copyWith(bottomShowAiOrb: value);
    await _storage.setBottomShowAiOrb(value);
  }

  Future<void> setBottomBlur(bool value) async {
    state = state.copyWith(bottomBlur: value);
    await _storage.setBottomBlur(value);
  }

  void reload() {
    state = AppearanceLayout.fromStorage(_storage);
  }
}
