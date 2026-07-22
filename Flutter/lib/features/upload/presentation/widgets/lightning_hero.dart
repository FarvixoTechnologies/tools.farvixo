import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../theme/app_typography.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../theme/upload_theme.dart';
import '../../domain/upload_status.dart';
import '../upload_layout.dart';
import 'lightning_stage_painter.dart';

/// The Lightning Upload hero stage.
///
/// Renders the key art via [LightningStagePainter] and drives it from four
/// independent animation controllers, so the folder can float while the ring
/// spins while a strike fires — none of them fighting for the same ticker.
///
/// Reduce-motion is honoured throughout: controllers are stopped and the stage
/// renders as a still frame with the folder centred and the ring at rest. The
/// art is fully legible without any motion.
class LightningHero extends StatefulWidget {
  const LightningHero({
    super.key,
    required this.status,
    this.progress = 0,
    this.caption,
    this.onTap,
    this.isDropTarget = false,
    this.metrics,
  });

  /// Drives the stage phase and accent.
  final UploadStatus status;

  /// 0–1 aggregate progress; fills the ring.
  final double progress;

  /// Secondary line under the status label (speed · ETA, file name, error).
  final String? caption;

  /// Tapping the stage opens the source picker.
  final VoidCallback? onTap;

  /// True while a drag payload hovers the stage.
  final bool isDropTarget;

  /// Size caps for the current device. Resolved from context when omitted.
  final UploadMetrics? metrics;

  @override
  State<LightningHero> createState() => _LightningHeroState();
}

class _LightningHeroState extends State<LightningHero>
    with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: UploadStage.float,
  );
  late final AnimationController _strike = AnimationController(
    vsync: this,
    duration: UploadStage.strike,
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: UploadStage.ringSpin,
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: UploadStage.burst,
  );

  Timer? _strikeTimer;
  bool _reduceMotion = false;

  StagePhase get _phase =>
      widget.isDropTarget ? StagePhase.charging : widget.status.phase;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = Motion.reduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(LightningHero old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status || old.isDropTarget != widget.isDropTarget) {
      if (widget.status == UploadStatus.completed &&
          old.status != UploadStatus.completed) {
        _burst.forward(from: 0);
      }
      _sync();
    }
  }

  /// Starts/stops the loops to match the current phase.
  void _sync() {
    _strikeTimer?.cancel();

    if (_reduceMotion) {
      for (final c in [_float, _strike, _spin]) {
        c.stop();
        c.value = 0;
      }
      // A still frame still needs the bolt visible when energy is flowing.
      _strike.value = switch (_phase) {
        StagePhase.striking => 0.9,
        StagePhase.working || StagePhase.charging => 0.45,
        _ => 0,
      };
      return;
    }

    if (!_float.isAnimating) _float.repeat();

    switch (_phase) {
      case StagePhase.resting:
        _spin.stop();
        _scheduleStrike(UploadStage.strikeGap);
      case StagePhase.charging:
        if (!_spin.isAnimating) _spin.repeat();
        _scheduleStrike(UploadStage.strikeGap ~/ 2);
      case StagePhase.working:
        if (!_spin.isAnimating) _spin.repeat();
        _scheduleStrike(UploadStage.strikeGap ~/ 3);
      case StagePhase.striking:
        if (!_spin.isAnimating) _spin.repeat();
        _scheduleStrike(UploadStage.strike * 1.6);
      case StagePhase.celebrating:
        _spin.stop();
        _strike.animateTo(0);
      case StagePhase.faulted:
        _spin.stop();
        _strike.stop();
        _strike.value = 0;
    }
  }

  /// Fires one strike, then queues the next after [gap].
  void _scheduleStrike(Duration gap) {
    _strikeTimer?.cancel();
    _strikeTimer = Timer(gap, () {
      if (!mounted) return;
      _strike.forward(from: 0).then((_) {
        if (mounted) _strike.reverse();
      });
      _sync();
    });
  }

  @override
  void dispose() {
    _strikeTimer?.cancel();
    _float.dispose();
    _strike.dispose();
    _spin.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final accent = status.color;

    return Semantics(
      button: widget.onTap != null,
      label: 'Upload. ${status.label}'
          '${widget.caption == null ? '' : '. ${widget.caption}'}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final m = widget.metrics ?? UploadMetrics.of(context);

            // Fit the stage to the tighter of the two axes so the art never
            // distorts, then clamp to this device's caps so it neither
            // shrinks below legibility on a small phone nor dominates an
            // ultrawide display.
            final maxW = constraints.maxWidth.isFinite
                ? constraints.maxWidth.clamp(0.0, m.heroMaxWidth)
                : m.heroMaxWidth;
            final maxH = constraints.maxHeight.isFinite
                ? constraints.maxHeight.clamp(0.0, m.heroMaxHeight)
                : m.heroMaxHeight;

            var w = maxW;
            var h = w / UploadStage.aspect;
            if (h > maxH) {
              h = maxH;
              w = h * UploadStage.aspect;
            }
            // Never render below the floor — a squashed stage reads as broken
            // rather than compact.
            if (h < m.heroMinHeight && maxH >= m.heroMinHeight) {
              h = m.heroMinHeight;
              w = h * UploadStage.aspect;
            }

            return Center(
              child: SizedBox(
                width: w,
                height: h,
                child: ClipRRect(
                  borderRadius: Radii.brHero,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: Listenable.merge(
                            [_float, _strike, _spin, _burst],
                          ),
                          builder: (context, _) => CustomPaint(
                            painter: LightningStagePainter(
                              phase: _phase,
                              accent: accent,
                              float: _float.value,
                              strike: Motion.easeOut
                                  .transform(_strike.value.clamp(0.0, 1.0)),
                              spin: _spin.value,
                              progress: widget.progress,
                              burst: _burst.value,
                            ),
                          ),
                        ),
                      ),
                      // Drop-target ring.
                      if (widget.isDropTarget)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: Radii.brHero,
                              border: Border.all(
                                color: accent.withValues(alpha: 0.9),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: Insets.md,
                        right: Insets.md,
                        bottom: Insets.md,
                        child: _StageCaption(
                          status: status,
                          caption: widget.caption,
                          accent: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Status line rendered over the bottom of the stage.
class _StageCaption extends StatelessWidget {
  const _StageCaption({
    required this.status,
    required this.caption,
    required this.accent,
  });

  final UploadStatus status;
  final String? caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(status.icon, size: 16, color: accent),
            const SizedBox(width: Gap.icon),
            Flexible(
              child: Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall(
                  context,
                  color: UploadPalette.onStage,
                  weight: FontWeights.extrabold,
                ),
              ),
            ),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: Space.s4),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption(
              context,
              color: UploadPalette.onStageMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small standalone lightning mark — used in the app bar and empty states.
class LightningMark extends StatelessWidget {
  const LightningMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [UploadPalette.boltHot, UploadPalette.boltDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: UploadPalette.bolt.withValues(alpha: 0.45),
              blurRadius: size * 0.5,
            ),
          ],
        ),
        child: Icon(
          Icons.bolt_rounded,
          size: size * 0.62,
          color: UploadPalette.onStage,
        ),
      ),
    );
  }
}
