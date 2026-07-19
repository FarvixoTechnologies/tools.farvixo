import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../services/settings_sync_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import 'settings_widgets.dart';

/// Full accent palette sheet: presets + custom HSV picker + saved colors.
class AccentColorPickerSheet extends ConsumerStatefulWidget {
  const AccentColorPickerSheet({super.key});

  @override
  ConsumerState<AccentColorPickerSheet> createState() =>
      _AccentColorPickerSheetState();
}

class _AccentColorPickerSheetState
    extends ConsumerState<AccentColorPickerSheet> {
  late HSVColor _hsv;
  late final TextEditingController _hexCtrl;

  @override
  void initState() {
    super.initState();
    final accent = ref.read(accentColorProvider);
    _hsv = HSVColor.fromColor(accent);
    _hexCtrl = TextEditingController(text: _toHex(accent));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  Color get _draft => _hsv.toColor();

  String _toHex(Color c) {
    final v = c.toARGB32() & 0xFFFFFF;
    return v.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  void _setHsv(HSVColor hsv, {bool syncHex = true}) {
    setState(() {
      _hsv = hsv;
      if (syncHex) _hexCtrl.text = _toHex(hsv.toColor());
    });
  }

  void _apply(Color color) {
    ref.read(accentColorProvider.notifier).setColor(color);
    SettingsSyncService.instance.setAccentColor(color.toARGB32());
    setState(() {
      _hsv = HSVColor.fromColor(color);
      _hexCtrl.text = _toHex(color);
    });
  }

  Future<void> _addToPalette() async {
    await ref.read(customAccentPaletteProvider.notifier).add(_draft);
    _apply(_draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Color added to your palette'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onHexChanged(String raw) {
    final cleaned = raw.replaceAll('#', '').trim();
    if (cleaned.length != 6) return;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return;
    final color = Color(0xFF000000 | value);
    _setHsv(HSVColor.fromColor(color), syncHex: false);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final accent = ref.watch(accentColorProvider);
    final mine = ref.watch(customAccentPaletteProvider);
    final draft = _draft;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.textMuted.withValues(alpha: .5),
                    borderRadius: Radii.brPill,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Accent color',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick a preset or create your own color',
                style: TextStyle(fontSize: 13, color: p.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Palette',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in AccentPresets.all)
                    AccentSwatch(
                      color: color,
                      selected: color.toARGB32() == accent.toARGB32(),
                      onTap: () => _apply(color),
                    ),
                ],
              ),
              if (mine.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'My colors',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in mine)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AccentSwatch(
                            color: color,
                            selected: color.toARGB32() == accent.toARGB32(),
                            onTap: () => _apply(color),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: () => ref
                                  .read(customAccentPaletteProvider.notifier)
                                  .remove(color),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: p.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: p.border),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 12,
                                  color: p.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Custom color',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: draft,
                      borderRadius: Radii.brCard,
                      border: Border.all(color: p.border),
                      boxShadow: [
                        BoxShadow(
                          color: draft.withValues(alpha: 0.45),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hexCtrl,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                      decoration: InputDecoration(
                        prefixText: '# ',
                        prefixStyle: TextStyle(color: p.textMuted),
                        labelText: 'Hex',
                        filled: true,
                        fillColor: p.surface2,
                        border: OutlineInputBorder(
                          borderRadius: Radii.brButton,
                          borderSide: BorderSide(color: p.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: Radii.brButton,
                          borderSide: BorderSide(color: p.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: _onHexChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Hue', style: TextStyle(fontSize: 12, color: p.textMuted)),
              const SizedBox(height: 6),
              _HueSlider(
                value: _hsv.hue,
                onChanged: (h) => _setHsv(_hsv.withHue(h)),
              ),
              const SizedBox(height: 12),
              Text(
                'Saturation',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: _hsv.saturation,
                  activeColor: draft,
                  inactiveColor: p.surface2,
                  onChanged: (s) => _setHsv(_hsv.withSaturation(s)),
                ),
              ),
              Text(
                'Brightness',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: _hsv.value,
                  activeColor: draft,
                  inactiveColor: p.surface2,
                  onChanged: (v) => _setHsv(_hsv.withValue(v)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addToPalette,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add to palette'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.textPrimary,
                        side: BorderSide(color: p.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: Radii.brButton,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _apply(draft);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: draft,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: Radii.brButton,
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final thumbX = (value / 360) * w;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _emit(d.localPosition.dx, w),
            onPanUpdate: (d) => _emit(d.localPosition.dx, w),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: Radii.brPill,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF00FFFF),
                        Color(0xFF0000FF),
                        Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: (thumbX - 10).clamp(0, w - 20),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(1, value, 1, 1).toColor(),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(blurRadius: 6, color: Colors.black26),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _emit(double dx, double width) {
    final hue = ((dx / width) * 360).clamp(0.0, 360.0);
    onChanged(hue);
  }
}
