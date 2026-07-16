import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';

/// Main shell — 5-tab floating bottom navigation with a center 72dp AI orb
/// (docs/FARVIXO — HOME DASHBOARD.md §10: Home • Tools • AI • Favorites • Profile).
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _go(int index) => widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accent = cs.primary;
    // Raw system inset (gesture pill or 3-button nav bar). With edge-to-edge
    // the body draws behind it, so the floating nav must be lifted above it —
    // otherwise the Android nav buttons overlap the tab labels.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final mutedColor =
        isDark ? AppColors.textMuted : cs.onSurface.withValues(alpha: .45);
    // Dual-tone gradient derived from the custom accent so the AI orb and
    // selected state always follow the user's chosen colour.
    final accentGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [accent, Color.lerp(accent, AppColors.brandMagenta, .55)!],
    );

    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 12 + bottomInset),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.bgSurface : Colors.white)
                .withValues(alpha: isDark ? .92 : .97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .5 : .12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                selected: index == 0,
                accent: accent,
                accentGradient: accentGradient,
                mutedColor: mutedColor,
                onTap: () => _go(0),
              ),
              _NavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: 'Tools',
                selected: index == 1,
                accent: accent,
                accentGradient: accentGradient,
                mutedColor: mutedColor,
                onTap: () => _go(1),
              ),
              // -------- center AI orb (72dp, breathing glow) --------
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'AI Assistant',
                    child: GestureDetector(
                      onTap: () => _go(2),
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          final t = _pulse.value;
                          return SizedBox(
                            width: 72,
                            height: 72,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // rotating dashed ring
                                Transform.rotate(
                                  angle: t * math.pi,
                                  child: CustomPaint(
                                    size: const Size(66, 66),
                                    painter: _OrbRingPainter(
                                      color: index == 2
                                          ? AppColors.brandMagenta
                                          : accent,
                                      opacity: .45 + t * .4,
                                    ),
                                  ),
                                ),
                                // breathing core
                                Container(
                                  width: 52 + t * 3,
                                  height: 52 + t * 3,
                                  decoration: BoxDecoration(
                                    gradient: accentGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(
                                            alpha: .45 + t * .3),
                                        blurRadius: 20 + t * 12,
                                        spreadRadius: 1 + t * 2,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'AI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.favorite_outline_rounded,
                activeIcon: Icons.favorite_rounded,
                label: 'Favorites',
                selected: index == 3,
                accent: accent,
                accentGradient: accentGradient,
                mutedColor: mutedColor,
                onTap: () => _go(3),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                selected: index == 4,
                accent: accent,
                accentGradient: accentGradient,
                mutedColor: mutedColor,
                onTap: () => _go(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.accentGradient,
    required this.mutedColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color accent;
  final Gradient accentGradient;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: ShaderMask(
                  shaderCallback: (bounds) => (selected
                          ? accentGradient
                          : LinearGradient(
                              colors: [mutedColor, mutedColor]))
                      .createShader(bounds),
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: 23,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? accent : mutedColor,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbRingPainter extends CustomPainter {
  _OrbRingPainter({required this.color, required this.opacity});
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: opacity);
    // dashed arcs
    const segments = 4;
    for (var i = 0; i < segments; i++) {
      final start = i * (2 * math.pi / segments);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start,
          math.pi / segments, false, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbRingPainter old) =>
      old.opacity != opacity || old.color != color;
}
