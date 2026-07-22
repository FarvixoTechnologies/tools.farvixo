import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/premium_kit.dart';
import 'services/qr_payload_builder.dart';

/// The generator supports these payload kinds (a curated subset of [QrType]).
enum GenKind { url, text, wifi, email, phone, sms, contact, location, upi }

extension _GenKindX on GenKind {
  String get label => switch (this) {
        GenKind.url => 'URL',
        GenKind.text => 'Text',
        GenKind.wifi => 'Wi-Fi',
        GenKind.email => 'Email',
        GenKind.phone => 'Phone',
        GenKind.sms => 'SMS',
        GenKind.contact => 'Contact',
        GenKind.location => 'Location',
        GenKind.upi => 'UPI',
      };

  IconData get icon => switch (this) {
        GenKind.url => Icons.link_rounded,
        GenKind.text => Icons.notes_rounded,
        GenKind.wifi => Icons.wifi_rounded,
        GenKind.email => Icons.mail_rounded,
        GenKind.phone => Icons.phone_rounded,
        GenKind.sms => Icons.sms_rounded,
        GenKind.contact => Icons.person_rounded,
        GenKind.location => Icons.location_on_rounded,
        GenKind.upi => Icons.payments_rounded,
      };

  /// Field keys shown for this kind.
  List<String> get fields => switch (this) {
        GenKind.url => ['url'],
        GenKind.text => ['text'],
        GenKind.wifi => ['ssid', 'password'],
        GenKind.email => ['address', 'subject', 'body'],
        GenKind.phone => ['number'],
        GenKind.sms => ['number', 'message'],
        GenKind.contact => ['name', 'phone', 'email', 'org'],
        GenKind.location => ['lat', 'lng'],
        GenKind.upi => ['vpa', 'name', 'amount', 'note'],
      };
}

