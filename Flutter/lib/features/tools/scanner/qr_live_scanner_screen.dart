import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/design_tokens.dart';
import 'providers/qr_settings_provider.dart';

/// Live QR scanner — full-bleed camera viewfinder with a glass scan frame,
/// animated scan line, torch toggle and haptic feedback on detection.
///
/// Pushed with `Navigator.push` (no router change); pops with the decoded
/// string, or `null` when the user backs out.
class QrLiveScannerScreen extends ConsumerStatefulWidget {
  const QrLiveScannerScreen({super.key});

  @override
  ConsumerState<QrLiveScannerScreen> createState() =>
      _QrLiveScannerScreenState();
}

class _QrLiveScannerScreenState extends ConsumerState<QrLiveScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: Motion.breathe,
  )..repeat(reverse: true);

  bool _handled = false;
  bool _torchOn = false;
  bool _success = false;

  @override
  void dispose() {
    _scanLine.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    String? value;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        value = raw;
        break;
      }
    }
    _handleValue(value);
  }

  /// Shared success path for both live detection and gallery decode: give
  /// feedback, flash the frame green, then return the value.
  Future<void> _handleValue(String? value) async {
    if (_handled || !mounted || value == null || value.isEmpty) return;
    _handled = true;
    final settings = ref.read(qrSettingsProvider);
    if (settings.vibration) HapticFeedback.mediumImpact();
    if (settings.sound) SystemSound.play(SystemSoundType.click);
    setState(() => _success = true);
    // Brief green-frame confirmation before returning.
    await Future<void>.delayed(Motion.medium);
    if (mounted) Navigator.of(context).pop(value);
  }

  Future<void> _scanFromGallery() async {
    try {
      final file =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final capture = await _controller.analyzeImage(file.path);
      final value = capture?.barcodes
          .map((b) => b.rawValue)
          .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
      if (value == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('No QR code found in that image.'),
            ),
          );
        }
        return;
      }
      await _handleValue(value);
    } catch (_) {
      // Picker cancelled or decode failed — ignore.
    }
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
      backgroundColor: AppColors.scrim,
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
                    child: CustomPaint(
                      painter: _CornersPainter(
                        color: _success
                            ? AppColors.success
                            : AppColors.brandPrimaryHover,
                      ),
                    ),
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
                  Text(
                    'Scan QR Code',
                    style: AppTypography.titleMedium(
                      context,
                      color: AppColors.onAccent,
                      weight: FontWeights.extrabold,
                    ).copyWith(letterSpacing: .3),
                  ),
                  const Spacer(),
                  _RoundButton(
                    icon: Icons.history_rounded,
                    label: 'Scan history',
                    onTap: () => context.push('/qr-history'),
                  ),
                  const SizedBox(width: Insets.sm),
                  _RoundButton(
                    icon: Icons.tune_rounded,
                    label: 'Scanner settings',
                    onTap: () => context.push('/qr-settings'),
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
                    _GalleryButton(onTap: _scanFromGallery),
                    const SizedBox(height: Insets.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Insets.md, vertical: Insets.sm),
                      decoration: BoxDecoration(
                        color: AppColors.scrim.withValues(alpha: .45),
                        borderRadius: Radii.brPill,
                        border: Border.all(
                          color: AppColors.onAccent.withValues(alpha: .15),
                        ),
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _success
                              ? 'QR code detected'
                              : 'Point your camera at a QR code',
                          style: AppTypography.bodyMedium(context, color: _success ? AppColors.success : AppColors.onAccent, weight: FontWeights.semibold),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      'Decoded on-device • nothing leaves your phone',
                      style: AppTypography.labelSmall(context, color: AppColors.onAccent.withValues(alpha: .55)),
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

/// Pill button to decode a QR from a gallery image.
class _GalleryButton extends StatelessWidget {
  const _GalleryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan from a photo',
      child: InkWell(
        borderRadius: Radii.brPill,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg, vertical: Insets.sm + 2),
          decoration: BoxDecoration(
            color: AppColors.onAccent.withValues(alpha: .12),
            borderRadius: Radii.brPill,
            border: Border.all(color: AppColors.onAccent.withValues(alpha: .3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_rounded,
                  size: 18, color: AppColors.onAccent),
              const SizedBox(width: Insets.sm),
              Text(
                'Scan from photo',
                style: AppTypography.bodyMedium(
                  context,
                  color: AppColors.onAccent,
                  weight: FontWeights.bold,
                ),
              ),
            ],
          ),
        ),
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
                : AppColors.scrim.withValues(alpha: .45),
            border: Border.all(
              color: active
                  ? AppColors.goldPremium
                  : AppColors.onAccent.withValues(alpha: .2),
            ),
          ),
          child: Icon(
            icon,
            size: 21,
            color: active ? AppColors.goldPremium : AppColors.onAccent,
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
      Paint()..color = AppColors.scrim.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.window != window;
}

/// Accent corner brackets around the scan window.
class _CornersPainter extends CustomPainter {
  _CornersPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 30.0;
    final paint = Paint()
      ..color = color
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
  bool shouldRepaint(_CornersPainter old) => old.color != color;
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
      color: AppColors.scrim,
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
            style: AppTypography.titleLarge(context, color: AppColors.onAccent, weight: FontWeights.extrabold),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            denied
                ? 'Allow camera access in Settings to scan QR codes live — '
                    'or go back and scan from a photo instead.'
                : 'Could not start the camera. You can still scan from a '
                    'photo instead.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(context, color: AppColors.onAccent.withValues(alpha: .7)).copyWith(height: 1.5),
          ),
          const SizedBox(height: Insets.lg),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.image_rounded, size: 18),
            label: const Text('Scan from photo instead'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onAccent,
              side: BorderSide(color: AppColors.onAccent.withValues(alpha: .4)),
            ),
          ),
        ],
      ),
    );
  }
}
