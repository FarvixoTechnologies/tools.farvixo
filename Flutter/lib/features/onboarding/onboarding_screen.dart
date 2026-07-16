import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/farvixo_logo.dart';

/// FARVIXO — Onboarding v3.0 (3 pages, per LAUNCH/LOADING/ONBOARDING spec):
///
///   01  Welcome to Farvixo             — floating tool icons orbit the crown
///   02  AI Powered Smart Experience    — glowing AI-chip phone + holograms
///   03  Secure. Private. Always Reliable — shield + lock + scan line
///
/// SKIP on every page · arrow Next · GET STARTED on the last page →
/// Authentication (/login).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const _pageCount = 3;

  final _controller = PageController();
  int _index = 0;

  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(seconds: 10))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    _loop.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pageCount - 1;

  Future<void> _finish() async {
    await ref.read(storageServiceProvider).setOnboardingDone();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.animateToPage(
      _index + 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05010F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // starfield backdrop
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _loop,
              builder: (context, _) =>
                  CustomPaint(painter: _StarsPainter(_loop.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: [
                      _OnboardPage(
                        titleTop: 'Welcome to',
                        titleAccent: 'Farvixo',
                        accentGradient: const [
                          Color(0xFFF5B93D),
                          Color(0xFFC026D3)
                        ],
                        description:
                            'All-in-one platform with 120+ smart tools to simplify your work and life.',
                        visual: _ToolsOrbitVisual(loop: _loop),
                      ),
                      _OnboardPage(
                        titleTop: 'AI Powered',
                        titleAccent: 'Smart Experience',
                        accentGradient: const [
                          Color(0xFF8B5CF6),
                          Color(0xFF22D3EE)
                        ],
                        description:
                            'Advanced AI features to make your tasks faster, smarter and easier.',
                        visual: _AiPhoneVisual(loop: _loop),
                      ),
                      _OnboardPage(
                        titleTop: 'Secure. Private.',
                        titleAccent: 'Always Reliable',
                        accentGradient: const [
                          Color(0xFF8B5CF6),
                          Color(0xFF3B82F6)
                        ],
                        description:
                            'Your data is encrypted and 100% private with cloud sync anywhere.',
                        visual: _ShieldVisual(loop: _loop),
                      ),
                    ],
                  ),
                ),

                // ---------------- dots ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pageCount; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient:
                              i == _index ? AppColors.brandGradient : null,
                          color: i == _index
                              ? null
                              : AppColors.textMuted.withValues(alpha: .35),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ---------------- bottom bar ----------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 24, 26),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _finish,
                        child: const Text(
                          'SKIP',
                          style: TextStyle(
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child:
                                FadeTransition(opacity: anim, child: child)),
                        child: _isLast
                            ? _GetStartedButton(
                                key: const ValueKey('start'),
                                onTap: _next,
                              )
                            : _NextOrb(
                                key: const ValueKey('next'),
                                onTap: _next,
                              ),
                      ),
                    ],
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