/// QR generator: type tabs, per-type form, live preview, colour options and
/// PNG export/share. Reuses the Farvixo premium kit + qr_flutter (already a
/// dependency). Encodes payloads via [QrPayloadBuilder] so they round-trip
/// with the scanner's parser.
class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final _previewKey = GlobalKey();
  final _controllers = <String, TextEditingController>{};
  GenKind _kind = GenKind.url;
  Color _fg = AppColors.bgBase;
  bool _rounded = true;

  TextEditingController _ctrl(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _payload {
    String v(String k) => _ctrl(k).text.trim();
    return switch (_kind) {
      GenKind.url => QrPayloadBuilder.url(v('url')),
      GenKind.text => QrPayloadBuilder.text(_ctrl('text').text),
      GenKind.wifi =>
        QrPayloadBuilder.wifi(ssid: v('ssid'), password: v('password')),
      GenKind.email => QrPayloadBuilder.email(
          address: v('address'), subject: v('subject'), body: v('body')),
      GenKind.phone => QrPayloadBuilder.phone(v('number')),
      GenKind.sms =>
        QrPayloadBuilder.sms(number: v('number'), message: v('message')),
      GenKind.contact => QrPayloadBuilder.vcard(
          name: v('name'), phone: v('phone'), email: v('email'), org: v('org')),
      GenKind.location => QrPayloadBuilder.geo(v('lat'), v('lng')),
      GenKind.upi => QrPayloadBuilder.upi(
          vpa: v('vpa'), name: v('name'), amount: v('amount'), note: v('note')),
    };
  }

  bool get _hasContent => switch (_kind) {
        GenKind.wifi => _ctrl('ssid').text.trim().isNotEmpty,
        GenKind.location =>
          _ctrl('lat').text.trim().isNotEmpty && _ctrl('lng').text.trim().isNotEmpty,
        GenKind.upi => _ctrl('vpa').text.trim().isNotEmpty,
        _ => _ctrl(_kind.fields.first).text.trim().isNotEmpty,
      };

  Future<void> _exportPng() async {
    try {
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/farvixo-qr-${_kind.name}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Export failed: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final payload = _payload;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.md, Insets.sm, Insets.md, 0),
                child: FadeSlideIn(
                  child: PremiumHeader(
                    title: 'QR Generator',
                    subtitle: _kind.label,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                      Insets.md, Insets.md, Insets.md, Insets.xxl),
                  children: [
                    _kindTabs(),
                    const SizedBox(height: Insets.md),
                    _preview(p, payload),
                    const SizedBox(height: Insets.md),
                    _form(),
                    const SizedBox(height: Insets.md),
                    _styleRow(p),
                    const SizedBox(height: Insets.lg),
                    _actions(payload),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindTabs() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final k in GenKind.values) ...[
            _KindChip(
              kind: k,
              active: k == _kind,
              onTap: () => setState(() => _kind = k),
            ),
            const SizedBox(width: Insets.sm),
          ],
        ],
      ),
    );
  }

  Widget _preview(AppPalette p, String payload) {
    return Center(
      child: RepaintBoundary(
        key: _previewKey,
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: AppColors.onAccent,
            borderRadius: Radii.brCard,
          ),
          child: _hasContent
              ? QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: AppColors.onAccent,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: _fg,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: _rounded
                        ? QrDataModuleShape.circle
                        : QrDataModuleShape.square,
                    color: _fg,
                  ),
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                )
              : const SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(
                    child: Icon(Icons.qr_code_2_rounded,
                        size: 96, color: AppColors.lightTextMuted),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _form() {
    return GlassCard(
      child: Column(
        children: [
          for (final field in _kind.fields) ...[
            if (field != _kind.fields.first) const SizedBox(height: Insets.sm),
            TextField(
              controller: _ctrl(field),
              onChanged: (_) => setState(() {}),
              keyboardType: _keyboardFor(field),
              obscureText: field == 'password',
              minLines: field == 'body' || field == 'text' ? 2 : 1,
              maxLines: field == 'body' || field == 'text' ? 4 : 1,
              decoration: InputDecoration(
                isDense: true,
                labelText: _labelFor(field),
                border: const OutlineInputBorder(borderRadius: Radii.brButton),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _styleRow(AppPalette p) {
    const swatches = AppColors.qrSwatches;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Style',
              style: AppTypography.bodyMedium(context, color: p.textPrimary, weight: FontWeights.extrabold)),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              for (final c in swatches) ...[
                _Swatch(
                    color: c, selected: _fg == c, onTap: () => setState(() => _fg = c)),
                const SizedBox(width: Insets.sm),
              ],
              const Spacer(),
              Semantics(
                label: 'Rounded modules',
                child: IconButton(
                  tooltip: _rounded ? 'Square modules' : 'Rounded modules',
                  onPressed: () => setState(() => _rounded = !_rounded),
                  icon: Icon(
                    _rounded ? Icons.blur_on_rounded : Icons.grid_on_rounded,
                    color: p.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actions(String payload) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _hasContent ? _exportPng : null,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Save / Share PNG'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
        const SizedBox(width: Insets.sm),
        OutlinedButton(
          onPressed: _hasContent
              ? () {
                  Clipboard.setData(ClipboardData(text: payload));
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Payload copied'),
                    ),
                  );
                }
              : null,
          style: OutlinedButton.styleFrom(minimumSize: const Size(52, 50)),
          child: const Icon(Icons.copy_rounded),
        ),
      ],
    );
  }

  TextInputType? _keyboardFor(String field) => switch (field) {
        'number' || 'phone' => TextInputType.phone,
        'address' || 'email' => TextInputType.emailAddress,
        'url' => TextInputType.url,
        'lat' || 'lng' || 'amount' =>
          const TextInputType.numberWithOptions(decimal: true, signed: true),
        _ => null,
      };

  String _labelFor(String field) => switch (field) {
        'url' => 'URL',
        'ssid' => 'Network name (SSID)',
        'vpa' => 'UPI ID (VPA)',
        'org' => 'Organisation',
        'lat' => 'Latitude',
        'lng' => 'Longitude',
        _ => field[0].toUpperCase() + field.substring(1),
      };
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.active, required this.onTap});
  final GenKind kind;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: active,
      label: kind.label,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: active ? AppColors.brandGradient : null,
            color: active ? null : p.surface.withValues(alpha: 0.5),
            borderRadius: Radii.brPill,
            border: Border.all(color: active ? Colors.transparent : p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(kind.icon,
                  size: 15, color: active ? AppColors.onAccent : p.textSecondary),
              const SizedBox(width: 6),
              Text(kind.label,
                  style: AppTypography.bodySmall(context, color: active ? AppColors.onAccent : p.textSecondary, weight: FontWeights.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'QR colour',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? p.accent : p.border,
              width: selected ? 2.4 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
