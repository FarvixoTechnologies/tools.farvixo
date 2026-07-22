import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_palette.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/design_tokens.dart';
import '../providers/pdf_converter_provider.dart';

class ConverterSteps extends StatelessWidget {
  const ConverterSteps({super.key, required this.view});

  final ConverterView view;

  static const _labels = ['Upload', 'Analyze', 'Convert', 'Download'];

  int get _index => switch (view) {
        ConverterView.upload => 0,
        ConverterView.analysis || ConverterView.review => 1,
        ConverterView.convert ||
        ConverterView.compare ||
        ConverterView.diff =>
          2,
        ConverterView.results => 3,
      };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final active = _index;
    return Semantics(
      label: 'Step ${active + 1} of 4: ${_labels[active]}',
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i <= active ? p.accent : p.border,
                ),
              ),
            _Dot(label: _labels[i], active: i <= active, current: i == active),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.label,
    required this.active,
    required this.current,
  });

  final String label;
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          width: current ? 28 : 22,
          height: current ? 28 : 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? p.accent : p.surface2,
            border: Border.all(color: active ? p.accent : p.border),
          ),
          child: Text(
            '${_labels.indexOf(label) + 1}',
            style: AppTypography.labelSmall(context, color: active ? AppColors.onAccent : p.textMuted, weight: FontWeights.extrabold),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTypography.caption(
            context,
            color: active ? p.textPrimary : p.textMuted,
            weight: current ? FontWeights.bold : FontWeights.medium,
          ),
        ),
      ],
    );
  }

  static const _labels = ['Upload', 'Analyze', 'Convert', 'Download'];
}