// =============================================================================
// PAGE SHELL
// =============================================================================
class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.titleTop,
    required this.titleAccent,
    required this.accentGradient,
    required this.description,
    required this.visual,
  });

  final String titleTop;
  final String titleAccent;
  final List<Color> accentGradient;
  final String description;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          const Spacer(flex: 2),
          SizedBox(height: 300, child: Center(child: visual)),
          const Spacer(flex: 2),
          Text(
            titleTop,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          ShaderMask(
            shaderCallback: (b) =>
                LinearGradient(colors: accentGradient).createShader(b),
            child: Text(
              titleAccent,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// =============================================================================
// PAGE 1 VISUAL — crown logo + orbiting tool icons on glow platform
// =============================================================================
class _ToolsOrbitVisual extends StatelessWidget {
  const _ToolsOrbitVisual({required this.loop});
  final AnimationController loop;

  static const _icons = [
    (Icons.picture_as_pdf_rounded, AppColors.accentPdf),
    (Icons.photo_camera_rounded, AppColors.accentImage),
    (Icons.build_rounded, AppColors.goldPremium),
    (Icons.code_rounded, AppColors.accentDev),
    (Icons.image_rounded, AppColors.brandPrimaryHover),
    (Icons.settings_rounded, AppColors.accentText),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = loop.value;
        final bob = math.sin(t * 2 * math.pi * 2) * 6;
        return SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // glow platform
              Positioned(
                bottom: 24,
                child: Container(
                  width: 190,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: RadialGradient(colors: [
                      AppColors.accentText.withValues(alpha: .5),
                      AppColors.brandPrimary.withValues(alpha: .15),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              // orbiting hex tool chips
              for (var i = 0; i < _icons.length; i++)
                Transform.translate(
                  offset: Offset(
                    math.cos(t * 2 * math.pi * .5 +
                            i * 2 * math.pi / _icons.length) *
                        118,
                    math.sin(t * 2 * math.pi * .5 +
                                i * 2 * math.pi / _icons.length) *
                            72 -
                        16,
                  ),
                  child: _HexChip(icon: _icons[i].$1, color: _icons[i].$2),
                ),
              // floating crown logo
              Transform.translate(
                offset: Offset(0, bob - 14),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldPremium.withValues(alpha: .3),
                        blurRadius: 46,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const FarvixoLogo(size: 120),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HexChip extends StatelessWidget {
  const _HexChip({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .3), blurRadius: 12),
        ],
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

// =============================================================================
// PAGE 2 VISUAL — phone with pulsing AI chip + floating holo chips
// =============================================================================
class _AiPhoneVisual extends StatelessWidget {
  const _AiPhoneVisual({required this.loop});
  final AnimationController loop;

  static const _holo = [
    (Icons.auto_awesome_rounded, Offset(-120, -80)),
    (Icons.chat_bubble_outline_rounded, Offset(118, -66)),
    (Icons.image_outlined, Offset(126, 40)),
    (Icons.translate_rounded, Offset(-126, 30)),
    (Icons.mic_none_rounded, Offset(-96, 110)),
    (Icons.code_rounded, Offset(104, 118)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = loop.value;
        final pulse = (math.sin(t * 2 * math.pi * 3) + 1) / 2;
        return SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // energy ring on floor
              Positioned(
                bottom: 12,
                child: Container(
                  width: 200,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.brandPrimaryHover
                          .withValues(alpha: .3 + pulse * .3),
                    ),
                  ),
                ),
              ),
              // floating holo chips
              for (final (icon, off) in _holo)
                Transform.translate(
                  offset: off +
                      Offset(0, math.sin(t * 2 * math.pi * 2 + off.dx) * 6),
                  child: _HexChip(
                      icon: icon, color: AppColors.brandPrimaryHover),
                ),
              // phone
              Transform.translate(
                offset: Offset(0, math.sin(t * 2 * math.pi * 1.5) * 7),
                child: Container(
                  width: 128,
                  height: 226,
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                        color: AppColors.brandPrimaryHover
                            .withValues(alpha: .6),
                        width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimary
                            .withValues(alpha: .3 + pulse * .25),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    // AI chip
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandMagenta
                                .withValues(alpha: .5 + pulse * .4),
                            blurRadius: 22 + pulse * 14,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// PAGE 3 VISUAL — shield + lock + cloud + scan line
// =============================================================================
class _ShieldVisual extends StatelessWidget {
  const _ShieldVisual({required this.loop});
  final AnimationController loop;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = loop.value;
        final pulse = (math.sin(t * 2 * math.pi * 2) + 1) / 2;
        final scanY = (math.sin(t * 2 * math.pi * 1.2) + 1) / 2;
        return SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // cloud outline behind
              Positioned(
                top: 26,
                child: Icon(
                  Icons.cloud_outlined,
                  size: 200,
                  color: AppColors.accentDev
                      .withValues(alpha: .16 + pulse * .08),
                ),
              ),
              // energy base
              Positioned(
                bottom: 18,
                child: Container(
                  width: 180,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: RadialGradient(colors: [
                      AppColors.brandMagenta.withValues(alpha: .4),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              // shield
              Transform.translate(
                offset: Offset(0, math.sin(t * 2 * math.pi * 1.5) * 6),
                child: Container(
                  width: 150,
                  height: 170,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.brandPrimary.withValues(alpha: .35),
                        AppColors.accentDev.withValues(alpha: .18),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                      bottomLeft: Radius.circular(75),
                      bottomRight: Radius.circular(75),
                    ),
                    border: Border.all(
                        color: AppColors.brandPrimaryHover
                            .withValues(alpha: .7),
                        width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimary
                            .withValues(alpha: .35 + pulse * .25),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // scan line
                      Positioned(
                        top: 14 + scanY * 120,
                        left: 16,
                        right: 16,
                        child: Container(
                          height: 2.4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              AppColors.accentText.withValues(alpha: .9),
                              Colors.transparent,
                            ]),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentText
                                    .withValues(alpha: .7),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // glowing lock
                      Icon(
                        Icons.lock_rounded,
                        size: 58,
                        color: Color.lerp(
                          AppColors.brandPrimaryHover,
                          AppColors.brandMagenta,
                          pulse,
                        ),
                        shadows: [
                          Shadow(
                            color: AppColors.brandMagenta
                                .withValues(alpha: .8),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// BUTTONS
// =============================================================================
class _NextOrb extends StatelessWidget {
  const _NextOrb({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Next',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary.withValues(alpha: .5),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Get Started',
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary.withValues(alpha: .5),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GET STARTED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BACKDROP
// =============================================================================
class _StarsPainter extends CustomPainter {
  _StarsPainter(this.t);
  final double t;

  static final _stars = List.generate(60, (i) {
    final rnd = math.Random(i * 23 + 11);
    return (
      rnd.nextDouble(),
      rnd.nextDouble(),
      rnd.nextDouble() * 1.4 + .3,
      rnd.nextDouble() * math.pi * 2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final orb = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    orb.color = AppColors.brandPrimary.withValues(alpha: .10);
    canvas.drawCircle(Offset(size.width * .2, size.height * .2), 120, orb);
    orb.color = AppColors.brandMagenta.withValues(alpha: .07);
    canvas.drawCircle(Offset(size.width * .85, size.height * .75), 120, orb);

    final p = Paint();
    for (final (x, y, r, phase) in _stars) {
      final tw = .12 + (math.sin(t * 12 + phase) + 1) / 2 * .4;
      p.color = Colors.white.withValues(alpha: tw);
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, p);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.t != t;
}
