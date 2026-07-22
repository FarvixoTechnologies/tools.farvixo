import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../core/launch/splash_controller.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/farvixo_logo.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_typography.dart';

/// FARVIXO — Launch & Loading System v3.0
/// (docs: LAUNCH, LOADING & ONBOARDING SYSTEM — screens 001–005)
///
/// One premium screen, five acts:
///   Launch reveal (logo scale + RGB ring + particle burst), then four
///   loading phases mapped to real startup progress:
///     0–25%   Initializing Farvixo   · Please wait...
///     25–50%  Preparing Magic        · Almost there...
///     50–75%  Powering AI Engine     · This won't take long...
///     75–100% Launching Farvixo      · Welcome aboard...
/// Ends with a fade+scale hand-off to the Decision Engine's route.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _Phase {
  const _Phase(this.title, this.subtitle, this.accent);
  final String title;
  final String subtitle;
  final Color accent;
}

const _phases = [
  _Phase('Initializing Farvixo', 'Please wait...', AppColors.brandPrimaryHover),
  _Phase('Preparing Magic', 'Almost there...', AppColors.brandMagenta),
  _Phase('Powering AI Engine', "This won't take long...", AppColors.accentDev),
  _Phase('Launching Farvixo', 'Welcome aboard...', AppColors.goldPremium),
];

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  /// One-shot logo reveal (scale 0 → 100% with elastic pop).
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: Motion.verySlow,
  );

  /// Continuous loop: RGB ring rotation, particles, rays, crown shine.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: Motion.ambientFast,
  );

  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _reveal.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(splashControllerProvider.notifier).start();
      if (!MediaQuery.of(context).disableAnimations) {
        _loop.repeat();
      }
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    _loop.dispose();
    super.dispose();
  }

  Future<void> _exitTo(String route) async {
    if (_exiting) return;
    setState(() => _exiting = true);
    await Future<void>.delayed(Motion.page);
    if (!mounted) return;
    context.go(route);
    // Ask for notification permission only AFTER the splash has exited and
    // the destination screen has settled — never as the app's first frame.
    unawaited(
      Future<void>.delayed(Motion.refreshDwell).then(
        (_) => NotificationService.instance.requestPermissionIfNeeded(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(splashControllerProvider, (_, next) {
      if (next.targetRoute != null) _exitTo(next.targetRoute!);
    });

    final launch = ref.watch(splashControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: AnimatedOpacity(
        opacity: _exiting ? 0 : 1,
        duration: Motion.page,
        curve: Motion.easeOut,
        child: AnimatedScale(
          scale: _exiting ? 1.08 : 1,
          duration: Motion.page,
          curve: Motion.easeOut,
          child: launch.phase == LaunchPhase.error
              ? _ErrorFallback(
                  message: launch.message,
                  onRetry: () =>
                      ref.read(splashControllerProvider.notifier).retry(),
                )
              : _LaunchBody(
                  reveal: _reveal,
                  loop: _loop,
                  progress: launch.progress,
                ),
        ),
      ),
    );
  }
}

// =============================================================================
// BODY
// =============================================================================
class _LaunchBody extends StatelessWidget {
  const _LaunchBody({
    required this.reveal,
    required this.loop,
    required this.progress,
  });

  final Animation<double> reveal;
  final AnimationController loop;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Smoothly chase the real startup progress so the bar never jumps.
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: Motion.refreshDwell,
      curve: Motion.easeOut,
      builder: (context, shown, _) {
        final phaseIndex = (shown * 4).floor().clamp(0, 3);
        final phase = _phases[phaseIndex];

        return Stack(
          fit: StackFit.expand,
          children: [
            // ------------- galaxy background (phase-tinted) -------------
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, _) => CustomPaint(
                  painter: _GalaxyPainter(
                    t: loop.value,
                    accent: phase.accent,
                    warp: phaseIndex == 3, // star warp on final phase
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Semantics(
                label: '${AppConfig.appName} is starting',
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // ------------------- crown logo + RGB rings -------------------
                    ScaleTransition(
                      scale: CurvedAnimation(
                          parent: reveal, curve: Motion.elastic),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                            parent: reveal,
                            curve: const Interval(0, .4)),
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: AnimatedBuilder(
                            animation: loop,
                            builder: (context, child) {
                              final pulse =
                                  (math.sin(loop.value * 2 * math.pi * 2) +
                                          1) /
                                      2;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // RGB energy ring (360° rotation)
                                  Transform.rotate(
                                    angle: loop.value * 2 * math.pi,
                                    child: CustomPaint(
                                      size: const Size(190, 190),
                                      painter: _RgbRingPainter(),
                                    ),
                                  ),
                                  // counter-rotating gold dashed ring
                                  Transform.rotate(
                                    angle: -loop.value * 2 * math.pi * .6,
                                    child: CustomPaint(
                                      size: const Size(154, 154),
                                      painter: _DashRingPainter(
                                        AppColors.goldPremium
                                            .withValues(alpha: .55),
                                      ),
                                    ),
                                  ),
                                  // glow + logo
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.goldPremium
                                              .withValues(
                                                  alpha:
                                                      .18 + pulse * .22),
                                          blurRadius: 44 + pulse * 22,
                                          spreadRadius: 4,
                                        ),
                                        BoxShadow(
                                          color: AppColors.brandPrimary
                                              .withValues(
                                                  alpha:
                                                      .22 + pulse * .18),
                                          blurRadius: 70,
                                        ),
                                      ],
                                    ),
                                    child: child,
                                  ),
                                ],
                              );
                            },
                            child: const FarvixoLogo(size: 108),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ------------------- brand + tagline -------------------
                    FadeTransition(
                      opacity: CurvedAnimation(
                          parent: reveal, curve: const Interval(.35, 1)),
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [
                                AppColors.goldPremium,
                                AppColors.textPrimary,
                                AppColors.brandPrimaryHover,
                              ],
                            ).createShader(b),
                            child: Text(
                              AppConfig.appName.toUpperCase(),
                              style: AppTypography.displaySmall(context, color: AppColors.onAccent, weight: FontWeights.black).copyWith(letterSpacing: 6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI POWERED TOOLS ECOSYSTEM',
                            style: AppTypography.labelSmall(context, color: AppColors.lavender500, weight: FontWeights.semibold).copyWith(letterSpacing: 3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Smart Tools. AI Power. Limitless Possibilities.',
                            style: AppTypography.labelSmall(context, color: AppColors.slateMuted),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 3),

                    // ------------------- phase + progress -------------------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: Motion.slow,
                            transitionBuilder: (child, anim) =>
                                FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                        begin: const Offset(0, .4),
                                        end: Offset.zero)
                                    .animate(anim),
                                child: child,
                              ),
                            ),
                            child: Column(
                              key: ValueKey(phaseIndex),
                              children: [
                                Text(
                                  phase.title,
                                  style: AppTypography.titleMedium(context, color: AppColors.onAccent, weight: FontWeights.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  phase.subtitle,
                                  style: AppTypography.bodySmall(context, color: AppColors.lavender500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // gradient progress bar with glow head
                          ClipRRect(
                            borderRadius: Radii.brPill,
                            child: SizedBox(
                              height: 6,
                              child: LayoutBuilder(
                                builder: (context, c) => Stack(
                                  children: [
                                    Container(
                                        color: AppColors.onAccent
                                            .withValues(alpha: .08)),
                                    Container(
                                      width: c.maxWidth * shown,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [
                                          AppColors.brandPrimary,
                                          phase.accent,
                                        ]),
                                        boxShadow: [
                                          BoxShadow(
                                            color: phase.accent
                                                .withValues(alpha: .8),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${(shown * 100).round()}%',
                            style: AppTypography.bodyMedium(context, color: phase.accent, weight: FontWeights.extrabold),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Text(
                        'Version ${AppConfig.version}',
                        style: AppTypography.labelSmall(context, color: AppColors.slateMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// PAINTERS
// =============================================================================

/// Rainbow RGB energy ring (SweepGradient arc + orbiting spark).
class _RgbRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: c, radius: r);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          AppColors.goldPremium,
          AppColors.accentPink,
          AppColors.brandPrimaryHover,
          AppColors.accentDev,
          AppColors.accentCyanBright,
          AppColors.goldPremium,
        ],
      ).createShader(rect);
    canvas.drawArc(rect, 0, 2 * math.pi, false, ring);

    // bright spark at angle 0 (rotation supplied by parent Transform)
    final spark = Paint()
      ..color = AppColors.onAccent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(c.dx + r, c.dy), 5, spark);
  }

  @override
  bool shouldRepaint(_RgbRingPainter oldDelegate) => false;
}

class _DashRingPainter extends CustomPainter {
  _DashRingPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    const dashes = 20;
    for (var i = 0; i < dashes; i++) {
      final a = i * 2 * math.pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a,
          math.pi / dashes * .9, false, p);
    }
  }

  @override
  bool shouldRepaint(_DashRingPainter old) => old.color != color;
}

/// Galaxy particles + ambient rays; switches to star-warp streaks on the
/// final phase (§ MODULE 05 — Star Warp).
class _GalaxyPainter extends CustomPainter {
  _GalaxyPainter({required this.t, required this.accent, required this.warp});
  final double t;
  final Color accent;
  final bool warp;

  static final _stars = List.generate(90, (i) {
    final rnd = math.Random(i * 17 + 9);
    return (
      rnd.nextDouble(),          // x
      rnd.nextDouble(),          // y
      rnd.nextDouble() * 1.6 + .3, // radius
      rnd.nextDouble() * math.pi * 2, // twinkle phase
      rnd.nextDouble(),          // hue pick
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .38);

    // ambient light rays (slow rotation)
    final ray = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    for (var i = 0; i < 5; i++) {
      final a = t * 2 * math.pi * .15 + i * 2 * math.pi / 5;
      ray.color = accent.withValues(alpha: .05);
      final end = Offset(center.dx + math.cos(a) * size.height,
          center.dy + math.sin(a) * size.height);
      canvas.drawLine(center, end, ray..strokeWidth = 40);
    }

    // nebula orbs
    final orb = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
    orb.color = accent.withValues(alpha: .14);
    canvas.drawCircle(center, 150, orb);
    orb.color = AppColors.brandMagenta.withValues(alpha: .07);
    canvas.drawCircle(
        Offset(size.width * .85, size.height * .85), 130, orb);

    // stars — twinkle normally, streak outward in warp mode
    final p = Paint();
    for (final (x, y, r, phase, hue) in _stars) {
      final color = hue > .8
          ? AppColors.goldPremium
          : hue > .5
              ? AppColors.brandPrimaryHover
              : AppColors.onAccent;
      if (warp) {
        final pos = Offset(x * size.width, y * size.height);
        final dir = pos - center;
        final len = dir.distance == 0 ? const Offset(0, 1) : dir / dir.distance;
        final speed = 26 + r * 22;
        p
          ..color = color.withValues(alpha: .5)
          ..strokeWidth = r
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(pos, pos + len * speed, p);
        p.strokeWidth = 0;
      } else {
        final tw = .15 + (math.sin(t * 14 + phase) + 1) / 2 * .55;
        p.color = color.withValues(alpha: tw);
        canvas.drawCircle(Offset(x * size.width, y * size.height), r, p);
      }
    }
  }

  @override
  bool shouldRepaint(_GalaxyPainter old) =>
      old.t != t || old.accent != accent || old.warp != warp;
}

// =============================================================================
// ERROR FALLBACK
// =============================================================================
class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong!',
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge(context, color: AppColors.onAccent, weight: FontWeights.extrabold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.titleSmall(context, color: AppColors.lavender500),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                minimumSize: const Size(160, 48),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
