import 'package:flutter/material.dart';

import '../../../core/launch/models/splash_config.dart';

/// Progress with Details — real step message + gradient bar + percentage
/// (LAUNCH & SPLASH SYSTEM v2.0.0, sections 2 & 3).
class ProgressWidget extends StatelessWidget {
  const ProgressWidget({
    super.key,
    required this.config,
    required this.progress,
    required this.message,
  });

  final SplashConfig config;
  final double progress; // 0..1
  final String message;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    final colors = [
      config.progressColor,
      config.particleColors.length > 1
          ? config.particleColors[1]
          : config.progressColor,
    ];

    return Semantics(
      label: 'Loading progress',
      value: '$percent percent — $message',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              message,
              key: ValueKey(message),
              style: const TextStyle(fontSize: 14, color: Color(0xFF9BA0C2)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 220,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: config.progressTrackColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: progress.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: colors),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: config.progressColor
                                    .withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$percent%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9BA0C2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
