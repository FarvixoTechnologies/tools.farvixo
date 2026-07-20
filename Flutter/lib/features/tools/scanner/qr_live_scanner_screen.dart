import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/design_tokens.dart';

/// Live QR scanner — full-bleed camera viewfinder with a glass scan frame,
/// animated scan line, torch toggle and haptic feedback on detection.
///
/// Pushed with `Navigator.push` (no router change); pops with the decoded
/// string, or `null` when the user backs out.
class QrLiveScannerScreen extends StatefulWidget {
  const QrLiveScannerScreen({super.key});

  @override
  State<QrLiveScannerScreen> createState() => _QrLiveScannerScreenState();
}

class _QrLiveScannerScreenState extends State<QrLiveScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _scanLine.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    String? value;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        value = raw;
        break;
      }
    }
    if (value == null) return;
    _handled = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(value);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Torch unavailable on this device — ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final window = (size.width * 0.72).clamp(220.0, 340.0);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),

          // Dark scrim with a transparent scan window.
          Positioned.fill(
            child: CustomPaint(
              painter: _ScrimPainter(window: window),
            ),
          ),

          // Corner brackets + animated scan line.
          Center(
            child: SizedBox(
              width: window,
              height: window,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _CornersPainter()),
                  ),
                  if (!reduceMotion)
                    AnimatedBuilder(
                      animation: _scanLine,
                      builder: (context, _) => Align(
                        alignment:
                            Alignment(0, _scanLine.value * 2 - 1),
                        child: Container(
                          height: 2.4,
                          margin: const EdgeInsets.symmetric(
                              horizontal: Insets.md),
                          decoration: BoxDecoration(
                            borderRadius: Radii.brPill,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.brandPrimaryHover
                                    .withValues(alpha: 0),
                                AppColors.brandPrimaryHover,
                                AppColors.brandPrimaryHover
                                    .withValues(alpha: 0),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandPrimaryHover
                                    .withValues(alpha: .6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Top bar: back · title · torch.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.md, Insets.sm, Insets.md, 0),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                    ),
                  ),
                  const Spacer(),
                  _RoundButton(
                    icon: Icons.history_rounded,
                    label: 'Scan history',
                    onTap: () => context.push('/qr-history'),
                  ),
                  const SizedBox(width: Insets.sm),
                  _RoundButton(
                    icon: _torchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    label: _torchOn ? 'Torch off' : 'Torch on',
                    active: _torchOn,
                    onTap: _toggleTorch,
                  ),
                ],
              ),
            ),
          ),

          // Bottom hint.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: Insets.xl,
                  top: Insets.md,
                  left: Insets.lg,
                  right: Insets.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Insets.md, vertical: Insets.sm),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .45),
                        borderRadius: Radii.brPill,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .15),
                        ),
                      ),
                      child: const Text(
                        'Point your camera at a QR code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      'Decoded on-device • nothing leaves your phone',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular translucent control button on the camera overlay.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppColors.goldPremium.withValues(alpha: .25)
                : Colors.black.withValues(alpha: .45),
            border: Border.all(
              color: active
                  ? AppColors.goldPremium
                  : Colors.white.withValues(alpha: .2),
            ),
          ),
          child: Icon(
            icon,
            size: 21,
            color: active ? AppColors.goldPremium : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Darkens everything outside the centered scan window.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.window});

  final double window;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: window,
          height: window,
        ),
        const Radius.circular(Radii.panel),
      ));
    final scrim = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.window != window;
}

/// Accent corner brackets around the scan window.
class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 30.0;
    final paint = Paint()
      ..color = AppColors.brandPrimaryHover
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    const r = Radii.panel;
    final w = size.width, h = size.height;
    // Four corners, arcs following the window's rounded corners.
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - len, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, len),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h - len)
        ..lineTo(w, h - r)
        ..quadraticBezierTo(w, h, w - r, h)
        ..lineTo(w - len, h),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(len, h)
        ..lineTo(r, h)
        ..quadraticBezierTo(0, h, 0, h - r)
        ..lineTo(0, h - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornersPainter old) => false;
}

/// Friendly camera error / permission state.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            denied
                ? Icons.no_photography_rounded
                : Icons.videocam_off_rounded,
            size: 52,
            color: AppColors.lavender300,
          ),
          const SizedBox(height: Insets.md),
          Text(
            denied ? 'Camera permission needed' : 'Camera unavailable',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            denied
                ? 'Allow camera access in Settings to scan QR codes live — '
                    'or go back and scan from a photo instead.'
                : 'Could not start the camera. You can still scan from a '
                    'photo instead.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .7),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: Insets.lg),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.image_rounded, size: 18),
            label: const Text('Scan from photo instead'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: .4)),
            ),
          ),
        ],
      ),
    );
  }
}
