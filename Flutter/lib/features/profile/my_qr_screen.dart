import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_details_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../theme/design_tokens.dart';
import '../../utils/profile_link.dart';
import '../../widgets/premium_kit.dart';

/// Full-screen My QR — generate, preview, copy, share, and save.
class MyQrScreen extends ConsumerStatefulWidget {
  const MyQrScreen({super.key});

  @override
  ConsumerState<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends ConsumerState<MyQrScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _captureCardPng() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Future<File?> _writeTempPng(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.brButton),
      ),
    );
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    HapticFeedback.selectionClick();
    _snack('Profile link copied');
  }

  Future<void> _shareLink(String displayName, String url) async {
    HapticFeedback.selectionClick();
    await Share.share(
      ProfileLink.shareText(displayName: displayName, url: url),
      subject: '$displayName · Farvixo',
    );
  }

  Future<void> _shareQrImage(String displayName, String url) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _captureCardPng();
      if (png == null) {
        _snack('Couldn’t capture QR', error: true);
        return;
      }
      final file = await _writeTempPng(png, 'farvixo-qr');
      if (file == null) {
        _snack('Couldn’t save QR temporarily', error: true);
        return;
      }
      HapticFeedback.mediumImpact();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'farvixo-my-qr.png')],
        text: ProfileLink.shareText(displayName: displayName, url: url),
        subject: '$displayName · Farvixo QR',
      );
    } catch (_) {
      _snack('Share failed. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveQr() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _captureCardPng();
      if (png == null) {
        _snack('Couldn’t capture QR', error: true);
        return;
      }
      final file = await _writeTempPng(png, 'farvixo-qr');
      if (file == null) {
        _snack('Couldn’t prepare file', error: true);
        return;
      }
      HapticFeedback.mediumImpact();
      // System share sheet doubles as “Save to Files / Photos / Drive”.
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'farvixo-my-qr.png')],
        subject: 'Farvixo My QR',
      );
      if (mounted) _snack('Use the share sheet to save your QR');
    } catch (_) {
      _snack('Save failed. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final user = ref.watch(authProvider);
    final details = ref.watch(profileDetailsProvider);
    final displayName = details.displayName.isNotEmpty
        ? details.displayName
        : (user?.displayName ?? 'Guest');
    final handle = ProfileLink.handle(user: user, details: details);
    final url = ProfileLink.forUser(user: user, details: details);
    final avatarUrl = details.avatarUrl ?? user?.avatarUrl;
    final isGuest = user == null || user.isGuest;
    final isPro = user?.isPro ?? false;
    final bg = p.isDark ? AppColors.zincBase : p.bg;

    return Scaffold(
      backgroundColor: bg,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onClose: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Text(
                      'My QR',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineLarge(context, color: p.textPrimary, weight: FontWeights.black).copyWith(letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isGuest
                          ? 'Scan to open Farvixo Tools. Sign in for your personal profile link.'
                          : 'Others can scan this code to open your Farvixo profile.',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleSmall(context, color: p.textSecondary).copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: _QrCard(
                          data: url,
                          displayName: displayName,
                          handle: handle,
                          avatarUrl: avatarUrl,
                          isPro: isPro,
                          isGuest: isGuest,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _LinkChip(
                      url: url,
                      onCopy: () => _copyLink(url),
                    ),
                    const SizedBox(height: 24),
                    _ActionGrid(
                      busy: _busy,
                      onShareQr: () => _shareQrImage(displayName, url),
                      onShareLink: () => _shareLink(displayName, url),
                      onCopy: () => _copyLink(url),
                      onSave: _saveQr,
                    ),
                    if (isGuest) ...[
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: () => context.push('/login'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.accent,
                          side: BorderSide(color: p.accent.withValues(alpha: 0.5)),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: Radii.brCard,
                          ),
                        ),
                        child: const Text('Sign in for a personal QR'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: p.textPrimary),
          ),
          const Spacer(),
          Text(
            'Profile QR',
            style: AppTypography.titleMedium(context, color: p.textPrimary, weight: FontWeights.extrabold),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.data,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.isPro,
    required this.isGuest,
  });

  final String data;
  final String displayName;
  final String handle;
  final String? avatarUrl;
  final bool isPro;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final cardBg = p.isDark ? AppColors.zincSurface : AppColors.onAccent;

    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: Radii.brSheet,
        border: Border.all(color: p.border.withValues(alpha: 0.7)),
        boxShadow: Elevations.raised(p),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _MiniAvatar(url: avatarUrl, name: displayName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium(context, color: p.textPrimary, weight: FontWeights.extrabold),
                          ),
                        ),
                        if (isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: Radii.brPill,
                              gradient: AppColors.goldGradient,
                            ),
                            child: Text(
                              'PRO',
                              style: AppTypography.caption(context, color: AppColors.lightTextPrimary, weight: FontWeights.black),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      handle,
                      style: AppTypography.bodyMedium(context, color: AppColors.brandPrimaryHover, weight: FontWeights.semibold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.onAccent,
              borderRadius: Radii.brPanel,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimaryHover.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: AppColors.onAccent,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.bgBase,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: AppColors.bgBase,
              ),
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              embeddedImageStyle: const QrEmbeddedImageStyle(
                size: Size(44, 44),
              ),
              embeddedImage: const AssetImage('assets/logo/farvixo_logo.png'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'FARVIXO',
            style: AppTypography.labelMedium(context, color: p.textMuted, weight: FontWeights.black).copyWith(letterSpacing: 2.4),
          ),
          const SizedBox(height: 2),
          Text(
            isGuest ? 'tools.farvixo.com' : 'Scan to connect',
            style: AppTypography.labelMedium(context, color: p.textSecondary, weight: FontWeights.semibold),
          ),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : 'F';
    Widget child;
    if (url != null && url!.isNotEmpty) {
      if (url!.startsWith('http')) {
        child = Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (ctx, _, _) => _fallback(ctx, initial, p),
        );
      } else {
        child = Image.file(
          File(url!),
          fit: BoxFit.cover,
          errorBuilder: (ctx, _, _) => _fallback(ctx, initial, p),
        );
      }
    } else {
      child = _fallback(context, initial, p);
    }

    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.brandPrimaryHover, AppColors.fuchsia],
        ),
      ),
      child: ClipOval(child: ColoredBox(color: p.surface, child: child)),
    );
  }

  Widget _fallback(BuildContext context, String initial, AppPalette p) {
    return ColoredBox(
      color: p.surface2,
      child: Center(
        child: Text(
          initial,
          style: AppTypography.titleLarge(
            context,
            color: p.accent,
            weight: FontWeights.extrabold,
          ),
        ),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.url, required this.onCopy});

  final String url;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCopy,
        borderRadius: Radii.brCard,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.isDark ? AppColors.inputDark : p.surface2,
            borderRadius: Radii.brCard,
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: p.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(context, color: p.textSecondary, weight: FontWeights.semibold),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.copy_rounded, size: 18, color: p.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.busy,
    required this.onShareQr,
    required this.onShareLink,
    required this.onCopy,
    required this.onSave,
  });

  final bool busy;
  final VoidCallback onShareQr;
  final VoidCallback onShareLink;
  final VoidCallback onCopy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PrimaryAction(
                label: busy ? 'Working…' : 'Share QR',
                icon: Icons.qr_code_2_rounded,
                onTap: busy ? null : onShareQr,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SecondaryAction(
                label: 'Share Link',
                icon: Icons.ios_share_rounded,
                onTap: busy ? null : onShareLink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SecondaryAction(
                label: 'Copy Link',
                icon: Icons.copy_all_rounded,
                onTap: busy ? null : onCopy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SecondaryAction(
                label: 'Save Image',
                icon: Icons.download_rounded,
                onTap: busy ? null : onSave,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.brCard,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: Radii.brCard,
            gradient: onTap == null
                ? null
                : const LinearGradient(
                    colors: [AppColors.brandPrimaryHover, AppColors.fuchsia],
                  ),
            color: onTap == null ? AppColors.inputDarkBorder : null,
            boxShadow: onTap == null
                ? null
                : [
                    BoxShadow(
                      color: AppColors.brandPrimaryHover.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.onAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.titleSmall(context, color: AppColors.onAccent, weight: FontWeights.extrabold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.brCard,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: Radii.brCard,
            color: p.isDark ? AppColors.inputDark : p.surface2,
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: p.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.bodyMedium(context, color: p.textPrimary, weight: FontWeights.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens My QR from Profile / Settings quick actions.
Future<void> openMyQr(BuildContext context) async {
  await context.push('/profile/qr');
}
