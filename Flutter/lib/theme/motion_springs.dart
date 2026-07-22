/// Farvixo spring-physics motion tokens.
///
/// Fixed-duration curves ([Motion]) cover most UI; these springs cover the
/// interactions that must feel *physical* — drag release, fling, morphing
/// buttons, dropped-file landings. Never construct an ad-hoc
/// [SpringDescription] in feature code; pick a token here.
library;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'design_tokens.dart';

/// Named spring presets, from stiff-and-instant to soft-and-bouncy.
class Springs {
  Springs._();

  /// Crisp settle with no visible overshoot — press/release scale feedback.
  static const SpringDescription snappy = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 30,
  );

  /// Default interactive spring — slight overshoot, fast settle. Panels,
  /// draggable sheets, chip morphs.
  static const SpringDescription standard = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 24,
  );

  /// Playful bounce — dropped files landing in the queue, success icons.
  static const SpringDescription bouncy = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 16,
  );

  /// Soft, luxurious settle — hero cards, large surfaces gliding into place.
  static const SpringDescription gentle = SpringDescription(
    mass: 1.2,
    stiffness: 180,
    damping: 22,
  );

  /// Builds a [SpringSimulation] from [from] → [to] with initial [velocity].
  ///
  /// Honours reduce-motion: when the user has disabled animations the
  /// returned simulation is critically damped so it settles with no bounce.
  static SpringSimulation simulation(
    BuildContext context,
    SpringDescription spring, {
    required double from,
    required double to,
    double velocity = 0,
  }) {
    final desc = Motion.reduced(context)
        ? SpringDescription.withDampingRatio(
            mass: 1, stiffness: spring.stiffness, ratio: 1)
        : spring;
    return SpringSimulation(desc, from, to, velocity);
  }
}

/// Drives an [AnimationController] with a spring instead of a duration.
///
/// ```dart
/// controller.springTo(context, 1.0, spring: Springs.bouncy);
/// ```
extension SpringDrive on AnimationController {
  TickerFuture springTo(
    BuildContext context,
    double target, {
    SpringDescription spring = Springs.standard,
    double velocity = 0,
  }) {
    return animateWith(Springs.simulation(
      context,
      spring,
      from: value,
      to: target,
      velocity: velocity,
    ));
  }
}
