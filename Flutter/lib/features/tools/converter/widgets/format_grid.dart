import 'package:flutter/material.dart';

import '../../../../theme/app_palette.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/category_colors.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../widgets/premium_kit.dart';
import '../models/target_format.dart';

class FormatGrid extends StatelessWidget {
  const FormatGrid({
    super.key,
    required this.formats,
    required this.selected,
    required this.onSelect,
    this.locked,
    this.isPro = false,
    this.compareMode = false,
    this.compareSelected = const {},
    this.onToggleCompare,
  });

  final List<TargetFormat> formats;
  final TargetFormat? selected;
  final ValueChanged<TargetFormat> onSelect;
  final TargetFormat? locked;
  final bool isPro;
  final bool compareMode;
  final Set<TargetFormat> compareSelected;
  final ValueChanged<TargetFormat>? onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1000
            ? 5
            : w >= 720
                ? 4
                : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: formats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: w >= 720 ? 1.15 : 1.05,
          ),
          itemBuilder: (context, i) {
            final f = formats[i];
            final free = freeTargetFormats.contains(f);
            final lockedPro = !isPro && !free;
            final isOn = compareMode
                ? compareSelected.contains(f)
                : (selected == f || locked == f);
            return Semantics(
              button: true,
              selected: isOn,
              label:
                  '${f.label}. ${f.description}${lockedPro ? '. Pro' : ''}',
              child: PressableScale(
                onTap: locked != null && locked != f
                    ? null
                    : () {
                        if (compareMode) {
                          onToggleCompare?.call(f);
                        } else {
                          onSelect(f);
                        }
                      },
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: Radii.brTile,
                    border: Border.all(
                      color: isOn ? f.accentOf(context) : p.border,
                      width: isOn ? 1.6 : 1,
                    ),
                    color: isOn
                        ? f.accentOf(context).withValues(alpha: 0.12)
                        : p.surface.withValues(alpha: 0.55),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        lockedPro ? Icons.lock_rounded : f.icon,
                        color: f.accentOf(context),
                        size: 26,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        f.label,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall(context, color: p.textPrimary, weight: FontWeights.bold),
                      ),
                      if (lockedPro)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.s4),
                          child: Text(
                            'PRO',
                            style: AppTypography.caption(
                              context,
                              color: CategoryColors.premium.accentOf(context),
                              weight: FontWeights.extrabold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
