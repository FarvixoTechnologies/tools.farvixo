/// Farvixo animation primitives — dependency-free, token-driven, reduced-motion
/// aware building blocks reused across every screen.
///
/// * [FadeSlideIn]   — fade + slide-up on mount, staggered via [index]/[delay].
/// * [PressableScale] — scale-down press feedback + optional haptic, for any
///   tappable surface (cards, buttons, tiles).
/// * [AppPageRoute]  — shared fade-through page transition.
///
/// All of these honour `MediaQuery.disableAnimations` (system "reduce motion"):
/// when set, decorative motion collapses to a plain fade or is skipped entirely.
///
/// These widgets add no runtime behavior beyond presentation and pull all
/// timing/curves from [Motion] in `design_tokens.dart` — never hardcode a
/// duration here.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';

/// Staggered fade + slide-up entrance. Drop around any widget; [index] controls
/// the stagger delay (index * [stagger]). Self-contained (own controller) so it
/// can be used anywhere without a shared ticker.
///
/// Backward-compatible with the previous `premium_kit` version: `FadeSlideIn(
/// index: i, child: ...)` still works. New optional params ([delay],
/// [duration], [offset], [enabled]) only add capability.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    this.index = 0,
    this.delay = Duration.zero,
    this.duration = Motion.page,
    this.stagger = Motion.staggerStep,
    this.offset = 0.10,
    this.enabled = true,
    required this.child,
  });

  /// Position in a list; multiplies [stagger] for the entrance delay.
  final int index;

  /// Extra fixed delay added on top of the staggered delay.
  final Duration delay;

  /// Entrance animation length.
  final Duration duration;

  /// Per-item stagger step.
  final Duration stagger;

  /// Initial vertical offset as a fraction of the child height (slides up).
  final double offset;

  /// Set false to render the child immediately with no animation.
  final bool enabled;

  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Motion.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(0, widget.offset),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Motion.easeOut));

  bool _started = false;

  void _start() {
    if (_started) return;
    _started = true;
    final total = widget.delay +
        Duration(
          milliseconds: (widget.index * widget.stagger.inMilliseconds)
              .clamp(0, Motion.staggerCap.inMilliseconds),
        );
    Future<void>.delayed(total, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect reduce-motion: show the child instantly, no animation.
    if (!widget.enabled || MediaQuery.maybeDisableAnimationsOf(context) == true) {
      if (!_c.isCompleted) _c.value = 1;
      _started = true;
      return;
    }
    _start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Wraps a tappable child with a subtle scale-down press animation and optional
/// selection haptic. Reusable across cards, buttons and tiles so press feedback
/// is consistent everywhere.
///
/// Falls back to a plain [GestureDetector] (no scale) when reduce-motion is on.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.haptic = true,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale applied while pressed (1.0 = no shrink).
  final double pressedScale;

  /// Fire [HapticFeedback.selectionClick] on tap-down.
  final bool haptic;

  /// When false, renders child + gesture without the scale animation.
  final bool enabled;

  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  bool get _tappable => widget.onTap != null || widget.onLongPress != null;

  void _setDown(bool v) {
    if (!mounted || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) == true;
    final animate = widget.enabled && !reduceMotion && _tappable;

    Widget child = widget.child;
    if (animate) {
      child = AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: Motion.fast,
        curve: Motion.standard,
        child: child,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _tappable
          ? (_) {
              if (widget.haptic) HapticFeedback.selectionClick();
              if (animate) _setDown(true);
            }
          : null,
      onTapUp: _tappable ? (_) => _setDown(false) : null,
      onTapCancel: _tappable ? () => _setDown(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: child,
    );
  }
}

/// Shared fade-through page transition. Use in place of [MaterialPageRoute] for
/// a consistent, premium push feel. Reduce-motion aware (collapses to a plain
/// fade with no slide).
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          transitionDuration: Motion.page,
          reverseTransitionDuration: Motion.base,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            final reduceMotion =
                MediaQuery.maybeDisableAnimationsOf(context) == true;
            final fade = CurvedAnimation(
              parent: animation,
              curve: Motion.standard,
            );
            if (reduceMotion) {
              return FadeTransition(opacity: fade, child: child);
            }
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Motion.easeOut));
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
}
